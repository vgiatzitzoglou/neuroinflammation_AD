%% CREATE DISEASE FREQUENCY MAP (HEATMAP)
% This script sums up the binary cluster maps from all subjects in a group
% to create a "Frequency Map" showing the most common locations of disease.
%
% OUTPUT: ./outputs/results\Group_Frequency_Map.nii
% (Voxel Intensity = Number of subjects with a significant cluster at that spot)

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
spm('Defaults', 'PET');

%% ==== CONFIGURATION ====
cfg = ssa.default_config();
target_group = 'MCI';  % Change to 'MCI' for the other group
results_root = cfg.results_root;
output_filename = fullfile(results_root, [target_group '_Frequency_Map.nii']);

%% ==== MAIN PROCESSING ====
fprintf('Generating Frequency Map for Group: %s\n', target_group);

% Find all subjects in the results folder
d = dir(results_root);
d = d([d.isdir] & ~startsWith({d.name}, '.'));

% Filter for the target group (e.g., starts with AD)
is_target = startsWith({d.name}, target_group, 'IgnoreCase', true);
subjects = d(is_target);

if isempty(subjects)
    error('No subjects found starting with "%s" in %s', target_group, results_root);
end

fprintf('Found %d subjects. Stacking maps...\n', length(subjects));

% Initialize variables
sum_vol = [];
ref_header = [];
count = 0;

for i = 1:length(subjects)
    subjID = subjects(i).name;
    clusterFile = fullfile(results_root, subjID, 'Clusters.nii');
    
    if ~exist(clusterFile, 'file')
        fprintf('  [SKIP] %s (No Clusters.nii found)\n', subjID);
        continue;
    end
    
    % Load Cluster Map
    V = spm_vol(clusterFile);
    img = spm_read_vols(V);
    
    % Binarize (Any cluster ID becomes 1)
    binary_img = (img > 0);
    
    % Initialize sum volume on first valid subject
    if isempty(sum_vol)
        sum_vol = zeros(size(binary_img));
        ref_header = V; % Keep header for saving later
    end
    
    % Check dimensions
    if ~isequal(size(binary_img), size(sum_vol))
        fprintf('  [ERROR] Dimension mismatch for %s. Skipping.\n', subjID);
        continue;
    end
    
    % Add to total
    sum_vol = sum_vol + double(binary_img);
    count = count + 1;
    fprintf('  [ADDED] %s\n', subjID);
end

if count == 0
    error('No valid cluster maps were processed.');
end

%% ==== SAVE RESULT ====
fprintf('\nWriting Frequency Map...\n');

% Update Header
V_out = ref_header;
V_out.fname = output_filename;
V_out.dt = [16 0]; % Float32
V_out.descrip = sprintf('Frequency Map (N=%d) - %s', count, target_group);

% Write Volume
spm_write_vol(V_out, sum_vol);

fprintf('------------------------------------------------\n');
fprintf('SUCCESS! Map saved to:\n%s\n', output_filename);
fprintf('Max Overlap: %d subjects (at the "hottest" spot)\n', max(sum_vol(:)));
fprintf('------------------------------------------------\n');
