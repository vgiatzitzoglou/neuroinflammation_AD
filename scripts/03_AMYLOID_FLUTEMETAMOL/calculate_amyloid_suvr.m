function calculate_amyloid_suvr()
% CALCULATE_AMYLOID_SUVR - Calculate SUVR for amyloid PET imaging
% This script processes PET and T1 images, coregisters them, normalizes to MNI space,
% and calculates SUVR using cerebellum as reference region and extracts values
% from JHU (48 regions) and Hammersmith (84 regions) atlases.
%
% Requirements: SPM12 in MATLAB path
% Author: Generated for amyloid SUVR analysis
% Date: January 2026

%% Setup paths and parameters
% Base directory containing subject folders
base_dir = fullfile(pwd, 'example_data', 'amyloid');

% Atlas paths
hammersmith_atlas = fullfile(pwd, 'atlases', 'hammers_atlas.img');
jhu_atlas = fullfile(pwd, 'atlases', 'JHU-ICBM-labels-1mm.nii');

% Cerebellum ROIs in Hammersmith atlas (ROIs 17 and 18)
cerebellum_rois = [17, 18];

% Output directory
output_dir = fullfile(base_dir, 'SUVR_Results');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Initialize SPM defaults
spm('defaults', 'PET');
spm_jobman('initcfg');

%% Get list of subjects
subject_dirs = dir(fullfile(base_dir, '*'));
subject_dirs = subject_dirs([subject_dirs.isdir]);
subject_dirs = subject_dirs(~ismember({subject_dirs.name}, {'.', '..'}));

fprintf('Found %d subject directories\n', length(subject_dirs));

%% Load atlases
fprintf('Loading atlases...\n');
V_hammersmith = spm_vol(hammersmith_atlas);
atlas_hammersmith = spm_read_vols(V_hammersmith);

V_jhu = spm_vol(jhu_atlas);
atlas_jhu = spm_read_vols(V_jhu);

% Get unique ROI values
hammersmith_labels = unique(atlas_hammersmith(:));
hammersmith_labels(hammersmith_labels == 0) = []; % Remove background
jhu_labels = unique(atlas_jhu(:));
jhu_labels(jhu_labels == 0) = []; % Remove background

fprintf('Hammersmith atlas: %d regions\n', length(hammersmith_labels));
fprintf('JHU atlas: %d regions\n', length(jhu_labels));

%% Initialize results structure
results = struct();
subject_count = 0;

%% Process each subject
for i = 1:length(subject_dirs)
    subject_id = subject_dirs(i).name;
    subject_path = fullfile(base_dir, subject_id);
    
    fprintf('\n=== Processing subject %d/%d: %s ===\n', i, length(subject_dirs), subject_id);
    
    % Find T1 and PET files
    t1_file = find_file(subject_path, '*_T1.nii');
    pet_file = find_file(subject_path, 'PET_Amyloid_*.nii');
    
    if isempty(t1_file) || isempty(pet_file)
        fprintf('WARNING: Missing files for %s (T1: %d, PET: %d)\n', ...
            subject_id, ~isempty(t1_file), ~isempty(pet_file));
        continue;
    end
    
    subject_count = subject_count + 1;
    
    try
        %% Step 1: Coregister PET to T1
        fprintf('Step 1: Coregistering PET to T1...\n');
        [coregistered_pet, ~] = coregister_pet_to_t1(pet_file, t1_file);
        
        %% Step 2: Normalize T1 to MNI space
        fprintf('Step 2: Normalizing T1 to MNI space...\n');
        [normalized_t1, deformation_field] = normalize_to_mni(t1_file);
        
        %% Step 3: Apply normalization to coregistered PET
        fprintf('Step 3: Normalizing PET to MNI space...\n');
        normalized_pet = apply_normalization(coregistered_pet, deformation_field);
        
        %% Step 4: Reslice atlases to PET space (if needed)
        fprintf('Step 4: Reslicing atlases to match PET...\n');
        [atlas_hammersmith_resliced, atlas_jhu_resliced] = reslice_atlases_to_pet(...
            normalized_pet, hammersmith_atlas, jhu_atlas);
        
        %% Step 5: Extract cerebellum reference value
        fprintf('Step 5: Extracting cerebellum reference value...\n');
        cereb_value = extract_cerebellum_value(normalized_pet, ...
            atlas_hammersmith_resliced, cerebellum_rois);
        
        if isnan(cereb_value) || cereb_value <= 0
            fprintf('WARNING: Invalid cerebellum value for %s\n', subject_id);
            continue;
        end
        
        fprintf('Cerebellum mean value: %.4f\n', cereb_value);
        
        %% Step 6: Extract ROI values and calculate SUVR
        fprintf('Step 6: Calculating SUVR for all ROIs...\n');
        
        % Hammersmith ROIs
        suvr_hammersmith = extract_roi_suvr(normalized_pet, ...
            atlas_hammersmith_resliced, hammersmith_labels, cereb_value);
        
        % JHU ROIs
        suvr_jhu = extract_roi_suvr(normalized_pet, ...
            atlas_jhu_resliced, jhu_labels, cereb_value);
        
        %% Store results
        results(subject_count).subject_id = subject_id;
        results(subject_count).cerebellum_value = cereb_value;
        results(subject_count).suvr_hammersmith = suvr_hammersmith;
        results(subject_count).suvr_jhu = suvr_jhu;
        results(subject_count).hammersmith_labels = hammersmith_labels;
        results(subject_count).jhu_labels = jhu_labels;
        
        fprintf('Successfully processed %s\n', subject_id);
        
    catch ME
        fprintf('ERROR processing %s: %s\n', subject_id, ME.message);
        fprintf('Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        continue;
    end
end

%% Save results to Excel
fprintf('\n=== Saving results to Excel ===\n');
if subject_count > 0
    save_results_to_excel(results, output_dir);
    fprintf('Results saved to: %s\n', output_dir);
else
    fprintf('No subjects were successfully processed.\n');
end

fprintf('\n=== Processing complete! ===\n');
fprintf('Total subjects processed: %d/%d\n', subject_count, length(subject_dirs));

end

%% Helper Functions

function filepath = find_file(directory, pattern)
% Find a file matching the pattern in the directory
files = dir(fullfile(directory, pattern));
if isempty(files)
    filepath = '';
else
    filepath = fullfile(directory, files(1).name);
end
end

function [coregistered_pet, resliced_pet] = coregister_pet_to_t1(pet_file, t1_file)
% Coregister PET to T1 using SPM12
fprintf('  Coregistering: %s\n', pet_file);
fprintf('  Reference: %s\n', t1_file);

% Create SPM batch for coregistration
matlabbatch = {};
matlabbatch{1}.spm.spatial.coreg.estimate.ref = {[t1_file ',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.source = {[pet_file ',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.other = {''};
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

% Run batch
spm_jobman('run', matlabbatch);

coregistered_pet = pet_file;
resliced_pet = pet_file; % Coregistration updates header, no new file created
end

function [normalized_t1, deformation_field] = normalize_to_mni(t1_file)
% Normalize T1 to MNI space using SPM12 segmentation and normalization
fprintf('  Normalizing: %s\n', t1_file);

[pth, nam, ext] = fileparts(t1_file);

% Create SPM batch for segmentation (which includes normalization)
matlabbatch = {};
matlabbatch{1}.spm.spatial.preproc.channel.vols = {[t1_file ',1']};
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1]; % Save bias corrected

% Tissue probability maps
matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,1')};
matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,2')};
matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,3')};
matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,4')};
matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,5')};
matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {fullfile(spm('Dir'), 'tpm', 'TPM.nii,6')};
matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1]; % Forward and inverse deformations

% Run batch
spm_jobman('run', matlabbatch);

% Output files
deformation_field = fullfile(pth, ['y_' nam ext]);
normalized_t1 = fullfile(pth, ['w' nam ext]);

% If normalized T1 doesn't exist, create it by applying the deformation
if ~exist(normalized_t1, 'file')
    fprintf('  Creating normalized T1...\n');
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.normalise.write.subj.def = {deformation_field};
    matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {[t1_file ',1']};
    matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
    matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [1 1 1];
    matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
    spm_jobman('run', matlabbatch);
end
end

function normalized_pet = apply_normalization(pet_file, deformation_field)
% Apply normalization to PET using the deformation field from T1
fprintf('  Applying normalization to PET...\n');

[pth, nam, ext] = fileparts(pet_file);

% Create SPM batch for normalization write
matlabbatch = {};
matlabbatch{1}.spm.spatial.normalise.write.subj.def = {deformation_field};
matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {[pet_file ',1']};
matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2]; % 2mm for PET
matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';

% Run batch
spm_jobman('run', matlabbatch);

normalized_pet = fullfile(pth, ['w' nam ext]);
end

function [atlas_hammersmith_resliced, atlas_jhu_resliced] = reslice_atlases_to_pet(...
    normalized_pet, hammersmith_atlas, jhu_atlas)
% Reslice atlases to match PET image space
fprintf('  Reslicing atlases...\n');

% Get output directory
[pth, ~, ~] = fileparts(normalized_pet);

% Reslice Hammersmith atlas
atlas_hammersmith_resliced = fullfile(pth, 'hammersmith_resliced.nii');
reslice_image(hammersmith_atlas, normalized_pet, atlas_hammersmith_resliced, 0); % Nearest neighbor

% Reslice JHU atlas
atlas_jhu_resliced = fullfile(pth, 'jhu_resliced.nii');
reslice_image(jhu_atlas, normalized_pet, atlas_jhu_resliced, 0); % Nearest neighbor
end

function reslice_image(source_img, reference_img, output_img, interp)
% Reslice source image to match reference image space
matlabbatch = {};
matlabbatch{1}.spm.spatial.coreg.write.ref = {[reference_img ',1']};
matlabbatch{1}.spm.spatial.coreg.write.source = {[source_img ',1']};
matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = interp; % 0 = nearest neighbor for labels
matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';

spm_jobman('run', matlabbatch);

% Rename output file
[pth, nam, ext] = fileparts(source_img);
resliced_file = fullfile(pth, ['r' nam ext]);
movefile(resliced_file, output_img);
end

function cereb_value = extract_cerebellum_value(pet_file, atlas_file, cereb_rois)
% Extract mean value from cerebellum ROIs
V_pet = spm_vol(pet_file);
pet_data = spm_read_vols(V_pet);

V_atlas = spm_vol(atlas_file);
atlas_data = spm_read_vols(V_atlas);

% Create cerebellum mask
cereb_mask = ismember(atlas_data, cereb_rois);

% Extract values
cereb_values = pet_data(cereb_mask);
cereb_values = cereb_values(~isnan(cereb_values) & cereb_values > 0);

if isempty(cereb_values)
    cereb_value = NaN;
else
    cereb_value = mean(cereb_values);
end
end

function suvr_values = extract_roi_suvr(pet_file, atlas_file, roi_labels, cereb_value)
% Extract SUVR values for all ROIs
V_pet = spm_vol(pet_file);
pet_data = spm_read_vols(V_pet);

V_atlas = spm_vol(atlas_file);
atlas_data = spm_read_vols(V_atlas);

suvr_values = zeros(length(roi_labels), 1);

for i = 1:length(roi_labels)
    roi_mask = (atlas_data == roi_labels(i));
    roi_values = pet_data(roi_mask);
    roi_values = roi_values(~isnan(roi_values) & roi_values > 0);
    
    if ~isempty(roi_values)
        roi_mean = mean(roi_values);
        suvr_values(i) = roi_mean / cereb_value;
    else
        suvr_values(i) = NaN;
    end
end
end

function save_results_to_excel(results, output_dir)
% Save results to Excel file
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
excel_file = fullfile(output_dir, ['SUVR_Results_' timestamp '.xlsx']);

% Get labels from first subject
hammersmith_labels = results(1).hammersmith_labels;
jhu_labels = results(1).jhu_labels;

% Create column headers
headers = {'Subject_ID', 'Cerebellum_Mean'};

% Add Hammersmith headers
for i = 1:length(hammersmith_labels)
    headers{end+1} = sprintf('Hammersmith_ROI_%d', hammersmith_labels(i));
end

% Add JHU headers
for i = 1:length(jhu_labels)
    headers{end+1} = sprintf('JHU_ROI_%d', jhu_labels(i));
end

% Create data matrix
n_subjects = length(results);
n_cols = length(headers);
data = cell(n_subjects + 1, n_cols);

% Add headers
data(1, :) = headers;

% Add data
for i = 1:n_subjects
    row = i + 1;
    data{row, 1} = results(i).subject_id;
    data{row, 2} = results(i).cerebellum_value;
    
    % Hammersmith SUVRs
    col_offset = 3;
    for j = 1:length(results(i).suvr_hammersmith)
        data{row, col_offset + j - 1} = results(i).suvr_hammersmith(j);
    end
    
    % JHU SUVRs
    col_offset = col_offset + length(results(i).suvr_hammersmith);
    for j = 1:length(results(i).suvr_jhu)
        data{row, col_offset + j - 1} = results(i).suvr_jhu(j);
    end
end

% Write to Excel
writecell(data, excel_file);
fprintf('Excel file created: %s\n', excel_file);

% Also save as MATLAB structure
mat_file = fullfile(output_dir, ['SUVR_Results_' timestamp '.mat']);
save(mat_file, 'results');
fprintf('MATLAB file created: %s\n', mat_file);
end