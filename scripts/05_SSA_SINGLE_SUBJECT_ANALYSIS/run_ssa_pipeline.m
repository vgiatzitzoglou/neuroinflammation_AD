%% SSA main script
% This is the SSA script I would start from now.
% The older versions had the same bits copied around, so the boring repeated
% parts are in +ssa. Still check paths/thresholds before running.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

cfg = ssa.default_config();

% edit these for a local run if needed
% cfg.root_dir = fullfile(pwd, 'example_data', 'pet_subjects');
% cfg.target_groups = {'AD', 'MCI', 'HC'};
% cfg.include_remaining_controls = true;
% cfg.overwrite_models = true;

spm('Defaults', 'PET');
spm_jobman('initcfg');

cfg.mask_file = ssa.prepare_mask(cfg.mask_file);
[~, control_scans, ref_img_path, reference_ids] = ssa.select_normative_controls(cfg);

fprintf('\nrunning SSA target groups...\n');
processed = 0;
skipped = 0;

for g = 1:numel(cfg.target_groups)
    group_name = cfg.target_groups{g};
    group_dir = fullfile(cfg.root_dir, group_name);
    subject_dirs = ssa.list_subject_dirs(group_dir);

    if isempty(subject_dirs)
        fprintf('  skip: %s has no subject folders\n', group_name);
        continue;
    end

    for i = 1:numel(subject_dirs)
        subject_id = subject_dirs(i).name;

        if strcmp(group_name, cfg.control_group) && ...
                (~cfg.include_remaining_controls || ismember(subject_id, reference_ids))
            skipped = skipped + 1;
            continue;
        end

        subject_dir = fullfile(group_dir, subject_id);
        pet_file = ssa.find_pet_image(subject_dir, cfg.pet_patterns);
        if isempty(pet_file)
            fprintf('  skip: %s/%s no PET image found\n', group_name, subject_id);
            skipped = skipped + 1;
            continue;
        end

        out_dir = fullfile(group_dir, [subject_id 'Contrast']);
        fprintf('\n%s/%s\n', group_name, subject_id);

        try
            final_pet = ssa.reslice_to_reference(pet_file, ref_img_path);
            final_pet = ssa.rescale_to_target_mean(final_pet, cfg.target_mean, cfg.mask_file);
            ssa.run_two_sample_model(out_dir, control_scans, [final_pet ',1'], cfg.mask_file, cfg);

            if cfg.generate_clusters
                cluster_file = fullfile(out_dir, 'Clusters.nii');
                ssa.write_clusters(out_dir, cluster_file, ...
                    cfg.p_threshold, cfg.extent_threshold, cfg.contrast_index);
            end
            processed = processed + 1;
        catch ME
            skipped = skipped + 1;
            fprintf('  fail: %s/%s: %s\n', group_name, subject_id, ME.message);
        end
    end
end

fprintf('\nSSA done. processed: %d. skipped/failed: %d.\n', processed, skipped);
