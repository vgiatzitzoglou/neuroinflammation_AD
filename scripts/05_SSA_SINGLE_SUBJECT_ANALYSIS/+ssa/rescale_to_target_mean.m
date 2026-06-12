function out_file = rescale_to_target_mean(source_img, target_mean, mask_file)
% rescale low-intensity PET images using a brain mask

out_file = source_img;
pet_vol = spm_vol(source_img);
pet_data = spm_read_vols(pet_vol);
mask_vol = spm_vol(mask_file);
mask_data = spm_read_vols(mask_vol);

values = pet_data(mask_data > 0.5);
values = values(values > 0 & ~isnan(values));
if isempty(values)
    error('No non-zero PET voxels inside mask for %s', source_img);
end

current_mean = mean(values);
if current_mean >= 1.0
    return;
end

factor = target_mean / current_mean;
fprintf('  Rescaling PET intensity: %.3f -> %.3f (x%.3f)\n', current_mean, target_mean, factor);

[p, n, e] = fileparts(source_img);
out_file = fullfile(p, ['sc' n e]);
out_vol = pet_vol;
out_vol.fname = out_file;
out_vol.dt = [16 0];
out_vol.descrip = sprintf('Rescaled x%.3f', factor);
spm_write_vol(out_vol, pet_data * factor);
end
