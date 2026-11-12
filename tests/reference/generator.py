import torch
import torch.nn as nn

class ResidualBlock3D(nn.Module):
    def __init__(self, channels, dropout=0.5):
        super().__init__()
        self.block = nn.Sequential(
            nn.Conv3d(channels, channels, kernel_size=3, stride=1, padding=1, bias=False, padding_mode='reflect'),
            nn.InstanceNorm3d(channels),
            nn.ReLU(inplace=True),
            nn.Dropout3d(dropout),
            nn.Conv3d(channels, channels, kernel_size=3, stride=1, padding=1, bias=False, padding_mode='reflect'),
            nn.InstanceNorm3d(channels)
        )

    def forward(self, x):
        return x + self.block(x)

class Generator3D(nn.Module):
    """
    Size-preserving 3D generator for inputs shaped (N, C_in, D=160, H=100, W=100).
    Downsample 3x (4,2,1) → Up 3x (4,2,1); the first upsample uses
    output_padding=(0,1,1) to recover H/W exactly (D unaffected).
    """
    def __init__(self, in_ch=2, out_ch=1, num_res_blocks=9):
        super().__init__()

        # Encoder (D,H,W all halved each block)
        self.down1 = nn.Sequential(
            nn.Conv3d(in_ch, 64, kernel_size=4, stride=2, padding=1, bias=False, padding_mode='reflect'),
            nn.InstanceNorm3d(64),
            nn.ReLU(inplace=True),
        )
        self.down2 = nn.Sequential(
            nn.Conv3d(64, 128, kernel_size=4, stride=2, padding=1, bias=False, padding_mode='reflect'),
            nn.InstanceNorm3d(128),
            nn.ReLU(inplace=True),
        )
        self.down3 = nn.Sequential(
            nn.Conv3d(128, 256, kernel_size=4, stride=2, padding=1, bias=False, padding_mode='reflect'),
            nn.InstanceNorm3d(256),
            nn.ReLU(inplace=True),
        )

        # Bottleneck (residual blocks at the coarsest scale)
        self.res_blocks = nn.Sequential(
            *[ResidualBlock3D(256) for _ in range(num_res_blocks)]
        )

        # Decoder
        # NOTE: First upsample uses output_padding=(0,1,1) so:
        #   D: 20 -> 40 (no +1), H/W: 12 -> 25 (+1), then 25->50->100
        self.up1 = nn.Sequential(
            nn.ConvTranspose3d(256, 128,
                               kernel_size=(4,4,4),
                               stride=(2,2,2),
                               padding=(1,1,1),
                               output_padding=(0,1,1),   # <-- key fix
                               bias=False),
            nn.InstanceNorm3d(128),
            nn.ReLU(inplace=True),
        )
        self.up2 = nn.Sequential(
            nn.ConvTranspose3d(128, 64,
                               kernel_size=(4,4,4),
                               stride=(2,2,2),
                               padding=(1,1,1),
                               output_padding=(0,0,0),
                               bias=False),
            nn.InstanceNorm3d(64),
            nn.ReLU(inplace=True),
        )
        self.up3 = nn.Sequential(
            nn.ConvTranspose3d(64, out_ch,
                               kernel_size=(4,4,4),
                               stride=(2,2,2),
                               padding=(1,1,1),
                               output_padding=(0,0,0)),
            nn.Sigmoid(),
        )

    def forward(self, x):
        d1 = self.down1(x)   # (N,64, 80, 50, 50)
        d2 = self.down2(d1)  # (N,128,40, 25, 25)
        d3 = self.down3(d2)  # (N,256,20, 12, 12)
        r  = self.res_blocks(d3)
        u1 = self.up1(r)     # (N,128,40, 25, 25)     H/W got +1 from 24->25
        u2 = self.up2(u1)    # (N,64, 80, 50, 50)
        out= self.up3(u2)    # (N,1,  160,100,100)
        return out
