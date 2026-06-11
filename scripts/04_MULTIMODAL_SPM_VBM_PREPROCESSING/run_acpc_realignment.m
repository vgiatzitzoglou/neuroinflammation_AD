function run_acpc_realignment()
    % This script automatically "reorients" all subject T1 scans by
    % co-registering them to the standard SPM MNI template.
    % This is a crucial step to ensure the [0,0,0] origin is set
    % (approximately) to the Anterior Commissure before segmentation.

    fprintf('--- Starting Automatic AC-PC Realignment ---\n');

    % --- 1. Setup Paths and Subjects ---
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));

    % --- FIX: Changed dataDir to Windows-style path ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');

    % Get the SPM12 toolbox path
    spm_path = spm('Dir');
    
    % --- FIX: Point to the template in the 'tpm' folder ---
    % This is more robust than the 'canonical' folder
    template_file = fullfile(spm_path, 'tpm', 'TPM.nii');
    if ~exist(template_file, 'file')
        fprintf('ERROR: Could not find SPM''s template file at:\n%s\n', template_file);
        fprintf('Your SPM installation may be incomplete. Trying canonical/T1.nii...\n');
        
        % Fallback to canonical T1
        template_file = fullfile(spm_path, 'canonical', 'T1.nii');
        if ~exist(template_file, 'file')
             fprintf('ERROR: Could not find T1.nii in canonical folder either.\n');
             fprintf('Please check your SPM installation.\n');
             return;
        end
    end
    fprintf('Found MNI Template: %s\n', template_file);

    subjects = pipeline.default_subjects();

    fprintf('Found %d subjects to process...\n', numel(subjects));

    % --- 2. Initialize SPM Job Manager ---
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    % --- 3. Loop Through Each Subject ---
    for i = 1:numel(subjects)
        
        subjectID = subjects{i};
        fprintf('\n--- Realigning Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
        subjectDir = fullfile(dataDir, subjectID);
        
        % Special check for C41(MCI181)
        if ~exist(subjectDir, 'dir')
             if strcmp(subjectID, 'C41(MCI181)')
                 subjectDir = fullfile(dataDir, 'C41');
                 if ~exist(subjectDir, 'dir')
                     fprintf('WARNING: Directory not found for %s. Skipping.\n', subjectID);
                     continue;
                 end
             else
                fprintf('WARNING: Directory not found for %s. Skipping.\n', subjectID);
                continue;
             end
        end
        
        % --- 4. Find the T1 Scan ---
        t1_file = find_t1_file(subjectDir, subjectID);
        
        if isempty(t1_file)
            fprintf('WARNING: T1 scan for %s not found. Skipping.\n', subjectID);
            continue;
        end
        
        fprintf('Found T1 scan: %s\n', t1_file);

        % --- 5. Define the SPM Co-register Job ---
        % This will align the "Source" (subject T1) to the "Reference" (MNI T1)
        % and save the new orientation information to the *header* of the
        % source file. It does NOT create a new image.
        matlabbatch = {};
        matlabbatch{1}.spm.spatial.coreg.estimate.ref = {[template_file, ',1']};
        matlabbatch{1}.spm.spatial.coreg.estimate.source = {[t1_file, ',1']};
        matlabbatch{1}.spm.spatial.coreg.estimate.other = {''};
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

        % --- 6. Run the Job ---
        try
            spm_jobman('run', matlabbatch);
            fprintf('--- Successfully realigned Subject: %s ---\n', subjectID);
        catch e
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
            fprintf('ERROR processing Subject: %s\n', subjectID);
            fprintf('Error message: %s\n', e.message);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        end
        
        clear matlabbatch;
    end
    
    fprintf('\n--- Automatic Realignment Finished! ---\n');
    fprintf('You can now safely run the "run_vbm_segmentation.m" script.\n');

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
