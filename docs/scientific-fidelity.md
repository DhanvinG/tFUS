# Scientific fidelity and integration decisions

Baseline: `8869c727d4f7aac110676e15972dffa1ac162254`. `baseline.m` is the
text extracted from code paragraphs in `generateDatasetCurrent.mlx`, with three
personal-directory strings replaced by `<PATIENT_DATA_ROOT>` in this readable copy.
The original binary Live Script is unchanged. `tests/reference/` contains the
three original Python files, byte for byte, solely for regression comparisons.

## MATLAB execution path

The Live Script combines helper definitions and multiple manually run patient
sessions: CT4 loading/annotation, CT1 soft-to-bone annotation transfer, and CT3
40-pose dataset generation. Running all paragraphs sequentially would mix
patients and hard-coded directories. The integrated path parameterizes the
loading/annotation session and feeds its saved volumes into the CT3 dataset
logic. Optional target-mask reuse follows the existing nearest-neighbor operation.
Patient identity and paths now come from a single configuration.

Preserved operations include raw DICOM pixel reads; skull permutation; isotropic
`imresize3`; original `PutIntoFOV` indexing; AssistedFreehand slice masks;
40 azimuth/elevation poses; 100 mm stand-off, curvature radius and diameter;
odd-diameter adjustment; the existing Rodrigues/Euler calculations and rotation
order; transducer translation; `regionprops3` centroid and bounding-box calls;
the exact clamped crop; and output resizing to `[100 100 160]`.

The active pose loop uses **configured p0**, originally `[165,240,229]`, not the
ROI centroid or `calculateRotTrans`. The latter and the focal-centroid functions
are retained as reusable baseline helpers, but are not newly substituted into
the active placement method. The nominal “30 poses” comments in the Live Script
are inaccurate: 8 azimuths times 5 elevations makes 40. The seeded split remains
`rng(0)`, 10 validation poses and 30 training poses.

Simulation retains 250 kHz, 6.19e4 Pa source magnitude, 22°C, thresholds 260/-70,
the same attenuation values and 1.4 tissue power, `hounsfield2density(CT+1000,true)`,
water lower bounds, CFL 0.1, 300 mm propagation distance, sinusoidal source,
full-volume `p_max_all`, and `kspaceFirstOrder3DG` arguments. Output MAT keys,
filenames, interpolation, spacing and origin calculations are unchanged.

## Python behavior

Both model implementations are source-identical to baseline, preserving parameter
names and old state dictionaries. This includes nine residual blocks, dropout,
InstanceNorm, reflection padding, transpose-convolution output padding, and the
discriminator sigmoid even though its objective uses LSGAN-style MSE.

CT thresholds, clipping, volume normalization, negative lens-mask channel,
axis handling, pressure sanitization, global median-percentile scaling and target
clipping are identical. Losses and weights, Adam settings, seed 2023,
cuDNN benchmarking, batch size 2, 320 epochs, learning rate 1e-4, StepLR,
label smoothing, update order, gradient clipping, validation batch size 1,
checkpoint score and patience 25 remain baseline defaults. Configuring batch
size, epochs or learning rate explicitly changes those run settings and is
recorded. No mixed precision, augmentation or changed objective was introduced.

## Explicit corrections and added checks

1. **Imports:** baseline `models.*` imports referenced a nonexistent directory.
   Models now live in `tfus.models`; root files remain compatibility imports.
2. **DICOM paths:** `DicomToVolume` read relative filenames despite accepting a
   directory. Reads now use `fullfile(dicom_folder, filenumber)`. Intensities,
   ordering and indexing are unchanged.
3. **Validation broadcasting:** A90 thresholds now reshape to `(N,1,1,1,1)`
   instead of `(N,1,1,1)`. The old expression mixed samples when N>1. Results
   for the baseline validation batch size of 1 are identical.
4. **Invalid inputs:** empty/mispaired datasets, unsupported array shapes,
   nonfinite CT/masks and invalid explicit references now fail before misleading
   results. Pressure NaN/Inf sanitization and zero-reference fallback stay intact.
5. **Geometry guards:** non-0.625 mm grids and invalid FOV padding are rejected,
   not automatically shifted/resampled. The old `PutIntoFOV` requires positive
   even margins; correcting its index origin would change placement coordinates.
6. **Inference scale:** training writes its original global pressure reference;
   inference reuses the exact input preprocessing and generator state dict.
7. **Execution:** paths, saved stage state, review confirmation, logging, output
   protection and completion markers replace manual session orchestration.
8. **Windows progress output:** training messages use ASCII labels (`dPR`, `dF`)
   so a legacy console encoding cannot abort an epoch while printing metrics.

## Preserved limitations that need scientific review

- Raw DICOM reads do not apply rescale slope/intercept. `medicalVolume` and the
  numbered-file loop may have different slice conventions. The loader is not a
  general DICOM series discovery/registration implementation.
- `PutIntoFOV` uses the original one-voxel-sensitive centering convention.
  Crop boundary indices repeat edge voxels rather than padding. Neither changes.
- `rotation_matrix_from_vectors` has a collinear division singularity, and
  `calculateRotTrans` has fragile legacy intermediate calculations. Neither is
  used by the active 40-pose loop; they are retained without silently redesigning
  geometry. `apply_min_limits` leaves its second declared output unassigned and
  is unused by the active simulation path.
- The pose-loop parallel-vector branch returns identity; changing the grid to
  include antiparallel vectors would require review. The fixed current grid
  avoids that case.
- The baseline metric multiplies centroid distance by fixed 0.625 mm even though
  exported resampled spacing can be anisotropic. It is retained for compatibility,
  not represented as a corrected physical-distance metric.
- Pose splitting from one patient is not an independent patient-level evaluation.
  The baseline `test` set is used for early stopping and checkpoint selection.
- Seeded training with `cudnn.benchmark=True` is not guaranteed bitwise deterministic.
- All pose masks are retained in memory as in baseline. Full simulation/training
  require a workstation with appropriate RAM and GPU capacity.

## Further validation

Before relying on results, compare the old and modular MATLAB workflows on the
same CT/annotation: FOV arrays, every pose mask/rotation/center, cropped arrays,
medium/source parameters, output MAT metadata and pressure volumes. Compare
within the numerical tolerance appropriate for the same k-Wave executable/GPU.
The repository includes exact extraction tests and focused geometry tests, but
these do not establish real-data acoustic equivalence.
