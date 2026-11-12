function [sim_transducer_cut, sim_transducerF_cut, sim_skull_cut, sim_ct_cut, cut_start, cut_target] = CutSimArea(sim_transducer, sim_transducerF, sim_skull, sim_ct, sim_target)

% use logical mask and get bounding boxes
stats = regionprops3(logical(sim_transducer), "BoundingBox");

% --- pick the first component's box (keeps original behavior) ---
if isempty(stats)
    error('CutSimArea:NoComponent','sim_transducer has no non-zero voxels.');
end
bb = stats.BoundingBox(1,:);   % [x y z dx dy dz]

% Best Range for 70mm transducer
% range = [124, 124, 300];

% Best Range for 100mm transducer
range = [172, 172, 300];

% center in X/Y at the box center; keep your Z offset by -5 from the box start
center = [bb(1) + bb(4)/2, bb(2) + bb(5)/2, bb(3) - 5];

cutXS = ceil(center(1) - range(1)/2);
cutYS = ceil(center(2) - range(2)/2);
cutZS = ceil(center(3));

cutXE = ceil(center(1) + range(1)/2 - 1);
cutYE = ceil(center(2) + range(2)/2 - 1);
cutZE = ceil(center(3) + range(3) - 1);

cut_start = [cutXS, cutYS, cutZS];

cutX = cutXS:cutXE;
cutY = cutYS:cutYE;
cutZ = cutZS:cutZE;

% clamp to valid indices
[nY, nX, nZ] = size(sim_transducer);
cutX(cutX < 1)  = 1;  cutX(cutX > nX) = nX;
cutY(cutY < 1)  = 1;  cutY(cutY > nY) = nY;
cutZ(cutZ < 1)  = 1;  cutZ(cutZ > nZ) = nZ;

sim_transducer_cut  = sim_transducer( cutY, cutX, cutZ );
sim_transducerF_cut = sim_transducerF(cutY, cutX, cutZ );
sim_skull_cut       = sim_skull(      cutY, cutX, cutZ );
sim_ct_cut          = sim_ct(         cutY, cutX, cutZ );
cut_target          = sim_target(     cutY, cutX, cutZ );

end
