%-----------------------------------------------------------------------
% MATLAB Script to Clean Processed Files
%
% This script loops through your 'organized_pet_dti' folder and
% deletes all intermediate and output files from the processing batch,
% resetting your folders to a clean state.
%
% It KEEPS your original T1, PET, dti_FA, and dti_MD files.
%-----------------------------------------------------------------------

function cleanup()

    % --- CONFIGURATION ---
    baseDir = pwd;
    dataDir = fullfile(baseDir, 'organized_pet_dti');
    
    if ~exist(dataDir, 'dir')
        error('Could not find data directory: %s\nPlease run this script from the folder *containing* organized_pet_dti.', dataDir);
    end

    % --- List of all subjects to process ---
    subjects = { ...
        "AD014", "AD018", "AD023", "AD024", "AD027", "AD029", "AD030", ...
        "AD035", "AD036", "AD042", "C004", "C008", "C011", "C012", ...
        "C013", "C018", "C023", "C029", "C030", "C035", "C036", "C037", ...
        "C041", "C41(MCI181)", "MCI013", "MCI024", "MCI032", "MCI037", ...
        "MCI039", "MCI040", "MCI045", "MCI051", "MCI057", "MCI059", ...
        "MCI084", "MCI095", "MCI100", "MCI104", "MCI106", "MCI141", ...
        "MCI153", "MCI156", "MCI163" ...
    };

    fprintf('--- Starting cleanup for %d subjects ---\n', length(subjects));

    % --- LOOP AND DELETE ---
    for i = 1:length(subjects)
        subjectID = subjects{i};
        subjectDir = fullfile(dataDir, subjectID);
        
        if ~exist(subjectDir, 'dir')
            fprintf('Skipping %s, directory not found.\n', subjectID);
            continue;
        end
        
        fprintf('Cleaning %s...\n', subjectID);
        
        % Delete warped files
        delete(fullfile(subjectDir, '*wPET.nii*'));
        delete(fullfile(subjectDir, '*wdti_FA.nii*'));
        delete(fullfile(subjectDir, '*wdti_MD.nii*'));
        delete(fullfile(subjectDir, '*wSUVR_*.nii*'));
        
        % Delete segmentation files
        delete(fullfile(subjectDir, '*c1T1.nii*'));
        delete(fullfile(subjectDir, '*c2T1.nii*'));
        delete(fullfile(subjectDir, '*c3T1.nii*'));
        delete(fullfile(subjectDir, '*mT1.nii*'));
        delete(fullfile(subjectDir, '*y_T1.nii*'));
        delete(fullfile(subjectDir, '*T1_seg8.mat'));
        delete(fullfile(subjectDir, '*seg8.mat'));

    end
    
    % Delete the shared cerebellum mask
    delete(fullfile(dataDir, 'mni_cerebellum_mask.nii*'));
    
    fprintf('\n--- CLEANUP COMPLETE ---\n');
    fprintf('You are now ready to run the main processing batch.\n');

end
