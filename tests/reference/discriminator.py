import torch.nn as nn
import torch

class Discriminator3D(nn.Module):
    def __init__(self, in_ch=2, base_ch=64):
        super().__init__()

        def block(in_c, out_c, ks=4, st=2, pad=1, norm=True):
            layers = [nn.Conv3d(in_c, out_c, ks, st, pad, bias=not norm)]
            if norm:
                layers.append(nn.InstanceNorm3d(out_c))
            layers.append(nn.LeakyReLU(0.2, inplace=True))
            return layers

        self.model = nn.Sequential(
            *block(in_ch,          base_ch,   norm=False),     
            *block(base_ch,        base_ch*2),                  
            *block(base_ch*2,      base_ch*4),                  
            *block(base_ch*4,      base_ch*8),                  
            *block(base_ch*8,      base_ch*8),                  
            *block(base_ch*8,      base_ch*8, ks=3, st=1, pad=1),     
            *block(base_ch*8,      base_ch*8, ks=3, st=1, pad=1),
            nn.Conv3d(base_ch*8, 1, 3, 1, 1),                     
            nn.Sigmoid()                                         
        )

    def forward(self, x):
        return self.model(x)
