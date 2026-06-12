%% disease frequency map
% sums binary cluster maps across a group

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
spm('Defaults', 'PET');

%% config
cfg = ssa.default_config();
target_group = 'MCI';  % change to AD for the other group
results_root = cfg.results_root;
output_filename = fullfile(results_root, [target_group '_Frequency_Map.nii']);

%% main bit
fprintf('generating frequency map for group: %s\n', target_group);

% find all subjects in the results folder
d = dir(results_root);
d = d([d.isdir] & ~startsWith({d.name}, '.'));

% filter for the target group
is_target = startsWith({d.name}, target_group, 'IgnoreCase', true);
subjects = d(is_target);

if isempty(subjects)
    error('No subjects found starting with "%s" in %s', target_group, results_root);
end

fprintf('found %d subjects. stacking maps...\n', length(subjects));

% initialize variables
sum_vol = [];
ref_header = [];
count = 0;

for i = 1:length(subjects)
    subjID = subjects(i).name;
    clusterFile = fullfile(results_root, subjID, 'Clusters.nii');
    
    if ~exist(clusterFile, 'file')
        fprintf('  skip: %s no Clusters.nii\n', subjID);
        continue;
    end
    
    % load cluster map
    V = spm_vol(clusterFile);
    img = spm_read_vols(V);
    
    % binarize, any cluster ID becomes 1
    binary_img = (img > 0);
    
    % initialize sum volume on first valid subject
    if isempty(sum_vol)
        sum_vol = zeros(size(binary_img));
        ref_header = V; % keep header for saving later
    end
    
    % check dimensions
    if ~isequal(size(binary_img), size(sum_vol))
        fprintf('  error: dimension mismatch for %s, skipping\n', subjID);
        continue;
    end
    
    % add to total
    sum_vol = sum_vol + double(binary_img);
    count = count + 1;
    fprintf('  added %s\n', subjID);
end

if count == 0
    error('No valid cluster maps were processed.');
end

%% save result
fprintf('\nwriting frequency map...\n');

% update header
V_out = ref_header;
V_out.fname = output_filename;
V_out.dt = [16 0]; % float32
V_out.descrip = sprintf('frequency map (N=%d) - %s', count, target_group);

% write volume
spm_write_vol(V_out, sum_vol);

fprintf('------------------------------------------------\n');
fprintf('done, map saved to:\n%s\n', output_filename);
fprintf('max overlap: %d subjects\n', max(sum_vol(:)));
fprintf('------------------------------------------------\n');
