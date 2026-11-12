"""Baseline optimization and selection behavior, with configurable paths."""
import json
from pathlib import Path
import numpy as np
import torch
from torch import nn, optim
from torch.utils.data import DataLoader
import torch.nn.functional as F
from .models import Generator3D, Discriminator3D
from .data import UltrasoundDataset
from .losses import rrmse, gdl_loss
from .metrics import evaluate

def set_requires_grad(model, flag=True):
    for p in model.parameters():
        p.requires_grad_(flag)

def train(config):
    # ---- Training config (paper-like) ----
    bs, epochs, lr = config['batch_size'], config['epochs'], config['learning_rate']
    data = Path(config['output_dir']) / 'data'
    checkpoint_dir = Path(config['output_dir']) / 'checkpoints'
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    if (checkpoint_dir / 'best_G.pt').exists():
        raise FileExistsError(f"Training output already exists: {checkpoint_dir}. Use a new output directory.")
    torch.manual_seed(2023); np.random.seed(2023)
    dev = torch.device(('cuda' if torch.cuda.is_available() else 'cpu') if config['device'] == 'auto' else config['device'])
    torch.backends.cudnn.benchmark = True

    # ---- Datasets / Loaders: compute p_ref on train, reuse for val ----
    train_ds = UltrasoundDataset(data / 'train/CT', data / 'train/P')
    val_ds   = UltrasoundDataset(data / 'test/CT', data / 'test/P',
                                 p_ref=train_ds.p_ref)
    (checkpoint_dir / 'normalization.json').write_text(json.dumps({'p_ref': train_ds.p_ref,
        'axes': 'D,H,W', 'shape': [160,100,100], 'config': config}, indent=2))
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
              f"MAE {val_mae:.4f} | rRMSE {val_rrmse:.4f} | dPR {val_dpr:.3f} | "
              f"DSC_A90 {val_dice:.3f} | dF(mm) {val_dfmm:.2f}")

        # ---- Model selection: checkpoint best on composite score; early stopping ----
        if ep == 1:
            checkpoint_dir.mkdir(parents=True, exist_ok=True)
            best_score = -float('inf')
            epochs_no_improve = 0
            patience = 25  # stop if no improvement for 25 epochs

        # Define a composite score: prioritize Dice, penalize dPR and dF
        # (Weights are reasonable defaults; tweak if you prefer different trade-offs.)
        score = (val_dice) - 0.5*(val_dpr) - 0.02*(val_dfmm)

        # Save best
        if score > best_score:
            best_score = score
            epochs_no_improve = 0
            torch.save(G.state_dict(), checkpoint_dir / 'best_G.pt')
            torch.save(D.state_dict(), checkpoint_dir / 'best_D.pt')
            with open(checkpoint_dir / 'val_metrics.txt', "a") as f:
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
            raise RuntimeError('Got NaN/Inf in G - check data values / ε guards')

    print('Training finished without NaNs')
    return checkpoint_dir / 'best_G.pt'
