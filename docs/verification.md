# Verification record

Local verification on 2026-11-12, Windows, Python 3.11.0, isolated environment:
PyTorch 2.15.0+cpu, NumPy 2.4.6, h5py 3.16.0, matplotlib 3.11.2.
The system Python's pre-existing PyTorch installation failed DLL loading; all
reported numerical tests use the separate environment created for this refactor.

## Passed

`python -m unittest discover -s tests -v`: 17 tests passed.

- Both model source ASTs equal the original implementations.
- Dataset tensors and global pressure reference exactly equal baseline for
  three supported input axis arrangements, including pressure NaN/Inf handling.
- Inference input preprocessing exactly equals training preprocessing.
- rRMSE and both gradient-difference loss modes exactly equal baseline.
- Single-case validation metrics equal baseline; a two-case fixture verifies
  that the explicit threshold-broadcasting correction avoids cross-case mixing.
- Empty and mismatched datasets are rejected.
- Original generator and discriminator full-volume output shapes pass on the
  PyTorch meta device (shape propagation, not numerical execution).
- The actual nine-residual-block generator passes a numerical CPU forward
  on a smaller `16 x 20 x 20` input.
- One real optimizer epoch with lightweight substitute networks and full-size
  synthetic volumes exercises the unchanged optimization/control flow, saves
  weights and pressure-reference metadata, then reloads weights for prediction
  and exports a pressure figure. This is a pipeline smoke test, not a complete
  scientific-model training run.
- Missing legacy checkpoint scale is rejected; failed stages record failure
  and release their run lock.
- The complete stage order and MATLAB completion-marker/process handoff pass
  mocked integration checks, including quoted paths and missing markers.
- All 20 MATLAB helpers match the extracted Live Script, allowing only the
  documented DICOM directory correction. Pose math and the simulation/export
  body match baseline, allowing configuration of p0/paths and progress output.

Python compilation and command-line help were also checked. A wheel built
successfully and includes all 25 runtime MATLAB files. GitHub Actions runs
the Python suite on pull requests; see the PR checks for its separate result.

## Not executed

MATLAB R2026a is installed locally, but startup returns **MathWorks Licensing
Error 10: license expired**. Therefore the included MATLAB tests, source parsing
by MATLAB, desktop annotation, DICOM loading, transducer construction and k-Wave
GPU execution could not be run. No patient CT, k-Wave setup or trained scientific
checkpoint was supplied in this task. Full-resolution numerical model inference,
320-epoch training, real-data pressure comparison and interactive review remain
unverified. Static preservation is evidence of extraction fidelity, not proof of
runtime or acoustic equivalence.

## Workstation acceptance procedure

1. Run `matlab -batch "results=runtests('matlab/tests'); assertSuccess(results)"`
   with a valid license and required toolboxes.
2. Configure a compatible CT and k-Wave GPU installation. Run `tfus prepare`,
   inspect slice order/intensity/ROI/p0, then accept the geometry.
3. Run `tfus simulate`; compare all pose transforms and representative pressure
   outputs to the original manually executed session using identical inputs.
4. Run `tfus validate`; confirm 30/10 matched files and the expected pressure
   reference. Inspect the saved MATLAB metadata and Python tensor orientation.
5. On a disposable run/config, use a short training smoke run, then predict and
   visualize. Restore baseline training settings in a fresh run for the real
   experiment; do not mistake smoke-run weights for validated trained weights.
6. Run full training, retain logs/config/software versions, and evaluate on an
   independent patient cohort before making generalization claims.
