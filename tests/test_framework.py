import ast
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import h5py
import numpy as np
import torch
from torch import nn

from tfus.config import DEFAULTS, load_config
from tfus.data import UltrasoundDataset, load_input
from tfus.losses import rrmse, gdl_loss
from tfus.metrics import paper_metrics

ROOT = Path(__file__).resolve().parents[1]


def reference():
    # Execute baseline definitions only; the main training job is not run.
    source = (ROOT / 'tests/reference/train.py').read_text(encoding='utf-8')
    source = source.replace('from models.generator', 'from tfus.models.generator').replace('from models.discriminator', 'from tfus.models.discriminator')
    namespace = {'__name__': 'baseline'}
    exec(compile(source, 'baseline_train.py', 'exec'), namespace)
    return namespace


def fixture(root, name='case', shape=(160, 100, 100)):
    (root / 'CT').mkdir(parents=True, exist_ok=True)
    (root / 'P').mkdir(parents=True, exist_ok=True)
    ct = np.zeros(shape, dtype=np.float32)
    ct.flat[0:6] = [-100, 249, 250, 500, 1500, 2000]
    mask = np.zeros(shape, dtype=np.uint8)
    mask.flat[4] = 1
    pressure = np.full(shape, 12, dtype=np.float32)
    pressure.flat[0:3] = [np.nan, np.inf, -np.inf]
    path = root / 'CT' / f'{name}_CT.mat'
    with h5py.File(path, 'w') as f:
        f['ct'], f['lens_mask'] = ct, mask
        f['spacing_mm'] = [[1.1, 1.2, 1.3]]
    with h5py.File(root / 'P' / f'{name}_P.mat', 'w') as f:
        f['p_map'] = pressure
    return path


class Compatibility(unittest.TestCase):
    def test_architecture_source_is_unchanged(self):
        for name in ['generator', 'discriminator']:
            old = ast.dump(ast.parse((ROOT / f'tests/reference/{name}.py').read_text(encoding='utf-8')))
            new = ast.dump(ast.parse((ROOT / f'src/tfus/models/{name}.py').read_text(encoding='utf-8')))
            self.assertEqual(old, new)

    def test_input_target_and_reference_match_baseline(self):
        for shape in [(160,100,100), (100,100,160), (100,160,100)]:
            with self.subTest(shape=shape), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                path = fixture(root, shape=shape)
                old = reference()['UltrasoundDataset'](root/'CT', root/'P')
                new = UltrasoundDataset(root/'CT', root/'P')
                self.assertEqual(old.p_ref, new.p_ref)
                for a, b in zip(old[0], new[0]):
                    self.assertTrue(torch.equal(a, b))
                self.assertTrue(torch.equal(load_input(path), new[0][0]))
                self.assertEqual(new[0][0].shape, (2,160,100,100))

    def test_pair_mismatch_and_empty_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(ValueError):
                UltrasoundDataset(root/'CT', root/'P')
            fixture(root)
            (root/'P/case_P.mat').rename(root/'P/wrong_P.mat')
            with self.assertRaises(ValueError):
                UltrasoundDataset(root/'CT', root/'P')

    def test_losses_and_single_case_metrics_match(self):
        old = reference()
        torch.manual_seed(11)
        x, y = torch.rand(1,1,8,8,8), torch.rand(1,1,8,8,8)
        self.assertTrue(torch.equal(rrmse(x,y), old['rrmse'](x,y)))
        for mode in ['l1','l2']:
            self.assertTrue(torch.equal(gdl_loss(x,y,mode), old['gdl_loss'](x,y,mode)))
        self.assertEqual(paper_metrics(x,y), old['paper_metrics'](x,y))

    def test_metrics_do_not_broadcast_across_patients(self):
        x = torch.zeros(2,1,4,4,4)
        y = torch.zeros_like(x)
        x[0,0,0,0,0] = y[0,0,0,0,0] = 1
        x[1,0,3,3,3] = y[1,0,3,3,3] = .1
        self.assertEqual(paper_metrics(x,y), (0.,1.,0.))

    def test_generator_full_shape_on_meta_device(self):
        from tfus.models import Generator3D, Discriminator3D
        with torch.device('meta'):
            generator = Generator3D(in_ch=2)
            discriminator = Discriminator3D(in_ch=3)
            self.assertEqual(tuple(generator(torch.zeros(1,2,160,100,100)).shape), (1,1,160,100,100))
            self.assertEqual(discriminator(torch.zeros(1,3,160,100,100)).shape[1], 1)

    def test_real_generator_forward(self):
        from tfus.models import Generator3D
        # All nine residual blocks; smaller volume limits CPU memory/time.
        torch.manual_seed(42)
        model = Generator3D().eval()
        with torch.inference_mode():
            result = model(torch.zeros(1,2,16,20,20))
        self.assertEqual(tuple(result.shape), (1,1,16,20,20))
        self.assertTrue(torch.isfinite(result).all())

    def test_config_paths_and_typo(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'config.json'
            path.write_text(json.dumps({'output_dir': 'out'}))
            self.assertEqual(Path(load_config(path)['output_dir']), (Path(temp)/'out').resolve())
            path.write_text(json.dumps({'epoch': 1}))
            with self.assertRaises(ValueError):
                load_config(path)


class TinyGenerator(nn.Module):
    def __init__(self, **kwargs):
        super().__init__()
        self.layer = nn.Conv3d(2,1,1)
    def forward(self, x):
        return torch.sigmoid(self.layer(x))


class TinyDiscriminator(nn.Module):
    def __init__(self, **kwargs):
        super().__init__()
        self.layer = nn.Conv3d(3,1,1)
    def forward(self, x):
        return torch.sigmoid(self.layer(x[:,:,::16,::10,::10]))


class Integration(unittest.TestCase):
    def test_matlab_bridge_waits_and_requires_completion(self):
        from tfus.bridge import run_matlab
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cfg = {**DEFAULTS, 'output_dir': str(root)}
            def completed(args, **kwargs):
                self.assertTrue(kwargs['check'])
                self.assertIn('-desktop', args)
                self.assertIn('-r', args)
                self.assertIn("config''quoted.json", args[-1])
                (root/'prepare.complete').write_text('done')
            with patch('tfus.bridge.shutil.which', return_value='matlab'), patch('tfus.bridge.subprocess.run', side_effect=completed):
                run_matlab('prepare', cfg, root/"config'quoted.json")
            with patch('tfus.bridge.shutil.which', return_value='matlab'), patch('tfus.bridge.subprocess.run'):
                with self.assertRaisesRegex(RuntimeError, 'without completing'):
                    run_matlab('simulate', cfg, root/'config.json')

    def test_unified_run_stage_order(self):
        from tfus.cli import main
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'config.json'
            path.write_text(json.dumps({'output_dir': 'run'}))
            with patch('tfus.cli.execute') as execute:
                main(['run', '--config', str(path)])
            self.assertEqual([call.args[0] for call in execute.call_args_list],
                ['prepare','simulate','validate','train','predict','visualize'])

    def test_training_checkpoint_prediction_and_figure(self):
        from tfus.training import train
        from tfus.inference import predict
        from tfus.visualization import visualize
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fixture(root/'data/train')
            ct = fixture(root/'data/test')
            cfg = {**DEFAULTS, 'output_dir': str(root), 'epochs': 1, 'batch_size': 1, 'device': 'cpu'}
            with patch('tfus.training.Generator3D', TinyGenerator), patch('tfus.training.Discriminator3D', TinyDiscriminator):
                checkpoint = train(cfg)
            self.assertTrue(checkpoint.is_file())
            self.assertEqual(json.loads((checkpoint.parent/'normalization.json').read_text())['p_ref'], 12.)
            with patch('tfus.inference.Generator3D', TinyGenerator):
                prediction = predict(ct, checkpoint, root/'prediction.h5', 'cpu')
            with h5py.File(prediction) as f:
                np.testing.assert_allclose(f['p_map'][()], f['p_normalized'][()]*12)
                np.testing.assert_equal(f['spacing_mm'][()], [[1.1,1.2,1.3]])
            self.assertTrue(visualize(prediction, root/'figure.png').is_file())
            with self.assertRaises(FileExistsError):
                train(cfg)

    def test_legacy_checkpoint_requires_reference(self):
        from tfus.inference import predict
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, 'Legacy weights'):
                predict('unused.mat', Path(temp)/'legacy.pt', Path(temp)/'out.h5')

    def test_failed_stage_records_manifest_and_releases_lock(self):
        from tfus.cli import main
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp)/'config.json'
            root = Path(temp)/'run'
            config.write_text(json.dumps({'output_dir': str(root)}))
            with self.assertRaises(SystemExit):
                main(['validate','--config',str(config)])
            self.assertFalse((root/'.running').exists())
            record = json.loads((root/'manifest.jsonl').read_text())
            self.assertEqual(record['status'], 'failed')


if __name__ == '__main__':
    torch.set_num_threads(2)
    unittest.main()
