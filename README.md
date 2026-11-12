# tFUS research framework

A connected workflow for interactive CT annotation, the repository's existing
k-Wave simulation pipeline, 3D conditional GAN training, and pressure prediction.
The scientific baseline is commit `8869c727d4f7aac110676e15972dffa1ac162254`.
The original Live Script remains in the repository; all original Python files
remain in Git history and as regression fixtures.

```text
DICOM CT → MATLAB annotation/review → 40 baseline poses → k-Wave CT/P pairs
         → validate data → train 3D-cGAN → predict held-out inputs → pressure figures
```

## Installation

Use Python 3.10 or newer and a licensed MATLAB with Medical Imaging Toolbox,
Image Processing Toolbox, and `rotm2eul` (Robotics System Toolbox or a compatible
MathWorks toolbox providing it). Install k-Wave and its CUDA executable required
by `kspaceFirstOrder3DG`. The solver is deliberately unchanged; a working CUDA
GPU and k-Wave binary setup are needed for simulation. MATLAB's desktop must be
available for annotation. Large FOV volumes and the retained 40 pose masks require
substantial RAM (the logical pose masks alone are about 8.8 GB).

```bash
git clone https://github.com/DhanvinG/tFUS.git
cd tFUS
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
# Linux/macOS instead: source .venv/bin/activate
python -m pip install --upgrade pip
# Install the appropriate PyTorch build for your hardware first.
python -m pip install -e .
```

For CPU-only Python testing, install PyTorch with
`python -m pip install torch --index-url https://download.pytorch.org/whl/cpu`
before installing this package. CPU training is supported but the complete model
and full volumes are expensive. This does not make the MATLAB GPU solver CPU-based.

Copy `config.example.json` to `config.local.json` and set the DICOM, k-Wave,
output paths and patient slice ranges. Relative paths resolve from the config
file, not your terminal directory. `matlab_executable` may be an absolute path.

## Run the connected workflow

```bash
tfus run --config config.local.json
```

MATLAB opens the original AssistedFreehand annotation interaction for every
configured sagittal slice. Finish each ROI by double-clicking. A final review
shows the mask and configured placement target; accepting it lets the workflow
continue automatically through simulation, training, prediction and figure export.
Cancellation stops the workflow and records the failure. MATLAB closes when its
stage finishes; Python waits and checks its completion marker before proceeding.

**Patient setup is explicit.** The active baseline places transducers around a
fixed point, `target_point_vox = [165,240,229]`, in the FOV's existing coordinate
convention. It does **not** calculate this point from the ROI centroid. Set this
point for your patient before running and review its overlay. The existing
centroid, rotation, translation, crop and focal-analysis functions are retained.
No new positioning method or automatic registration is introduced.

The baseline DICOM loader expects sequential `IMG0001.dcm`, `IMG0002.dcm`, …
names, with the configured start/end indices. It reads raw `dicomread` values,
as before; do not assume it applies DICOM rescale slope/intercept. Confirm your
dataset matches that intensity convention. The validated baseline geometry uses
0.6250 mm isotropic voxels and positive even FOV padding. Unsupported spacing or
padding fails with an explanation instead of silently changing coordinates.
See [scientific fidelity](docs/scientific-fidelity.md) before adapting inputs.

For an already aligned annotation, set `target_mask_file` to a MAT file containing
`target` and `voxel_size`. This preserves the script's optional nearest-neighbor
mask reuse and still requires visual review. It does not register different scans.

## Run stages independently

```bash
tfus prepare   --config config.local.json
tfus simulate  --config config.local.json
tfus validate  --config config.local.json
tfus train     --config config.local.json
tfus predict   --config config.local.json
tfus visualize --config config.local.json --show
```

`prepare` saves the patient volumes and target; `simulate` uses that saved state
without asking for annotation again. `train` can use existing baseline files:
place paired `*_CT.mat` and `*_P.mat` files in the output directory's
`data/train/{CT,P}` and `data/test/{CT,P}` folders. Pair stems must agree.
The baseline 30/10 pose split is preserved; the directory named `test` is used
for model selection as in the original, so it is a validation set, not an
independent final test cohort. Patient-level generalization needs separate data.

Predict a single prepared CT/transducer input using existing generator weights:

```bash
tfus predict --config config.local.json --input path/to/patient_pose01_CT.mat --checkpoint path/to/best_G.pt
tfus visualize --config config.local.json --input path/to/prediction.h5 --show
```

Keep `normalization.json` beside `best_G.pt`. For an older checkpoint without
this sidecar, supply `--p-ref VALUE` using the **original training** pressure
reference (median of per-volume 99.5th percentiles, after baseline sanitization).
It cannot be recovered from the model weights or estimated from a new CT.
Prediction takes a resampled CT **and lens mask**, not an unprocessed DICOM scan.

## Outputs and recovery

```text
runs/<patient>/
  config.resolved.json       resolved settings; retained across stages
  prepared.mat              volumes, ROI, voxel size, FOV
  <patient>_*.mat            baseline intermediate volumes and target
  poses.mat                 pose rotations/centers, p0, 30/10 split
  data/{train,test}/{CT,P}/  unchanged MATLAB v7.3 training format
  checkpoints/              best_G.pt, best_D.pt, normalization.json, val_metrics.txt
  predictions/              HDF5 normalized and pressure-scaled volumes
  figures/                  orthogonal pressure slices through the predicted peak
  pipeline.log              Python progress and failures
  matlab-*.log              MATLAB progress and failures
  manifest.jsonl            timestamped stage outcomes
```

Run individual stages after a failure; `run` is a fresh full execution, not an
automatic resume command. Existing prepared state, datasets or trained weights
are protected from overwrite. To retry a partially completed simulation, archive
its `data/` directory first; simulation restarts all 40 poses. To retrain, use a
new output directory with a copy of the data. A run directory is tied to its
resolved configuration. If the process is forcibly killed, remove `.running`
only after confirming that neither Python nor its MATLAB process is still running.
Training retains the original best-weight checkpoints; optimizer-state resume
is not implemented and is not implied by stage-level recovery.

Predictions are in model `(D,H,W)` coordinates, with `p_map = p_normalized * p_ref`.
The baseline clips training targets to `[0,1]`, so this scale cannot recover
pressures beyond the training reference. Prediction HDF5 is explicitly `.h5`,
not falsely labeled as a MATLAB v7.3 MAT file. Read it in MATLAB using `h5read`.
Spacing/origin metadata is copied unchanged and labeled as original MATLAB
metadata; figures use voxel coordinates. No inverse warp to patient space is claimed.

## Repository map and verification

- `matlab/functions/`: 20 extracted baseline functions plus a geometry guard.
- `matlab/stages/`: preparation, original pose construction and simulation/export.
- `matlab/tfus_entry.m`: MATLAB entry point and saved-state boundaries.
- `src/tfus/`: CLI, MATLAB bridge, data, losses, metrics, models, training and inference.
- `tests/`: baseline parity, input validation, model shape and integration tests.
- `matlab/tests/`: geometry checks for a licensed MATLAB environment.
- `docs/baseline.m`: every code paragraph from the `.mlx`, with personal paths redacted.

```bash
python -m unittest discover -s tests -v
matlab -batch "results=runtests('matlab/tests'); assertSuccess(results)"
```

See [verification](docs/verification.md) for the actual checks performed and
remaining MATLAB/k-Wave/real-data validation, and [scientific fidelity](docs/scientific-fidelity.md)
for preserved behavior, explicit corrections and known baseline limitations.
