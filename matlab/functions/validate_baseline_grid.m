function validate_baseline_grid(ct, skull, FOV, voxel_size)
% Fail explicitly instead of changing the baseline centering or coordinates.
assert(abs(voxel_size - 0.6250) < 1e-9, ...
    'Baseline pose grid requires 0.6250 mm isotropic spacing. Other spacings require a separately validated scientific change.');
assert(isequal(size(ct),size(skull)), 'CT and skull dimensions differ.');
dims = FOV ./ voxel_size;
extra = dims - size(ct);
assert(all(dims == round(dims)) && all(extra >= 2) && all(mod(extra,2) == 0), ...
    'Baseline PutIntoFOV requires positive even padding. No automatic shift or crop is applied.');
end
