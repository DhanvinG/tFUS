function [resized_CT, resized_skull, voxel_size] = ResizeCT(ct_data, voxelized_skull, voxel_spacing, volume_name)


% Permute voxzelized_skull (for some reason X and Y are switched)
voxelized_skull_p = permute(voxelized_skull,[2,1,3]);


% Find max spacing (to subsample to)
voxel_size = max(voxel_spacing);


% Determine resizing factor
resize_factor_X = voxel_spacing(1)/voxel_size;
resize_factor_Y = voxel_spacing(2)/voxel_size;
resize_factor_Z = voxel_spacing(3)/voxel_size;


% Resize CT and skull data
resized_skull = imresize3(voxelized_skull_p,[(resize_factor_X*size(voxelized_skull_p,1)) ...
(resize_factor_Y*size(voxelized_skull_p,2)) (resize_factor_Z*size(voxelized_skull_p,3))]);
resized_CT = imresize3(ct_data,[(resize_factor_X*size(ct_data,1)) (resize_factor_Y*size(ct_data,2)) ...
(resize_factor_Z*size(ct_data,3))]);


% Save both files for further analysis
save(append(volume_name,'_resized_CT_data.mat'),"resized_skull","resized_CT","voxel_size");


end
