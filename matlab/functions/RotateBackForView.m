function [sim_transducer, sim_transducerF, sim_skull, sim_ct, focalZoneVolumeRot, sim_target] = RotateBackForView(translated_center_point_1, adjusted_transducer_focal_1, adjusted_transducer_1, FOV_field_skull, FOV_field_ct, focal_zone, target, rotation)


% Find origin from translated center point
original_center = [size(adjusted_transducer_1,1)/2, size(adjusted_transducer_1,2)/2, size(adjusted_transducer_1,3)/2];
old_center = [translated_center_point_1(2), translated_center_point_1(1), translated_center_point_1(3)];
% origin = original_center-old_center;
origin = [0,0,0];


% Translate all fields to origin to prepare for rotation
transducerF_at_origin = imtranslate(adjusted_transducer_focal_1, origin, "OutputView","same");
transducer_at_origin = imtranslate(adjusted_transducer_1, origin, "OutputView","same");
skull_at_origin = imtranslate(FOV_field_skull, origin, "OutputView","same");
ct_at_origin = imtranslate(FOV_field_ct, origin, "OutputView","same");
focal_zone_at_origin = imtranslate(focal_zone, origin, "OutputView","same");
target_at_origin = imtranslate(target, origin, "OutputView","same");


new_center_point = original_center;


% Rotate in reverse order
xRot = rotation(1);
yRot = rotation(2);
zRot = rotation(3);


% Apply rotations using imrotate3
transducerVolumeRotX = imrotate3(transducer_at_origin, xRot, [1 0 0], 'nearest', 'crop');
transducerVolumeRotY = imrotate3(transducerVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_transducer = imrotate3(transducerVolumeRotY, zRot, [0 0 1], 'nearest', 'crop');


transducerFVolumeRotX = imrotate3(transducerF_at_origin, xRot, [1 0 0], 'nearest', 'crop');
transducerFVolumeRotY = imrotate3(transducerFVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_transducerF = imrotate3(transducerFVolumeRotY, zRot, [0 0 1], 'nearest', 'crop');


skullVolumeRotX = imrotate3(skull_at_origin, xRot, [1 0 0], 'nearest', 'crop');
skullVolumeRotY = imrotate3(skullVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_skull = imrotate3(skullVolumeRotY, zRot, [0 0 1], 'nearest', 'crop');


ctVolumeRotX = imrotate3(ct_at_origin, xRot, [1 0 0], 'nearest', 'crop');
ctVolumeRotY = imrotate3(ctVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_ct = imrotate3(ctVolumeRotY, zRot, [0 0 1], 'nearest', 'crop');


focalZoneVolumeRotX = imrotate3(focal_zone_at_origin, rotation(1), [1 0 0], 'nearest', 'crop');
focalZoneVolumeRotY = imrotate3(focalZoneVolumeRotX, rotation(2), [0 1 0], 'nearest', 'crop');
focalZoneVolumeRot = imrotate3(focalZoneVolumeRotY, rotation(3), [0 0 1], 'nearest', 'crop');


targetRotX = imrotate3(target_at_origin, rotation(1), [1 0 0], 'nearest', 'crop');
targetRotY = imrotate3(targetRotX, rotation(2), [0 1 0], 'nearest', 'crop');
sim_target = imrotate3(targetRotY, rotation(3), [0 0 1], 'nearest', 'crop');
%
% % Translate all fields to origin to prepare for rotation
% sim_transducerF = imtranslate(sim_transducerF, -origin, "OutputView","same");
% sim_transducer = imtranslate(sim_transducer, -origin, "OutputView","same");
% sim_skull = imtranslate(sim_skull, -origin, "OutputView","same");
% sim_ct = imtranslate(sim_ct, -origin, "OutputView","same");
% focalZoneVolumeRot = imtranslate(focalZoneVolumeRot, -origin, "OutputView","same");
% sim_target = imtranslate(sim_target, -origin, "OutputView","same");
end
