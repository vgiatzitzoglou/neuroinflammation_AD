% Flutemetamol amyloid SUVR script
% DICOM -> SUVR values/table. This is still quite path-dependent, so check the
% folders and atlas before running.

%  config

% input paths
excel_path = fullfile(pwd, 'example_data', 'master_subjects.xlsx');
base_path = fullfile(pwd, 'example_data', 'amyloid_dicom');
out_root = fullfile(pwd, 'outputs', 'amyloid_suvr');

% T1 MRI structure: base_path/{SubjectID}/{SubjectID}_MRI/{SubjectID}_MRI/scans/2_MPRAGE_ADNI_P2/DICOM/
% T1 files start with W*

% atlas bits
atlas_path = fullfile(pwd, 'atlases', 'hammers_atlas.img');
cerebellum_rois = [17, 18];  % Whole cerebellum (R and L)
brainstem_roi = 19;

% cortical ROIs for amyloid quantification
% exclude cerebellum, brainstem, ventricles, WM/subcortical labels
cortical_rois = [1:16, 20:44, 53:76];  % All gray matter cortical regions

% amyloid positivity cutoff (Park et al. 2025)
amyloid_cutoff = 1.38;  % Whole cerebellum reference
% TODO: change this if using a different reference region / paper.

% MNI normalization parameters
voxel_size = [1 1 1];  % 1mm isotropic (high resolution)
bounding_box = [-90 -126 -72; 90 90 108];  % Tight brain

% PET acquisition parameters
frames_to_average = 'all';  % Average all frames (90-120 min post-injection typical)
exclude_movement = true;  % Flag for movement detection (manual review needed)

% processing options
compress_output = false;  % No compression (faster)
save_qc_images = true;  % Save quality control images
create_suvr_overlays = true;  % Create SUVR overlay images

% scan name patterns for flutemetamol
scan_patterns = {
    '3D mode 6 x 5min list mode acquisition (AC)',
    'flutemetamol',
    '6x5min',
    'amyloid',
    'AC'
};
fprintf('flutemetamol amyloid SUVR\n');
fprintf('settings:\n');
fprintf('  atlas:           Hammers (84 ROIs)\n');
fprintf('  reference:       whole cerebellum (ROIs 17-18)\n');
fprintf('  cutoff:          SUVR > %.2f (Park 2025)\n', amyloid_cutoff);
fprintf('  MNI space:       %dmm isotropic, tight bbox\n', voxel_size(1));
fprintf('  cortical ROIs:   %d regions\n', length(cortical_rois));
fprintf('  QC images:       %s\n', string(save_qc_images));

%  check setup

fprintf('checking environment...\n');

% check required paths
assert(exist(excel_path, 'file') ~= 0, 'Excel file not found: %s', excel_path);
assert(exist(base_path, 'dir') ~= 0, 'Base path not found: %s', base_path);
assert(exist(atlas_path, 'file') ~= 0, 'Atlas not found: %s', atlas_path);

% check SPM12
if isempty(which('spm'))
    error('SPM12 not found in MATLAB path. Please add SPM12.');
end
fprintf('  ok SPM12 found\n');

% check dcm2niix
[status, ~] = system('which dcm2niix');
if status ~= 0
    warning('dcm2niix not in PATH. DICOM conversion will fail.');
else
    fprintf('  ok dcm2niix found\n');
end

% create output dirs
if ~exist(out_root, 'dir')
    mkdir(out_root);
end

qc_dir = fullfile(out_root, 'QC_Images');
if save_qc_images && ~exist(qc_dir, 'dir')
    mkdir(qc_dir);
end

fprintf('  ok output dirs created\n\n');

%  load subject ids

fprintf('loading subject IDs from Excel...\n');

try
    T_master = readtable(excel_path);
    raw_ids = T_master{:, 1};
    
    % convert to cell array of strings
    ids = cell(size(raw_ids, 1), 1);
    for i = 1:size(raw_ids, 1)
        ids{i} = to_string(raw_ids(i, :));
    end
    ids = ids(~cellfun(@isempty, ids));
    
    % normalize IDs (MCI013, AD012, C003 format with leading zeros)
    norm_ids = cellfun(@normalize_id, ids, 'UniformOutput', false);
    
    fprintf('  found %d subjects in Excel\n', numel(ids));
    fprintf('  example IDs: %s, %s, %s\n', ids{1}, ids{min(2,end)}, ids{min(3,end)});
    fprintf('  normalized:  %s, %s, %s\n\n', norm_ids{1}, norm_ids{min(2,end)}, norm_ids{min(3,end)});
    
catch ME
    error('Failed to read Excel: %s', ME.message);
end

%  subject folders

fprintf('scanning for subject folders...\n');

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

fprintf('  mapped %d unique subject IDs\n\n', subj_map.Count);

%  main loop
fprintf('processing subjects\n');

results = cell(numel(norm_ids), 1);
success_count = 0;
log_messages = {};

for i = 1:numel(norm_ids)
    nid = norm_ids{i};
    tic;
    
    fprintf('[%d/%d] %s (%s)\n', i, numel(norm_ids), ids{i}, nid);
    fprintf('-----------------------------------------------------------\n');
    
    % init result row
    result = init_result_struct(ids{i}, nid);
    
    try
        %% step 1: find and convert DICOM to NIfTI
        fprintf('step 1: DICOM conversion\n');
        
        if ~isKey(subj_map, nid)
            error('No subject folder found');
        end
        
        subj_paths = subj_map(nid);
        mean_pet = '';
        dicom_path_used = '';
        
        % try each subject folder
        for p = 1:numel(subj_paths)
            subj_path = subj_paths{p};
            
            % find DICOM directory
            dicom_dir = find_dicom_pet(subj_path, nid, scan_patterns);
            if isempty(dicom_dir)
                continue;
            end
            
            fprintf('  found DICOM: %s\n', dicom_dir);
            dicom_path_used = dicom_dir;
            
            % create output directory
            out_dir = fullfile(out_root, nid, 'nifti');
            if ~exist(out_dir, 'dir')
                mkdir(out_dir);
            end
            
            % convert DICOM
            [ok, msg] = run_dcm2niix(dicom_dir, out_dir);
            if ~ok
                fprintf('  error: conversion failed: %s\n', msg);
                continue;
            end
            
            % average 4D frames
            mean_pet = average_4d_frames(out_dir, nid);
            if ~isempty(mean_pet)
                fprintf('  ok mean PET: %s\n', mean_pet);
                break;
            end
        end
        
        if isempty(mean_pet)
            error('Failed to create mean PET image');
        end
        
        result.PET_file = mean_pet;
        result.DICOM_path = dicom_path_used;
        
        %% step 2: find T1 MRI
        fprintf('step 2: locate T1 MRI\n');
        
        t1_file = find_t1_mri(subj_paths{1}, nid);
        if isempty(t1_file)
            error('No T1 MRI found');
        end
        
        fprintf('  ok T1: %s\n', t1_file);
        result.T1_file = t1_file;
        
        %% step 3: coregister PET to T1
        fprintf('step 3: coregistration\n');
        
        coreg_pet = coregister_pet_to_t1(mean_pet, t1_file);
        fprintf('  ok Coregistered: %s\n', coreg_pet);
        
        % QC image for coregistration
        if save_qc_images
            save_coreg_qc(t1_file, coreg_pet, qc_dir, nid);
        end
        
        %% step 4: normalize to MNI space
        fprintf('step 4: spatial normalization\n');
        
        [norm_t1, norm_pet, def_field] = normalize_to_mni(t1_file, coreg_pet, voxel_size, bounding_box);
        fprintf('  ok normalized PET: %s\n', norm_pet);
        
        % QC image for normalization
        if save_qc_images
            save_norm_qc(norm_t1, norm_pet, qc_dir, nid);
        end
        
        result.Normalized_PET = norm_pet;
        result.Deformation_field = def_field;
        
        %% step 5: calculate SUVR
        fprintf('step 5: SUVR calculation\n');
        
        [suvr_file, cereb_mean] = calculate_suvr_whole_cerebellum(norm_pet, atlas_path, ...
                                                                   cerebellum_rois, out_root, nid);
        fprintf('  ok SUVR image: %s\n', suvr_file);
        fprintf('  ok cerebellum mean: %.4f\n', cereb_mean);
        
        if abs(cereb_mean - 1.0) > 0.1
            fprintf('  warning: cerebellum mean should be ~1.0, got %.4f\n', cereb_mean);
        end
        
        result.SUVR_file = suvr_file;
        result.Cerebellum_mean = cereb_mean;
        
        %% step 6: extract ROI values
        fprintf('step 6: ROI extraction\n');
        
        [roi_values, roi_labels] = extract_all_roi_values(suvr_file, atlas_path);
        
        % cortical SUVR (mean of cortical ROIs)
        cortex_suvrs = roi_values(cortical_rois);
        cortex_suvrs = cortex_suvrs(~isnan(cortex_suvrs));
        cortex_mean = mean(cortex_suvrs);
        
        % global brain SUVR (all non-zero ROIs)
        global_suvrs = roi_values(~isnan(roi_values) & roi_values > 0);
        global_mean = mean(global_suvrs);
        
        fprintf('  ok cortical SUVR: %.4f\n', cortex_mean);
        fprintf('  ok global SUVR: %.4f\n', global_mean);
        
        % amyloid classification
        is_positive = cortex_mean > amyloid_cutoff;
        status_str = string(is_positive);
        status_str(status_str == "1") = 'positive';
        status_str(status_str == "0") = 'negative';
        
        fprintf('  ok classification: %s (cutoff %.2f)\n', status_str, amyloid_cutoff);
        
        result.Cortex_SUVR = cortex_mean;
        result.Global_SUVR = global_mean;
        result.Amyloid_status = char(status_str);
        result.ROI_values = roi_values;
        result.ROI_labels = roi_labels;
        
        %% step 7: create SUVR overlay (optional)
        if create_suvr_overlays
            fprintf('step 7: SUVR overlay\n');
            create_suvr_overlay_image(norm_t1, suvr_file, qc_dir, nid, cortex_mean, status_str);
            fprintf('  ok overlay saved\n');
        end
        
        result.Status = 'success';
        result.Processing_time = toc;
        success_count = success_count + 1;
        
        fprintf('  ok success (%.1f seconds)\n\n', result.Processing_time);
        
    catch ME
        result.Status = 'failed';
        result.Error_message = ME.message;
        result.Processing_time = toc;
        
        fprintf('  failed: %s (%.1f seconds)\n\n', ME.message, result.Processing_time);
        
        % log error
        log_messages{end+1} = sprintf('%s: %s', nid, ME.message); %#ok<AGROW>
    end
    
    results{i} = result;
end

%  export tables
fprintf('exporting results\n');

excel_output = fullfile(out_root, sprintf('Flutemetamol_SUVR_Results_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS')));

try
    % sheet 1: summary
    
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
    fprintf('  ok sheet 1: summary (%d subjects)\n', height(T_summary));
    
    % sheet 2: all ROI values
    
    roi_data = {};
    roi_header = {'Subject_ID', 'Normalized_ID', 'Status'};
    
    % get max number of ROIs
    max_rois = 0;
    for i = 1:numel(results)
        if strcmp(results{i}.Status, 'success')
            max_rois = max(max_rois, length(results{i}.ROI_values));
        end
    end
    
    % build ROI column names
    for j = 1:max_rois
        roi_header{end+1} = sprintf('ROI_%03d_SUVR', j); %#ok<AGROW>
    end
    
    % extract ROI data
    for i = 1:numel(results)
        r = results{i};
        if strcmp(r.Status, 'success')
            row_data = {r.Subject_ID, r.Normalized_ID, r.Status};
            roi_vals = r.ROI_values;
            
            % pad with NaN if needed
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
        fprintf('  ok sheet 2: ROI details (%d subjects, %d ROIs)\n', height(T_roi), max_rois);
    end
    
    % sheet 3: QC checks
    
    qc_data = {};
    for i = 1:numel(results)
        r = results{i};
        
        % calculate QC metrics
        cereb_check = '';
        if ~isnan(r.Cerebellum_mean)
            if abs(r.Cerebellum_mean - 1.0) < 0.05
                cereb_check = 'pass';
            elseif abs(r.Cerebellum_mean - 1.0) < 0.1
                cereb_check = 'warning';
            else
                cereb_check = 'fail';
            end
        end
        
        suvr_range_check = '';
        if ~isnan(r.Cortex_SUVR)
            if r.Cortex_SUVR >= 0.5 && r.Cortex_SUVR <= 3.0
                suvr_range_check = 'pass';
            else
                suvr_range_check = 'fail';
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
    fprintf('  ok sheet 3: QC\n');
    
    fprintf('\nok Excel file saved: %s\n', excel_output);
    
catch ME
    warning('Failed to write Excel file: %s', ME.message);
    fprintf('  saving CSV files instead...\n');
    
    % Fallback to CSV
    csv_summary = fullfile(out_root, 'Summary.csv');
    writetable(T_summary, csv_summary);
    fprintf('  ok %s\n', csv_summary);
end

%  processing log

log_file = fullfile(out_root, sprintf('Processing_Log_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
fid = fopen(log_file, 'w');
fprintf(fid, 'flutemetamol amyloid SUVR pipeline - processing log\n');
fprintf(fid, 'date: %s\n', datestr(now));
fprintf(fid, 'total subjects: %d\n', numel(results));
fprintf(fid, 'successful: %d\n', success_count);
fprintf(fid, 'failed: %d\n', numel(results) - success_count);

if ~isempty(log_messages)
    fprintf(fid, 'errors:\n');
    for i = 1:length(log_messages)
        fprintf(fid, '  %s\n', log_messages{i});
    end
end

fclose(fid);

%  final summary
fprintf('done\n');
fprintf('total subjects:        %d\n', numel(results));
fprintf('successfully processed: %d\n', success_count);
fprintf('failed:                 %d\n', numel(results) - success_count);
fprintf('\namyloid classification:\n');

pos_count = sum(cellfun(@(r) strcmp(r.Amyloid_status, 'positive'), results));
neg_count = sum(cellfun(@(r) strcmp(r.Amyloid_status, 'negative'), results));

fprintf('  Abeta+ (positive): %d (%.1f%%)\n', pos_count, 100*pos_count/success_count);
fprintf('  Abeta- (negative): %d (%.1f%%)\n', neg_count, 100*neg_count/success_count);
fprintf('\noutput files:\n');
fprintf('  Excel:   %s\n', excel_output);
fprintf('  Log:     %s\n', log_file);
if save_qc_images
    fprintf('  QC images: %s\n', qc_dir);
end

%  helper functions

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
    % normalize to MCI013, AD012, C003 style
    s = upper(regexprep(char(id), '\s+', ''));
    if isempty(s), nid = ''; return; end
    
    % Match known prefixes
    m = regexp(s, '^(MCI|AD|C)(\d+)', 'tokens', 'once');
    if ~isempty(m)
        prefix = m{1};
        num = m{2};
        num = regexprep(num, '^0+', '');  % remove leading zeros
        if isempty(num), num = '0'; end
        num = sprintf('%03d', str2double(num));  % add back as 3 digits
        nid = [prefix num];
        return;
    end
    
    % fallback
    nid = regexprep(s, '[^A-Z0-9]', '');
end

function dicom_dir = find_dicom_pet(subj_path, nid, patterns)
    % find DICOM PET directory following structure
    % {subj_path}/{nid}_MRI/{nid}_MRI/scans/{scan_folder}/DICOM/
    
    dicom_dir = '';
    
    % look for MRI subdirectory
    mri_path = fullfile(subj_path, [nid '_MRI'], [nid '_MRI'], 'scans');
    
    if ~exist(mri_path, 'dir')
        % try alternative structure
        mri_path = fullfile(subj_path, 'scans');
    end
    
    if ~exist(mri_path, 'dir')
        return;
    end
    
    % find scan folder matching patterns
    scan_folders = dir(mri_path);
    scan_folders = scan_folders([scan_folders.isdir] & ~ismember({scan_folders.name}, {'.','..'}));
    
    for s = 1:numel(scan_folders)
        scan_name = scan_folders(s).name;
        
        % Check if matches any pattern
        for p = 1:numel(patterns)
            if contains(lower(scan_name), lower(patterns{p}))
                % found matching scan, look for DICOM
                candidate = fullfile(mri_path, scan_name, 'DICOM');
                
                if exist(candidate, 'dir')
                    % check if has DICOM files
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
    % find T1 MRI file starting with W* in DICOM folder
    % structure: {subj_path}/{nid}_MRI/{nid}_MRI/scans/2_MPRAGE_ADNI_P2/DICOM/
    
    t1_file = '';
    
    % build path to MPRAGE DICOM
    mprage_path = fullfile(subj_path, [nid '_MRI'], [nid '_MRI'], 'scans', '2_MPRAGE_ADNI_P2', 'DICOM');
    
    if ~exist(mprage_path, 'dir')
        % try alternative structure
        scans_dir = fullfile(subj_path, 'scans');
        if exist(scans_dir, 'dir')
            % look for MPRAGE folder
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
    
    % look for files starting with W*
    w_files = dir(fullfile(mprage_path, 'W*.nii'));
    
    if ~isempty(w_files)
        % use most recent if multiple
        [~, idx] = max([w_files.datenum]);
        t1_file = fullfile(mprage_path, w_files(idx).name);
        return;
    end
    
    % fallback: any .nii file
    nii_files = dir(fullfile(mprage_path, '*.nii'));
    if ~isempty(nii_files)
        [~, idx] = max([nii_files.datenum]);
        t1_file = fullfile(mprage_path, nii_files(idx).name);
    end
end

function [ok, msg] = run_dcm2niix(dicom_dir, out_dir)
    % run dcm2niix without compression
    cmd = sprintf('dcm2niix -z n -o "%s" "%s"', out_dir, dicom_dir);
    [status, output] = system(cmd);
    ok = (status == 0);
    msg = output;
end

function mean_out = average_4d_frames(out_dir, nid)
    % average all frames from 4D PET
    mean_out = '';
    
    nii_files = dir(fullfile(out_dir, '*.nii'));
    if isempty(nii_files)
        return;
    end
    
    % use largest file, probably the 4D series
    [~, idx] = max([nii_files.bytes]);
    nii_path = fullfile(out_dir, nii_files(idx).name);
    
    try
        V = spm_vol(nii_path);
        
        if numel(V) == 1
            % already a single frame
            mean_out = nii_path;
            return;
        end
        
        % read all frames and average
        fprintf('    averaging %d frames...\n', numel(V));
        Y = spm_read_vols(V);
        Ymean = mean(Y, 4);
        
        % write mean image
        Vout = V(1);
        Vout.fname = fullfile(out_dir, [nid '_mean.nii']);
        Vout.descrip = sprintf('Mean of %d frames', numel(V));
        spm_write_vol(Vout, Ymean);
        
        mean_out = Vout.fname;
        
    catch ME
        fprintf('    warning: %s\n', ME.message);
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
    
    % segment T1 to get deformation field
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {t1_file};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];
    
    % tissue classes
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
    
    % get deformation field
    [pth, name, ~] = fileparts(t1_file);
    def_field = fullfile(pth, ['y_' name '.nii']);
    
    % apply normalization to T1 and PET with custom voxel size and bbox
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
    % calculate SUVR using whole cerebellum as reference
    
    % load images
    V_pet = spm_vol(norm_pet);
    pet_img = spm_read_vols(V_pet);
    
    V_atlas = spm_vol(atlas_path);
    atlas_img = spm_read_vols(V_atlas);
    
    % resample atlas if needed
    if ~isequal(size(pet_img), size(atlas_img))
        atlas_img = imresize3(atlas_img, size(pet_img), 'nearest');
    end
    
    % extract cerebellum (whole: gray + white)
    cereb_mask = ismember(atlas_img, cereb_rois);
    cereb_vals = pet_img(cereb_mask & pet_img > 0);
    cereb_mean = mean(cereb_vals);
    
    % calculate SUVR
    suvr_img = pet_img / cereb_mean;
    suvr_img(~isfinite(suvr_img)) = 0;
    
    % save
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
    % extract SUVR for all ROIs in atlas
    
    V_suvr = spm_vol(suvr_file);
    suvr_img = spm_read_vols(V_suvr);
    
    V_atlas = spm_vol(atlas_path);
    atlas_img = spm_read_vols(V_atlas);
    
    % resample if needed
    if ~isequal(size(suvr_img), size(atlas_img))
        atlas_img = imresize3(atlas_img, size(suvr_img), 'nearest');
    end
    
    % get unique ROIs
    unique_rois = unique(atlas_img(:));
    unique_rois = unique_rois(unique_rois > 0);
    
    max_roi = max(unique_rois);
    roi_values = nan(max_roi, 1);
    roi_labels = cell(max_roi, 1);
    
    % extract mean for each ROI
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
    % save coregistration check image
    try
        % use SPM's check_reg for visual QC
        spm_check_registration(t1_file, pet_file);
        
        % save screenshot
        qc_file = fullfile(qc_dir, sprintf('%s_coreg_check.png', nid));
        saveas(gcf, qc_file);
        close(gcf);
    catch
        % silent fail
    end
end

function save_norm_qc(norm_t1, norm_pet, qc_dir, nid)
    % save normalization check image
    try
        spm_check_registration(norm_t1, norm_pet);
        
        qc_file = fullfile(qc_dir, sprintf('%s_norm_check.png', nid));
        saveas(gcf, qc_file);
        close(gcf);
    catch
        % silent fail
    end
end

function create_suvr_overlay_image(mri_file, suvr_file, qc_dir, nid, cortex_suvr, status)
    % create SUVR overlay on MRI with classification
    try
        figure('Position', [100, 100, 1200, 400]);
        
        % load images
        V_mri = spm_vol(mri_file);
        V_suvr = spm_vol(suvr_file);
        
        mri_img = spm_read_vols(V_mri);
        suvr_img = spm_read_vols(V_suvr);
        
        % get middle slices
        mid_x = round(size(mri_img, 1) / 2);
        mid_y = round(size(mri_img, 2) / 2);
        mid_z = round(size(mri_img, 3) / 2);
        
        % plot 3 views
        views = {squeeze(mri_img(mid_x, :, :))', squeeze(mri_img(:, mid_y, :))', squeeze(mri_img(:, :, mid_z))};
        suvr_views = {squeeze(suvr_img(mid_x, :, :))', squeeze(suvr_img(:, mid_y, :))', squeeze(suvr_img(:, :, mid_z))};
        titles = {'Sagittal', 'Coronal', 'Axial'};
        
        for v = 1:3
            subplot(1, 3, v);
            imagesc(views{v});
            colormap gray;
            axis image off;
            hold on;
            
            % overlay SUVR, threshold > 1.0
            suvr_overlay = suvr_views{v};
            suvr_overlay(suvr_overlay < 1.0) = NaN;
            
            h = imagesc(suvr_overlay);
            set(h, 'AlphaData', ~isnan(suvr_overlay) * 0.5);
            colormap(gca, hot);
            caxis([1.0, 2.0]);
            
            title(sprintf('%s - %s', titles{v}, status), 'FontSize', 12, 'FontWeight', 'bold');
        end
        
        % add colorbar
        c = colorbar('Position', [0.92, 0.3, 0.02, 0.4]);
        ylabel(c, 'SUVR', 'FontSize', 11);
        
        % add text annotation
        annotation('textbox', [0.35, 0.02, 0.3, 0.05], ...
                  'String', sprintf('Cortex SUVR: %.3f (%s)', cortex_suvr, status), ...
                  'FontSize', 14, 'FontWeight', 'bold', ...
                  'HorizontalAlignment', 'center', ...
                  'EdgeColor', 'none');
        
        % save
        overlay_file = fullfile(qc_dir, sprintf('%s_SUVR_overlay.png', nid));
        saveas(gcf, overlay_file);
        close(gcf);
    catch
        % silent fail
    end
end
