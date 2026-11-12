"""Explicit configuration; relative paths are relative to the JSON file."""
import json
import math
import re
from pathlib import Path

DEFAULTS = dict(volume_name='CT3_Bone', matlab_executable='matlab', z_start=1,
    z_end=272, missing_slices=0, annotation_start=225, annotation_stop=275,
    target_point_vox=[165, 240, 229], target_mask_file='', batch_size=2,
    epochs=320, learning_rate=1e-4, device='auto', dicom_dir='', kwave_dir='',
    output_dir='runs/default')


def load_config(path):
    path = Path(path).resolve()
    supplied = json.loads(path.read_text(encoding='utf-8'))
    unknown = set(supplied) - set(DEFAULTS)
    if unknown:
        raise ValueError(f"Unknown configuration keys: {sorted(unknown)}")
    cfg = {**DEFAULTS, **supplied}
    if not isinstance(cfg['output_dir'], str) or not cfg['output_dir'].strip():
        raise ValueError('output_dir must be a nonempty path')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', cfg['volume_name']):
        raise ValueError('volume_name must contain only letters, digits, underscores or hyphens')
    for key in ['z_start', 'z_end', 'annotation_start', 'annotation_stop', 'epochs', 'batch_size']:
        if type(cfg[key]) is not int or cfg[key] < 1:
            raise ValueError(f'{key} must be a positive integer')
    if cfg['z_start'] > cfg['z_end'] or cfg['annotation_start'] > cfg['annotation_stop']:
        raise ValueError('Slice ranges must be increasing')
    if type(cfg['missing_slices']) is not int or not 0 <= cfg['missing_slices'] < cfg['z_start']:
        raise ValueError('missing_slices must be nonnegative and less than z_start')
    if not math.isfinite(cfg['learning_rate']) or cfg['learning_rate'] <= 0:
        raise ValueError('learning_rate must be finite and positive')
    p = cfg['target_point_vox']
    if not isinstance(p, list) or len(p) != 3 or any(type(v) not in (int, float) or not math.isfinite(v) or v < 1 or v > 480 for v in p):
        raise ValueError('target_point_vox must contain three finite coordinates in [1,480]')
    for key in ['dicom_dir', 'kwave_dir', 'output_dir', 'target_mask_file']:
        if cfg[key]:
            cfg[key] = str((path.parent / cfg[key]).resolve())
    return cfg
