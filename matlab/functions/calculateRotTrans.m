function [eul_deg_2, transducer_loc, target_loc, eul_deg, R] = calculateRotTrans(target, transducer_est_loc, voxel_size, focal_length)
p0 = target;
p1 = transducer_est_loc;
v = p0-p1;
% Let's define si and theta in such a way that.
r = norm(v);
si = atan2(v(3),v(1))
theta = atan2(v(2),sqrt(v(1).^2+v(3).^2))
v = [r*cos(si)*cos(theta), r*sin(theta), r*sin(si)*cos(theta)];
j = [cos(si)*cos(theta), sin(theta), sin(si)*cos(theta)];
% Correspond to j vector you can also find orthonormal vector to j
i = [sin(si), 0, -cos(si)];
k = [cos(si)*sin(theta), -cos(theta), sin(si)*sin(theta)];
% Rotation matrix;
m = [i',j',k'];
% You can use MATLAB inbuilt function to convert rotation matrix to Euler system
eul = rotm2eul(m);
eul_deg = rad2deg(eul)


% Calculate the rotation matrix to align the initial z-axis to the direction of the target
initial_orientation = [0, 0, 1]; % Positive Z direction
direction = v / norm(v); % Normalize the target direction
% Calculate the rotation matrix to align the transducer with the target direction
R = rotation_matrix_from_vectors(initial_orientation, direction)
% You can use MATLAB inbuilt function to convert rotation matrix to Euler system
eul_2 = rotm2eul(R);
eul_deg_2 = rad2deg(eul_2)


% Apply the rotation to the transducer location
Atransducer_loc = (R * (p1 - p0)')' + p0;


% Apply the rotation to the transducer location
target_loc = (R * (p0 - p1)')' + p1;
% Transducer point
far_target_distance = focal_length/voxel_size;
distance = sqrt((p1(1) - p0(1))^2 + (p1(2) - p0(2))^2 + (p1(3) - p0(3))^2);
ratio = far_target_distance/distance;
diff_t = p1-p0;
dis_t = diff_t*ratio;
transducer_loc = round(dis_t + p0);
new_distance = sqrt((transducer_loc(1) - p0(1))^2 + (transducer_loc(2) - p0(2))^2 + (transducer_loc(3) - p0(3))^2);
C = cross(p0, transducer_loc)
D = dot(p0, transducer_loc);
NP0 = norm(p0); % used for scaling
if ~all(C==0) % check for colinearity
Z = [0 -C(3) C(2); C(3) 0 -C(1); -C(2) C(1) 0] ;
R1 = (eye(3) + Z + Z^2 * (1-D)/(norm(C)^2)) / NP0^2; % rotation matrix
else
R1 = sign(D) * (norm(p1) / NP0); % orientation and scaling
end
R_deg = rad2deg(R1);
eulXYZ = rotm2eul(R1,'XYZ');
eulXYZ_deg = rad2deg(eulXYZ);
end
