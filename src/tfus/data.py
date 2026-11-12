"""Baseline MATLAB v7.3 loading and normalization."""
import os, glob
from pathlib import Path
import h5py
import numpy as np
import torch
from torch.utils.data import Dataset

def load_input(path):
    # ---- CT + mask ----
    with h5py.File(path, 'r') as f:
        ct     = torch.from_numpy(f['ct'][()]).float()
        lens_m = torch.from_numpy(f['lens_mask'][()]).float()
    if ct.shape != lens_m.shape:
        raise ValueError(f"CT/mask shape mismatch in {path}")
    if sorted(ct.shape) != [100, 100, 160]:
        raise ValueError(f"Expected a 100 x 100 x 160 volume, got {tuple(ct.shape)}")
    if not torch.isfinite(ct).all() or not torch.isfinite(lens_m).all():
        raise ValueError(f"Nonfinite CT/mask in {path}")

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

    return X

class UltrasoundDataset(Dataset):
    def __init__(self, ct_folder, p_folder, p_ref=None, q=99.5):
        """
        p_ref: global amplitude reference (float). If None, compute as the median of the
               q-th percentile across all training P maps. Use the same value for val.
        q    : percentile used to form a robust per-volume peak estimate before aggregating.
        """
        self.ct_files = sorted(glob.glob(os.path.join(ct_folder, '*_CT.mat')))
        self.p_files  = sorted(glob.glob(os.path.join(p_folder,  '*_P.mat')))
        if not self.ct_files or len(self.ct_files) != len(self.p_files):
            raise ValueError("Expected nonempty, equally sized CT/P datasets")
        for ct, pressure in zip(self.ct_files, self.p_files):
            if Path(ct).name.removesuffix('_CT.mat') != Path(pressure).name.removesuffix('_P.mat'):
                raise ValueError(f"Mismatched CT/P pair: {ct}, {pressure}")

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

        if not np.isfinite(self.p_ref) or self.p_ref <= 0:
            raise ValueError("p_ref must be finite and positive")

    def __len__(self):
        return len(self.ct_files)

    def __getitem__(self, idx):
        X = load_input(self.ct_files[idx])

        # ---- Target P map ----
        with h5py.File(self.p_files[idx], 'r') as f:
            p_map = torch.from_numpy(f['p_map'][()]).float()

        # Align target to (D,H,W)
        if p_map.shape == (100, 100, 160):
            p_map = p_map.permute(2,0,1)
        elif 160 in p_map.shape and p_map.shape.count(100) >= 2:
            p_map = p_map.movedim(list(p_map.shape).index(160), 0)

        if tuple(p_map.shape) != (160, 100, 100):
            raise ValueError(f"Invalid pressure shape: {tuple(p_map.shape)}")
        # Global scaling + clamp, then add channel dim -> (1, D, H, W)
        p_map = torch.nan_to_num(p_map, nan=0.0, posinf=0.0, neginf=0.0)
        p_map = p_map / self.p_ref
        p_map = torch.clamp(p_map, 0.0, 1.0)
        p_map = p_map.unsqueeze(0)

        return X, p_map
