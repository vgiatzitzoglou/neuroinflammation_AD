function run_dti_processing_v2()
    % This script processes your DTI (FA and MD) files to bring them
    % into the same final MNI space as your VBM and PET SUVR maps.
    % It runs: 1) Coregister, 2) Normalize, 3) Smooth.
    %
    % v2 Fix: Runs each step sequentially to avoid dependency errors.

    fprintf('--- Starting DTI Processing Batch (v2) ---\n');

    % --- 1. Setup Paths and Subjects ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');
    SMOOTH_FWHM = [8 8 8]; % Same as your PET and VBM
    
    subjects = { ...
        'AD014', 'AD018', 'AD023', 'AD024', 'AD027', 'AD029', 'AD030', 'AD035', 'AD036', 'AD042', ...
        'C004', 'C008', 'C011', 'C012', 'C013', 'C018', 'C023', 'C029', 'C030', 'C035', ...
        'C036', 'C037', 'C041', 'C41(MCI181)', ...
        'MCI013', 'MCI024', 'MCI032', 'MCI037', 'MCI039', 'MCI040', 'MCI045', 'MCI051', ...
        'MCI057', 'MCI059', 'MCI084', 'MCI095', 'MCI100', 'MCI104', 'MCI106', 'MCI141', ...
        'MCI153', 'MCI156', 'MCI163' ...
    };

    fprintf('Found %d subjects to process...\n', numel(subjects));
    
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    % --- 2. Loop Through Each Subject ---
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        fprintf('\n--- Processing Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
        subjectDir = find_subject_directory(dataDir, subjectID);
        if isempty(subjectDir), fprintf('WARNING: Directory not found. Skipping.\n'); continue; end
        
        % --- 3. Find All Necessary Files ---
        t1_file = find_t1_file(subjectDir, subjectID);
        if isempty(t1_file), fprintf('WARNING: T1 scan not found. Skipping.\n'); continue; end
        
        fa_file = find_dti_file(subjectDir, subjectID, 'FA');
        if isempty(fa_file), fprintf('WARNING: DTI FA file not found. Skipping.\n'); continue; end
        
        md_file = find_dti_file(subjectDir, subjectID, 'MD');
        if isempty(md_file), fprintf('WARNING: DTI MD file not found. Skipping.\n'); continue; end
        
        [~, t1_name, t1_ext] = fileparts(t1_file);
        if strcmp(t1_ext, '.gz'), [~, t1_name, ~] = fileparts(t1_name); end
        
        y_file = fullfile(subjectDir, ['y_' t1_name '.nii']);
        if ~exist(y_file, 'file')
            fprintf('WARNING: VBM output (y_ file) not found for %s. Did segmentation run? Skipping.\n', subjectID);
            continue;
        end
        
        % --- 4. Define Intermediate Filenames ---
        [~, fa_name, fa_ext] = fileparts(fa_file);
        if strcmp(fa_ext, '.gz'), [~, fa_name, ~] = fileparts(fa_name); end
        resliced_fa_file = fullfile(subjectDir, ['r' fa_name '.nii']);
        warped_fa_file = fullfile(subjectDir, ['wr' fa_name '.nii']);
        final_fa_file = fullfile(subjectDir, ['swr' fa_name '.nii']);

        [~, md_name, md_ext] = fileparts(md_file);
        if strcmp(md_ext, '.gz'), [~, md_name, ~] = fileparts(md_name); end
        resliced_md_file = fullfile(subjectDir, ['r' md_name '.nii']);
        warped_md_file = fullfile(subjectDir, ['wr' md_name '.nii']);
        final_md_file = fullfile(subjectDir, ['swr' md_name '.nii']);

        % --- 5. Run Pipeline Step-by-Step ---
        try
            % Step 1: Coregister DTI to T1 (Estimate & Reslice)
            fprintf('Step 1: Coregistering FA/MD maps to T1...\n');
            matlabbatch = {};
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {[t1_file, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = {[fa_file, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.other = {[md_file, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
            spm_jobman('run', matlabbatch);
            
            if ~exist(resliced_fa_file, 'file') || ~exist(resliced_md_file, 'file'), error('Coregistered DTI files not created.'); end

            % Step 2: Normalize DTI maps to MNI Space (using Forward Warp)
            fprintf('Step 2: Normalizing FA/MD maps to MNI space...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {y_file};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {
                                                                       resliced_fa_file
                                                                       resliced_md_file
                                                                       };
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2]; % 2mm voxel size (to match PET)
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
            spm_jobman('run', matlabbatch);
            
            if ~exist(warped_fa_file, 'file') || ~exist(warped_md_file, 'file'), error('Warped DTI files not created.'); end
            
            % Step 3: Smooth the final, warped DTI maps
            fprintf('Step 3: Smoothing final DTI maps...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.smooth.data = {
                                                     warped_fa_file
                                                     warped_md_file
                                                     };
            matlabbatch{1}.spm.spatial.smooth.fwhm = SMOOTH_FWHM;
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 0;
            matlabbatch{1}.spm.spatial.smooth.prefix = 's';
            spm_jobman('run', matlabbatch);
            
            if ~exist(final_fa_file, 'file') || ~exist(final_md_file, 'file'), error('Smoothed DTI files not created.'); end

            fprintf('--- Successfully processed DTI for Subject: %s ---\n', subjectID);
            
            % --- 6. Cleanup Intermediate Files ---
            fprintf('Cleaning up intermediate files...\n');
            delete(resliced_fa_file);
            delete(resliced_md_file);
            delete(warped_fa_file);
            delete(warped_md_file);

        catch e
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
            fprintf('ERROR processing DTI for Subject: %s\n', subjectID);
            fprintf('Error message: %s\n', e.message);
            fprintf('At line: %d in file %s\n', e.stack(1).line, e.stack(1).name);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        end
        
    end
    
    fprintf('\n--- DTI Processing Batch Finished! ---\n');

end % End of main function

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
        if ~isempty(files) && exist(fullfile(directory, files(1).name), 'file')
            full_file_path = fullfile(directory, files(1).name); return; 
        end
    end, end
end

function full_file_path = find_dti_file(directory, subjectID, type) % type is 'FA' or 'MD'
    full_file_path = ''; id_list = {};
    if startsWith(subjectID, 'AD0'), id_list = {subjectID, strrep(subjectID, 'AD0', 'AD')};
    elseif startsWith(subjectID, 'C00'), id_list = {subjectID, strrep(subjectID, 'C00', 'C0'), strrep(subjectID, 'C00', 'C')};
    elseif startsWith(subjectID, 'C0'), id_list = {subjectID, strrep(subjectID, 'C0', 'C')};
    else, id_list = {subjectID}; end
    
    name_patterns = {['_dti_' type '.nii*'], ['_DTI_' type '.nii*']};
    
    for id = id_list
        for pattern_base = name_patterns
            pattern = sprintf('%s%s', id{1}, pattern_base{1});
            files = dir(fullfile(directory, pattern)); files = files(~[files.isdir]);
            if ~isempty(files) && exist(fullfile(directory, files(1).name), 'file')
                full_file_path = fullfile(directory, files(1).name); return;
            end
        end
    end
end