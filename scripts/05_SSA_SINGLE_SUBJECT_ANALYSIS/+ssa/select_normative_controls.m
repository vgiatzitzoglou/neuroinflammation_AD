function [controls, control_scans, ref_img_path, reference_ids] = select_normative_controls(cfg)
%SELECT_NORMATIVE_CONTROLS Select the lowest-mean controls for SSA reference.

control_dir = fullfile(cfg.root_dir, cfg.control_group);
control_dirs = ssa.list_subject_dirs(control_dir);
control_dirs = control_dirs(startsWith({control_dirs.name}, 'C', 'IgnoreCase', true));

if isempty(control_dirs)
    error('No control subjects found in %s', control_dir);
end

mask_vol = spm_vol(cfg.mask_file);
mask_data = spm_read_vols(mask_vol);
mask_idx = mask_data > 0.5;

controls = struct('id', {}, 'path', {}, 'mean', {});
fprintf('Calculating control means from %d candidate controls...\n', numel(control_dirs));

for i = 1:numel(control_dirs)
    subject_id = control_dirs(i).name;
    subject_dir = fullfile(control_dir, subject_id);
    pet_file = ssa.find_pet_image(subject_dir, cfg.pet_patterns);
    if isempty(pet_file)
        fprintf('  [SKIP] %s: no PET image found\n', subject_id);
        continue;
    end

    try
        pet_vol = spm_vol(pet_file);
        pet_data = spm_read_vols(pet_vol);
        values = pet_data(mask_idx);
        values = values(values > 0 & ~isnan(values));
        if isempty(values)
            fprintf('  [SKIP] %s: no non-zero voxels inside mask\n', subject_id);
            continue;
        end
        controls(end + 1).id = subject_id; %#ok<AGROW>
        controls(end).path = pet_file;
        controls(end).mean = mean(values);
    catch ME
        fprintf('  [SKIP] %s: %s\n', subject_id, ME.message);
    end
end

if isempty(controls)
    error('No valid control PET images found in %s', control_dir);
end

[~, idx] = sort([controls.mean]);
controls = controls(idx(1:min(cfg.normative_count, numel(idx))));

control_scans = cell(numel(controls), 1);
fprintf('Selected reference controls:\n');
for i = 1:numel(controls)
    control_scans{i} = [controls(i).path ',1'];
    fprintf('  %2d. %s (mean %.3f)\n', i, controls(i).id, controls(i).mean);
end

ref_img_path = controls(1).path;
reference_ids = {controls.id};
end
