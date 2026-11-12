import torch
import torch.nn.functional as F
EPS = 1e-8

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
