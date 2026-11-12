"""Unified CLI with independently runnable stages and a durable run manifest."""
import argparse
from contextlib import redirect_stdout, redirect_stderr
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import traceback
from .config import load_config


class Tee:
    def __init__(self, *streams):
        self.streams = streams
    def write(self, text):
        for stream in self.streams:
            stream.write(text)
            stream.flush()
        return len(text)
    def flush(self):
        for stream in self.streams:
            stream.flush()


def execute(stage, cfg, config_path, args):
    root = Path(cfg['output_dir'])
    if stage in ('prepare', 'simulate'):
        from .bridge import run_matlab
        run_matlab(stage, cfg, config_path)
    elif stage == 'train':
        from .training import train
        train(cfg)
    elif stage == 'validate':
        from .data import UltrasoundDataset
        reference = None
        for split in ['train', 'test']:
            ds = UltrasoundDataset(root / 'data' / split / 'CT', root / 'data' / split / 'P', p_ref=reference)
            reference = ds.p_ref
            for i in range(len(ds)):
                ds[i]
            print(f'{split}: {len(ds)} valid paired volumes; p_ref={reference}')
    elif stage == 'predict':
        from .inference import predict
        inputs = [Path(args.input)] if args.input else sorted((root / 'data/test/CT').glob('*_CT.mat'))
        if not inputs:
            raise FileNotFoundError('No prediction input. Supply --input or generate test CT packs.')
        for ct in inputs:
            output = root / 'predictions' / (ct.stem + '_prediction.h5')
            print(f'Predicting {ct.name}')
            predict(ct, args.checkpoint or root / 'checkpoints/best_G.pt', output, cfg['device'], args.p_ref)
    elif stage == 'visualize':
        from .visualization import visualize
        inputs = [Path(args.input)] if args.input else sorted((root / 'predictions').glob('*.h5'))
        if not inputs:
            raise FileNotFoundError('No predictions to visualize')
        for prediction in inputs:
            visualize(prediction, root / 'figures' / (prediction.stem + '.png'), args.show)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['run', 'prepare', 'simulate', 'validate', 'train', 'predict', 'visualize'])
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--input', help='CT .mat for predict; prediction .h5 for visualize')
    parser.add_argument('--checkpoint', help='Generator state_dict for predict')
    parser.add_argument('--p-ref', type=float, help='Original training amplitude reference for legacy checkpoints')
    parser.add_argument('--show', action='store_true', help='Open matplotlib figures after saving')
    args = parser.parse_args(argv)
    if args.input and args.stage not in ('predict', 'visualize'):
        parser.error('--input is only valid for predict or visualize')
    if (args.checkpoint or args.p_ref is not None) and args.stage != 'predict':
        parser.error('--checkpoint and --p-ref are only valid for predict')
    try:
        cfg = load_config(args.config)
        root = Path(cfg['output_dir'])
        root.mkdir(parents=True, exist_ok=True)
        resolved = root / 'config.resolved.json'
        if resolved.exists() and json.loads(resolved.read_text()) != cfg:
            raise ValueError('Output directory belongs to a different configuration; choose a new output_dir')
        resolved.write_text(json.dumps(cfg, indent=2), encoding='utf-8')
        # Exclusive lock prevents concurrent stages from writing the same run.
        lock = root / '.running'
        with lock.open('x') as f:
            import os
            f.write(str(os.getpid()))
        try:
            stages = ['prepare', 'simulate', 'validate', 'train', 'predict', 'visualize'] if args.stage == 'run' else [args.stage]
            with (root / 'pipeline.log').open('a', encoding='utf-8') as log:
                with redirect_stdout(Tee(sys.stdout, log)), redirect_stderr(Tee(sys.stderr, log)):
                    for stage in stages:
                        print(f'[{stage}] starting', flush=True)
                        record = dict(stage=stage, started=datetime.now(timezone.utc).isoformat())
                        try:
                            execute(stage, cfg, resolved, args)
                            record['status'] = 'complete'
                        except BaseException as exc:
                            record.update(status='failed', error=str(exc))
                            traceback.print_exc()
                            raise
                        finally:
                            record['finished'] = datetime.now(timezone.utc).isoformat()
                            with (root / 'manifest.jsonl').open('a', encoding='utf-8') as manifest:
                                manifest.write(json.dumps(record) + '\n')
                        print(f'[{stage}] complete', flush=True)
        finally:
            lock.unlink(missing_ok=True)
    except (Exception, KeyboardInterrupt) as exc:
        parser.exit(1, f'tfus: {exc}\n')


if __name__ == '__main__':
    main()
