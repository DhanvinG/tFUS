function PlotMaxPress(maxPress, skull, transducer, focal_point, plot_skull)
% Plot Maxiumum Pressure Plots
figure;
for x_index = focal_point(1)
imagesc(squeeze(maxPress(x_index,:,:)));
c = colorbar;
ylabel(c, 'Pressure(Pa)', 'FontSize', 16,'Rotation', 90 )
set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(x_index,: , :)), 1, 'LineColor', 'r', 'LineWidth', 2);
end
% Overlay the skull shape
contour(squeeze(transducer(x_index,: , :)), 1, 'LineColor', [0.4, 0.2, 0.1], 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(3), focal_point(2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Z Position', 'FontSize', 16);
ylabel('Y Position', 'FontSize', 16);
title(['Max Pressure in X', num2str(x_index)],'FontSize', 16);
% view([-90, 90]);
pause(0.01); % Pause to create an animation effect
ax = gca; % Get the current axes
ax.FontSize = 16; % Change axis tick label size
end
figure;
for y_index = focal_point(2)
imagesc(squeeze(maxPress(:,y_index,:)));
c = colorbar;
ylabel(c, 'Pressure(Pa)', 'FontSize', 16,'Rotation', 90)
set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(:,y_index , :)), 1, 'LineColor', 'r', 'LineWidth', 2);
ax = gca; % Get the current axes
ax.FontSize = 16; % Change axis tick label size
end
% Overlay the skull shape
contour(squeeze(transducer(:,y_index , :)), 1, 'LineColor', 'magenta', 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(3), focal_point(1), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Z Position','FontSize', 16);
ylabel('X Position', 'FontSize', 16);
title(['Max Pressure in Y', num2str(y_index)], 'FontSize', 16);
% view([-90, 90]);
pause(0.01); % Pause to create an animation effect
ax = gca; % Get the current axes
ax.FontSize = 16; % Change axis tick label size
end
figure;
for z_index = focal_point(3)
imagesc(squeeze(maxPress(:,:,z_index)));
c = colorbar;
ylabel(c,'Pressure(Pa)', 'FontSize', 16,'Rotation', 90 )
set(gca,'CLim',[0 0.95e6]);
hold on; % Hold the plot to overlay the skull shape and focal point
if plot_skull
% Overlay the skull shape
contour(squeeze(skull(:,: , z_index)), 1, 'LineColor', 'r', 'LineWidth', 2);
ax = gca; % Get the current axes
ax.FontSize = 16; % Change axis tick label size
end


% Overlay the skull shape
contour(squeeze(transducer(:,: , z_index)), 1, 'LineColor', 'r', 'LineWidth', 2);
% Plot the expected focal point
% plot(focal_point(2), focal_point(1), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('Y Position', 'FontSize', 16);
ylabel('X Position','FontSize', 16);
title(['Max Pressure in Z', num2str(z_index)], 'FontSize', 16);
% view([-90, 90]);
pause(0.01);
ax = gca; % Get the current axes
ax.FontSize = 16; % Change axis tick label size
end
end
