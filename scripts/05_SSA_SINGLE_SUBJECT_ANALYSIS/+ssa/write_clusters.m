function has_clusters = write_clusters(spm_mat_or_dir, out_file, p_threshold, extent_threshold, contrast_index, mask_file)
% write connected-component labels for thresholded SPM results

if nargin < 5 || isempty(contrast_index)
    contrast_index = 1;
end
if nargin < 6
    mask_file = '';
end

if isfolder(spm_mat_or_dir)
    spm_dir = spm_mat_or_dir;
else
    spm_dir = fileparts(spm_mat_or_dir);
end
if ~exist(fullfile(spm_dir, 'SPM.mat'), 'file')
    error('SPM.mat not found in %s', spm_dir);
end

xSPM = struct();
xSPM.swd = spm_dir;
xSPM.title = 'SSA';
xSPM.Ic = contrast_index;
xSPM.n = 1;
xSPM.u = p_threshold;
xSPM.k = extent_threshold;
xSPM.thresDesc = 'none';
xSPM.units = {'mm'};
xSPM.Im = [];
xSPM.pm = [];
xSPM.Ex = [];
if ~isempty(mask_file) && exist(mask_file, 'file')
    xSPM.pm = mask_file;
    xSPM.Ex = 1;
end

[SPM, xSPM] = spm_getSPM(xSPM);
has_clusters = ~isempty(xSPM.XYZ);
if ~has_clusters
    fprintf('  No significant clusters at p<%.4f, k=%d.\n', p_threshold, extent_threshold);
    return;
end

cluster_labels = spm_clusters(xSPM.XYZ);
vol = SPM.xVol.VRpv;
vol.fname = out_file;
vol.dt = [16 0];
vol.descrip = sprintf('SSA clusters p<%.4f k=%d contrast=%d', ...
    p_threshold, extent_threshold, contrast_index);

img = zeros(vol.dim);
for i = 1:size(xSPM.XYZ, 2)
    xyz = xSPM.XYZ(:, i);
    img(xyz(1), xyz(2), xyz(3)) = cluster_labels(i);
end
spm_write_vol(vol, img);
end
