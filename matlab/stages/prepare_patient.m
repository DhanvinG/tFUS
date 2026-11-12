% DICOM loading and ROI interaction extracted from the Live Script.
[skull_data, ct_data, voxel_spacing] = DicomToVolume(cfg.dicom_dir, volume_name, ...
    cfg.z_start, cfg.z_end, cfg.missing_slices, false);
[resized_CT, resized_skull, voxel_size] = ResizeCT(ct_data, skull_data, voxel_spacing, volume_name);
FOV = [300, 300, 300];
validate_baseline_grid(resized_CT, resized_skull, FOV, voxel_size);
[FOV_field_skull, FOV_field_ct] = PutIntoFOV(resized_CT, resized_skull, FOV, voxel_size);
volDims = ceil(FOV ./ voxel_size);
if isempty(cfg.target_mask_file)
    target = false(volDims);
    assert(cfg.annotation_stop <= size(target,2), 'Annotation slices exceed the FOV.');
    figure('Name', 'tFUS target annotation');
    for i = cfg.annotation_start:cfg.annotation_stop
        fprintf('Annotate sagittal slice %d/%d; double-click to finish the ROI.\n', i, cfg.annotation_stop);
        I = squeeze(FOV_field_ct(:, i, :));
        img = imshow(I, [0, 100]);
        view([-90, 90]);
        roi = images.roi.AssistedFreehand(img);
        draw(roi);
        assert(isvalid(roi) && ~isempty(roi.Position), 'Annotation cancelled.');
        target(:, i, :) = createMask(roi);
        imshow(squeeze(target(:, i, :)));
    end
else
    % Existing soft-to-bone mask reuse: same nearest-neighbor operation as baseline.
    S = load(cfg.target_mask_file, 'target', 'voxel_size');
    assert(isfield(S,'target') && isfield(S,'voxel_size'), 'Target file requires target and voxel_size.');
    assert(abs(S.voxel_size - voxel_size) < 1e-9, 'Annotation voxel size must match CT; registration is not inferred.');
    if ~isequal(size(FOV_field_ct), size(S.target))
        target = imresize3(uint8(S.target > 0), size(FOV_field_ct), 'nearest') > 0;
    else
        target = S.target;
    end
end
assert(any(target(:)), 'Target mask is empty.');
save([volume_name '_target.mat'], 'target', 'voxel_size', '-v7.3');
% Inspect the actual fixed placement point, not an inferred ROI centroid.
midY = round(cfg.target_point_vox(2));
figure('Name','tFUS annotation and configured placement target');
imshow(squeeze(FOV_field_ct(:,midY,:)), [0 100]); hold on;
contour(squeeze(target(:,midY,:)), [0.5 0.5], 'g', 'LineWidth', 1);
plot(cfg.target_point_vox(3), cfg.target_point_vox(1), 'r+', 'MarkerSize', 12);
title(sprintf('Y=%d; green: ROI; red: configured p0', midY));
answer = questdlg('Accept annotation and configured p0 for the baseline pose grid?', ...
    'Review geometry', 'Accept', 'Cancel', 'Cancel');
assert(strcmp(answer, 'Accept'), 'Geometry review cancelled; edit configuration and rerun prepare.');
save(prepared_file, 'resized_CT', 'resized_skull', 'voxel_size', 'target', 'FOV', '-v7.3');
