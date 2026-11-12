function R = rotation_matrix_from_vectors(A, B)
% A and B are unit vectors, the initial and final direction vectors
A = A / norm(A);
B = B / norm(B);
v = cross(A, B);
c = dot(A, B);
s = norm(v);
kmat = [ 0 -v(3) v(2);
v(3) 0 -v(1);
-v(2) v(1) 0];
R = eye(3) + kmat + kmat^2 * (1 - c) / s^2;
end
