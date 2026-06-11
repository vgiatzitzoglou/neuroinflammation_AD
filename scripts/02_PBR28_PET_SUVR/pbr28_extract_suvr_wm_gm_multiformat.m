% PBR28 SUVR EXTRACTION PIPELINE - COMPLETE VERSION
% Extracts individual ROIs + grouped tracts/lobes
% 4-sheet Excel output with processing log

%% ========================================================================
%  CONFIGURATION
%  ========================================================================

% Input paths
pbr28_root = fullfile(pwd, 'example_data', 'pbr28', 'ALL');
jhu_atlas = fullfile(pwd, 'atlases', 'JHU-ICBM-labels-1mm.nii');
hammers_atlas = fullfile(pwd, 'atlases', 'hammers_atlas.img');

% Output
output_file = fullfile(pwd, 'outputs', 'PBR28_SUVR_WM_GM_Analysis.xlsx');
log_file = fullfile(pwd, 'outputs', 'PBR28_Processing_Log.txt');

% Image patterns (try multiple formats)
image_patterns = {
    'Nor_Cor_*_Realign_PBR28_6090_add_cereb.nii',  % Standard SUVR format
    'Nor_Cor_*_Realign_PBR28_6090_add_cereb.img',  % Analyze format with cereb
    'Nor_Cor_*_Realign_PBR28_6090_add.nii',        % Without _cereb suffix
    'Nor_Cor_*_Realign_PBR28_6090_add.img'         % Analyze format without cereb
};

fprintf('=================================================================\n');
fprintf('PBR28 SUVR EXTRACTION PIPELINE - COMPLETE\n');
fprintf('=================================================================\n');
fprintf('Input:  %s\n', pbr28_root);
fprintf('Output: %s\n', output_file);
fprintf('Log:    %s\n', log_file);
fprintf('=================================================================\n\n');

%% ========================================================================
%  VALIDATE INPUTS
%  ========================================================================

fprintf('Validating inputs...\n');

assert(exist(pbr28_root, 'dir') ~= 0, 'PBR28 root not found: %s', pbr28_root);
assert(exist(jhu_atlas, 'file') ~= 0, 'JHU atlas not found: %s', jhu_atlas);
assert(exist(hammers_atlas, 'file') ~= 0, 'Hammers atlas not found: %s', hammers_atlas);

out_dir = fileparts(output_file);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

fprintf('  ✓ All paths validated\n\n');

%% ========================================================================
%  DEFINE TRACT GROUPINGS
%  ========================================================================

fprintf('Defining tract groupings...\n');

% JHU-ICBM-labels-1mm.nii structure:
% ROI 1 = Unclassified (background/CSF)
% ROI 2-49 = 48 labeled white matter tracts

% Define bilateral tract pairs (your specified list)
% Format: {Name, ROI_L, ROI_R}
bilateral_tracts = {
    'ATR',                           24, 25;  % Anterior thalamic radiation
    'CST',                           8,  9;   % Corticospinal tract
    'Cingulum_cingulate',            36, 37;  % Cingulum (cingulate gyrus)
    'Cingulum_hippocampus',          38, 39;  % Cingulum (hippocampus)
    'SLF',                           42, 43;  % Superior longitudinal fasciculus
    'IFOF',                          44, 45;  % Inferior fronto-occipital fasciculus
    'ILF',                           32, 33;  % Inferior longitudinal fasciculus (via Sagittal stratum)
    'Uncinate',                      46, 47;  % Uncinate fasciculus
    'PTR',                           30, 31   % Posterior thalamic radiation (optic radiation)
};

% Midline tracts (single ROI, no L/R)
midline_tracts = {
    'Forceps_major',    6;   % Splenium of corpus callosum
    'Forceps_minor',    4    % Genu of corpus callosum
};

fprintf('  ✓ Defined 9 bilateral tracts\n');
fprintf('  ✓ Defined 2 midline tracts\n');

% Hammers GM lobe groupings (same as before)
hammers_lobes = struct();
hammers_lobes.Frontal = [23, 24, 25, 26, 27, 28, 29, 41, 42, 43, 44, 69, 70, 71, 72];
hammers_lobes.Temporal = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 30, 31, 53, 54, 55, 56];
hammers_lobes.Parietal = [32, 33, 34, 35, 73, 74, 75, 76];
hammers_lobes.Occipital = [15, 16, 36, 37];
hammers_lobes.Cingulate = [38, 39, 40];
hammers_lobes.Subcortical = [1, 2, 20, 21, 22, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68];

fprintf('  ✓ Defined 6 GM lobes\n\n');

%% ========================================================================
%  FIND ALL SUBJECTS
%  ========================================================================

fprintf('Searching for subjects...\n');

subj_dirs = dir(pbr28_root);
subj_dirs = subj_dirs([subj_dirs.isdir]);
subj_dirs = subj_dirs(~ismember({subj_dirs.name}, {'.', '..'}));

subjects = {};
groups = {};
file_paths = {};
skipped_subjects = {};
skip_reasons = {};

for i = 1:length(subj_dirs)
    subj_name = subj_dirs(i).name;
    subj_path = fullfile(pbr28_root, subj_name);
    
    % Skip non-subject folders
    if strcmp(subj_name, 'processed_results') || strcmp(subj_name, 'backup')
        continue;
    end
    
    % Try multiple image patterns
    img_files = [];
    pattern_used = '';
    
    for p = 1:length(image_patterns)
        img_files = dir(fullfile(subj_path, image_patterns{p}));
        if ~isempty(img_files)
            pattern_used = image_patterns{p};
            break;
        end
    end
    
    if isempty(img_files)
        skipped_subjects{end+1} = subj_name; %#ok<AGROW>
        skip_reasons{end+1} = 'No image found'; %#ok<AGROW>
        continue;
    end
    
    if length(img_files) > 1
        fprintf('  ⚠ Multiple images for %s, using: %s\n', subj_name, img_files(1).name);
    end
    
    img_path = fullfile(subj_path, img_files(1).name);
    
    % Extract group
    if startsWith(upper(subj_name), 'AD')
        group = 'AD';
    elseif startsWith(upper(subj_name), 'MCI')
        group = 'MCI';
    elseif startsWith(upper(subj_name), 'C')
        group = 'HC';
    else
        group = 'UNKNOWN';
    end
    
    subjects{end+1} = subj_name; %#ok<AGROW>
    groups{end+1} = group; %#ok<AGROW>
    file_paths{end+1} = img_path; %#ok<AGROW>
end

n_subjects = length(subjects);
n_skipped = length(skipped_subjects);

fprintf('  Found %d subjects to process\n', n_subjects);
fprintf('    AD:  %d\n', sum(strcmp(groups, 'AD')));
fprintf('    MCI: %d\n', sum(strcmp(groups, 'MCI')));
fprintf('    HC:  %d\n', sum(strcmp(groups, 'HC')));

if n_skipped > 0
    fprintf('  ⚠ Skipped %d subjects (see log file)\n', n_skipped);
end
fprintf('\n');

if n_subjects == 0
    error('No subjects found!');
end

%% ========================================================================
%  LOAD ATLASES
%  ========================================================================

fprintf('Loading atlases...\n');

V_jhu = spm_vol(jhu_atlas);
jhu_img = spm_read_vols(V_jhu);
fprintf('  ✓ JHU atlas: %dx%dx%d\n', size(jhu_img, 1), size(jhu_img, 2), size(jhu_img, 3));

V_hammers = spm_vol(hammers_atlas);
hammers_img = spm_read_vols(V_hammers);
fprintf('  ✓ Hammers atlas: %dx%dx%d\n\n', size(hammers_img, 1), size(hammers_img, 2), size(hammers_img, 3));

%% ========================================================================
%  EXTRACT VALUES
%  ========================================================================

fprintf('=================================================================\n');
fprintf('EXTRACTING ROI VALUES\n');
fprintf('=================================================================\n\n');

% Initialize storage
wm_individual = nan(n_subjects, 49);  % All 49 JHU ROIs (including ROI 1 = unclassified)
gm_individual = nan(n_subjects, 84);  % All 84 Hammers ROIs

failed_subjects = {};
fail_reasons = {};

for subj_idx = 1:n_subjects
    fprintf('[%d/%d] %s (%s)\n', subj_idx, n_subjects, subjects{subj_idx}, groups{subj_idx});
    
    try
        % Load PBR28 image
        V_pet = spm_vol(file_paths{subj_idx});
        pet_img = spm_read_vols(V_pet);
        pet_dims = size(pet_img);
        
        % Resample atlases if needed
        if ~isequal(size(jhu_img), pet_dims)
            jhu_resampled = imresize3(jhu_img, pet_dims, 'nearest');
        else
            jhu_resampled = jhu_img;
        end
        
        if ~isequal(size(hammers_img), pet_dims)
            hammers_resampled = imresize3(hammers_img, pet_dims, 'nearest');
        else
            hammers_resampled = hammers_img;
        end
        
        % Extract WM individual ROIs (1-49)
        for roi = 1:49
            mask = jhu_resampled == roi;
            vals = pet_img(mask & pet_img > 0 & isfinite(pet_img));
            
            if ~isempty(vals)
                wm_individual(subj_idx, roi) = mean(vals);
            end
        end
        
        % Extract GM individual ROIs (1-84)
        for roi = 1:84
            mask = hammers_resampled == roi;
            vals = pet_img(mask & pet_img > 0 & isfinite(pet_img));
            
            if ~isempty(vals)
                gm_individual(subj_idx, roi) = mean(vals);
            end
        end
        
        wm_valid = sum(~isnan(wm_individual(subj_idx, :)));
        gm_valid = sum(~isnan(gm_individual(subj_idx, :)));
        
        fprintf('  ✓ WM ROIs: %d/49 valid\n', wm_valid);
        fprintf('  ✓ GM ROIs: %d/84 valid\n', gm_valid);
        
        if wm_valid < 40 || gm_valid < 70
            fprintf('  ⚠ WARNING: Low ROI coverage\n');
        end
        
    catch ME
        fprintf('  ✗ ERROR: %s\n', ME.message);
        failed_subjects{end+1} = subjects{subj_idx}; %#ok<AGROW>
        fail_reasons{end+1} = ME.message; %#ok<AGROW>
    end
    
    fprintf('\n');
end

%% ========================================================================
%  CALCULATE BILATERAL TRACTS AND LOBES
%  ========================================================================

fprintf('Calculating bilateral tracts and lobes...\n');

% Bilateral tracts: average L and R
n_bilateral = size(bilateral_tracts, 1);
wm_tracts = nan(n_subjects, n_bilateral + length(midline_tracts));

for i = 1:n_bilateral
    roi_l = bilateral_tracts{i, 2};
    roi_r = bilateral_tracts{i, 3};
    
    % Average left and right
    wm_tracts(:, i) = nanmean([wm_individual(:, roi_l), wm_individual(:, roi_r)], 2);
end

% Midline tracts: single ROI
for i = 1:length(midline_tracts)
    roi = midline_tracts{i, 2};
    wm_tracts(:, n_bilateral + i) = wm_individual(:, roi);
end

fprintf('  ✓ Calculated %d bilateral tracts\n', n_bilateral);
fprintf('  ✓ Calculated %d midline tracts\n', length(midline_tracts));

% GM lobes
lobe_names = fieldnames(hammers_lobes);
gm_lobes = nan(n_subjects, length(lobe_names));

for lobe_idx = 1:length(lobe_names)
    lobe_name = lobe_names{lobe_idx};
    lobe_rois = hammers_lobes.(lobe_name);
    
    % Average all ROIs in this lobe
    gm_lobes(:, lobe_idx) = nanmean(gm_individual(:, lobe_rois), 2);
end

fprintf('  ✓ Calculated %d GM lobes\n\n', length(lobe_names));

%% ========================================================================
%  CREATE OUTPUT TABLES (4 SHEETS)
%  ========================================================================

fprintf('Creating output tables...\n');

% =========================================================================
% SHEET 1: WM Individual ROIs (49 columns)
% =========================================================================

wm_ind_table = table();
wm_ind_table.SubjectID = subjects';
wm_ind_table.Group = groups';

for roi = 1:49
    col_name = sprintf('WM_ROI_%02d', roi);
    wm_ind_table.(col_name) = wm_individual(:, roi);
end

fprintf('  ✓ Sheet 1: WM_Individual_ROIs (%d subjects, 49 ROIs)\n', height(wm_ind_table));

% =========================================================================
% SHEET 2: WM Tracts (11 columns: 9 bilateral + 2 midline)
% =========================================================================

wm_tract_table = table();
wm_tract_table.SubjectID = subjects';
wm_tract_table.Group = groups';

% Add bilateral tracts
for i = 1:n_bilateral
    tract_name = bilateral_tracts{i, 1};
    wm_tract_table.(tract_name) = wm_tracts(:, i);
end

% Add midline tracts
for i = 1:length(midline_tracts)
    tract_name = midline_tracts{i, 1};
    wm_tract_table.(tract_name) = wm_tracts(:, n_bilateral + i);
end

fprintf('  ✓ Sheet 2: WM_Tracts (%d subjects, 11 tracts)\n', height(wm_tract_table));

% =========================================================================
% SHEET 3: GM Individual ROIs (84 columns)
% =========================================================================

gm_ind_table = table();
gm_ind_table.SubjectID = subjects';
gm_ind_table.Group = groups';

for roi = 1:84
    col_name = sprintf('GM_ROI_%02d', roi);
    gm_ind_table.(col_name) = gm_individual(:, roi);
end

fprintf('  ✓ Sheet 3: GM_Individual_ROIs (%d subjects, 84 ROIs)\n', height(gm_ind_table));

% =========================================================================
% SHEET 4: GM Lobes (6 columns)
% =========================================================================

gm_lobe_table = table();
gm_lobe_table.SubjectID = subjects';
gm_lobe_table.Group = groups';

for lobe_idx = 1:length(lobe_names)
    lobe_name = lobe_names{lobe_idx};
    gm_lobe_table.(lobe_name) = gm_lobes(:, lobe_idx);
end

fprintf('  ✓ Sheet 4: GM_Lobes (%d subjects, 6 lobes)\n\n', height(gm_lobe_table));

%% ========================================================================
%  EXPORT TO EXCEL
%  ========================================================================

fprintf('Exporting to Excel...\n');

if exist(output_file, 'file')
    delete(output_file);
end

writetable(wm_ind_table, output_file, 'Sheet', '1_WM_Individual_ROIs');
writetable(wm_tract_table, output_file, 'Sheet', '2_WM_Tracts');
writetable(gm_ind_table, output_file, 'Sheet', '3_GM_Individual_ROIs');
writetable(gm_lobe_table, output_file, 'Sheet', '4_GM_Lobes');

fprintf('  ✓ Saved: %s\n\n', output_file);

%% ========================================================================
%  WRITE PROCESSING LOG
%  ========================================================================

fprintf('Writing processing log...\n');

fid = fopen(log_file, 'w');
fprintf(fid, '=================================================================\n');
fprintf(fid, 'PBR28 SUVR EXTRACTION - PROCESSING LOG\n');
fprintf(fid, '=================================================================\n');
fprintf(fid, 'Date: %s\n', datestr(now));
fprintf(fid, 'Input directory: %s\n', pbr28_root);
fprintf(fid, 'Output file: %s\n', output_file);
fprintf(fid, '=================================================================\n\n');

fprintf(fid, 'SUMMARY\n');
fprintf(fid, '  Successfully processed: %d subjects\n', n_subjects);
fprintf(fid, '    AD:  %d\n', sum(strcmp(groups, 'AD')));
fprintf(fid, '    MCI: %d\n', sum(strcmp(groups, 'MCI')));
fprintf(fid, '    HC:  %d\n', sum(strcmp(groups, 'HC')));
fprintf(fid, '  Skipped: %d subjects\n', n_skipped);
fprintf(fid, '  Failed during processing: %d subjects\n\n', length(failed_subjects));

if n_skipped > 0
    fprintf(fid, 'SKIPPED SUBJECTS (no image found):\n');
    fprintf(fid, '-----------------------------------------------------------\n');
    for i = 1:n_skipped
        fprintf(fid, '  %s: %s\n', skipped_subjects{i}, skip_reasons{i});
    end
    fprintf(fid, '\n');
end

if ~isempty(failed_subjects)
    fprintf(fid, 'FAILED SUBJECTS (processing error):\n');
    fprintf(fid, '-----------------------------------------------------------\n');
    for i = 1:length(failed_subjects)
        fprintf(fid, '  %s: %s\n', failed_subjects{i}, fail_reasons{i});
    end
    fprintf(fid, '\n');
end

fprintf(fid, 'TRACT DEFINITIONS:\n');
fprintf(fid, '-----------------------------------------------------------\n');
fprintf(fid, 'Bilateral tracts (average of L and R):\n');
for i = 1:n_bilateral
    fprintf(fid, '  %s: ROI %d (L) + ROI %d (R)\n', ...
        bilateral_tracts{i, 1}, bilateral_tracts{i, 2}, bilateral_tracts{i, 3});
end
fprintf(fid, '\nMidline tracts:\n');
for i = 1:length(midline_tracts)
    fprintf(fid, '  %s: ROI %d\n', midline_tracts{i, 1}, midline_tracts{i, 2});
end

fclose(fid);

fprintf('  ✓ Log saved: %s\n\n', log_file);

%% ========================================================================
%  SUMMARY STATISTICS
%  ========================================================================

fprintf('=================================================================\n');
fprintf('SUMMARY STATISTICS\n');
fprintf('=================================================================\n\n');

fprintf('WHITE MATTER TRACTS (mean SUVR):\n');
fprintf('-----------------------------------------------------------\n');
for g = {'AD', 'MCI', 'HC'}
    group_name = g{1};
    group_idx = strcmp(groups, group_name);
    n_group = sum(group_idx);
    
    if n_group == 0, continue; end
    
    mean_suvr = nanmean(wm_tracts(group_idx, :), 'all');
    std_suvr = nanstd(wm_tracts(group_idx, :), 0, 'all');
    
    fprintf('  %s (N=%d): %.3f ± %.3f\n', group_name, n_group, mean_suvr, std_suvr);
end

fprintf('\nGRAY MATTER LOBES (mean SUVR):\n');
fprintf('-----------------------------------------------------------\n');
for g = {'AD', 'MCI', 'HC'}
    group_name = g{1};
    group_idx = strcmp(groups, group_name);
    n_group = sum(group_idx);
    
    if n_group == 0, continue; end
    
    mean_suvr = nanmean(gm_lobes(group_idx, :), 'all');
    std_suvr = nanstd(gm_lobes(group_idx, :), 0, 'all');
    
    fprintf('  %s (N=%d): %.3f ± %.3f\n', group_name, n_group, mean_suvr, std_suvr);
end

fprintf('\n=================================================================\n');
fprintf('EXTRACTION COMPLETE\n');
fprintf('=================================================================\n');
fprintf('Excel output: %s\n', output_file);
fprintf('Processing log: %s\n', log_file);
fprintf('=================================================================\n');