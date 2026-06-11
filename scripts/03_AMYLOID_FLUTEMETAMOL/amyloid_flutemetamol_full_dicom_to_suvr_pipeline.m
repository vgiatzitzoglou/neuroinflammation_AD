% COMPLETE FLUTEMETAMOL AMYLOID SUVR PIPELINE - CUSTOMIZED FOR YOUR DATA
% From DICOM → Excel with SUVR quantification and amyloid classification
% Customized: 1mm MNI, tight bbox, whole cerebellum ref, cutoff 1.38, QC images

%% ========================================================================
%  CONFIGURATION - CUSTOMIZED FOR YOUR DATA
%  ========================================================================

% Input paths
excel_path = fullfile(pwd, 'example_data', 'master_subjects.xlsx');
base_path = fullfile(pwd, 'example_data', 'amyloid_dicom');
out_root = fullfile(pwd, 'outputs', 'amyloid_suvr');

% T1 MRI structure: base_path/{SubjectID}/{SubjectID}_MRI/{SubjectID}_MRI/scans/2_MPRAGE_ADNI_P2/DICOM/
% T1 files start with: W*

% Atlas configuration
atlas_path = fullfile(pwd, 'atlases', 'hammers_atlas.img');
cerebellum_rois = [17, 18];  % Whole cerebellum (R and L)
brainstem_roi = 19;

% Cortical ROIs for amyloid quantification (exclude cerebellum, brainstem, ventricles)
% Based on Hammers atlas (84 ROIs total)
% Exclude: 17-18 (cerebellum), 19 (brainstem), 45-52 (ventricles), 77-84 (white matter/subcortical)
cortical_rois = [1:16, 20:44, 53:76];  % All gray matter cortical regions

% Amyloid positivity cutoff (Park et al. 2025)
amyloid_cutoff = 1.38;  % Whole cerebellum reference

% MNI normalization parameters
voxel_size = [1 1 1];  % 1mm isotropic (high resolution)
bounding_box = [-90 -126 -72; 90 90 108];  % Tight brain

% PET acquisition parameters
frames_to_average = 'all';  % Average all frames (90-120 min post-injection typical)
exclude_movement = true;  % Flag for movement detection (manual review needed)

% Processing options
compress_output = false;  % No compression (faster)
save_qc_images = true;  % Save quality control images
create_suvr_overlays = true;  % Create SUVR overlay images

% Scan name patterns for flutemetamol
scan_patterns = {
    '3D mode 6 x 5min list mode acquisition (AC)',
    'flutemetamol',
    '6x5min',
    'amyloid',
    'AC'
};

fprintf('=================================================================\n');
fprintf('FLUTEMETAMOL AMYLOID SUVR PIPELINE - CUSTOMIZED\n');
fprintf('=================================================================\n');
fprintf('Configuration:\n');
fprintf('  Atlas:           Hammers (84 ROIs)\n');
fprintf('  Reference:       Whole cerebellum (ROIs 17-18)\n');
fprintf('  Cutoff:          SUVR > %.2f (Park 2025)\n', amyloid_cutoff);
fprintf('  MNI space:       %dmm isotropic, tight bbox\n', voxel_size(1));
fprintf('  Cortical ROIs:   %d regions\n', length(cortical_rois));
fprintf('  QC images:       %s\n', string(save_qc_images));
fprintf('=================================================================\n\n');

%% ========================================================================
%  VALIDATE ENVIRONMENT
%  ========================================================================

fprintf('Validating environment...\n');

% Check required paths
assert(exist(excel_path, 'file') ~= 0, 'Excel file not found: %s', excel_path);
assert(exist(base_path, 'dir') ~= 0, 'Base path not found: %s', base_path);
assert(exist(atlas_path, 'file') ~= 0, 'Atlas not found: %s', atlas_path);

% Check SPM12
if isempty(which('spm'))
    error('SPM12 not found in MATLAB path. Please add SPM12.');
end
fprintf('  ✓ SPM12 found\n');

% Check dcm2niix
[status, ~] = system('which dcm2niix');
if status ~= 0
    warning('dcm2niix not in PATH. DICOM conversion will fail.');
else
    fprintf('  ✓ dcm2niix found\n');
end

% Create output directory structure
if ~exist(out_root, 'dir')
    mkdir(out_root);
end

qc_dir = fullfile(out_root, 'QC_Images');
if save_qc_images && ~exist(qc_dir, 'dir')
    mkdir(qc_dir);
end

fprintf('  ✓ Output directories created\n\n');

%% ========================================================================
%  LOAD SUBJECT IDS FROM EXCEL
%  ========================================================================

fprintf('Loading subject IDs from Excel...\n');

try
    T_master = readtable(excel_path);
    raw_ids = T_master{:, 1};
    
    % Convert to cell array of strings
    ids = cell(size(raw_ids, 1), 1);
    for i = 1:size(raw_ids, 1)
        ids{i} = to_string(raw_ids(i, :));
    end
    ids = ids(~cellfun(@isempty, ids));
    
    % Normalize IDs (MCI013, AD012, C003 format with leading zeros)
    norm_ids = cellfun(@normalize_id, ids, 'UniformOutput', false);
    
    fprintf('  Found %d subjects in Excel\n', numel(ids));
    fprintf('  Example IDs: %s, %s, %s\n', ids{1}, ids{min(2,end)}, ids{min(3,end)});
    fprintf('  Normalized:  %s, %s, %s\n\n', norm_ids{1}, norm_ids{min(2,end)}, norm_ids{min(3,end)});
    
catch ME
    error('Failed to read Excel: %s', ME.message);
end

%% ========================================================================
%  BUILD SUBJECT DIRECTORY MAP
%  ========================================================================

fprintf('Scanning for subject folders...\n');

subj_dirs = dir(base_path);
subj_dirs = subj_dirs([subj_dirs.isdir] & ~ismember({subj_dirs.name}, {'.','..'}));

subj_map = containers.Map();
for i = 1:numel(subj_dirs)
    name = subj_dirs(i).name;
    norm = normalize_id(name);
    if isempty(norm), continue; end
    
    if ~isKey(subj_map, norm)
        subj_map(norm) = {};
    end
    subj_map(norm) = [subj_map(norm), {fullfile(base_path, name)}];
end

fprintf('  Mapped %d unique subject IDs\n\n', subj_map.Count);

%% ========================================================================
%  MAIN PROCESSING LOOP
%  ========================================================================

fprintf('=================================================================\n');
fprintf('PROCESSING SUBJECTS\n');
fprintf('=================================================================\n\n');

results = cell(numel(norm_ids), 1);
success_count = 0;
log_messages = {};

for i = 1:numel(norm_ids)
    nid = norm_ids{i};
    tic;
    
    fprintf('[%d/%d] %s (%s)\n', i, numel(norm_ids), ids{i}, nid);
    fprintf('-----------------------------------------------------------\n');
    
    % Initialize result structure
    result = init_result_struct(ids{i}, nid);
    
    try
        %% STEP 1: Find and convert DICOM to NIfTI
        fprintf('STEP 1: DICOM Conversion\n');
        
        if ~isKey(subj_map, nid)
            error('No subject folder found');
        end
        
        subj_paths = subj_map(nid);
        mean_pet = '';
        dicom_path_used = '';
        
        % Try each subject folder
        for p = 1:numel(subj_paths)
            subj_path = subj_paths{p};
            
            % Find DICOM directory
            dicom_dir = find_dicom_pet(subj_path, nid, scan_patterns);
            if isempty(dicom_dir)
                continue;
            end
            
            fprintf('  Found DICOM: %s\n', dicom_dir);
            dicom_path_used = dicom_dir;
            
            % Create output directory
            out_dir = fullfile(out_root, nid, 'nifti');
            if ~exist(out_dir, 'dir')
                mkdir(out_dir);
            end
            
            % Convert DICOM
            [ok, msg] = run_dcm2niix(dicom_dir, out_dir);
            if ~ok
                fprintf('  ✗ Conversion failed: %s\n', msg);
                continue;
            end
            
            % Average 4D frames
            mean_pet = average_4d_frames(out_dir, nid);
            if ~isempty(mean_pet)
                fprintf('  ✓ Mean PET: %s\n', mean_pet);
                break;
            end
        end
        
        if isempty(mean_pet)
            error('Failed to create mean PET image');
        end
        
        result.PET_file = mean_pet;
        result.DICOM_path = dicom_path_used;
        
        %% STEP 2: Find T1 MRI
        fprintf('STEP 2: Locate T1 MRI\n');
        
        t1_file = find_t1_mri(subj_paths{1}, nid);
        if isempty(t1_file)
            error('No T1 MRI found');
        end
        
        fprintf('  ✓ T1: %s\n', t1_file);
        result.T1_file = t1_file;
        
        %% STEP 3: Coregister PET to T1
        fprintf('STEP 3: Coregistration\n');
        
        coreg_pet = coregister_pet_to_t1(mean_pet, t1_file);
        fprintf('  ✓ Coregistered: %s\n', coreg_pet);
        
        % QC: Save coregistration check
        if save_qc_images
            save_coreg_qc(t1_file, coreg_pet, qc_dir, nid);
        end
        
        %% STEP 4: Normalize to MNI space
        fprintf('STEP 4: Spatial Normalization\n');
        
        [norm_t1, norm_pet, def_field] = normalize_to_mni(t1_file, coreg_pet, voxel_size, bounding_box);
        fprintf('  ✓ Normalized PET: %s\n', norm_pet);
        
        % QC: Save normalization check
        if save_qc_images
            save_norm_qc(norm_t1, norm_pet, qc_dir, nid);
        end
        
        result.Normalized_PET = norm_pet;
        result.Deformation_field = def_field;
        
        %% STEP 5: Calculate SUVR
        fprintf('STEP 5: SUVR Calculation\n');
        
        [suvr_file, cereb_mean] = calculate_suvr_whole_cerebellum(norm_pet, atlas_path, ...
                                                                   cerebellum_rois, out_root, nid);
        fprintf('  ✓ SUVR image: %s\n', suvr_file);
        fprintf('  ✓ Cerebellum mean: %.4f\n', cereb_mean);
        
        if abs(cereb_mean - 1.0) > 0.1
            fprintf('  ⚠ WARNING: Cerebellum mean should be ~1.0, got %.4f\n', cereb_mean);
        end
        
        result.SUVR_file = suvr_file;
        result.Cerebellum_mean = cereb_mean;
        
        %% STEP 6: Extract ROI values
        fprintf('STEP 6: ROI Extraction\n');
        
        [roi_values, roi_labels] = extract_all_roi_values(suvr_file, atlas_path);
        
        % Calculate cortical SUVR (mean of cortical ROIs)
        cortex_suvrs = roi_values(cortical_rois);
        cortex_suvrs = cortex_suvrs(~isnan(cortex_suvrs));
        cortex_mean = mean(cortex_suvrs);
        
        % Global brain SUVR (all non-zero ROIs)
        global_suvrs = roi_values(~isnan(roi_values) & roi_values > 0);
        global_mean = mean(global_suvrs);
        
        fprintf('  ✓ Cortical SUVR: %.4f\n', cortex_mean);
        fprintf('  ✓ Global SUVR: %.4f\n', global_mean);
        
        % Amyloid classification
        is_positive = cortex_mean > amyloid_cutoff;
        status_str = string(is_positive);
        status_str(status_str == "1") = 'POSITIVE';
        status_str(status_str == "0") = 'NEGATIVE';
        
        fprintf('  ✓ Classification: %s (cutoff %.2f)\n', status_str, amyloid_cutoff);
        
        result.Cortex_SUVR = cortex_mean;
        result.Global_SUVR = global_mean;
        result.Amyloid_status = char(status_str);
        result.ROI_values = roi_values;
        result.ROI_labels = roi_labels;
        
        %% STEP 7: Create SUVR overlay (optional)
        if create_suvr_overlays
            fprintf('STEP 7: SUVR Overlay\n');
            create_suvr_overlay_image(norm_t1, suvr_file, qc_dir, nid, cortex_mean, status_str);
            fprintf('  ✓ Overlay saved\n');
        end
        
        result.Status = 'SUCCESS';
        result.Processing_time = toc;
        success_count = success_count + 1;
        
        fprintf('  ✓✓✓ SUCCESS (%.1f seconds)\n\n', result.Processing_time);
        
    catch ME
        result.Status = 'FAILED';
        result.Error_message = ME.message;
        result.Processing_time = toc;
        
        fprintf('  ✗✗✗ FAILED: %s (%.1f seconds)\n\n', ME.message, result.Processing_time);
        
        % Log error
        log_messages{end+1} = sprintf('%s: %s', nid, ME.message); %#ok<AGROW>
    end
    
    results{i} = result;
end

%% ========================================================================
%  EXPORT RESULTS TO EXCEL (3 SHEETS)
%  ========================================================================

fprintf('=================================================================\n');
fprintf('EXPORTING RESULTS\n');
fprintf('=================================================================\n');

excel_output = fullfile(out_root, sprintf('Flutemetamol_SUVR_Results_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS')));

try
    % =====================================================================
    % SHEET 1: SUMMARY - Status, Global SUVR, Classification
    % =====================================================================
    
    summary_data = {};
    for i = 1:numel(results)
        r = results{i};
        summary_data(end+1, :) = {
            r.Subject_ID, ...
            r.Normalized_ID, ...
            r.Status, ...
            r.Cerebellum_mean, ...
            r.Global_SUVR, ...
            r.Cortex_SUVR, ...
            r.Amyloid_status, ...
            r.Processing_time, ...
            r.Error_message
        }; %#ok<AGROW>
    end
    
    T_summary = cell2table(summary_data, 'VariableNames', ...
        {'Subject_ID', 'Normalized_ID', 'Processing_Status', 'Cerebellum_Mean', ...
         'Global_SUVR', 'Cortex_SUVR', 'Amyloid_Classification', 'Processing_Time_sec', 'Error_Message'});
    
    writetable(T_summary, excel_output, 'Sheet', '1_Summary');
    fprintf('  ✓ Sheet 1: Summary (%d subjects)\n', height(T_summary));
    
    % =====================================================================
    % SHEET 2: ALL ROI VALUES - Detailed SUVR for each ROI
    % =====================================================================
    
    roi_data = {};
    roi_header = {'Subject_ID', 'Normalized_ID', 'Status'};
    
    % Get max number of ROIs
    max_rois = 0;
    for i = 1:numel(results)
        if strcmp(results{i}.Status, 'SUCCESS')
            max_rois = max(max_rois, length(results{i}.ROI_values));
        end
    end
    
    % Build ROI column names
    for j = 1:max_rois
        roi_header{end+1} = sprintf('ROI_%03d_SUVR', j); %#ok<AGROW>
    end
    
    % Extract ROI data
    for i = 1:numel(results)
        r = results{i};
        if strcmp(r.Status, 'SUCCESS')
            row_data = {r.Subject_ID, r.Normalized_ID, r.Status};
            roi_vals = r.ROI_values;
            
            % Pad with NaN if needed
            if length(roi_vals) < max_rois
                roi_vals(end+1:max_rois) = NaN;
            end
            
            row_data = [row_data, num2cell(roi_vals')];
            roi_data(end+1, :) = row_data; %#ok<AGROW>
        end
    end
    
    if ~isempty(roi_data)
        T_roi = cell2table(roi_data, 'VariableNames', roi_header);
        writetable(T_roi, excel_output, 'Sheet', '2_ROI_Details');
        fprintf('  ✓ Sheet 2: ROI Details (%d subjects, %d ROIs)\n', height(T_roi), max_rois);
    end
    
    % =====================================================================
    % SHEET 3: QUALITY CONTROL METRICS
    % =====================================================================
    
    qc_data = {};
    for i = 1:numel(results)
        r = results{i};
        
        % Calculate QC metrics
        cereb_check = '';
        if ~isnan(r.Cerebellum_mean)
            if abs(r.Cerebellum_mean - 1.0) < 0.05
                cereb_check = 'PASS';
            elseif abs(r.Cerebellum_mean - 1.0) < 0.1
                cereb_check = 'WARNING';
            else
                cereb_check = 'FAIL';
            end
        end
        
        suvr_range_check = '';
        if ~isnan(r.Cortex_SUVR)
            if r.Cortex_SUVR >= 0.5 && r.Cortex_SUVR <= 3.0
                suvr_range_check = 'PASS';
            else
                suvr_range_check = 'FAIL';
            end
        end
        
        qc_data(end+1, :) = {
            r.Subject_ID, ...
            r.Normalized_ID, ...
            r.Status, ...
            r.Cerebellum_mean, ...
            cereb_check, ...
            r.Cortex_SUVR, ...
            suvr_range_check, ...
            r.Processing_time, ...
            r.PET_file, ...
            r.T1_file
        }; %#ok<AGROW>
    end
    
    T_qc = cell2table(qc_data, 'VariableNames', ...
        {'Subject_ID', 'Normalized_ID', 'Status', 'Cerebellum_Mean', 'Cerebellum_QC', ...
         'Cortex_SUVR', 'SUVR_Range_QC', 'Processing_Time', 'PET_File', 'T1_File'});
    
    writetable(T_qc, excel_output, 'Sheet', '3_Quality_Control');
    fprintf('  ✓ Sheet 3: Quality Control\n');
    
    fprintf('\n✓✓✓ Excel file saved: %s\n', excel_output);
    
catch ME
    warning('Failed to write Excel file: %s', ME.message);
    fprintf('  Saving CSV files instead...\n');
    
    % Fallback to CSV
    csv_summary = fullfile(out_root, 'Summary.csv');
    writetable(T_summary, csv_summary);
    fprintf('  ✓ %s\n', csv_summary);
end

%% ========================================================================
%  PROCESSING LOG
%  ========================================================================

% Save processing log
log_file = fullfile(out_root, sprintf('Processing_Log_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
fid = fopen(log_file, 'w');
fprintf(fid, 'FLUTEMETAMOL AMYLOID SUVR PIPELINE - PROCESSING LOG\n');
fprintf(fid, '=================================================================\n');
fprintf(fid, 'Date: %s\n', datestr(now));
fprintf(fid, 'Total subjects: %d\n', numel(results));
fprintf(fid, 'Successful: %d\n', success_count);
fprintf(fid, 'Failed: %d\n', numel(results) - success_count);
fprintf(fid, '=================================================================\n\n');

if ~isempty(log_messages)
    fprintf(fid, 'ERRORS:\n');
    for i = 1:length(log_messages)
        fprintf(fid, '  %s\n', log_messages{i});
    end
end

fclose(fid);

%% ========================================================================
%  FINAL SUMMARY
%  ========================================================================

fprintf('\n=================================================================\n');
fprintf('PIPELINE COMPLETE\n');
fprintf('=================================================================\n');
fprintf('Total subjects:        %d\n', numel(results));
fprintf('Successfully processed: %d\n', success_count);
fprintf('Failed:                 %d\n', numel(results) - success_count);
fprintf('\nAmyloid Classification:\n');

pos_count = sum(cellfun(@(r) strcmp(r.Amyloid_status, 'POSITIVE'), results));
neg_count = sum(cellfun(@(r) strcmp(r.Amyloid_status, 'NEGATIVE'), results));

fprintf('  Aβ+ (POSITIVE): %d (%.1f%%)\n', pos_count, 100*pos_count/success_count);
fprintf('  Aβ- (NEGATIVE): %d (%.1f%%)\n', neg_count, 100*neg_count/success_count);
fprintf('\nOutput files:\n');
fprintf('  Excel:   %s\n', excel_output);
fprintf('  Log:     %s\n', log_file);
if save_qc_images
    fprintf('  QC images: %s\n', qc_dir);
end
fprintf('=================================================================\n');

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function result = init_result_struct(id, nid)
    result = struct();
    result.Subject_ID = id;
    result.Normalized_ID = nid;
    result.Status = '';
    result.Error_message = '';
    result.Processing_time = 0;
    result.PET_file = '';
    result.T1_file = '';
    result.DICOM_path = '';
    result.Normalized_PET = '';
    result.SUVR_file = '';
    result.Deformation_field = '';
    result.Cerebellum_mean = NaN;
    result.Global_SUVR = NaN;
    result.Cortex_SUVR = NaN;
    result.Amyloid_status = '';
    result.ROI_values = [];
    result.ROI_labels = {};
end

function s = to_string(x)
    if iscell(x)
        if isempty(x), s = ''; return; end
        s = to_string(x{1});
        return;
    end
    if ischar(x)
        s = strtrim(x);
    elseif isstring(x)
        s = strtrim(char(x));
    elseif isnumeric(x)
        if isempty(x) || any(isnan(x))
            s = '';
        else
            s = strtrim(sprintf('%.0f', x(1)));
        end
    else
        s = strtrim(char(string(x)));
    end
end

function nid = normalize_id(id)
    % Normalize to format: MCI013, AD012, C003 (with leading zeros)
    s = upper(regexprep(char(id), '\s+', ''));
    if isempty(s), nid = ''; return; end
    
    % Match known prefixes
    m = regexp(s, '^(MCI|AD|C)(\d+)', 'tokens', 'once');
    if ~isempty(m)
        prefix = m{1};
        num = m{2};
        num = regexprep(num, '^0+', '');  % Remove leading zeros
        if isempty(num), num = '0'; end
        num = sprintf('%03d', str2double(num));  % Add back as 3 digits
        nid = [prefix num];
        return;
    end
    
    % Fallback
    nid = regexprep(s, '[^A-Z0-9]', '');
end

function dicom_dir = find_dicom_pet(subj_path, nid, patterns)
    % Find DICOM PET directory following structure:
    % {subj_path}/{nid}_MRI/{nid}_MRI/scans/{scan_folder}/DICOM/
    
    dicom_dir = '';
    
    % Look for MRI subdirectory
    mri_path = fullfile(subj_path, [nid '_MRI'], [nid '_MRI'], 'scans');
    
    if ~exist(mri_path, 'dir')
        % Try alternative structure
        mri_path = fullfile(subj_path, 'scans');
    end
    
    if ~exist(mri_path, 'dir')
        return;
    end
    
    % Find scan folder matching patterns
    scan_folders = dir(mri_path);
    scan_folders = scan_folders([scan_folders.isdir] & ~ismember({scan_folders.name}, {'.','..'}));
    
    for s = 1:numel(scan_folders)
        scan_name = scan_folders(s).name;
        
        % Check if matches any pattern
        for p = 1:numel(patterns)
            if contains(lower(scan_name), lower(patterns{p}))
                % Found matching scan, look for DICOM
                candidate = fullfile(mri_path, scan_name, 'DICOM');
                
                if exist(candidate, 'dir')
                    % Check if has DICOM files
                    dcm_files = dir(fullfile(candidate, '*'));
                    dcm_files = dcm_files(~[dcm_files.isdir]);
                    
                    if ~isempty(dcm_files)
                        dicom_dir = candidate;
                        return;
                    end
                end
            end
        end
    end
end

function t1_file = find_t1_mri(subj_path, nid)
    % Find T1 MRI file starting with W* in DICOM folder
    % Structure: {subj_path}/{nid}_MRI/{nid}_MRI/scans/2_MPRAGE_ADNI_P2/DICOM/
    
    t1_file = '';
    
    % Build path to MPRAGE DICOM
    mprage_path = fullfile(subj_path, [nid '_MRI'], [nid '_MRI'], 'scans', '2_MPRAGE_ADNI_P2', 'DICOM');
    
    if ~exist(mprage_path, 'dir')
        % Try alternative structure
        scans_dir = fullfile(subj_path, 'scans');
        if exist(scans_dir, 'dir')
            % Look for MPRAGE folder
            scan_folders = dir(scans_dir);
            scan_folders = scan_folders([scan_folders.isdir]);
            
            for s = 1:numel(scan_folders)
                if contains(lower(scan_folders(s).name), 'mprage')
                    mprage_path = fullfile(scans_dir, scan_folders(s).name, 'DICOM');
                    break;
                end
            end
        end
    end
    
    if ~exist(mprage_path, 'dir')
        return;
    end
    
    % Look for files starting with W*
    w_files = dir(fullfile(mprage_path, 'W*.nii'));
    
    if ~isempty(w_files)
        % Use most recent if multiple
        [~, idx] = max([w_files.datenum]);
        t1_file = fullfile(mprage_path, w_files(idx).name);
        return;
    end
    
    % Fallback: any .nii file
    nii_files = dir(fullfile(mprage_path, '*.nii'));
    if ~isempty(nii_files)
        [~, idx] = max([nii_files.datenum]);
        t1_file = fullfile(mprage_path, nii_files(idx).name);
    end
end

function [ok, msg] = run_dcm2niix(dicom_dir, out_dir)
    % Run dcm2niix without compression
    cmd = sprintf('dcm2niix -z n -o "%s" "%s"', out_dir, dicom_dir);
    [status, output] = system(cmd);
    ok = (status == 0);
    msg = output;
end

function mean_out = average_4d_frames(out_dir, nid)
    % Average all frames from 4D PET
    mean_out = '';
    
    nii_files = dir(fullfile(out_dir, '*.nii'));
    if isempty(nii_files)
        return;
    end
    
    % Use largest file (likely the 4D series)
    [~, idx] = max([nii_files.bytes]);
    nii_path = fullfile(out_dir, nii_files(idx).name);
    
    try
        V = spm_vol(nii_path);
        
        if numel(V) == 1
            % Already a single frame
            mean_out = nii_path;
            return;
        end
        
        % Read all frames and average
        fprintf('    Averaging %d frames...\n', numel(V));
        Y = spm_read_vols(V);
        Ymean = mean(Y, 4);
        
        % Write mean image
        Vout = V(1);
        Vout.fname = fullfile(out_dir, [nid '_mean.nii']);
        Vout.descrip = sprintf('Mean of %d frames', numel(V));
        spm_write_vol(Vout, Ymean);
        
        mean_out = Vout.fname;
        
    catch ME
        fprintf('    Warning: %s\n', ME.message);
    end
end

function coreg_pet = coregister_pet_to_t1(pet_file, t1_file)
    % SPM coregistration: PET to T1
    
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {t1_file};
    matlabbatch{1}.spm.spatial.coreg.estwrite.source = {pet_file};
    matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = ...
        [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
    
    spm_jobman('run', matlabbatch);
    
    [pth, name, ext] = fileparts(pet_file);
    coreg_pet = fullfile(pth, ['r' name ext]);
end

function [norm_t1, norm_pet, def_field] = normalize_to_mni(t1_file, pet_file, voxel_size, bbox)
    % SPM segmentation + normalization with custom parameters
    
    % Segment T1 to get deformation field
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {t1_file};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];
    
    % Tissue classes
    tpm_path = fullfile(spm('Dir'), 'tpm', 'TPM.nii');
    for c = 1:6
        matlabbatch{1}.spm.spatial.preproc.tissue(c).tpm = {sprintf('%s,%d', tpm_path, c)};
        matlabbatch{1}.spm.spatial.preproc.tissue(c).ngaus = [1 1 2 3 4 2];
        matlabbatch{1}.spm.spatial.preproc.tissue(c).native = [1 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(c).warped = [0 0];
    end
    
    matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1];
    
    spm_jobman('run', matlabbatch);
    
    % Get deformation field
    [pth, name, ~] = fileparts(t1_file);
    def_field = fullfile(pth, ['y_' name '.nii']);
    
    % Apply normalization to T1 and PET with custom voxel size and bbox
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.normalise.write.subj.def = {def_field};
    matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {t1_file; pet_file};
    matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = bbox;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = voxel_size;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
    
    spm_jobman('run', matlabbatch);
    
    norm_t1 = fullfile(pth, ['w' name '.nii']);
    
    [pth_pet, name_pet, ext_pet] = fileparts(pet_file);
    norm_pet = fullfile(pth_pet, ['w' name_pet ext_pet]);
end

function [suvr_file, cereb_mean] = calculate_suvr_whole_cerebellum(norm_pet, atlas_path, cereb_rois, out_root, nid)
    % Calculate SUVR using whole cerebellum as reference
    
    % Load images
    V_pet = spm_vol(norm_pet);
    pet_img = spm_read_vols(V_pet);
    
    V_atlas = spm_vol(atlas_path);
    atlas_img = spm_read_vols(V_atlas);
    
    % Resample atlas if needed
    if ~isequal(size(pet_img), size(atlas_img))
        atlas_img = imresize3(atlas_img, size(pet_img), 'nearest');
    end
    
    % Extract cerebellum (whole: gray + white)
    cereb_mask = ismember(atlas_img, cereb_rois);
    cereb_vals = pet_img(cereb_mask & pet_img > 0);
    cereb_mean = mean(cereb_vals);
    
    % Calculate SUVR
    suvr_img = pet_img / cereb_mean;
    suvr_img(~isfinite(suvr_img)) = 0;
    
    % Save
    V_out = V_pet;
    suvr_file = fullfile(out_root, nid, [nid '_SUVR_WholeCereb.nii']);
    
    if ~exist(fileparts(suvr_file), 'dir')
        mkdir(fileparts(suvr_file));
    end
    
    V_out.fname = suvr_file;
    V_out.descrip = sprintf('SUVR WholeCereb ref=%.4f', cereb_mean);
    spm_write_vol(V_out, suvr_img);
end

function [roi_values, roi_labels] = extract_all_roi_values(suvr_file, atlas_path)
    % Extract SUVR for all ROIs in atlas
    
    V_suvr = spm_vol(suvr_file);
    suvr_img = spm_read_vols(V_suvr);
    
    V_atlas = spm_vol(atlas_path);
    atlas_img = spm_read_vols(V_atlas);
    
    % Resample if needed
    if ~isequal(size(suvr_img), size(atlas_img))
        atlas_img = imresize3(atlas_img, size(suvr_img), 'nearest');
    end
    
    % Get unique ROIs
    unique_rois = unique(atlas_img(:));
    unique_rois = unique_rois(unique_rois > 0);
    
    max_roi = max(unique_rois);
    roi_values = nan(max_roi, 1);
    roi_labels = cell(max_roi, 1);
    
    % Extract mean for each ROI
    for r = unique_rois'
        mask = atlas_img == r;
        vals = suvr_img(mask & suvr_img > 0);
        
        if ~isempty(vals)
            roi_values(r) = mean(vals);
        end
        
        roi_labels{r} = sprintf('ROI_%03d', r);
    end
end

function save_coreg_qc(t1_file, pet_file, qc_dir, nid)
    % Save coregistration check image
    try
        % Use SPM's check_reg for visual QC
        spm_check_registration(t1_file, pet_file);
        
        % Save screenshot
        qc_file = fullfile(qc_dir, sprintf('%s_coreg_check.png', nid));
        saveas(gcf, qc_file);
        close(gcf);
    catch
        % Silent fail
    end
end

function save_norm_qc(norm_t1, norm_pet, qc_dir, nid)
    % Save normalization check image
    try
        spm_check_registration(norm_t1, norm_pet);
        
        qc_file = fullfile(qc_dir, sprintf('%s_norm_check.png', nid));
        saveas(gcf, qc_file);
        close(gcf);
    catch
        % Silent fail
    end
end

function create_suvr_overlay_image(mri_file, suvr_file, qc_dir, nid, cortex_suvr, status)
    % Create SUVR overlay on MRI with classification
    try
        figure('Position', [100, 100, 1200, 400]);
        
        % Load images
        V_mri = spm_vol(mri_file);
        V_suvr = spm_vol(suvr_file);
        
        mri_img = spm_read_vols(V_mri);
        suvr_img = spm_read_vols(V_suvr);
        
        % Get middle slices
        mid_x = round(size(mri_img, 1) / 2);
        mid_y = round(size(mri_img, 2) / 2);
        mid_z = round(size(mri_img, 3) / 2);
        
        % Plot 3 views
        views = {squeeze(mri_img(mid_x, :, :))', squeeze(mri_img(:, mid_y, :))', squeeze(mri_img(:, :, mid_z))};
        suvr_views = {squeeze(suvr_img(mid_x, :, :))', squeeze(suvr_img(:, mid_y, :))', squeeze(suvr_img(:, :, mid_z))};
        titles = {'Sagittal', 'Coronal', 'Axial'};
        
        for v = 1:3
            subplot(1, 3, v);
            imagesc(views{v});
            colormap gray;
            axis image off;
            hold on;
            
            % Overlay SUVR (threshold > 1.0)
            suvr_overlay = suvr_views{v};
            suvr_overlay(suvr_overlay < 1.0) = NaN;
            
            h = imagesc(suvr_overlay);
            set(h, 'AlphaData', ~isnan(suvr_overlay) * 0.5);
            colormap(gca, hot);
            caxis([1.0, 2.0]);
            
            title(sprintf('%s - %s', titles{v}, status), 'FontSize', 12, 'FontWeight', 'bold');
        end
        
        % Add colorbar
        c = colorbar('Position', [0.92, 0.3, 0.02, 0.4]);
        ylabel(c, 'SUVR', 'FontSize', 11);
        
        % Add text annotation
        annotation('textbox', [0.35, 0.02, 0.3, 0.05], ...
                  'String', sprintf('Cortex SUVR: %.3f (%s)', cortex_suvr, status), ...
                  'FontSize', 14, 'FontWeight', 'bold', ...
                  'HorizontalAlignment', 'center', ...
                  'EdgeColor', 'none');
        
        % Save
        overlay_file = fullfile(qc_dir, sprintf('%s_SUVR_overlay.png', nid));
        saveas(gcf, overlay_file);
        close(gcf);
    catch
        % Silent fail
    end
end
