function plot_slicePost(matrix, matrix_t_1, matrix_t_2, matrix_target, slice_range, plane_type)
figure;
for i = slice_range
midX = i;
midY = i;
midZ = i;
% Extract the slices for the specified plane
if strcmp(plane_type, 'XY')
slice = squeeze(matrix(:, :, midZ));
slice_tr1 = squeeze(matrix_t_1(:, :, midZ));
slice_tr2 = squeeze(matrix_t_2(:, :, midZ));
slice_tar = squeeze(matrix_target(:, :, midZ));
title_text = ['XY Plane ', num2str(i)];
xlabel_text = 'Y';
ylabel_text = 'X';
elseif strcmp(plane_type, 'XZ')
slice = squeeze(matrix(:, midY, :));
slice_tr1 = squeeze(matrix_t_1(:, midY, :));
slice_tr2 = squeeze(matrix_t_2(:, midY, :));
slice_tar = squeeze(matrix_target(:, midY, :));
title_text = ['XZ Plane ', num2str(i)];
xlabel_text = 'Z';
ylabel_text = 'X';
elseif strcmp(plane_type, 'YZ')
slice = squeeze(matrix(midX, :, :));
slice_tr1 = squeeze(matrix_t_1(midX, :, :));
slice_tr2 = squeeze(matrix_t_2(midX, :, :));
slice_tar = squeeze(matrix_target(midX, :, :));
title_text = ['YZ Plane ', num2str(i)];
xlabel_text = 'Z';
ylabel_text = 'Y';
end


% Plot the plane
ax1 = axes;
im = imagesc(ax1,slice);
im.AlphaData = 1;
axis equal;
% title(title_text);
% xlabel(xlabel_text);
% ylabel(ylabel_text);
ax2 = axes;
im1 = imagesc(ax2, slice_tr1);
im1.AlphaData = 0.5;
axis equal;
linkaxes([ax1, ax2]);
ax2.Visible = 'off';
ax2.XTick = [];
ax2.YTick = [];
hold(ax2,'on')
contour(slice_tr2, 1, 'LineColor', 'red', 'LineWidth', 1);
contour(slice_tar, 1, 'LineColor', 'g', 'LineWidth', .1);
colormap(ax1, 'gray');
clim(ax1, [0,50]);
colormap(ax2, 'hot');
%set the axes and colorbar position
% set([ax1,ax2],'Position',[.17 .11 .685 .815]);
% cb1 = colorbar(ax1,'Position',[.05 .11 .0675 .815]);
% cb2 = colorbar(ax2,'Position',[.88 .11 .0675 .815]);
% Label the colorbars
% cb1.Label.String = 'Signal Intensity (housefield units)';
% cb2.Label.String = 'Pressure (Pa)';
hold(ax1,'off')
hold(ax2,'off')
pause(0.001);
ax1.Visible = 'off';
ax1.XTick = [];
ax1.YTick = [];
end
end
