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
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));

    baseDir = pwd;
    dataDir = fullfile(baseDir, 'organized_pet_dti');
    
    if ~exist(dataDir, 'dir')
        error('Could not find data directory: %s\nPlease run this script from the folder *containing* organized_pet_dti.', dataDir);
    end

    subjects = pipeline.default_subjects();

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
    
    fprintf('\n--- cleanup done ---\n');
    fprintf('You are now ready to run the main processing batch.\n');

end
