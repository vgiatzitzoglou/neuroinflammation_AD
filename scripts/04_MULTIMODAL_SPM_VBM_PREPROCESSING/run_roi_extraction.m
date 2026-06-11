function run_roi_extraction()
    % This script extracts the mean values from your specified atlas
    % for all subjects and all modalities. It saves the results
    % to a single CSV file, ready for statistical analysis.
    
    fprintf('--- Starting ROI Data Extraction ---\n');

    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));

    % ---!!! ATLAS FILE PATH UPDATED !!!---
    % This is the correct 2mm atlas to match your processed files.
    ATLAS_FILE = fullfile(pwd, 'atlases', 'JHU-ICBM-labels-2mm.nii.gz');
    
    % --- Define Your Subjects and Data ---
    baseDir = fullfile(pwd, 'example_data', 'organized_pet_dti');
    outputFile = fullfile(baseDir, 'roi_results.csv');
    
    subjects = pipeline.default_subjects();
    
    % Modalities to extract. NOTE: We use the SMOOTHED 's' files!
    % ---!!! BUG FIX: Removed extra 's' from file suffixes !!!---
    modalities = {
        's', 'wSUVR_PET', 'SUVR';      % Prefix, File Suffix, Output Column Name
        's', 'wdti_FA', 'FA';
        's', 'wdti_MD', 'MD'
    };

    % --- Check if Atlas file exists ---
    if ~exist(ATLAS_FILE, 'file')
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        fprintf('ERROR: Atlas file not found at:\n%s\n', ATLAS_FILE);
        fprintf('Please check the path. Note that folder names with spaces are tricky.\n');
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        return;
    end
    
    % Load the atlas
    Vatlas = spm_vol(ATLAS_FILE);
    atlas_data = spm_read_vols(Vatlas);
    
    % Get the unique region numbers (e.g., 1, 2, 3...)
    % We skip 0, which is always background
    region_labels = unique(atlas_data(atlas_data > 0));
    num_regions = length(region_labels);
    fprintf('Loaded atlas with %d regions.\n', num_regions);

    % --- Prepare the output CSV file ---
    % Create the header row
    header = {'Subject_ID', 'Group'};
    for r = 1:num_regions
        for m = 1:size(modalities, 1)
            mod_name = modalities{m, 3};
            region_num = region_labels(r);
            header{end+1} = sprintf('%s_Region_%d', mod_name, region_num);
        end
    end
    
    % Open the file for writing
    fid = fopen(outputFile, 'w');
    % Write the header
    fprintf(fid, '%s\n', strjoin(header, ','));
    
    % --- Loop through each subject and extract data ---
    fprintf('Processing %d subjects...\n', length(subjects));
    
    for i = 1:length(subjects)
        subj = subjects{i};
        subjDir = fullfile(baseDir, subj);
        fprintf('  Processing %s...\n', subj);
        
        % Determine group
        group = 'Unknown';
        if startsWith(subj, 'AD'), group = 'AD';
        elseif startsWith(subj, 'C'), group = 'HC';
        elseif startsWith(subj, 'MCI'), group = 'MCI';
        end
        
        % This cell array will hold one row of data for the CSV
        csv_row = {subj, group};
        
        % Loop through each region in the atlas
        for r = 1:num_regions
            region_num = region_labels(r);
            % Create a mask for just this one region
            region_mask = (atlas_data == region_num);
            
            % Loop through each modality (SUVR, FA, MD)
            for m = 1:size(modalities, 1)
                prefix = modalities{m, 1};
                file_suffix = modalities{m, 2};
                
                % Build the filename (e.g., sAD030_wSUVR_PET.nii.gz)
                file_pattern = [prefix, subj, '_', file_suffix, '.*']; % Use .* for .nii or .nii.gz
                
                found_file = find_file_robust(subjDir, file_pattern);
                
                mean_val = NaN; % Default to Not-a-Number
                
                if ~isempty(found_file)
                    try
                        % Load the subject's data
                        Vdata = spm_vol(found_file);
                        subj_data = spm_read_vols(Vdata);
                        
                        % Extract all values from inside this region
                        values_in_region = subj_data(region_mask);
                        
                        % Calculate the mean, ignoring NaNs and Zeros
                        mean_val = mean(values_in_region(values_in_region > 0 & ~isnan(values_in_region)), 'omitnan');
                        
                    catch e
                        fprintf('WARNING: Could not process file %s. Error: %s\n', found_file, e.message);
                    end
                else
                    fprintf('WARNING: Could not find file matching %s in %s\n', file_pattern, subjDir);
                end
                
                % Add the mean value to our row
                csv_row{end+1} = num2str(mean_val);
            end
        end
        
        % Write the complete row for this subject to the CSV
        fprintf(fid, '%s\n', strjoin(csv_row, ','));
    end
    
    fclose(fid);
    fprintf('--- Data extraction complete! ---\n');
    fprintf('Results saved to: %s\n', outputFile);

end % End of main function

% --- Helper Function ---
function file_path = find_file_robust(searchDir, file_pattern)
    % This function finds a file matching the pattern.
    file_path = '';
    
    files = dir(fullfile(searchDir, file_pattern));
    if ~isempty(files)
        file_path = fullfile(searchDir, files(1).name);
    end
end
