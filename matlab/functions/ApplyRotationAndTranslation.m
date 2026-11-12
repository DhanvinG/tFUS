function [adjusted_transducer, adjusted_transducer_focal, translated_center_point] = ApplyRotationAndTranslation(transducer, transducer_focal, rotation, translation, FOV, voxel_size, center_point)

% --- keep masks logical to save memory ---
transducer       = logical(transducer);
transducer_focal = logical(transducer_focal);

% --- 1) Apply Rotation (same, nearest keeps masks) ---
transducerFVolumeRotX = imrotate3(transducer_focal, rotation(1), [1 0 0], 'nearest', 'crop');
transducerFVolumeRotY = imrotate3(transducerFVolumeRotX, rotation(2), [0 1 0], 'nearest', 'crop');
transducerFVolumeRot  = imrotate3(transducerFVolumeRotY, rotation(3), [0 0 1], 'nearest', 'crop');

transducerVolumeRotX = imrotate3(transducer, rotation(1), [1 0 0], 'nearest', 'crop');
transducerVolumeRotY = imrotate3(transducerVolumeRotX, rotation(2), [0 1 0], 'nearest', 'crop');
transducerVolumeRot  = imrotate3(transducerVolumeRotY, rotation(3), [0 0 1], 'nearest', 'crop');

% --- 2) Build FOV with INTEGER dims and logical class ---
volDims = ceil(FOV ./ voxel_size);               % integer [Nx Ny Nz]
transducer_field  = false(volDims);              % logical saves RAM
transducerF_field = false(volDims);

% integer centering
ExX = volDims(1) - size(transducerVolumeRot,1);
ExY = volDims(2) - size(transducerVolumeRot,2);
ExZ = volDims(3) - size(transducerVolumeRot,3);

sx = 1 + floor(ExX/2);
sy = 1 + floor(ExY/2);
sz = 1 + floor(ExZ/2);

% place into center
transducer_field( sx:sx+size(transducerVolumeRot,1)-1, ...
                  sy:sy+size(transducerVolumeRot,2)-1, ...
                  sz:sz+size(transducerVolumeRot,3)-1) = logical(transducerVolumeRot);

transducerF_field(sx:sx+size(transducerFVolumeRot,1)-1, ...
                  sy:sy+size(transducerFVolumeRot,2)-1, ...
                  sz:sz+size(transducerFVolumeRot,3)-1) = logical(transducerFVolumeRot);

new_center_point = [center_point(1)+floor(ExX/2), ...
                    center_point(2)+floor(ExY/2), ...
                    center_point(3)+floor(ExZ/2)];

% --- 3) Apply final (integer) translation ---
translation = round(translation);
adjusted_transducer       = imtranslate(transducer_field,   translation, "OutputView","same");
adjusted_transducer_focal = imtranslate(transducerF_field, translation,  "OutputView","same");

translated_center_point = new_center_point + translation;
end
