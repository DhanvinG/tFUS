function [density, sound_speed] = apply_min_limits(matrix, min_value)
matrix(matrix < min_value) = min_value;
density = matrix;
end
