"""Compatibility entry point: python train.py --config config.json."""
from tfus.training import train
from tfus.data import UltrasoundDataset
from tfus.losses import rrmse, gdl_loss
from tfus.metrics import evaluate, paper_metrics
if __name__ == '__main__':
    import sys
    from tfus.cli import main
    main(['train', *sys.argv[1:]])
