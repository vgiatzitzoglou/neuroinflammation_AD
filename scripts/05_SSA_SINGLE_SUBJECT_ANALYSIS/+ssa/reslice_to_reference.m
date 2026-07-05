function out_file = reslice_to_reference(source_img, ref_img)
% reslice source_img if geometry differs from ref_img

out_file = source_img;
src = spm_vol(source_img);
ref = spm_vol(ref_img);

if isequal(src.dim, ref.dim) && isequal(src.mat, ref.mat)
    return;
end

fprintf('  Reslicing to reference geometry...\n');
flags = struct();
flags.mask = 0;
flags.mean = 0;
flags.interp = 1;
flags.which = 1;
spm_reslice({ref_img, source_img}, flags);

[p, n, e] = fileparts(source_img);
candidate = fullfile(p, ['r' n e]);
if ~exist(candidate, 'file')
    error('SPM reslice completed but output was not found: %s', candidate);
end
out_file = candidate;
end
