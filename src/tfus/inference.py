"""Inference shares training preprocessing and restores the training pressure scale."""
import json
from pathlib import Path
import h5py
import numpy as np
import torch
from .data import load_input
from .models import Generator3D


def predict(ct_file, checkpoint, output, device='auto', p_ref=None):
    checkpoint, output = Path(checkpoint), Path(output)
    if output.exists():
        raise FileExistsError(output)
    if p_ref is None:
        metadata = checkpoint.parent / 'normalization.json'
        if not metadata.exists():
            raise ValueError('Legacy weights require --p-ref from the original training dataset; it cannot be inferred from weights')
        p_ref = json.loads(metadata.read_text())['p_ref']
    if not np.isfinite(p_ref) or p_ref <= 0:
        raise ValueError('p_ref must be finite and positive')
    dev = torch.device(('cuda' if torch.cuda.is_available() else 'cpu') if device == 'auto' else device)
    x = load_input(ct_file).unsqueeze(0).to(dev)
    model = Generator3D(in_ch=2).to(dev)
    model.load_state_dict(torch.load(checkpoint, map_location=dev, weights_only=True), strict=True)
    model.eval()
    with torch.inference_mode():
        normalized = model(x)[0, 0].cpu().numpy()
    if normalized.shape != (160, 100, 100) or not np.isfinite(normalized).all():
        raise RuntimeError('Generator returned invalid output')
    output.parent.mkdir(parents=True, exist_ok=True)
    with h5py.File(ct_file, 'r') as source, h5py.File(output, 'w') as dest:
        dest.create_dataset('p_normalized', data=normalized, compression='gzip')
        dest.create_dataset('p_map', data=normalized * p_ref, compression='gzip')
        dest.attrs['p_ref'] = float(p_ref)
        dest.attrs['axes'] = 'D,H,W (model axes; no patient-space inverse transform)'
        dest.attrs['pressure_units'] = 'Pa (training-reference scaled; targets clipped at p_ref)'
        dest.attrs['input_file'] = str(Path(ct_file).resolve())
        dest.attrs['checkpoint'] = str(checkpoint.resolve())
        for key in ['spacing_mm', 'origin_vox', 'origin_mm']:
            if key in source:
                dest.create_dataset(key, data=source[key][()])
        dest.attrs['metadata_axes'] = 'Copied unchanged from MATLAB input; spacing_mm is in original MATLAB axis order'
    return output
