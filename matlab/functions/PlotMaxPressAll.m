function PlotMaxPressAll(maxPress, skull, transducer, plane_type, slice_range, plot_skull)
figure;
for i = slice_range
midX = i;
midY = i;
midZ = i;
% Extract the slices for the specified plane
if strcmp(plane_type, 'XY')
imagesc(squeeze(maxPress(:,:,midZ)));
c = colorbar;
ylabel(c, 'Pressure(Pa)', 'FontSize', 16,'Rotation', 90 )
% set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(:,:,midZ)), 1, 'LineColor', 'r', 'LineWidth', 2);
end
% Overlay the skull shape
contour(squeeze(transducer(:,:,midZ)), 1, 'LineColor', [0.4, 0.2, 0.1], 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(3), focal_point(2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Z Position', 'FontSize', 16);
ylabel('Y Position', 'FontSize', 16);
title(['XY Plane ', num2str(i)],'FontSize', 16);
% view([-90, 90]);
hold off;
pause(0.001);
elseif strcmp(plane_type, 'XZ')
imagesc(squeeze(maxPress(:, midY, :)));
c = colorbar;
ylabel(c, 'Pressure(Pa)', 'FontSize', 16,'Rotation', 90 )
% set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(:, midY, :)), 1, 'LineColor', 'r', 'LineWidth', 2);
end
% Overlay the skull shape
contour(squeeze(transducer(:, midY, :)), 1, 'LineColor', [0.4, 0.2, 0.1], 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(3), focal_point(2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Z Position', 'FontSize', 16);
ylabel('Y Position', 'FontSize', 16);
title(['XZ Plane ', num2str(i)],'FontSize', 16);
% view([-90, 90]);
hold off;
pause(0.001);
elseif strcmp(plane_type, 'YZ')
imagesc(squeeze(maxPress(midX, :, :)));
c = colorbar;
ylabel(c, 'Pressure(Pa)', 'FontSize', 16,'Rotation', 90 )
% set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(midX, :, :)), 1, 'LineColor', 'r', 'LineWidth', 2);
end
% Overlay the skull shape
contour(squeeze(transducer(midX, :, :)), 1, 'LineColor', [0.4, 0.2, 0.1], 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(3), focal_point(2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Z Position', 'FontSize', 16);
ylabel('Y Position', 'FontSize', 16);
title(['YZ Plane ', num2str(i)],'FontSize', 16);
% view([-90, 90]);
hold off;
pause(0.001);
end
end
end
