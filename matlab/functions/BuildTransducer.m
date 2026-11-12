function [transducer_origin_cut, transducerF_origin_cut, center_point] = BuildTransducer(radius, diameter)


% Focus is equal to the radius of curvature
focus = radius;


% Define bounding box (big enough to allow rotation)
Nx = (radius-1)*2;
Ny = (radius-1)*2;
Nz = (radius-1)*2;


% Define Transducer center point and focal point (face up)
center_point = [Nx/2,Ny/2,Nz/2];
focal_point = [Nx/2,Nx/2,focus];


% Build Transducer using makebowl function
transducer = makeBowl([Nx, Ny, Nz], [center_point(1),center_point(2),center_point(3)] , radius, diameter, [focal_point(1),focal_point(2),focal_point(3)], 'RemoveOverlap', true);
% Make transducer with focus stick
transducer_focal = transducer;
% add 3x3xfocuslength stick
transducer_focal(Nx/2-1:Nx/2+1,Ny/2-1:Ny/2+1,Nz/2:Nz/2+focus-1) = 1;


% Confirm transducer is in origin of bounding box
% Find origin
transducerOrigin = [-size(transducer, 1) / 2, -size(transducer, 2) / 2, -size(transducer, 3) / 2];
% Apply translation to move transducer to the origin
transducerF_at_origin = imtranslate(transducer_focal, transducerOrigin, "OutputView","full");
transducer_at_origin = imtranslate(transducer, transducerOrigin, "OutputView","full");
% Cut any region outside of transducer bounding box
transducerF_origin_cut = transducerF_at_origin(1:(size(transducer_focal, 1)) , 1:(size(transducer_focal, 2)), 1:(size(transducer_focal, 3)));
transducer_origin_cut = transducer_at_origin(1:(size(transducer, 1)) , 1:(size(transducer, 2)), 1:(size(transducer, 3)));
end
