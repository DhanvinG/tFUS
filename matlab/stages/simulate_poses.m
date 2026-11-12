    for poseIdx = 1:nPoses
    fprintf('Simulating pose %d/%d\n', poseIdx, nPoses);


    % --- keep just ONE bowl -----------------------------------------------
    rotation = rotList(poseIdx,:);
    adjusted_transducer_1       = txMask{poseIdx};
    adjusted_transducer_focal_1 = txFocal{poseIdx};
    center_point_1              = ctr_out(poseIdx,:);
    % -----------------------------------------------------------------------

    % 5

    % Pick Transducer to Simulate and adjust rotation of skull to match
    % Also cut down to defined window (currently diameter*1.5xfocal*2)
    [sim_transducer_precut_1, sim_transducerF_precut_1, sim_skull_precut_1, sim_ct_precut_1, sim_target_1, stats_1b, stats_1c] = PrepareSimField(center_point_1, ceil(adjusted_transducer_focal_1), ceil(adjusted_transducer_1), FOV_field_skull, FOV_field_ct, target, rotation);
    [sim_transducer_1, sim_transducerF_1, sim_skull_1, sim_ct_1, cut_start_1, cut_target_1] = CutSimArea(sim_transducer_precut_1, sim_transducerF_precut_1, sim_skull_precut_1, sim_ct_precut_1, sim_target_1);


    % 7

    % Prepare sim (parameters)

    freq = 25e4; % [Hz]
    mag = 6.19e4; % [Pa] 1.177e5 = 1.1e6 in water for 70mm 1.177e5 = 4.1856e6 in water for 100mm

    % Create the k-Wave medium structure
    inwater = false; % Replace

    temp = 22;

    % Define thresholds for segmentation
    bone_threshold = 260; % Threshold for bone in Hounsfield Units (HU)
    soft_tissue_threshold = -70; % Threshold for soft tissue in Hounsfield Units (HU)



    %% Tissue Properites from itis.swiss/virtual-population/tissue-properties
    % Attenuation
    aSkullCortical = 4.7384; % dB/(MHz^y cm) 13.63825 Np/m @ 250kHz
    aSkullCancellous = 4.0824; % dB/(MHz^y cm) 8.904834828248589 Np/m @ 250kHz
    aBrain = 0.5909; % dB/(MHz^y cm) 1.1221095273212693 Np/m @ 250kHz
    aWater = 0.0022; % dB/(MHz^y cm) 0.00633210900575 Np/m @ 250kHz

    % Prepare medium for sim
    % Create masks for different regions
    skull_mask_1 = sim_ct_1 > bone_threshold;
    soft_tissue_mask_1 = (sim_ct_1 > soft_tissue_threshold) & (sim_ct_1 <= bone_threshold);
    water_mask_1 = sim_ct_1 <= soft_tissue_threshold;

    % Create the alpha coefficient matrix
    alpha_coeff_1 = zeros(size(sim_ct_1));
    alpha_coeff_1(skull_mask_1) = aSkullCortical;
    alpha_coeff_1(soft_tissue_mask_1) = aBrain;
    alpha_coeff_1(water_mask_1) = aWater;

    % Use an average or dominant frequency power law exponent for the whole medium
    % For example, you might use an average value based on the expected proportions of each tissue type
    y_skull = 1.4; % Skull
    y_soft_tissue = 1.0; % Soft tissue
    y_water = 2.0; % Water

    % Convert CT image to density
    [density_cutoff_1, sound_speed_cutoff_1] = hounsfield2density(double(sim_ct_1)+1000, true);

    % Sound speed (water = waterSoundSpeed(temp))
    for x = 1:size(sound_speed_cutoff_1,1)
     for y = 1:size(sound_speed_cutoff_1,2)
     for z = 1:size(sound_speed_cutoff_1,3)
     if sound_speed_cutoff_1(x,y,z) < waterSoundSpeed(temp)
     sound_speed_cutoff_1(x,y,z) = waterSoundSpeed(temp);
     end
     end
     end
    end

    % Density (water = waterDensity(temp))
    for x = 1:size(density_cutoff_1,1)
     for y = 1:size(density_cutoff_1,2)
     for z = 1:size(density_cutoff_1,3)
     if density_cutoff_1(x,y,z) < waterDensity(temp)
     density_cutoff_1(x,y,z) = waterDensity(temp);
     end
     end
     end
    end


    % Define the k-Wave grid for sim
    Nx = size(sim_ct_1, 1); % number of grid points in the x direction
    Ny = size(sim_ct_1, 2); % number of grid points in the y direction
    Nz = size(sim_ct_1, 3); % number of grid points in the z direction
    dx = voxel_size * 1e-3; % grid point spacing in the x direction [mm]
    dy = voxel_size * 1e-3; % grid point spacing in the y direction [mm]
    dz = voxel_size * 1e-3; % grid point spacing in the z direction [mm]
    grid_size = [Nx, Ny, Nz]; % vector specifying grid size

    % Create the k-Wave grid
    kgrid = kWaveGrid(Nx, dx, Ny, dy, Nz, dz);

    if inwater
     medium_1.density = waterDensity(temp) * ones(Nx, Ny, Nz); % example density in kg/m^3

     medium_1.sound_speed = waterSoundSpeed(temp) * ones(Nx, Ny, Nz); % assuming a constant speed of sound of 1500 m/s

     medium_1.alpha_coeff = aWater; % Attenuation coefficient [Np/m]

     medium_1.alpha_power = y_water; % Use a scalar value for the power law exponent
    else
     medium_1.density = density_cutoff_1;

     medium_1.sound_speed = sound_speed_cutoff_1;

     medium_1.alpha_coeff = alpha_coeff_1; % Attenuation coefficient [Np/m]

     medium_1.alpha_power = y_skull; % Use a scalar value for the power law exponent
    end

    % Define K-wave source
    % Define the source in terms of the transducer pressure
    % source_1.p_mask = makeBowl([Nx,Ny,Nz],[63,63,5],radius, diameter, [63,63,50]);
    % source_2.p_mask = makeBowl([Nx,Ny,Nz],[63,63,5],radius, diameter, [63,63,50]);


    source_1.p_mask = round(sim_transducer_1);

    % Calculate the time step using an integer number of points per period
    c0 = 1500; % speed of sound (min)
    ppw = c0 / (freq * dx); % points per wavelength
    % cfl number
    cfl = 0.1; % Replace
    ppp = ceil(ppw / cfl); % points per period
    T = 1 / freq; % period [s]
    dt = T / ppp; % time step [s]

    % Define the total propagation time
    total_distance = 300e-3; % Replace
    total_time = total_distance / c0;

    % Set up the k-Wave time array
    Nt = round(total_time / dt);

    kgrid.setTime(Nt, dt);

    % Define a time-varying sinusoidal source
    source_freq = freq; % [Hz]
    source_mag = mag; % [Pa]
    source_1.p = source_mag * sin(2 * pi * source_freq * kgrid.t_array); % Define a sinusoidal pressure signal at 0.25 MHz
    % source_2.p = source_mag * sin(2 * pi * source_freq * kgrid.t_array); % Define a sinusoidal pressure signal at 0.25 MHz


    % Setup Sensor
    sensor.mask = ones(Nx, Ny, Nz); % all grid points as sensor points

    sensor.record = {'p_max_all'};
    % sensor.record_start_index = 4000;

    % Run Simulation
    % input arguments
    input_args = {'PlotLayout', true, 'PlotPML', true, 'PMLInside', false ...
     'DataCast', 'single', 'CartInterp', 'nearest'};

    % run the simulation
    sensor_data_1 = kspaceFirstOrder3DG(kgrid, medium_1, source_1, sensor, input_args{:});
    % 8

    % [Npoints, Ntimesteps] = size(sensor_data_1.p);   % <-- use what you got

    % sanity check: Npoints should equal Nx*Ny*Nz
    % assert(Npoints == Nx*Ny*Nz,      ...
           % 'Sensor mask is not full‑volume or Nx,Ny,Nz are wrong.');

    % Nx_eff = kgrid.Nx - 2*kgrid.PMLSize(1);
    % Ny_eff = kgrid.Ny - 2*kgrid.PMLSize(2);
    % Nz_eff = kgrid.Nz - 2*kgrid.PMLSize(3);

    % assert(Npoints == Nx_eff*Ny_eff*Nz_eff);

    % reshape with the true time dimension, not a magic 877
    % sensor_data_reshape_1 = reshape(sensor_data_1.p,[Nx,Ny,Nz,Ntimesteps]);

    % figure;
    % for t_index = 1:200
     % imagesc(squeeze(sensor_data_reshape_1(:, 62,:, t_index)));
     % colorbar;
     % set(gca, 'CLim', [-1e6, 1e6]);
     % hold on;

     % contour(squeeze(sim_skull_1(:, 62,:)),1,'LineColor', 'r', 'LineWidth', 2);

     % hold off;
     % pause(0.01);
    % end


    % max_press_1w = sensor_data_1.p_max_all; % max pressure field
    % focal_point_1 = [size(max_press_1w,1)/2, size(max_press_1w,2)/2, 2+(100/voxel_size)];



    % max_press_1 = sensor_data_1.p_max_all;
    % focal_point_1 = [size(max_press_1,1)/2, size(max_press_1,2)/2, 2+(100/voxel_size)];



    % PlotMaxPress(max_press_1w, sim_skull_1, sim_transducer_1, focal_point_1, false)


    % PlotMaxPress(max_press_1, sim_skull_1, source_1.p_mask, focal_point_1, true)


    % PlotMaxPress(max_press_2, sim_skull_2, source_2.p_mask, focal_point_2, true)



    % [focal_zone_1w] = PlotAlongFocus(max_press_1w, sim_skull_1, source_1.p_mask, focal_point_1, medium_1, cut_target_1);


    % [focal_zone_1] = PlotAlongFocus(max_press_1, sim_skull_1, source_1.p_mask, focal_point_1, medium_1, cut_target_1);


    % [focal_zone_2] = PlotAlongFocus(max_press_2, sim_skull_2, source_2.p_mask, focal_point_2, medium_2, cut_target_2);

    % [focal_zone_1w] = PlotAlongFocus(max_press_1w, sim_skull_1, source_1.p_mask, focal_point_1, medium_1, cut_target_1, voxel_size, inwater);
    % [focal_zone_1]  = PlotAlongFocus(max_press_1,  sim_skull_1, source_1.p_mask, focal_point_1, medium_1, cut_target_1, voxel_size, inwater);
    % [focal_zone_2]  = PlotAlongFocus(max_press_2,  sim_skull_2, source_2.p_mask, focal_point_2, medium_2, cut_target_2, voxel_size, inwater);

        if ~ismember(poseIdx, [trainIdx, testIdx])
            continue;
        end

        % pick base folder for train vs test
        if ismember(poseIdx, testIdx)
            base = fullfile(cfg.output_dir, 'data', 'test');
        else
            base = fullfile(cfg.output_dir, 'data', 'train');
        end

    % B.  -----------  save the CT‑side input ---------------------------------
    ct_file = fullfile(base,'CT', sprintf('%s_pose%02d_CT.mat', volume_name, poseIdx));

    targetSize = [100 100 160];
    origSize   = size(sim_ct_1);
    spacing_mm = (origSize .* voxel_size) ./ targetSize;

    % Resample inputs (linear for CT, nearest for masks)
    sim_ct_resized         = imresize3(sim_ct_1,           targetSize, 'linear');
    sim_skull_resized      = imresize3(sim_skull_1>0,      targetSize, 'nearest');
    sim_transducer_resized = imresize3(sim_transducer_1>0, targetSize, 'nearest');
    sim_target_resized     = imresize3(cut_target_1>0,     targetSize, 'nearest');

    % Resample label
    p_map_rs = imresize3(single(sensor_data_1.p_max_all), targetSize, 'linear');

    % ---- save CT pack ----
    ct_file = fullfile(base,'CT', sprintf('%s_pose%02d_CT.mat', volume_name, poseIdx));
    ct_struct = struct();
    ct_struct.ct            = single(sim_ct_resized);
    ct_struct.skull_mask    = uint8(sim_skull_resized);
    ct_struct.lens_mask     = uint8(sim_transducer_resized);
    ct_struct.target_mask   = uint8(sim_target_resized);
    ct_struct.spacing_mm    = spacing_mm;
    ct_struct.origin_vox    = cut_start_1;                 % optional
    ct_struct.origin_mm     = cut_start_1 .* voxel_size;   % optional
    ct_struct.already_resampled = true;                    % optional
    save(ct_file,'-struct','ct_struct','-v7.3');

    % ---- save P label ----
    p_file   = fullfile(base,'P',  sprintf('%s_pose%02d_P.mat', volume_name, poseIdx));
    p_struct = struct();
    p_struct.p_map          = p_map_rs;
    p_struct.spacing_mm     = spacing_mm;     % keep with label too
    p_struct.rotation_deg   = rotation;
    p_struct.center_point_1 = center_point_1;
    p_struct.freq           = freq;
    p_struct.source_mag     = mag;
    save(p_file,'-struct','p_struct','-v7.3');


    disp(['💾  Saved CT ► ' ct_file]);
    disp(['💾  Saved P  ► ' p_file]);
    end
