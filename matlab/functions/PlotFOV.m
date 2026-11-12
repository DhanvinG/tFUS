function PlotFOV(FOV_field_skull, adjusted_transducer_focal_1, target, focal_zone, voxel_size)
% Smooth skull to try and lower computational time to plot
smooth_FOV_field_skull = smooth3(FOV_field_skull);




% Create figure
figure;


% Define meshgrid for the FOV
[X_voxel, Y_voxel, Z_voxel] = meshgrid(1:size(FOV_field_skull,2), 1:size(FOV_field_skull,1), 1:size(FOV_field_skull,3));
X_mm = X_voxel * voxel_size;
Y_mm = Y_voxel * voxel_size;
Z_mm = Z_voxel * voxel_size;
% Plot voxelized skull (blue, transparent)
patch(isosurface(X_mm, Y_mm, Z_mm, smooth_FOV_field_skull, 0.5), 'FaceColor', 'blue', 'EdgeColor', 'none', 'FaceAlpha', 0.2);
hold on;


% Plot transducer (red, more opaque)
patch(isosurface(X_mm, Y_mm, Z_mm, adjusted_transducer_focal_1, 0.5), 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.5);


if sum(sum(sum(target))) > 0
% Plot target (cyan, more opaque)
patch(isosurface(X_mm, Y_mm, Z_mm, target, 0.5), 'FaceColor', 'cyan', 'EdgeColor', 'none', 'FaceAlpha', 0.5)
end


if sum(sum(sum(focal_zone))) > 0
% Plot focal zone (green, more opaque)
patch(isosurface(X_mm, Y_mm, Z_mm, focal_zone, 0.5), 'FaceColor', 'green', 'EdgeColor', 'none', 'FaceAlpha', 0.5)
end
axis equal;
xlabel('Y-axis (mm)', 'FontSize', 15);
ylabel('X-axis (mm)', 'FontSize', 15);
zlabel('Z-axis (mm)', 'FontSize', 15);
title('Skull and Transducer in FOV', 'FontSize', 15);
camlight;
grid on;
view(3);
lighting gouraud;
ax = gca; % Get the current axes
ax.FontSize = 15; % Change axis tick label size
end
