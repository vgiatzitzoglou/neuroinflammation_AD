function run_smoothing()
    % This script smooths the final warped (w...) files for all subjects.
    % It creates new files prefixed with 's' (e.g., swSUVR_PET.nii.gz).
    % These 's' files are what you will use for your final analysis.

    fprintf('--- Starting Smoothing Script ---\n');

    % --- Define Your Subjects and Data ---
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));
    baseDir = fullfile(pwd, 'example_data', 'organized_pet_dti');
    
    subjects = pipeline.default_subjects();

    % The 3 file types we want to smooth
    file_types = {
        'wSUVR_PET.nii.gz', ...
        'wdti_FA.nii.gz', ...
        'wdti_MD.nii.gz' ...
    };

    % Smoothing Kernel (Full-Width at Half-Maximum) in mm
    % [8 8 8] is a standard kernel for this type of analysis.
    SMOOTH_FWHM = [8 8 8];
    
    % Get the full path to SPM
    spm_path = fileparts(which('spm'));

    % Initialize SPM
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    matlabbatch = {};
    files_to_smooth = {};

    % --- Build a list of ALL files from ALL subjects ---
    for i = 1:length(subjects)
        subj = subjects{i};
        subjDir = fullfile(baseDir, subj);
        
        for j = 1:length(file_types)
            file_pattern = [subj, '_', file_types{j}];
            
            % Use the helper function to find the file
            found_file = find_file_robust(subjDir, file_pattern);
            
            if ~isempty(found_file)
                % SPM needs the file path with the frame number (e.g., ',1')
                files_to_smooth{end+1, 1} = [found_file, ',1'];
            else
                fprintf('WARNING: Could not find %s for subject %s. Skipping.\n', file_pattern, subj);
            end
        end
    end

    if isempty(files_to_smooth)
        fprintf('ERROR: No files were found to smooth. Check your paths and file names.\n');
        return;
    end

    % --- Create a single batch job to smooth all files at once ---
    matlabbatch{1}.spm.spatial.smooth.data = files_to_smooth;
    matlabbatch{1}.spm.spatial.smooth.fwhm = SMOOTH_FWHM;
    matlabbatch{1}.spm.spatial.smooth.dtype = 0; % 0 = same as input
    matlabbatch{1}.spm.spatial.smooth.im = 0; % 0 = no implicit masking
    matlabbatch{1}.spm.spatial.smooth.prefix = 's'; % Output file prefix

    % --- Run the batch ---
    fprintf('Found %d files. Starting smoothing... This may take a while.\n', length(files_to_smooth));
    try
        spm_jobman('run', matlabbatch);
        fprintf('--- smoothing done ---\n');
    catch e
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        fprintf('ERROR during smoothing:\n');
        fprintf('%s\n', e.message);
        fprintf('At line: %d in file %s\n', e.stack(1).line, e.stack(1).file);
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
    end

end % End of main function

% --- Helper Function ---
function file_path = find_file_robust(searchDir, file_pattern)
    % This function finds a file matching the pattern, handling .nii and .nii.gz
    
    file_path = '';
    
    % Check for exact match (which now includes .gz)
    search_pattern_full = fullfile(searchDir, file_pattern);
    files = dir(search_pattern_full);
    if ~isempty(files)
        file_path = fullfile(searchDir, files(1).name);
        return;
    end

    % If no .gz, check for .nii
    if endsWith(file_pattern, '.nii.gz')
        file_pattern_nii = strrep(file_pattern, '.nii.gz', '.nii');
        search_pattern_nii = fullfile(searchDir, file_pattern_nii);
        files_nii = dir(search_pattern_nii);
        if ~isempty(files_nii)
            file_path = fullfile(searchDir, files_nii(1).name);
            return;
        end
    end
end
