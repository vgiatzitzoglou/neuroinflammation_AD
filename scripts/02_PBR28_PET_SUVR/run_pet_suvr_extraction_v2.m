function run_pet_suvr_extraction_v2()
    % This script extracts SUVR data from your final processed PET files
    % (swnative_SUVR_PET_2.nii.gz) using the JHU White Matter atlas.
    % ---!! THIS VERSION FIXES THE DIMENSION MISMATCH ERROR !! ---
    
    fprintf('--- Starting PET SUVR (JHU) ROI Extraction (v2) ---\n');

    % --- 1. Setup Paths and Subjects ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');
    
    outDir = strsplit(userpath, ';');
    outputFile = fullfile(outDir{1}, 'pet_suvr_JHU_results_2.csv');
    fprintf('Output file will be saved to: %s\n', outputFile);
    
    atlas_file = fullfile(pwd, 'atlases', 'JHU-ICBM-labels-2mm.nii');
    
    if ~exist(atlas_file, 'file'), fprintf('ERROR: Could not find JHU atlas file at:\n%s\n', atlas_file); return; end
    
    subjects = { ...
        'AD014', 'AD018', 'AD023', 'AD024', 'AD027', 'AD029', 'AD030', 'AD035', 'AD036', 'AD042', ...
        'C004', 'C008', 'C011', 'C012', 'C013', 'C018', 'C023', 'C029', 'C030', 'C035', ...
        'C036', 'C037', 'C041', 'C41(MCI181)', ...
        'MCI013', 'MCI024', 'MCI032', 'MCI037', 'MCI039', 'MCI040', 'MCI045', 'MCI051', ...
        'MCI057', 'MCI059', 'MCI084', 'MCI095', 'MCI100', 'MCI104', 'MCI106', 'MCI141', ...
        'MCI153', 'MCI156', 'MCI163' ...
    };

    % --- 2. Load Atlas and Prepare CSV Header ---
    fprintf('Loading atlas: %s\n', atlas_file);
    
    % Decompress atlas if needed
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
    for r_idx = 1:maxRegions, r = region_labels(r_idx); header{end+1} = sprintf('SUVR_Region_%d', r); end
    
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
        
        % This is the final file from the v3 processing script
        suvr_file_gz = fullfile(subjectDir, 'swnative_SUVR_PET_2.nii.gz');
        suvr_file_nii = fullfile(subjectDir, 'swnative_SUVR_PET_2.nii');
        
        suvr_file = '';
        if exist(suvr_file_gz, 'file')
            suvr_file = suvr_file_gz;
        elseif exist(suvr_file_nii, 'file')
            suvr_file = suvr_file_nii;
        else
            fprintf('WARNING: Final SUVR file (swnative_SUVR_PET_2.nii) not found for %s. Skipping.\n', subjectID);
            continue;
        end
        
        Vsuvr = spm_vol(suvr_file);
        SUVR_Data = spm_read_vols(Vsuvr);
        
        % ---!! FIX: RESLICE ATLAS TO MATCH IMAGE DIMENSIONS !! ---
        currentAtlasData = AtlasData;
        if ~isequal(Vsuvr.dim, Vatlas.dim)
            fprintf('INFO: Image/Atlas dimension mismatch for %s. Reslicing atlas...\n', subjectID);
            fprintf('  Image: [%d %d %d], Atlas: [%d %d %d]\n', Vsuvr.dim, Vatlas.dim);
            
            % Define reslice options
            flags = struct('interp', 0, ... % 0 = Nearest Neighbour (good for labels)
                           'mask', false, ...
                           'mean', false, ...
                           'which', 1, ... % Reslice 2nd image (atlas)
                           'wrap', [0 0 0]);
            
            % Reslice the atlas to the image
            % Must use char() for spm_reslice
            spm_reslice({char(Vsuvr.fname), char(Vatlas.fname)}, flags);
            
            % Get the name of the new resliced file (prefixed with 'r')
            [p, n, e] = fileparts(Vatlas.fname);
            resliced_atlas_file = fullfile(p, ['r' n e]); % <-- Fixed 'r'n e typo
            
            if ~exist(resliced_atlas_file, 'file')
                fprintf('FATAL ERROR: Resliced atlas file not created. Skipping.\n');
                continue;
            end

            Vatlas_resliced = spm_vol(resliced_atlas_file);
            currentAtlasData = spm_read_vols(Vatlas_resliced);
            
            % Delete the temporary resliced atlas
            delete(resliced_atlas_file);
            
            % Final check
            if ~isequal(Vsuvr.dim, Vatlas_resliced.dim)
                 fprintf('FATAL ERROR: Reslicing failed for %s. Skipping.\n', subjectID);
                 continue;
            end
        end
        % ---!! END FIX !! ---
        
        dataRow = {subjectID, group};
        for r_idx = 1:maxRegions
            r = region_labels(r_idx);
            region_voxels = find(abs(currentAtlasData - r) < 1e-5); % Find voxels for this region
            meanSUVR = 0;
            if ~isempty(region_voxels), meanSUVR = mean(SUVR_Data(region_voxels), 'omitnan'); end
            dataRow{end+1} = meanSUVR;
        end
        
        fprintf(fid, '%s,%s,', dataRow{1}, dataRow{2});
        formatSpec = '%.10f,';
        for k = 3:numel(dataRow)-1, fprintf(fid, formatSpec, dataRow{k}); end
        fprintf(fid, '%.10f\n', dataRow{end});
        
    end % End subject loop

    fclose(fid);
    fprintf('\n--- PET SUVR (JHU) Extraction Finished! ---\n');
    fprintf('Your final data file is ready for Excel/SPSS at:\n%s\n', outputFile);

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