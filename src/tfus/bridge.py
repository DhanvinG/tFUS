"""Launch a dedicated MATLAB process and wait for verified completion."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def matlab_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def run_matlab(stage, cfg, config_path):
    root = Path(__file__).resolve().parents[2] / 'matlab'
    if not root.is_dir():
        root = Path(sys.prefix) / 'share/tfus/matlab'
    if not root.is_dir():
        raise FileNotFoundError('MATLAB sources missing. Install with pip install -e . from the repository checkout.')
    executable = shutil.which(cfg['matlab_executable'])
    if not executable:
        raise FileNotFoundError(f"MATLAB executable not found: {cfg['matlab_executable']}")
    output = Path(cfg['output_dir'])
    marker = output / f'{stage}.complete'
    marker.unlink(missing_ok=True)
    statement = f"addpath({matlab_quote(root)}); tfus_entry({matlab_quote(config_path)}, {matlab_quote(stage)})"
    args = [executable]
    if os.name == 'nt':
        args += ['-wait']
    args += ['-logfile', str(output / f'matlab-{stage}.log')]
    if stage == 'prepare':
        # Annotation needs a real interactive desktop. Exit codes propagate to Python.
        args += ['-desktop', '-r', f"try; {statement}; exit(0); catch ME; disp(getReport(ME,'extended')); exit(1); end"]
    else:
        args += ['-batch', statement]
    subprocess.run(args, check=True, cwd=output)
    if not marker.is_file():
        raise RuntimeError(f'MATLAB exited without completing {stage}; inspect its log')
