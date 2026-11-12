function plot_slice(matrix, matrix_t_1, matrix_t_2, matrix_target, slice_range, plane_type)
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
% Plot the selected plane slice
imagesc(slice);
title(title_text);
xlabel(xlabel_text);
ylabel(ylabel_text);
colormap('gray');
% Set color limits
clim([0, 50]);
% Add contours for the transducers and target (if available)
hold on;
contour(slice_tr1, 1, 'LineColor', 'r', 'LineWidth', 1);
contour(slice_tr2, 1, 'LineColor', 'g', 'LineWidth', 0.1);
if ~isempty(slice_tar)
contour(slice_tar, 1, 'LineColor', 'b', 'LineWidth', 0.1);
end
hold off;
pause(0.001);
end
end
