function [sim_transducer, sim_transducerF, sim_skull, sim_ct, sim_target, stats, stats1] = PrepareSimField(translated_center_point_1, adjusted_transducer_focal_1, adjusted_transducer_1, FOV_field_skull, FOV_field_ct, target, rotation)


stats = regionprops3(adjusted_transducer_focal_1,"Centroid","PrincipalAxisLength","BoundingBox","Orientation");


% Find origin from translated center point
original_center = [size(adjusted_transducer_1,1)/2, size(adjusted_transducer_1,2)/2, size(adjusted_transducer_1,3)/2];
old_center = [translated_center_point_1(2), translated_center_point_1(1), translated_center_point_1(3)];
origin = original_center-old_center;


% Translate all fields to origin to prepare for rotation
transducerF_at_origin = imtranslate(adjusted_transducer_focal_1, origin, "OutputView","same");
transducer_at_origin = imtranslate(adjusted_transducer_1, origin, "OutputView","same");
skull_at_origin = imtranslate(FOV_field_skull, origin, "OutputView","same");
ct_at_origin = imtranslate(FOV_field_ct, origin, "OutputView","same");
target_at_origin = imtranslate(target, origin, "OutputView","same");


new_center_point = original_center;


stats1 = regionprops3(transducerF_at_origin,"Centroid","PrincipalAxisLength","BoundingBox","Orientation");


% Rotate in reverse order
xRot = -rotation(1);
yRot = -rotation(2);
zRot = -rotation(3);


% Apply rotations using imrotate3
transducerVolumeRotX = imrotate3(transducer_at_origin, zRot, [0 0 1], 'nearest', 'crop');
transducerVolumeRotY = imrotate3(transducerVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_transducer = imrotate3(transducerVolumeRotY, xRot, [1 0 0], 'nearest', 'crop');


transducerFVolumeRotX = imrotate3(transducerF_at_origin, zRot, [0 0 1], 'nearest', 'crop');
transducerFVolumeRotY = imrotate3(transducerFVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_transducerF = imrotate3(transducerFVolumeRotY, xRot, [1 0 0], 'nearest', 'crop');


skullVolumeRotX = imrotate3(skull_at_origin, zRot, [0 0 1], 'nearest', 'crop');
skullVolumeRotY = imrotate3(skullVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_skull = imrotate3(skullVolumeRotY, xRot, [1 0 0], 'nearest', 'crop');


ctVolumeRotX = imrotate3(ct_at_origin, zRot, [0 0 1], 'nearest', 'crop');
ctVolumeRotY = imrotate3(ctVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_ct = imrotate3(ctVolumeRotY, xRot, [1 0 0], 'nearest', 'crop');


targetVolumeRotX = imrotate3(target_at_origin, zRot, [0 0 1], 'nearest', 'crop');
targetVolumeRotY = imrotate3(targetVolumeRotX, yRot, [0 1 0], 'nearest', 'crop');
sim_target = imrotate3(targetVolumeRotY, xRot, [1 0 0], 'nearest', 'crop');
end
