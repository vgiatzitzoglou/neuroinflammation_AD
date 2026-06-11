function run_vbm_smoothing()
    % This script smooths the final VBM output files (mwc1 and mwc2)
    % for all 43 subjects, preparing them for statistical analysis.
    
    fprintf('--- Starting VBM Smoothing Batch ---\n');

    % --- 1. Setup Paths and Subjects ---
    dataDir = fullfile(pwd, 'example_data', 'pbr28'); % --- CORRECTED DIRECTORY ---
    
    % This is the smoothing kernel (FWHM in mm). 8mm is standard for VBM.
    SMOOTH_FWHM = [8 8 8];
    
    % ---!! UPDATED Subject list with 'AD0XX' format !! ---
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
    
    % This cell array will hold all the files we need to smooth
    files_to_smooth = {};

    % --- 2. Find All Files to Smooth ---
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        
        subjectDir = find_subject_directory(dataDir, subjectID);
        if isempty(subjectDir)
            fprintf('WARNING: Directory not found for %s. Skipping.\n', subjectID);
            continue;
        end
        
        t1_file_path = find_t1_file(subjectDir, subjectID);
        if isempty(t1_file_path)
            fprintf('WARNING: T1 file not found for %s. Skipping.\n', subjectID);
            continue;
        end
        
        % Reconstruct the output filenames
        [~, t1_name, t1_ext] = fileparts(t1_file_path);
        
        if strcmp(t1_ext, '.gz')
            [~, t1_name, ~] = fileparts(t1_name); % Get name before .nii
        end
        
        % Find the 'mwc1' (modulated warped gray matter) file
        mwc1_file = fullfile(subjectDir, ['mwc1' t1_name '.nii']);
        % Find the 'mwc2' (modulated warped white matter) file
        mwc2_file = fullfile(subjectDir, ['mwc2' t1_name '.nii']);
        
        % Add files to our list if they exist
        if exist(mwc1_file, 'file')
            files_to_smooth{end+1, 1} = [mwc1_file, ',1'];
        else
            fprintf('WARNING: mwc1 file not found for %s (looked for %s)\n', subjectID, mwc1_file);
        end
        
        if exist(mwc2_file, 'file')
            files_to_smooth{end+1, 1} = [mwc2_file, ',1'];
        else
             fprintf('WARNING: mwc2 file not found for %s (looked for %s)\n', subjectID, mwc2_file);
        end
    end
    
    if isempty(files_to_smooth)
        fprintf('ERROR: No mwc1 or mwc2 files were found to smooth. Did segmentation run correctly?\n');
        return;
    end

    % --- 3. Define and Run the SPM Batch Job ---
    fprintf('Found %d files to smooth. Starting batch...\n', numel(files_to_smooth));
    
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.smooth.data = files_to_smooth;
    matlabbatch{1}.spm.spatial.smooth.fwhm = SMOOTH_FWHM;
    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
    matlabbatch{1}.spm.spatial.smooth.im = 0;
    matlabbatch{1}.spm.spatial.smooth.prefix = 's'; % Output: smwc1...nii
    
    try
        spm_jobman('run', matlabbatch);
        fprintf('--- VBM Smoothing Batch Finished! ---\n');
        fprintf('Your final files (smwc1... and smwc2...) are ready for statistics.\n');
    catch e
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        fprintf('ERROR during smoothing:\n');
        fprintf('Error message: %s\n', e.message);
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
    end

end % End main function

% --- Helper Function ---
function full_dir_path = find_subject_directory(baseDir, subjectID)
    full_dir_path = '';
    path1 = fullfile(baseDir, subjectID); % e.g., ./example_data/pbr28\AD014
    if exist(path1, 'dir'), full_dir_path = path1; return; end
    
    % Handle C41(MCI181) -> C41
    if strcmp(subjectID, 'C41(MCI181)'), path2 = fullfile(baseDir, 'C41');
        if exist(path2, 'dir'), full_dir_path = path2; return; end; end
    
    % Handle C004 -> C04
    if startsWith(subjectID, 'C00'), altID = strrep(subjectID, 'C00', 'C0'); 
        path3 = fullfile(baseDir, altID);
        if exist(path3, 'dir'), full_dir_path = path3; return; end; end
    
    % Handle AD014 -> AD14
    if startsWith(subjectID, 'AD0'), altID = strrep(subjectID, 'AD0', 'AD'); 
        path4 = fullfile(baseDir, altID);
        if exist(path4, 'dir'), full_dir_path = path4; return; end; end
end
% --- Helper Function ---
function full_file_path = find_t1_file(directory, subjectID)
    full_file_path = '';
    
    % Create a list of all possible subject ID names to check
    id_list = {subjectID}; % e.g., 'AD014'
    if startsWith(subjectID, 'AD0')
        id_list{end+1} = strrep(subjectID, 'AD0', 'AD'); % 'AD14'
    elseif startsWith(subjectID, 'C00')
        id_list{end+1} = strrep(subjectID, 'C00', 'C0'); % 'C04'
        id_list{end+1} = strrep(subjectID, 'C00', 'C');  % 'C4'
    elseif startsWith(subjectID, 'C0')
        id_list{end+1} = strrep(subjectID, 'C0', 'C'); % 'C18'
    end
    
    % List of possible T1 file endings
    name_patterns = {'_T1.nii*', '_MR_cc_reor.nii*'};
    
    % Loop through all combinations
    for id = id_list
        for pattern_base = name_patterns
            pattern = sprintf('%s%s', id{1}, pattern_base{1});
            files = dir(fullfile(directory, pattern));
            files = files(~[files.isdir]); 
            
            if ~isempty(files)
                full_file_path = fullfile(directory, files(1).name);
                return; 
            end
        end
    end
end