%% run SSA for subjects missing outputs
% Scans ./example_data/pet_subjects and calls ssa_batch only where
% SPM.mat exists but cluster/result outputs are missing.
% Useful after a half-finished SSA run.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

cfg = ssa.default_config();
cfg.output_root = fullfile(pwd, 'outputs', 'ssa');

if exist(cfg.mask_file, 'file')
    mask_file = cfg.mask_file;
else
    warning('Mask file not found: %s. Continuing without an explicit mask.', cfg.mask_file);
    mask_file = '';
end

subjects = {};
fprintf('Scanning %s for missing SSA outputs...\n', cfg.root_dir);

group_dirs = dir(cfg.root_dir);
group_dirs = group_dirs([group_dirs.isdir] & ~startsWith({group_dirs.name}, '.'));

for g = 1:numel(group_dirs)
    group_name = group_dirs(g).name;
    group_dir = fullfile(cfg.root_dir, group_name);
    subject_dirs = ssa.list_subject_dirs(group_dir);

    for i = 1:numel(subject_dirs)
        subject_id = subject_dirs(i).name;
        subject_dir = fullfile(group_dir, subject_id);
        contrast_dir = ssa.resolve_contrast_dir(group_dir, subject_id);

        if isempty(contrast_dir)
            continue;
        end
        if ssa.has_ssa_outputs(subject_dir, contrast_dir, fullfile(cfg.output_root, subject_id))
            continue;
        end

        spm_mat = fullfile(contrast_dir, 'SPM.mat');
        if ~exist(spm_mat, 'file')
            fprintf('  [SKIP] %s/%s: no SPM.mat\n', group_name, subject_id);
            continue;
        end

        pet_img = ssa.find_pet_image(subject_dir, cfg.pet_patterns);
        if isempty(pet_img)
            fprintf('  [SKIP] %s/%s: no PET image\n', group_name, subject_id);
            continue;
        end

        subj = struct();
        subj.id = subject_id;
        subj.spm_mat = spm_mat;
        subj.pet_img = pet_img;
        subj.mask_img = mask_file;
        subj.threshold = cfg.p_threshold;
        subj.extent = cfg.extent_threshold;
        subj.contrast_index = cfg.contrast_index;
        subjects{end + 1} = subj; %#ok<SAGROW>
    end
end

if isempty(subjects)
    fprintf('No missing SSA outputs found.\n');
else
    fprintf('Found %d subjects with missing SSA outputs.\n', numel(subjects));
    ssa_batch(subjects, cfg.output_root);
end
