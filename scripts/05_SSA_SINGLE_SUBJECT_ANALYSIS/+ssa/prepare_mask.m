function mask_file = prepare_mask(mask_file)
%PREPARE_MASK Copy the analysis mask to a stable filename before SPM writes.

if isempty(mask_file)
    return;
end
if ~exist(mask_file, 'file')
    error('Mask file not found: %s', mask_file);
end

[mask_dir, ~, ~] = fileparts(mask_file);
safe_mask = fullfile(mask_dir, 'Safe_GMmask.nii');
if ~exist(safe_mask, 'file')
    copyfile(mask_file, safe_mask);
end
mask_file = safe_mask;
end
