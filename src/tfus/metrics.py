import torch
import torch.nn.functional as F
from .losses import rrmse

@torch.no_grad()
def paper_metrics(yhat, y, voxel_mm=0.6250):
    # ΔPR
    pr_hat = yhat.max(dim=-1)[0].max(dim=-1)[0].max(dim=-1)[0]
    pr     = y.max(dim=-1)[0].max(dim=-1)[0].max(dim=-1)[0]
    dpr    = (pr_hat - pr).abs() / pr.clamp_min(1e-8)

    # A90% Dice
    thr_hat = (yhat >= (pr_hat.view(-1,1,1,1,1)*0.9))
    thr     = (y    >= (pr.view(-1,1,1,1,1)*0.9))
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
