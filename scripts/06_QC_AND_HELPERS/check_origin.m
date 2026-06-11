function check_origin()
    % This script interactively checks the T1 scan for any subject
    % you choose. It opens the SPM 'Display' window and automatically
    % sets the crosshairs to the [0,0,0] origin, so you can
    % verify if it is correctly set to the Anterior Commissure (AC).

    fprintf('--- Interactive AC-PC Origin Check ---\n');

    % --- 1. Setup Paths and Find Subjects ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28');
    
    if ~exist(dataDir, 'dir')
        fprintf('ERROR: Data directory not found at: %s\n', dataDir);
        return;
    end
    
    % Get all items in the data directory
    d = dir(dataDir);
    % Filter out non-directories (like '.' and '..')
    is_dir = [d.isdir];
    dir_names = {d(is_dir).name};
    % Remove '.' and '..'
    dir_names = dir_names(~ismember(dir_names, {'.', '..'}));
    
    if isempty(dir_names)
        fprintf('ERROR: No subject folders found in %s\n', dataDir);
        return;
    end
    
    fprintf('Found %d potential subject folders.\n', numel(dir_names));
    fprintf('Available subjects:\n');
    fprintf('%s  ', dir_names{:});
    fprintf('\n----------------------------------------\n');

    % --- 2. Start Interactive Loop ---
    while true
        
        % Prompt user for a subject ID
        subjectID = input('\nEnter subject ID to check (or ''q'' to quit): ', 's');
        
        % Check if the user wants to quit
        if strcmpi(subjectID, 'q') || strcmpi(subjectID, 'exit')
            fprintf('--- Exiting check. ---\n');
            break;
        end
        
        % Check if the folder exists
        subjectDir = fullfile(dataDir, subjectID);
        if ~exist(subjectDir, 'dir')
            fprintf('ERROR: Folder not found: %s\n', subjectDir);
            continue; % Ask for input again
        end
        
        % --- 3. Find the T1 Scan ---
        t1_file = find_t1_file(subjectDir, subjectID);
        
        if isempty(t1_file)
            fprintf('WARNING: T1 scan for %s not found. Cannot check.\n', subjectID);
            continue; % Ask for input again
        end
        
        fprintf('Found T1 scan: %s\n', t1_file);
        
        % --- 4. Open Display and Set Origin ---
        fprintf('Opening SPM Display...');
        
        % Decompress if needed (spm_image can't read .gz)
        t1_file_nii = gunzip_if_needed(t1_file);
        
        try
            % --- FIX ---
            % Open the image. Newer SPM versions do not return an output.
            spm_image('init', t1_file_nii);
            
            % This is the magic command:
            % It moves the crosshairs to the [0 0 0] coordinate.
            spm_orthviews('Reposition', [0 0 0]);
            
            fprintf('\n>>> Check the SPM window. Crosshairs are now at [0,0,0].\n');
            % --- END FIX ---
            
        catch e
             fprintf('\nERROR: Could not display image %s.\n', t1_file_nii);
             fprintf('Message: %s\n', e.message);
        end
        
        % Re-compress the file if we unzipped it
        if ~strcmp(t1_file, t1_file_nii)
            gzip(t1_file_nii);
            delete(t1_file_nii);
        end
        
    end % End of while loop

end % End of main function

% --- Helper Function ---
function out_file = gunzip_if_needed(file_path)
    % Decompresses a .gz file for SPM and returns the .nii path.
    [fpath, name, ext] = fileparts(file_path);
    
    if strcmp(ext, '.gz')
        % It's gzipped, decompress it
        fprintf(' (Decompressing)...');
        gunzip(file_path);
        out_file = fullfile(fpath, name); % Return the .nii path
    else
        % It's already .nii
        out_file = file_path;
    end
end

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