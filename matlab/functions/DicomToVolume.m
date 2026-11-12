function [skull_data, ct_data, voxel_spacing] = DicomToVolume(dicom_folder, volume_name, z_start, z_end, missing_slices, plot)
% Convert dicoms to voxelized medVol for plotting
medVol = medicalVolume(dicom_folder);
% Convert dicoms to 3D volume for simulation
for i=z_start:z_end
if i < 10
filenumber = append('IMG000',int2str(i),'.dcm');
elseif i < 100 && i > 9
filenumber = append('IMG00',int2str(i),'.dcm');
else
filenumber = append('IMG0',int2str(i),'.dcm');
end


ct_data(:,:,i) = dicomread(fullfile(dicom_folder, filenumber));


if(plot)
imshow(ct_data(:,:,i),DisplayRange=[]);
end
end


% Get voxel spacing / other info if needed here:
info = dicominfo(fullfile(dicom_folder, filenumber));
voxel_spacing = [info.PixelSpacing(1), info.PixelSpacing(2), info.SliceThickness];


ct_data = ct_data(:,:,z_start:z_end);
skull_data = medVol.Voxels(:,:,(z_start-missing_slices):(z_end-missing_slices));


% Save both files for further analysis
save(append(volume_name,'_CT_data.mat'),"skull_data","ct_data","voxel_spacing");
end
