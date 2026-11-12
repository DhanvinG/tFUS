function [focal_zone_90MPA, focal_zone_30MPA] = PlotAlongFocusAll(MaxPressure, skull, transducer, focal_point, medium, target, voxel_size, inwater)
%Find Focal Point without reorientation
Nx = size(MaxPressure,1);
Ny = size(MaxPressure,2);
Nz = size(MaxPressure,3);
expected_focal_range = [1,Nx,1,Ny,1,Nz];
MaxPressureWOSkull = MaxPressure;
if inwater == false
for x = 1:Nx
for y = 1:Ny
for z = 1:Nz
if medium.density(x,y,z) > 1260
MaxPressureWOSkull(x,y,z) = 0;
end
if medium.density(x,y,z) < 1000.1
MaxPressureWOSkull(x,y,z) = 0;
end
end
end
end
end
% Find max along x
[M,I] = max(MaxPressureWOSkull(expected_focal_range(1):expected_focal_range(2),expected_focal_range(3):expected_focal_range(4), expected_focal_range(5):expected_focal_range(6)));
% Find max in y
[M2,I2] = max(M);
% Find max in z4 89
[M3,I3] = max(M2);
focalx = I(1,I2(1,1,I3),I3);
focaly = I2(1,1,I3);
focalz = I3;
% Max Pressure
max_pressure = max(max(max(MaxPressureWOSkull(expected_focal_range(1):expected_focal_range(2),expected_focal_range(3):expected_focal_range(4), expected_focal_range(5):expected_focal_range(6)))))
real_focal_point_max = [focalx,focaly,focalz]


center_point = [Nx/2, Ny/2, Nz/2];
% Determine Focal Threshold for Zone Without Reorientation
focal_threshold_45 = 0.45e6;
focal_threshold_90 = 0.95e6;
focal_threshold_30 = 0.3e6;
focal_threshold_140 = 1.4e6;




focal_zone_90MPA = MaxPressureWOSkull > focal_threshold_90;
focal_zone_45MPA = MaxPressureWOSkull > focal_threshold_45;
focal_zone_30MPA = MaxPressureWOSkull > focal_threshold_30;
focal_zone_140MPA = MaxPressureWOSkull > focal_threshold_140;


% Plot focal zone within skull
figure;
hold on;
% Plot the voxelized skull
[X_voxel, Y_voxel, Z_voxel] = meshgrid(1:Ny, 1:Nx, 1:Nz);
% Smooth skull to try and lower computational time to plot
smooth_FOV_field_skull = smooth3(skull>260);
% Convert grid points to millimeters
X_mm = X_voxel * voxel_size;
Y_mm = Y_voxel * voxel_size;
Z_mm = Z_voxel * voxel_size;
patch(isosurface(X_mm, Y_mm, Z_mm, smooth_FOV_field_skull, 0.2), 'FaceColor', 'blue', 'EdgeColor', 'none', 'FaceAlpha', 0.2);
% Plot the focal zone
patch(isosurface(X_mm, Y_mm, Z_mm, focal_zone_90MPA, 1.0), 'FaceColor', 'black', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
patch(isosurface(X_mm, Y_mm, Z_mm, focal_zone_30MPA, 0.5), 'FaceColor', 'green', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% Plot the transducer
%patch(isosurface(X_mm, Y_mm, Z_mm, transducer, 0.5), 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% Plot the transducer
axis equal;
xlabel('Y-axis (mm)', 'FontSize', 15);
ylabel('X-axis (mm)', 'FontSize', 15);
zlabel('Z-axis (mm)', 'FontSize', 15);
title('Skull and Transducer in FOV', 'FontSize', 16);
camlight;
grid on;
view(3);
lighting gouraud;
ax = gca; % Get the current axes
ax.FontSize = 15; % Change axis tick label size


% Plot focal fields in 3 planes
x_mm = (1:size(MaxPressure, 1)) * voxel_size;
figure('Name','X center line');
plot(x_mm, squeeze(MaxPressure(:,center_point(2),center_point(3))));
xlabel('X-axis (mm)', 'FontSize', 15);
ylabel('Pressure (Pa)', 'FontSize', 15);
hold on;
ax = gca; % Get the current axes
ax.FontSize = 15; % Change axis tick label size
% Show focal (50%)
h1 = yline(focal_threshold_45, 'Color', 'green', 'LineWidth', 2); % Add handle for legend
h1.DisplayName = '0.45 MPa Focal Threshold';


% Show focal (75%)
h2 = yline(focal_threshold_90, 'Color', '#77AC30', 'LineWidth', 2); % Add handle for legend
h2.DisplayName = '0.9 MPa Focal Threshold';


% Show transducer location
transducer_location_mm = focal_point(1) * voxel_size;
h3 = xline(transducer_location_mm, 'Color', 'red', 'LineWidth', 2); % Add handle for legend
h3.DisplayName = 'Transducer Location';


% Add legend
legend([h1, h2, h3], 'Location', 'best');




% Y Center Line
y_mm = (1:size(MaxPressure, 2)) * voxel_size;
figure('Name', 'Y center line');
plot(y_mm, squeeze(MaxPressure(center_point(1), :, center_point(3))));
xlabel('Y-axis (mm)', 'FontSize', 15);
ylabel('Pressure (Pa)', 'FontSize', 15);
hold on;
ax = gca; % Get the current axes
ax.FontSize = 15; % Change axis tick label size
% Show focal (50%)
h1 = yline(focal_threshold_45, 'Color', 'green', 'LineWidth', 2); % Add handle for legend
h1.DisplayName = '0.45 MPa Focal Threshold';


% Show focal (75%)
h2 = yline(focal_threshold_90, 'Color', '#77AC30', 'LineWidth', 2); % Add handle for legend
h2.DisplayName = '0.9 MPa Focal Threshold';


% Show transducer location
transducer_location_mm_y = focal_point(2) * voxel_size;
h3 = xline(transducer_location_mm_y, 'Color', 'red', 'LineWidth', 2);
h3.DisplayName = 'Transducer Location';
% Add legend
legend([h1, h2, h3], 'Location', 'best');
hold off;
% Z Center Line
z_mm = (1:size(MaxPressure, 3)) * voxel_size;
figure('Name', 'Z center line');
yyaxis left;
plot(z_mm, squeeze(MaxPressure(center_point(1), center_point(2), :)));
xlabel('Z-axis (mm)', 'FontSize', 15);
ylabel('Pressure (Pa)', 'FontSize', 15);
hold on;
ax = gca; % Get the current axes
ax.FontSize = 15; % Change axis tick label size
% Show focal (50%)
h1 = yline(focal_threshold_45, 'Color', 'green', 'LineWidth', 2); % Add handle for legend
h1.DisplayName = '0.45 MPa Focal Threshold';


% Show focal (75%)
h2 = yline(focal_threshold_90, 'Color', '#77AC30', 'LineWidth', 2); % Add handle for legend
h2.DisplayName = '0.9 MPa Focal Threshold';


yyaxis right;
plot(z_mm, squeeze(medium.alpha_coeff(center_point(1), center_point(2), :)));
ylabel('Alpha Coefficients', 'FontSize', 15);
hold on;
% Add legend
legend([h1, h2], 'Location', 'best');
hold off;
end
