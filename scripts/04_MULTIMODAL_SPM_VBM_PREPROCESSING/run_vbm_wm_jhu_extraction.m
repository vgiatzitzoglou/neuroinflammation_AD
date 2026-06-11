function run_vbm_wm_jhu_extraction()
    % This script extracts WHITE MATTER (WM) data from your FINAL SMOOTHED (smwc2) files.
    % It uses the JHU White Matter atlas.
    % *** THIS VERSION AUTOMATICALLY RESLICES THE ATLAS TO FIX MISMATCH ***
    
    fprintf('--- Starting VBM WHITE MATTER (WM) JHU ROI Extraction ---\n');

    % --- 1. Setup Paths and Subjects ---
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));
    dataDir = fullfile(pwd, 'example_data', 'pbr28'); % Corrected directory
    
    outDir = strsplit(userpath, ';');
    outputFile = fullfile(outDir{1}, 'vbm_WM_JHU_results.csv');
    fprintf('Output file will be saved to: %s\n', outputFile);
    
    atlas_file = fullfile(pwd, 'atlases', 'JHU-ICBM-labels-2mm.nii');
    
    if ~exist(atlas_file, 'file'), fprintf('ERROR: Could not find JHU atlas file at:\n%s\n', atlas_file); return; end
    
    subjects = pipeline.default_subjects();

    % --- 2. Load Atlas and Prepare CSV Header ---
    fprintf('Loading atlas: %s\n', atlas_file);
    
    [~,~,ext] = fileparts(atlas_file);
    atlas_nii_file = atlas_file;
    is_gzipped = false;
    if strcmp(ext, '.gz')
        fprintf('Decompressing atlas for reading...\n');
        gunzip(atlas_file);
        atlas_nii_file = atlas_file(1:end-3);
        is_gzipped = true;
    end
    
    Vatlas = spm_vol(atlas_nii_file);
    AtlasData = spm_read_vols(Vatlas);
    
    if is_gzipped, gzip(atlas_nii_file); delete(atlas_nii_file); end
    
    region_labels = unique(AtlasData(AtlasData > 0));
    maxRegions = length(region_labels);
    fprintf('Found %d regions in the JHU atlas.\n', maxRegions);
    
    header = {'Subject_ID', 'Group'};
    for r_idx = 1:maxRegions, r = region_labels(r_idx); header{end+1} = sprintf('WM_Region_%d', r); end
    
    fid = fopen(outputFile, 'w');
    if fid == -1, fprintf('ERROR: Could not create output file at:\n%s\n', outputFile); return; end
    
    fprintf(fid, '%s,', header{1:end-1});
    fprintf(fid, '%s\n', header{end});

    % --- 3. Loop Through Each Subject and Extract Data ---
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        fprintf('--- Processing Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
        group = '';
        if startsWith(subjectID, 'AD'), group = 'AD';
        elseif startsWith(subjectID, 'C0') || startsWith(subjectID, 'C41'), group = 'HC';
        elseif startsWith(subjectID, 'MCI'), group = 'MCI';
        end

        subjectDir = find_subject_directory(dataDir, subjectID);
        if isempty(subjectDir), fprintf('WARNING: Directory not found for %s. Skipping.\n', subjectID); continue; end
        
        t1_file_path = find_t1_file(subjectDir, subjectID);
        if isempty(t1_file_path), fprintf('WARNING: T1 file not found. Skipping.\n'); continue; end
        
        % Look for the SMOOTHED file 'smwc2'
        smwc2_file = find_processed_file(subjectDir, subjectID, t1_file_path, 'smwc2');

        if isempty(smwc2_file)
            fprintf('WARNING: smwc2 file not found for %s. Skipping.\n', subjectID);
            continue;
        end
        
        Vwm = spm_vol(smwc2_file);
        WM_Data = spm_read_vols(Vwm);
        
        % ---!! FIX: RESLICE ATLAS TO MATCH IMAGE DIMENSIONS !! ---
        currentAtlasData = AtlasData;
        if ~isequal(Vwm.dim, Vatlas.dim)
            fprintf('INFO: Image/Atlas dimension mismatch for %s. Reslicing atlas...\n', subjectID);
            
            % Define reslice options
            flags = struct('interp', 0, ... % 0 = Nearest Neighbour (good for labels)
                           'mask', false, ...
                           'mean', false, ...
                           'which', 1, ... % Reslice 2nd image (atlas)
                           'wrap', [0 0 0]);
            
            % Must use char() for spm_reslice
            spm_reslice({char(Vwm.fname), char(Vatlas.fname)}, flags);
            
            [p, n, e] = fileparts(Vatlas.fname);
            % ---!! FIX: Added space between 'r' and n !! ---
            resliced_atlas_file = fullfile(p, ['r' n e]);
            
            if ~exist(resliced_atlas_file, 'file'), fprintf('FATAL ERROR: Resliced atlas file not created. Skipping.\n'); continue; end
            Vatlas_resliced = spm_vol(resliced_atlas_file);
            currentAtlasData = spm_read_vols(Vatlas_resliced);
            delete(resliced_atlas_file);
            if ~isequal(Vwm.dim, Vatlas_resliced.dim), fprintf('FATAL ERROR: Reslicing failed for %s. Skipping.\n', subjectID); continue; end
        end
        % ---!! END FIX !! ---
        
        dataRow = {subjectID, group};
        for r_idx = 1:maxRegions
            r = region_labels(r_idx);
            region_voxels = find(abs(currentAtlasData - r) < 1e-5);
            meanWM = 0;
            if ~isempty(region_voxels), meanWM = mean(WM_Data(region_voxels), 'omitnan'); end
            dataRow{end+1} = meanWM;
        end
        
        fprintf(fid, '%s,%s,', dataRow{1}, dataRow{2});
        formatSpec = '%.10f,';
        for k = 3:numel(dataRow)-1, fprintf(fid, formatSpec, dataRow{k}); end
        fprintf(fid, '%.10f\n', dataRow{end});
        
    end % End subject loop

    fclose(fid);
    fprintf('\n--- VBM WM (JHU) Extraction Finished! ---\n');
    fprintf('Your final data file is ready at:\n%s\n', outputFile);

end % End main function

% --- Helper Functions ---
function full_dir_path = find_subject_directory(baseDir, subjectID)
    full_dir_path = '';
    path1 = fullfile(baseDir, subjectID);
    if exist(path1, 'dir'), full_dir_path = path1; return; end
    if strcmp(subjectID, 'C41(MCI181)'), path2 = fullfile(baseDir, 'C41');
        if exist(path2, 'dir'), full_dir_path = path2; return; end; end
    if startsWith(subjectID, 'C00'), altID = strrep(subjectID, 'C00', 'C0'); 
        path3 = fullfile(baseDir, altID);
        if exist(path3, 'dir'), full_dir_path = path3; return; end; end
    if startsWith(subjectID, 'AD0'), altID = strrep(subjectID, 'AD0', 'AD'); 
        path4 = fullfile(baseDir, altID);
        if exist(path4, 'dir'), full_dir_path = path4; return; end; end
end

function full_file_path = find_t1_file(directory, subjectID)
    full_file_path = ''; id_list = {};
    if startsWith(subjectID, 'AD0'), id_list = {subjectID, strrep(subjectID, 'AD0', 'AD')};
    elseif startsWith(subjectID, 'C00'), id_list = {subjectID, strrep(subjectID, 'C00', 'C0'), strrep(subjectID, 'C00', 'C')};
    elseif startsWith(subjectID, 'C0'), id_list = {subjectID, strrep(subjectID, 'C0', 'C')};
    else, id_list = {subjectID}; end
    name_patterns = {'_T1.nii*', '_MR_cc_reor.nii*'};
    for id = id_list, for pattern_base = name_patterns
        pattern = sprintf('%s%s', id{1}, pattern_base{1});
        files = dir(fullfile(directory, pattern)); files = files(~[files.isdir]);
        if ~isempty(files), full_file_path = fullfile(directory, files(1).name); return; end
    end, end
end

function full_file_path = find_processed_file(directory, subjectID, t1_path, prefix)
    % prefix is 'smwc1' or 'smwc2'
    full_file_path = '';
    
    [~, t1_name, t1_ext] = fileparts(t1_path);
    if strcmp(t1_ext, '.gz'), [~, t1_name, ~] = fileparts(t1_name); end
    
    possible_names = {};
    possible_names{end+1} = [prefix t1_name '.nii*'];
    possible_names{end+1} = [prefix subjectID '.nii*'];
    
    alt_subjectID = '';
    if startsWith(subjectID, 'AD0'), alt_subjectID = strrep(subjectID, 'AD0', 'AD');
    elseif startsWith(subjectID, 'C00'), alt_subjectID = strrep(subjectID, 'C00', 'C0');
    elseif startsWith(subjectID, 'C0'), alt_subjectID = strrep(subjectID, 'C0', 'C');
    end

    if ~isempty(alt_subjectID)
        possible_names{end+1} = [prefix alt_subjectID '.nii*'];
    end
    
    for pattern = possible_names
        files = dir(fullfile(directory, pattern{1}));
        files = files(~[files.isdir]);
        if ~isempty(files)
            full_file_path = fullfile(directory, files(1).name);
            return;
        end
    end
end
