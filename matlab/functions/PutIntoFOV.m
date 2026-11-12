function [FOV_field_skull, FOV_field_ct] = PutIntoFOV(resized_CT, resized_skull, FOV, voxel_size)


% Define FOV in voxel spacing
FOV_field_skull = zeros(FOV(1)/voxel_size, FOV(2)/voxel_size, FOV(3)/voxel_size);
FOV_field_ct = zeros(FOV(1)/voxel_size, FOV(2)/voxel_size, FOV(3)/voxel_size);
% Determine extra space on all sides (same for ct and skull)
ExtraX = size(FOV_field_skull,1) - size(resized_skull,1);
ExtraY = size(FOV_field_skull,2) - size(resized_skull,2);
ExtraZ = size(FOV_field_skull,3) - size(resized_skull,3);
% Place the skull data into the center of the FOV
FOV_field_skull((ExtraX/2):((ExtraX/2)+size(resized_skull,1)-1), (ExtraY/2):((ExtraY/2)+ ...
size(resized_skull,2)-1), (ExtraZ/2):((ExtraZ/2)+size(resized_skull,3)-1)) = resized_skull;
% Place the ct data into the center of the FOV
FOV_field_ct((ExtraX/2):((ExtraX/2)+size(resized_CT,1)-1), (ExtraY/2):((ExtraY/2)+ ...
size(resized_CT,2)-1), (ExtraZ/2):((ExtraZ/2)+size(resized_CT,3)-1)) = resized_CT;
end
