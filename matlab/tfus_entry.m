function tfus_entry(config_file, stage)
% Integrated entry point. Scripts below share this function workspace deliberately.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'functions'));
addpath(fullfile(root, 'stages'));
cfg = jsondecode(fileread(config_file));
cfg.target_point_vox = reshape(cfg.target_point_vox, 1, 3);
assert(isfolder(cfg.output_dir), 'Output directory does not exist.');
old = pwd;
cleanup = onCleanup(@() cd(old));
cd(cfg.output_dir);
volume_name = cfg.volume_name;
prepared_file = fullfile(cfg.output_dir, 'prepared.mat');
switch stage
    case 'prepare'
        assert(~isfile(prepared_file), 'Prepared state already exists; use simulate or a new output directory.');
        assert(isfolder(cfg.dicom_dir), 'DICOM directory not found.');
        assert(exist('medicalVolume','file') ~= 0, 'Medical Imaging Toolbox is required.');
        prepare_patient;
    case 'simulate'
        assert(isfile(prepared_file), 'Run prepare first.');
        assert(isfolder(cfg.kwave_dir), 'Configure kwave_dir with the k-Wave toolbox directory.');
        addpath(genpath(cfg.kwave_dir));
        assert(exist('kspaceFirstOrder3DG','file') ~= 0, 'k-Wave GPU solver wrapper not found.');
        assert(isempty(dir(fullfile(cfg.output_dir, 'data', '*', 'CT', '*_CT.mat'))), ...
            'Dataset output already exists; use a new output directory or archive the incomplete data directory before retrying.');
        load(prepared_file, 'resized_CT', 'resized_skull', 'voxel_size', 'target', 'FOV');
        validate_baseline_grid(resized_CT, resized_skull, FOV, voxel_size);
        [FOV_field_skull, FOV_field_ct] = PutIntoFOV(resized_CT, resized_skull, FOV, voxel_size);
        build_poses;
        nPoses = numel(az_list);
        assert(nPoses == 40, 'Baseline requires 40 poses.');
        rng(0);
        perm = randperm(nPoses);
        testIdx = sort(perm(1:10));
        trainIdx = sort(perm(11:40));
        for split = {'train','test'}
            mkdir(fullfile(cfg.output_dir, 'data', split{1}, 'CT'));
            mkdir(fullfile(cfg.output_dir, 'data', split{1}, 'P'));
        end
        save(fullfile(cfg.output_dir, 'poses.mat'), 'az_list', 'el_list', 'rotList', ...
            'ctr_out', 'p0', 'trainIdx', 'testIdx', 'voxel_size', '-v7.3');
        simulate_poses;
    otherwise
        error('tfus:Stage', 'Unknown MATLAB stage: %s', stage);
end
fid = fopen(fullfile(cfg.output_dir, [stage '.complete']), 'w');
assert(fid ~= -1, 'Cannot write completion marker.');
fprintf(fid, '%s\n', datestr(now, 30));
fclose(fid);
end
