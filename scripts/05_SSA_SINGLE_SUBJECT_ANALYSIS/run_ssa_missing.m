% run_ssa_missing.m
% Builds the subject list for all folders under ./example_data/pet_subjects that are missing SSA outputs

clear; clc;

% --- CONFIGURATION ---
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);  % Ensure ssa_batch.m is visible

base_dir = fullfile(pwd, 'example_data', 'pet_subjects');
out_root = fullfile(pwd, 'outputs', 'ssa');
mask_file = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');

% Check if mask exists
if ~exist(mask_file, 'file')
    warning('Mask file not found: %s\nWill proceed without mask.', mask_file);
    mask_file = '';
end

% Detection patterns
pet_candidates = @(id, subj_dir) fullfile(subj_dir, { ...
    ['Nor_Cor_' id '_Realign_PBR28_6090_add.nii.gz'], ...
    ['Nor_Cor_' id '_Realign_PBR28_6090_add.nii'], ...
    ['Nor_Cor_' id '.nii'], ...
    [id '_Realign_PBR28_all_add.nii.gz'], ...
    [id '_Realign_PBR28_all_add.nii']});

subjects = {};
groups = dir(base_dir);

fprintf('Scanning %s for subjects missing SSA...\n', base_dir);

for g = 1:numel(groups)
    grp = groups(g);
    if ~grp.isdir || any(strcmp(grp.name, {'.','..','Normalized_PET','SSA_Render_Images','weird'}))
        continue;
    end
    
    grp_name = grp.name;
    gdir = fullfile(base_dir, grp_name);
    subs = dir(gdir);
    
    for s = 1:numel(subs)
        subj = subs(s);
        if ~subj.isdir || any(strcmp(subj.name, {'.','..','Normalized_PET','SSA_Render_Images','weird'}))
            continue;
        end
        
        base_id = subj.name;
        
        % Skip if this is the "Contrast" folder itself
        if endsWith(base_id, 'Contrast')
            continue; 
        end
        
        % Define Main Directory and Contrast Directory
        subj_main = fullfile(gdir, base_id);
        contrast_dir = fullfile(gdir, [base_id 'Contrast']);
        
        % Check if Contrast folder exists
        if ~exist(contrast_dir, 'dir')
            continue;
        end

        % Check if SSA output already exists
        if has_ssa(subj_main, contrast_dir)
            continue; 
        end
        
        spm_mat = fullfile(contrast_dir, 'SPM.mat');
        if ~exist(spm_mat, 'file')
            fprintf('Skipping %s/%s (no SPM.mat in Contrast folder)\n', grp_name, base_id);
            continue;
        end
        
        % Pick PET image from the Main folder
        pet_img = '';
        candidates = pet_candidates(base_id, subj_main);
        for k = 1:numel(candidates)
            cand = candidates{k};
            if exist(cand, 'file')
                pet_img = cand;
                break;
            end
        end
        
        if isempty(pet_img)
            fprintf('Skipping %s/%s (no matching PET file found)\n', grp_name, base_id);
            continue;
        end
        
        % Add to processing list
        S = struct();
        S.id = base_id;
        S.spm_mat = spm_mat;
        S.pet_img = pet_img;
        
        % Optional mask - only include if it exists
        if ~isempty(mask_file) && exist(mask_file, 'file')
            S.mask_img = mask_file;
        else
            S.mask_img = '';
        end
        
        % Threshold settings
        S.thresh_desc = 'none';  % Uncorrected p-value
        S.threshold = 0.05;      % p < 0.05
        S.extent = 50;           % Extent threshold (voxels)
        
        subjects{end+1} = S;
    end
end

if isempty(subjects)
    fprintf('No subjects found that require processing.\n');
else
    fprintf('Found %d subjects to process.\n', numel(subjects));
    
    % Process subjects one by one with debugging
    for s = 1:numel(subjects)
        fprintf('\nProcessing subject %d/%d: %s\n', s, numel(subjects), subjects{s}.id);
        try
            ssa_batch(subjects(s), out_root);
        catch ME
            fprintf('Error processing %s: %s\n', subjects{s}.id, ME.message);
            fprintf('Continuing with next subject...\n');
        end
    end
end

% -------------------------------------------------------------------------
% LOCAL FUNCTION - has_ssa
% -------------------------------------------------------------------------
function found = has_ssa(dir_main, dir_contrast)
    found = false;
    check_dirs = {dir_main, dir_contrast};
    
    for d = 1:numel(check_dirs)
        dd = check_dirs{d};
        if ~exist(dd, 'dir'), continue; end
        
        listing = dir(dd);
        for k = 1:numel(listing)
            name = lower(listing(k).name);
            if listing(k).isdir, continue; end
            
            if startsWith(name,'clusters') && (endsWith(name,'.nii') || endsWith(name,'.obj'))
                found = true; return;
            end
            if startsWith(name,'results') && (endsWith(name,'.tsv') || endsWith(name,'.txt'))
                found = true; return;
            end
        end
    end
end
