    az_deg = 0 : 45 : 315;      % 8 azimuths: 0,45,90,…,315°
    el_deg = -40 : 20 : 40;       % 5 elevations: -40,-20,0,20,40°
    [AZ,EL] = meshgrid(az_deg,el_deg);
    az_list = AZ(:);              % 30×1
    el_list = EL(:);              % 30×1
    R_mm    = 100;                % 100 mm stand-off
    % voxel_size validated against the baseline before reaching this stage.
    R_vox   = R_mm/voxel_size;    % convert to voxels


    % Define transducer properties
    physical_radius = 100; % mm
    physical_diameter = 100; % mm

    % Convert transducer properties to grid points
    radius = round(physical_radius / voxel_size); % grid points
    diameter = round(physical_diameter / voxel_size); % grid points

    % Adjust diameter to be odd if it's even
    if mod(diameter, 2) == 0
     diameter = diameter - 1;
     display(append("Diameter was changed from: ", int2str(physical_diameter)," mm to: ",sprintf('%.2f',(diameter*voxel_size)), " mm"));
    end

    % Get the transducer volume (tranducer_focal is the tranducer with a stick,
    % pointing to the focal stop)
    [transducer_1, transducer_focal_1, center_point_1] = BuildTransducer(radius, diameter);
    % [transducer_2, transducer_focal_2, center_point_2] = BuildTransducer(radius, diameter);
    p0 = cfg.target_point_vox;
    for idx = 1:numel(az_list)
      % 1) compute p1
      az = az_list(idx);  el = el_list(idx);
      p1 = round(p0 + R_vox * [cosd(el)*cosd(az),cosd(el)*sind(az),sind(el)]);

      % 2) minimal‐rotation from +Z→(p0–p1)
      v = (p0-p1)/norm(p0-p1);
      k = [0 0 1];
      if norm(cross(k,v))<eps
        Rmat = eye(3);
      else
        axis  = cross(k,v); axis=axis/norm(axis);
        angle = acos(dot(k,v));
        K     = [0   -axis(3)  axis(2);
                 axis(3)  0   -axis(1);
                -axis(2) axis(1)   0];
        Rmat  = eye(3) + sin(angle)*K + (1-cos(angle))*K*K;
      end
      eulXYZ_deg = rad2deg(rotm2eul(Rmat,'XYZ'));

      % 3) translate bowl centre to p1
      trans_vox = round(p1 - size(FOV_field_skull)/2);

      % 4) build & map the transducer
      [baseMask, baseFoc, ctr_local] = BuildTransducer(radius, diameter);
      [txMask{idx}, txFocal{idx}, ctr_out(idx,:)] = ...
        ApplyRotationAndTranslation(baseMask, baseFoc, ...
          eulXYZ_deg, trans_vox, FOV, voxel_size, ctr_local);
          rotList(idx,:) = eulXYZ_deg;   % <- add this line *inside* the loop

      disp(['✅ Bowl ' num2str(idx) ' mapped']);

    end
