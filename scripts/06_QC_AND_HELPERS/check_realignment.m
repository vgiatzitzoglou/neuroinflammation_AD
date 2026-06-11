function check_realignment()
    % This script loops through all 43 subjects and opens the SPM
    % "Check Reg" tool to let you visually compare each subject's T1
    % scan against the MNI template one by one.

    fprintf('--- Starting AC-PC Realignment Check ---\n');

    % --- 1. Setup Paths and Subjects ---
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));
    
    % --- USE WINDOWS PATH ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');

    % Get the SPM12 toolbox path
    spm_path = spm('Dir');
    
    % Get the path to the SPM MNI template file
     template_file = fullfile(spm_path, 'tpm', 'TPM.nii');
    if ~exist(template_file, 'file')
        fprintf('ERROR: Could not find SPM''s template file at:\n%s\n', template_file);
        fprintf('Your SPM installation may be incomplete. Trying canonical/T1.nii...\n');
        return;
    end
    fprintf('Found MNI Template: %s\n', template_file);
    
    subjects = pipeline.default_subjects();

    fprintf('Found %d subjects to check...\n', numel(subjects));
    
    % --- 2. Loop Through Each Subject ---
    for i = 1:numel(subjects)
        
        subjectID = subjects{i};
        fprintf('\n--- Now checking Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
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
        
        % --- 3. Find the T1 Scan ---
        t1_file = find_t1_file(subjectDir, subjectID);
        
        if isempty(t1_file)
            fprintf('WARNING: T1 scan for %s not found. Skipping.\n', subjectID);
            continue;
        end
        
        % --- 4. Call spm_check_registration ---
        % Create a cell array with the MNI template first,
        % then the subject's T1.
        files_to_check = {
            template_file;
            t1_file
        };
        
        % Open the Check Reg window
        % ---!! FIX: Unpack the cell array with {:} !!---
        spm_check_registration(files_to_check{:});
        
        % --- 5. Pause and Wait for User ---
        fprintf('>>> Check the SPM window for alignment.\n');
        fprintf('>>> When finished, return to MATLAB and press any key to check the next subject...\n');
        pause;
        
        % Close the SPM graphics window
        close(gcf); 
        
    end
    
    fprintf('\n--- Realignment Check Finished! ---\n');

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
