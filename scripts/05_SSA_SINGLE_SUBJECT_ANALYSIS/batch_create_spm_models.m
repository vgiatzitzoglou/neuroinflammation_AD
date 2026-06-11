%% BATCH CREATE SPM SINGLE SUBJECT MODELS (SSA)
% This script automates the creation of SPM.mat files for Single Subject Analysis.
%
% UPDATE: FIXED GLOBAL NORMALIZATION & RESLICING
% 1. Scans ALL Healthy Controls (HC) & Selects Lowest 10.
% 2. Checks if Patient image geometry matches Controls -> RESLICES if needed.
% 3. Runs SPM Statistics using Proportional Scaling to 50 (Standard PET).
%
% Requirements: SPM12 must be installed and in the MATLAB path.

clear; clc;
spm('Defaults', 'PET');
spm_jobman('initcfg');

%% ==== CONFIGURATION ====
root_dir = fullfile(pwd, 'example_data', 'pet_subjects'); 

% Where are the healthy controls? (Used to build the reference group)
control_group_folder = 'HC'; 

% Which groups to process? (Patients to compare against HC)
target_groups = {'AD', 'MCI'}; 

% Mask File (Absolute Path) - Used for calculating the average
mask_file = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');

% PET File Pattern (To find the preprocessed images)
pet_patterns = {'Nor_Cor_*Realign*.nii', 'Nor_Cor_*Realign*.nii.gz', 'sw*_PET.nii', 'sw*_PET.nii.gz'};

%% ==== STEP 1: CALCULATE AVERAGES & SELECT LOWEST 10 CONTROLS ====
fprintf('Step 1: Finding Healthy Controls & Calculating Averages...\n');

ctrl_path = fullfile(root_dir, control_group_folder);
ctrl_subs = dir(ctrl_path);
ctrl_subs = ctrl_subs([ctrl_subs.isdir] & ~startsWith({ctrl_subs.name}, '.'));

% Filter for subjects starting with 'C'
is_c_subj = startsWith({ctrl_subs.name}, 'C', 'IgnoreCase', true);
ctrl_subs = ctrl_subs(is_c_subj);

if isempty(ctrl_subs)
    error('No control subjects found in %s', ctrl_path);
end

% Load Mask Volume Once
V_mask = spm_vol(mask_file);
mask_data = spm_read_vols(V_mask);
mask_idx = mask_data > 0.1;

subject_stats = []; 

fprintf('  Calculating global means for %d subjects...\n', length(ctrl_subs));

for i = 1:length(ctrl_subs)
    subID = ctrl_subs(i).name;
    if contains(subID, 'Contrast'), continue; end
    
    subDir = fullfile(ctrl_path, subID);
    petImg = find_pet_image(subDir, pet_patterns);
    
    if ~isempty(petImg)
        try
            V_pet = spm_vol(petImg);
            pet_data = spm_read_vols(V_pet);
            vals = pet_data(mask_idx);
            vals = vals(vals > 0 & ~isnan(vals));
            mean_val = mean(vals);
            
            row = struct();
            row.ID = subID;
            row.Path = petImg;
            row.Mean = mean_val;
            subject_stats = [subject_stats; row]; %#ok<AGROW>
        catch ME
            fprintf('    Warning: Could not read %s (%s)\n', subID, ME.message);
        end
    end
end

if isempty(subject_stats)
    error('No valid PET data found for controls.');
end

% --- SORT AND SELECT ---
fprintf('\n  Sorting controls by mean intensity...\n');
[~, sort_idx] = sort([subject_stats.Mean]);
sorted_stats = subject_stats(sort_idx);

% Select top 10 lowest
limit_count = min(10, length(sorted_stats));
selected_controls = sorted_stats(1:limit_count);

fprintf('  --- SELECTED CONTROLS (Lowest 10) ---\n');
control_scans = {};
for k = 1:length(selected_controls)
    fprintf('    %d. %s (Mean: %.2f)\n', k, selected_controls(k).ID, selected_controls(k).Mean);
    control_scans{end+1, 1} = [selected_controls(k).Path ',1']; 
end
fprintf('  -------------------------------------\n');

% Get reference image path (for reslicing)
ref_img_path = selected_controls(1).Path;


%% ==== STEP 2: PROCESS PATIENTS ====
fprintf('\nStep 2: Processing Target Groups using selected normative database...\n');

for g = 1:length(target_groups)
    groupName = target_groups{g};
    groupDir = fullfile(root_dir, groupName);
    
    if ~isfolder(groupDir), continue; end
    
    pat_subs = dir(groupDir);
    pat_subs = pat_subs([pat_subs.isdir] & ~startsWith({pat_subs.name}, '.'));
    
    for p = 1:length(pat_subs)
        subID = pat_subs(p).name;
        
        if contains(subID, 'Contrast'), continue; end
        
        subjPath = fullfile(groupDir, subID);
        petImg = find_pet_image(subjPath, pet_patterns);
        
        if isempty(petImg)
            fprintf('  Skipping %s (No PET image)\n', subID);
            continue;
        end
        
        % Define Output Directory
        outDir = fullfile(groupDir, [subID 'Contrast']);
        
        if exist(fullfile(outDir, 'SPM.mat'), 'file')
            fprintf('  Skipping %s (SPM.mat already exists)\n', subID);
            continue;
        end
        
        fprintf('  Processing %s...\n', subID);
        
        % --- AUTO-RESLICE CHECK ---
        % Ensure patient image matches control image geometry
        finalPetImg = check_and_reslice(petImg, ref_img_path);
        
        if isempty(finalPetImg)
            fprintf('    FAILED: Reslicing error.\n');
            continue;
        end
        
        % Create directory if needed
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        
        % --- RUN SPM BATCH ---
        try
            run_spm_job(outDir, control_scans, [finalPetImg ',1'], mask_file);
            fprintf('    Success!\n');
        catch ME
            fprintf('    FAILED: %s\n', ME.message);
        end
    end
end

fprintf('\n=== ALL DONE ===\n');


%% ==== HELPER FUNCTIONS ====

function pet_file = find_pet_image(folder, patterns)
    pet_file = '';
    for k = 1:length(patterns)
        f = dir(fullfile(folder, patterns{k}));
        if ~isempty(f)
            f = f(~[f.isdir]);
            if ~isempty(f)
                pet_file = fullfile(folder, f(1).name);
                return;
            end
        end
    end
    if isempty(pet_file)
       all_nii = dir(fullfile(folder, '*.nii'));
       for k = 1:length(all_nii)
           nm = all_nii(k).name;
           if ~contains(nm, 'GMmask') && ...
              ~contains(nm, 'Clusters') && ...
              ~contains(nm, 'Skull') && ...
              ~contains(nm, 'GMObjectmap') && ...
              ~contains(nm, '_GM_ObjectMap') && ...
              ~contains(nm, 'ObjectMap')
               pet_file = fullfile(folder, nm);
               return;
           end
       end
    end
end

function resliced_path = check_and_reslice(source_img, ref_img)
    % Checks if source_img matches ref_img orientation/dim.
    % If not, reslices source_img to match ref_img.
    
    resliced_path = source_img; % Default: return original if no change needed
    
    try
        V_ref = spm_vol(ref_img);
        V_src = spm_vol(source_img);
        
        % Check Dimensions and Matrix
        dim_match = isequal(V_ref.dim, V_src.dim);
        mat_match = isequal(V_ref.mat, V_src.mat);
        
        if dim_match && mat_match
            % No reslicing needed
            return;
        end
        
        fprintf('    Orientation/Dimension mismatch detected. Reslicing to match controls...\n');
        
        % Define Flags for Reslicing
        flags.mask = 0;
        flags.mean = 0;
        flags.interp = 1; % Trilinear interpolation
        flags.which = 1;  % Write resliced image (don't write mean)
        
        % Run Reslice
        spm_reslice({ref_img, source_img}, flags);
        
        % Construct new filename (SPM prefixes 'r')
        [p, n, e] = fileparts(source_img);
        resliced_path = fullfile(p, ['r' n e]);
        
        if exist(resliced_path, 'file')
            fprintf('    Reslicing complete: %s\n', ['r' n e]);
        else
            warning('Reslicing ran but output file not found.');
            resliced_path = '';
        end
        
    catch ME
        warning('Reslicing failed: %s', ME.message);
        resliced_path = '';
    end
end

function run_spm_job(out_dir, group1_scans, group2_scan, mask_p)
    % Builds and runs the SPM batch job
    
    matlabbatch = {}; % Initialize as CELL ARRAY
    
    % --- MODULE 1: FACTORIAL DESIGN SPECIFICATION ---
    matlabbatch{1}.spm.stats.factorial_design.dir = {out_dir};
    
    % Design: Two-sample t-test
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = group1_scans;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = {group2_scan};
    
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0; 
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1; 
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0; 
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0; 
    
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    
    % Masking
    if ~isempty(mask_p)
        matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1; 
        matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;         
        matlabbatch{1}.spm.stats.factorial_design.masking.em = {mask_p};  
    else
        matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
        matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
        matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    end
    
    % Global Calculation / Normalization (FIXED HERE)
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_mean = 1; % Calculate Mean
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_yes.gmscv = 50; % Scale to 50
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 2; % Proportional Scaling
    
    % --- MODULE 2: MODEL ESTIMATION ---
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    % --- MODULE 3: CONTRAST MANAGER ---
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Hypometabolism (Controls > Patient)';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Hypermetabolism (Patient > Controls)';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    
    matlabbatch{3}.spm.stats.con.delete = 1; 
    
    spm_jobman('run', matlabbatch);
end