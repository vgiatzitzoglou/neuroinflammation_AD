function cfg = default_config()
%DEFAULT_CONFIG Rough defaults for the SSA scripts.
% Change these locally. I kept the paths generic for GitHub.
% TODO if rerunning: check target_mean, p threshold, and extent threshold.

root_dir = fullfile(pwd, 'example_data', 'pet_subjects');

cfg = struct();
cfg.root_dir = root_dir;
cfg.control_group = 'HC';
cfg.target_groups = {'AD', 'MCI', 'HC'};
cfg.include_remaining_controls = true;
cfg.normative_count = 10;
cfg.mask_file = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');
cfg.output_root = fullfile(pwd, 'outputs', 'ssa');
cfg.results_root = fullfile(pwd, 'outputs', 'results');
cfg.pet_patterns = { ...
    'Nor_Cor_*Realign*.nii', ...
    'Nor_Cor_*Realign*.nii.gz', ...
    'Nor_Cor_*.nii', ...
    'Nor_Cor_*.nii.gz', ...
    'sw*_PET.nii', ...
    'sw*_PET.nii.gz', ...
    '*Realign*.nii', ...
    '*Realign*.nii.gz' ...
};
cfg.target_mean = 39.0;
cfg.p_threshold = 0.05;
cfg.extent_threshold = 50;
cfg.contrast_index = 1;
cfg.overwrite_models = true;
cfg.write_residuals = true;
cfg.generate_clusters = true;
end
