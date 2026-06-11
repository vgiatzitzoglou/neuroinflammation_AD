function run_vbm_segmentation()
    % This script runs the SPM12 "Segment" batch job (for VBM) on all subjects.
    % It finds the T1 scan for each subject and runs the segmentation.
    % This will create the native tissue maps (c1, c2), the deformation
    % fields (y_), and the final modulated, normalized 'mwc1' (Gray Matter)
    % and 'mwc2' (White Matter) files needed for statistical analysis.

    fprintf('--- Starting VBM Segmentation Batch ---\n');

    % --- 1. Setup Paths and Subjects ---

    % --- UPDATED: Set the main data directory to PBR29 ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');

    % Get the SPM12 toolbox path
    spm_path = spm('Dir');
    
    % Get the path to the SPM tissue probability maps (TPM)
    tpm_path = fullfile(spm_path, 'tpm', 'TPM.nii');
    if ~exist(tpm_path, 'file')
        fprintf('ERROR: Could not find SPM''s TPM.nii file at:\n%s\n', tpm_path);
        fprintf('Please ensure SPM12 is installed and in your MATLAB path.\n');
        return;
    end
    
    % Define the *exact* list of subjects to process
    % This list is formatted with '...' to prevent the 'vertcat' error.
    subjects = { ...
        'AD014', 'AD018', 'AD023', 'AD024', 'AD027', 'AD029', 'AD030', 'AD035', 'AD036', 'AD042', ...
        'C004', 'C008', 'C011', 'C012', 'C013', 'C018', 'C023', 'C029', 'C030', 'C035', ...
        'C036', 'C037', 'C041', ...
        'C41(MCI181)', ...
        'MCI013', 'MCI024', 'MCI032', 'MCI037', 'MCI039', 'MCI040', 'MCI045', 'MCI051', ...
        'MCI057', 'MCI059', 'MCI084', 'MCI095', 'MCI100', 'MCI104', 'MCI106', 'MCI141', ...
        'MCI153', 'MCI156', 'MCI163' ...
    };

    fprintf('Found %d subjects to process...\n', numel(subjects));

    % --- 2. Initialize SPM Job Manager ---
    spm('defaults', 'PET'); % Use PET/fMRI defaults
    spm_jobman('initcfg'); % Initialize the job manager
    
    % --- 3. Loop Through Each Subject ---
    for i = 1:numel(subjects)
        
        subjectID = subjects{i};
        fprintf('\n--- Processing Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
        % Set the subject's directory path
        subjectDir = fullfile(dataDir, subjectID);
        
        % Special check for C41(MCI181) which might be in folder C41
        if ~exist(subjectDir, 'dir')
             if strcmp(subjectID, 'C41(MCI181)')
                 subjectDir = fullfile(dataDir, 'C41');
                 if ~exist(subjectDir, 'dir')
                     fprintf('WARNING: Directory not found for %s at %s. Skipping.\n', subjectID, subjectDir);
                     continue;
                 end
             else
                fprintf('WARNING: Directory not found for %s at %s. Skipping.\n', subjectID, subjectDir);
                continue;
             end
        end
        
        % --- 4. Find the T1 Scan ---
        % Use the helper function to find the T1 file, handling
        % naming inconsistencies (e.g., AD14 vs C004)
        t1_file = find_t1_file(subjectDir, subjectID);
        
        if isempty(t1_file)
            fprintf('WARNING: T1 scan for %s not found in %s. Skipping.\n', subjectID, subjectDir);
            continue;
        end

        % SPM needs a cell array of strings, with the ',1' for dynamic scans
        t1_file_with_index = {[t1_file, ',1']};
        
        fprintf('Found T1 scan: %s\n', t1_file);

        % --- 5. Define the SPM Batch Job ---
        % Clear the batch for this new subject
        matlabbatch = {};
        
        matlabbatch{1}.spm.spatial.preproc.channel.vols = t1_file_with_index;
        matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
        matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
        matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0]; % Don't save bias corrected
        
        % Tissue 1 (GM)
        matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {[tpm_path, ',1']};
        matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
        matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0]; % Save c1 (native)
        matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 1]; % Save mwc1 (modulated, warped)
        
        % Tissue 2 (WM)
        matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {[tpm_path, ',2']};
        matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
        matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0]; % Save c2 (native)
        matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 1]; % Save mwc2 (modulated, warped)
        
        % Tissue 3 (CSF)
        matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {[tpm_path, ',3']};
        matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
        matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0]; % Save c3 (native)
        matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0]; % Don't save warped CSF
        
        % Tissue 4 (Bone)
        matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[tpm_path, ',4']};
        matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
        matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
        
        % Tissue 5 (Soft Tissue)
        matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[tpm_path, ',5']};
        matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
        matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
        
        % Tissue 6 (Outside)
        matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[tpm_path, ',6']};
        matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
        matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
        
        % Warping options (New Segment)
        matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
        matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
        matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
        matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
        matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
        matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
        matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1]; % Save Forward (y_) & Inverse (iy_) deformations

        % --- 6. Run the Job ---
        try
            spm_jobman('run', matlabbatch);
            fprintf('--- Successfully segmented Subject: %s ---\n', subjectID);
        catch e
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
            fprintf('ERROR processing Subject: %s\n', subjectID);
            fprintf('Error message: %s\n', e.message);
            fprintf('At line: %d in file %s\n', e.stack(1).line, e.stack(1).file);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        end
        
    end
    
    fprintf('\n--- VBM Segmentation Batch Finished! ---\n');

end % End of main function

% --- Helper Function ---
function full_file_path = find_t1_file(directory, subjectID)
    % This helper function finds the T1 file, handling naming
    % inconsistencies like AD14 vs C004.
    
    full_file_path = ''; % Initialize as empty
    
    % 1. Try the subject ID as-is (e.g., AD14, C004, MCI013)
    pattern1 = sprintf('%s_T1.nii*', subjectID);
    files1 = dir(fullfile(directory, pattern1));
    files1 = files1(~[files1.isdir]); % Remove directories
    
    if ~isempty(files1)
        full_file_path = fullfile(directory, files1(1).name);
        return;
    end

    % 2. If not found, try stripping the leading zero
    % (e.g., C004 -> C4)
    alt_id = '';
    if startsWith(subjectID, 'C0')
        alt_id = strrep(subjectID, 'C0', 'C'); % C004 -> C4
    else
        % No other patterns to try
        return;
    end

    pattern2 = sprintf('%s_T1.nii*', alt_id);
    files2 = dir(fullfile(directory, pattern2));
    files2 = files2(~[files2.isdir]); % Remove directories
    
    if ~isempty(files2)
        full_file_path = fullfile(directory, files2(1).name);
        return;
    end
end