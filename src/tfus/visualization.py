"""Orthogonal pressure slices in model voxel coordinates."""
from pathlib import Path
import h5py
import numpy as np


def visualize(prediction, output, show=False):
    import matplotlib
    if not show:
        matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    with h5py.File(prediction, 'r') as f:
        p = f['p_map'][()]
    if p.ndim != 3 or not np.isfinite(p).all():
        raise ValueError('Expected a finite 3D p_map')
    peak = np.unravel_index(p.argmax(), p.shape)
    fig, axes = plt.subplots(1, 3, figsize=(13, 4), layout='constrained')
    for axis, ax in enumerate(axes):
        im = ax.imshow(np.take(p, peak[axis], axis=axis), origin='lower', cmap='inferno', vmin=0, vmax=p.max())
        remaining = [v for i, v in enumerate(['D', 'H', 'W']) if i != axis]
        ax.set(title=f"{'DHW'[axis]} = {peak[axis]} (peak slice)", xlabel=remaining[1]+' voxel', ylabel=remaining[0]+' voxel')
    fig.colorbar(im, ax=axes, label='Predicted pressure (Pa; training-reference scaled)')
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=160)
    if show:
        plt.show()
    plt.close(fig)
    return output
