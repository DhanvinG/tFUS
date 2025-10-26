# train.py  (paper-matched losses + global target scaling + scheduler guard)

import os, glob, h5py, torch, numpy as np
from torch import nn, optim
from torch.utils.data import Dataset, DataLoader
import torch.nn.functional as F

from models.generator     import Generator3D
from models.discriminator import Discriminator3D

EPS = 1e-8

class UltrasoundDataset(Dataset):
    def __init__(self, ct_folder, p_folder, p_ref=None, q=99.5):
        """
        p_ref: global amplitude reference (float). If None, compute as the median of the
               q-th percentile across all training P maps. Use the same value for val.
        q    : percentile used to form a robust per-volume peak estimate before aggregating.
        """
        self.ct_files = sorted(glob.glob(os.path.join(ct_folder, '*_CT.mat')))
        self.p_files  = sorted(glob.glob(os.path.join(p_folder,  '*_P.mat')))
        assert len(self.ct_files) == len(self.p_files), "Mismatched CT/P file counts"

        if p_ref is not None:
            self.p_ref = float(p_ref)
        else:
            vals = []
            for pf in self.p_files:
                with h5py.File(pf, 'r') as f:
                    a = np.asarray(f['p_map'])
                    a = np.nan_to_num(a, nan=0.0, posinf=0.0, neginf=0.0)
                    vals.append(np.percentile(a, q))
            self.p_ref = float(np.median(vals)) if vals else 1.0
            if self.p_ref <= 0:
                self.p_ref = 1.0

    def __len__(self): 
        return len(self.ct_files)

    def __getitem__(self, idx):
        # ---- CT + mask ----
        with h5py.File(self.ct_files[idx], 'r') as f:
            ct     = torch.from_numpy(f['ct'][()]).float()
            lens_m = torch.from_numpy(f['lens_mask'][()]).float()

        # Axis fix -> (D,H,W) with D=160
        if ct.shape == (160, 100, 100):
            pass
        elif ct.shape == (100, 100, 160):
            ct, lens_m = ct.permute(2,0,1), lens_m.permute(2,0,1)
        elif 160 in ct.shape and ct.shape.count(100) >= 2:
            k = list(ct.shape).index(160)
            ct, lens_m = ct.movedim(k, 0), lens_m.movedim(k, 0)

        # Normalize CT on (D,H,W)
        ct = torch.clamp(ct, 0.0, 1500.0)
        ct[ct < 250.0] = 0.0
        nz = ct > 0
        vol_max = ct[nz].max() if nz.any() else ct.max()
        ct = ct / vol_max.clamp(min=1.0)

        lens_m = (lens_m > 0).float() * -1.0

        # (C,D,H,W)
        ct     = ct.unsqueeze(0)
        lens_m = lens_m.unsqueeze(0)
        X = torch.cat([ct, lens_m], dim=0)

        # ---- Target P map ----
        with h5py.File(self.p_files[idx], 'r') as f:
            p_map = torch.from_numpy(f['p_map'][()]).float()

        # Align target to (D,H,W)
        if p_map.shape == (100, 100, 160):
            p_map = p_map.permute(2,0,1)
        elif 160 in p_map.shape and p_map.shape.count(100) >= 2:
            p_map = p_map.movedim(list(p_map.shape).index(160), 0)

        # Global scaling + clamp, then add channel dim -> (1, D, H, W)
        p_map = torch.nan_to_num(p_map, nan=0.0, posinf=0.0, neginf=0.0)
        p_map = p_map / self.p_ref
        p_map = torch.clamp(p_map, 0.0, 1.0)
        p_map = p_map.unsqueeze(0)

        return X, p_map

def rrmse(pred, true):
    num   = torch.sum((pred - true) ** 2)
    denom = torch.sum(true ** 2).clamp_min(EPS)
    return torch.sqrt(num / denom)

# ---- SCALE-SAFE GDL (means, not sums) ----
def gdl_loss(pred, true, mode="l1"):
    # pred/true: (N,C,D,H,W)
    def grad(t):
        dx = t[:, :, 1:, :, :] - t[:, :, :-1, :, :]
        dy = t[:, :, :, 1:, :] - t[:, :, :, :-1, :]
        dz = t[:, :, :, :, 1:] - t[:, :, :, :, :-1]
        return dx, dy, dz

    gp = grad(pred)
    gt = grad(true)

    if mode == "l2":
        comps = [(p - t).pow(2).mean() for p, t in zip(gp, gt)]
    else:  # L1 is typically stabler
        comps = [F.l1_loss(p, t, reduction='mean') for p, t in zip(gp, gt)]
    return sum(comps) / len(comps)

def set_requires_grad(model, flag=True):
    for p in model.parameters():
        p.requires_grad_(flag)

@torch.no_grad()
def paper_metrics(yhat, y, voxel_mm=0.6250):
    # ΔPR
    pr_hat = yhat.max(dim=-1)[0].max(dim=-1)[0].max(dim=-1)[0]
    pr     = y.max(dim=-1)[0].max(dim=-1)[0].max(dim=-1)[0]
    dpr    = (pr_hat - pr).abs() / pr.clamp_min(1e-8)

    # A90% Dice
    thr_hat = (yhat >= (pr_hat.view(-1,1,1,1)*0.9))
    thr     = (y    >= (pr.view( -1,1,1,1)*0.9))
    thr_hat_ = thr_hat[:, 0]; thr_ = thr[:, 0]
    inter = (thr_hat_ & thr_).sum(dim=(1,2,3)).float()
    dice  = (2*inter) / (thr_hat_.sum(dim=(1,2,3)) + thr_.sum(dim=(1,2,3))).clamp_min(1e-8)

    # ΔF(mm)
    def centroid(mask):
        out = []
        for bi in range(mask.shape[0]):
            pts = mask[bi].nonzero(as_tuple=False).float()
            out.append(pts.mean(dim=0) if pts.numel()>0 else torch.zeros(3, device=mask.device))
        return torch.stack(out, dim=0)
    c_hat = centroid(thr_hat_); c = centroid(thr_)
    df_mm = ((c_hat - c).pow(2).sum(dim=1).sqrt() * voxel_mm)

    return dpr.mean().item(), dice.mean().item(), df_mm.mean().item()

@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    mae_sum=rrmse_sum=dpr_sum=dice_sum=dfmm_sum=0.0
    n=0
    for x,y in loader:
        x,y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
        yhat = model(x)
        if yhat.shape[-3:] != y.shape[-3:]:
            yhat = F.interpolate(yhat, size=y.shape[-3:], mode='trilinear', align_corners=False)
        mae_sum   += torch.mean(torch.abs(yhat - y)).item()
        rrmse_sum += rrmse(yhat, y).item()
        dpr,dice,dfmm = paper_metrics(yhat, y)
        dpr_sum  += dpr; dice_sum += dice; dfmm_sum += dfmm
        n+=1
    model.train()
    return (mae_sum/n, rrmse_sum/n, dpr_sum/n, dice_sum/n, dfmm_sum/n)

if __name__ == '__main__':
    # ---- Training config (paper-like) ----
    bs, epochs, lr = 2, 320, 1e-4
    torch.manual_seed(2023); np.random.seed(2023)
    dev = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    torch.backends.cudnn.benchmark = True

    # ---- Datasets / Loaders: compute p_ref on train, reuse for val ----
    train_ds = UltrasoundDataset(r'BoneCT\data\train\CT', r'BoneCT\data\train\P')
    val_ds   = UltrasoundDataset(r'BoneCT\data\test\CT',  r'BoneCT\data\test\P',
                                 p_ref=train_ds.p_ref)
    print(f"[INFO] Using global p_ref = {train_ds.p_ref:.6f}")

    train_loader = DataLoader(train_ds, batch_size=bs, shuffle=True, num_workers=0, pin_memory=True)
    val_loader   = DataLoader(val_ds,   batch_size=1,  shuffle=False, num_workers=0, pin_memory=True)

    # ---- Models ----
    G = Generator3D(in_ch=2).to(dev)
    D = Discriminator3D(in_ch=3).to(dev)

    # Size-preserving sanity check for G
    G.eval()
    with torch.no_grad():
        dummy = torch.zeros(1, 2, 160, 100, 100, device=dev)
        out = G(dummy)
        print("G out shape:", tuple(out.shape))
        assert out.shape[-3:] == (160, 100, 100), f"Generator is not size-preserving: {out.shape}"
    G.train()

    # ---- Optimizers / schedulers ----
    optG = optim.Adam(G.parameters(), lr=lr, betas=(0.5,0.999))
    optD = optim.Adam(D.parameters(), lr=lr, betas=(0.5,0.999))
    schedG = optim.lr_scheduler.StepLR(optG, step_size=10, gamma=0.9)
    schedD = optim.lr_scheduler.StepLR(optD, step_size=10, gamma=0.9)

    mae = nn.L1Loss(); mse = nn.MSELoss()

    # ---- Loss weights (paper) + no warm-up ----
    adv_w, mae_w, rrmse_w, gdl_w = 1.0, 30.0, 10.0, 10.0
    warmup_epochs = 0
    real_smooth = 0.9  # label smoothing for real labels (LSGAN target)

    for ep in range(1, epochs+1):
        lossD_item = float('nan'); lossG_item = float('nan')
        did_step_D = False

        for x, y in train_loader:
            x = x.to(dev, non_blocking=True); y = y.to(dev, non_blocking=True)
            fake = G(x)
            if fake.shape[-3:] != x.shape[-3:]:
                fake = F.interpolate(fake, size=x.shape[-3:], mode='trilinear', align_corners=False)

            # ---- (Optional warm-up path; here it's disabled with warmup_epochs=0) ----
            if ep <= warmup_epochs:
                set_requires_grad(D, False)
                recon_mae   = mae(fake, y) * mae_w
                recon_rrmse = rrmse(fake, y) * rrmse_w
                smooth      = gdl_loss(fake, y, mode="l1") * gdl_w
                lossG = recon_mae + recon_rrmse + smooth
                optG.zero_grad(set_to_none=True)
                lossG.backward()
                torch.nn.utils.clip_grad_norm_(G.parameters(), 1.0)
                optG.step()
                lossG_item = lossG.item()
                continue

            # ---- Discriminator step ----
            set_requires_grad(D, True)
            D_real = D(torch.cat([x, y], dim=1))
            D_fake = D(torch.cat([x, fake.detach()], dim=1))
            real_t = torch.full_like(D_real, real_smooth)
            fake_t = torch.zeros_like(D_fake)
            lossD  = 0.5 * (mse(D_real, real_t) + mse(D_fake, fake_t))
            optD.zero_grad(set_to_none=True)
            lossD.backward()
            optD.step()
            did_step_D = True
            lossD_item = lossD.item()

            # ---- Generator step ----
            set_requires_grad(D, False)
            D_fake2 = D(torch.cat([x, fake], dim=1))
            adv         = mse(D_fake2, torch.ones_like(D_fake2)) * adv_w
            recon_mae   = mae(fake, y) * mae_w
            recon_rrmse = rrmse(fake, y) * rrmse_w
            smooth      = gdl_loss(fake, y, mode="l1") * gdl_w
            lossG = adv + recon_mae + recon_rrmse + smooth
            optG.zero_grad(set_to_none=True)
            lossG.backward()
            torch.nn.utils.clip_grad_norm_(G.parameters(), 1.0)
            optG.step()
            lossG_item = lossG.item()

        # ---- Validation ----
        val_mae, val_rrmse, val_dpr, val_dice, val_dfmm = evaluate(G, val_loader, dev)
        print(f"Epoch {ep:03d} | D {lossD_item:.4f} | G {lossG_item:.4f} | "
              f"MAE {val_mae:.4f} | rRMSE {val_rrmse:.4f} | ΔPR {val_dpr:.3f} | "
              f"DSC_A90 {val_dice:.3f} | ΔF(mm) {val_dfmm:.2f}")

        # ---- Model selection: checkpoint best on composite score; early stopping ----
        if ep == 1:
            os.makedirs("checkpoints", exist_ok=True)
            best_score = -float('inf')
            epochs_no_improve = 0
            patience = 25  # stop if no improvement for 25 epochs
        
        # Define a composite score: prioritize Dice, penalize ΔPR and ΔF
        # (Weights are reasonable defaults; tweak if you prefer different trade-offs.)
        score = (val_dice) - 0.5*(val_dpr) - 0.02*(val_dfmm)
        
        # Save best
        if score > best_score:
            best_score = score
            epochs_no_improve = 0
            torch.save(G.state_dict(), "checkpoints/best_G.pt")
            torch.save(D.state_dict(), "checkpoints/best_D.pt")
            with open("checkpoints/val_metrics.txt", "a") as f:
                f.write(f"ep={ep} score={score:.4f} MAE={val_mae:.4f} rRMSE={val_rrmse:.4f} "
                        f"dPR={val_dpr:.4f} DSC={val_dice:.4f} dFmm={val_dfmm:.2f}\n")
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= patience:
                print(f"Early stopping at epoch {ep} (no improvement for {patience} epochs).")
                break
        
        # Step schedulers AFTER optimizer steps; guard D's scheduler
        schedG.step()
        if did_step_D:
            schedD.step()

        # Safety
        if not np.isfinite(lossG_item):
            raise RuntimeError('❗ Got NaN/Inf in G – check data values / ε guards')

    print('✓ Training finished without NaNs')

