%% MASTER SCRIPT: GENERATE ALL SSA FILES (AD, MCI, & REMAINING HC)
% This script runs the complete Single Subject Analysis pipeline.
%
% UPDATE: SPECIFICITY CHECK
% - Adds 'HC' to the target groups.
% - Automatically excludes the "Reference 10" controls from being analyzed
%   against themselves.
% - Processes the "Remaining HC" exactly like patients to test specificity.
%
% OUTPUTS GENERATED:
% 1. Preprocessing: r*.nii (Resliced), scr*.nii (Resliced & Scaled)
% 2. Model Estimation: beta_*.nii, ResMS.nii, RPV.nii, mask.nii
% 3. Contrasts: con_*.nii, spmT_0001.nii, spmT_0002.nii
% 4. Results: Clusters.nii (p<0.05, k=50)

clear; clc;
spm('Defaults', 'PET');
spm_jobman('initcfg');

%% ==== CONFIGURATION ====
root_dir = fullfile(pwd, 'example_data', 'pet_subjects'); 

% Added 'HC' to targets to process the remaining controls
groups = {'AD', 'MCI', 'HC'}; 
control_group = 'HC';

% Mask File
mask_file = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');

% Thresholds for Clusters
p_thresh = 0.05;
min_extent = 50;

% Target Mean for Scaling (Matches Healthy Controls)
target_mean = 39.0;

%% ==== STEP 0: SAFE MASK HANDLING ====
if ~exist(mask_file, 'file')
    error('Mask not found: %s', mask_file);
end
[p, n, e] = fileparts(mask_file);
safe_mask = fullfile(p, 'Safe_GMmask.nii');
if ~exist(safe_mask, 'file')
    copyfile(mask_file, safe_mask);
end
mask_file = safe_mask; 

%% ==== STEP 1: PREPARE CONTROLS (NORMATIVE DB) ====
fprintf('Step 1: Preparing Normative Database (Lowest 10 HC)...\n');
ctrl_path = fullfile(root_dir, control_group);
ctrl_subs = dir(ctrl_path);
ctrl_subs = ctrl_subs([ctrl_subs.isdir] & ~startsWith({ctrl_subs.name}, '.'));
ctrl_subs = ctrl_subs(startsWith({ctrl_subs.name}, 'C', 'IgnoreCase', true));

c_stats = [];
for i = 1:length(ctrl_subs)
    subDir = fullfile(ctrl_path, ctrl_subs(i).name);
    f = dir(fullfile(subDir, 'Nor_Cor_*.nii'));
    if ~isempty(f)
        try
            V = spm_vol(fullfile(subDir, f(1).name));
            dat = spm_read_vols(V);
            c_stats(end+1).mean = mean(dat(dat > 0.1)); %#ok<AGROW>
            c_stats(end).path = fullfile(subDir, f(1).name);
            c_stats(end).id = ctrl_subs(i).name;
        catch; end
    end
end

if isempty(c_stats), error('No control images found!'); end

% Select Lowest 10
[~, idx] = sort([c_stats.mean]);
selected_ctrls = c_stats(idx(1:min(10, end)));

% Store IDs of the reference set to exclude them later
reference_ids = {selected_ctrls.id}; 

control_scans = {};
fprintf('  Selected Reference Controls (Excluded from Analysis):\n');
for k=1:length(selected_ctrls)
    control_scans{end+1, 1} = [selected_ctrls(k).path ',1']; %#ok<AGROW>
    fprintf('    %s (%.2f)\n', selected_ctrls(k).id, selected_ctrls(k).mean);
end
ref_img_path = selected_ctrls(1).path; 

%% ==== STEP 2: PROCESS ALL GROUPS ====
fprintf('\nStep 2: Processing Subjects (Preprocessing + Stats + Clusters)...\n');

for g = 1:length(groups)
    grpName = groups{g};
    grpDir = fullfile(root_dir, grpName);
    pat_subs = dir(grpDir);
    pat_subs = pat_subs([pat_subs.isdir] & ~startsWith({pat_subs.name}, '.'));
    
    for p = 1:length(pat_subs)
        subID = pat_subs(p).name;
        
        % Skip Contrast folders
        if contains(subID, 'Contrast'), continue; end
        
        % CRITICAL CHECK: Is this subject part of the Normative DB?
        if ismember(subID, reference_ids)
            % fprintf('  [SKIP] %s is part of the Reference Database.\n', subID);
            continue; 
        end
        
        subjPath = fullfile(grpDir, subID);
        outDir = fullfile(grpDir, [subID 'Contrast']);
        
        fprintf('\n------------------------------------------------\n');
        fprintf('Subject: %s (%s)\n', subID, grpName);
        
        % A. FIND RAW IMAGE
        raw_pet = dir(fullfile(subjPath, 'Nor_Cor_*.nii'));
        if isempty(raw_pet), fprintf('  [SKIP] No PET image.\n'); continue; end
        pet_file = fullfile(subjPath, raw_pet(1).name);
        
        % B. CHECK GEOMETRY (RESLICE)
        final_file = check_and_reslice(pet_file, ref_img_path);
        
        % C. CHECK INTENSITY (RESCALE)
        final_file = check_and_rescale(final_file, target_mean);
        
        % D. RUN SPM STATS (ESTIMATE MODEL)
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        
        % Force update if SPM.mat exists but might be old/wrong
        % (Optional: comment out if you want to resume interrupted runs)
        if exist(fullfile(outDir, 'SPM.mat'), 'file')
             % delete(fullfile(outDir, 'SPM.mat')); 
             % fprintf('  [INFO] SPM.mat exists. Assuming valid.\n');
        end
        
        if ~exist(fullfile(outDir, 'SPM.mat'), 'file')
            try
                run_spm_stats_job(outDir, control_scans, [final_file ',1'], mask_file);
                fprintf('  [OK] Model Estimated\n');
            catch ME
                fprintf('  [FAIL] Stats failed: %s\n', ME.message);
                continue;
            end
        end
        
        % E. GENERATE CLUSTERS (RESULTS)
        try
            generate_clusters(outDir, p_thresh, min_extent);
            fprintf('  [OK] Clusters.nii check/create complete.\n');
        catch ME
            fprintf('  [FAIL] Cluster generation failed: %s\n', ME.message);
        end
    end
end

fprintf('\n=== PIPELINE COMPLETE ===\n');


%% ============================================================
%% HELPER FUNCTIONS
%% ============================================================

function f_out = check_and_reslice(f_in, f_ref)
    V_src = spm_vol(f_in);
    V_ref = spm_vol(f_ref);
    if isequal(V_src.dim, V_ref.dim) && isequal(V_src.mat, V_ref.mat)
        f_out = f_in; 
    else
        fprintf('    ...Reslicing to match controls\n');
        flags.mean = 0; flags.which = 1; flags.interp = 1;
        spm_reslice({f_ref, f_in}, flags);
        [pth, nm, ext] = fileparts(f_in);
        f_out = fullfile(pth, ['r' nm ext]);
    end
end

function f_out = check_and_rescale(f_in, target)
    V = spm_vol(f_in);
    Y = spm_read_vols(V);
    mask = (Y > 0.01); 
    curr_mean = mean(Y(mask));
    
    if curr_mean < 1.0 
        factor = target / curr_mean;
        fprintf('    ...Rescaling (Mean %.2f -> %.2f, Factor %.1f)\n', curr_mean, target, factor);
        Y_scaled = Y * factor;
        [pth, nm, ext] = fileparts(f_in);
        f_out = fullfile(pth, ['sc' nm ext]); 
        V_out = V;
        V_out.fname = f_out;
        V_out.descrip = sprintf('Rescaled x%.2f', factor);
        spm_write_vol(V_out, Y_scaled);
    else
        f_out = f_in;
    end
end

function run_spm_stats_job(out_dir, grp1, grp2, mask_p)
    matlabbatch = {};
    
    % Design
    matlabbatch{1}.spm.stats.factorial_design.dir = {out_dir};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = grp1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = {grp2};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0;
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {mask_p};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_mean = 1; 
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_yes.gmscv = 50; 
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 2;
    
    % Estimation
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 1; 
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    % Contrast
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Hypometabolism';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Hypermetabolism';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    matlabbatch{3}.spm.stats.con.delete = 1;
    
    spm_jobman('run', matlabbatch);
end

function generate_clusters(spm_dir, p_val, k_ext)
    load(fullfile(spm_dir, 'SPM.mat'), 'SPM');
    xSPM = struct('swd', spm_dir, 'title', 'SSA', 'Ic', 1, 'n', 1, 'u', p_val, 'k', k_ext, 'thresDesc', 'none');
    xSPM.units = {'mm'}; xSPM.Im = []; xSPM.pm = []; xSPM.Ex = [];
    
    [SPM, xSPM] = spm_getSPM(xSPM);
    
    if ~isempty(xSPM.XYZ)
        V = SPM.xVol.VRpv; 
        V.fname = fullfile(spm_dir, 'Clusters.nii');
        V.dt = [16 0];
        V.descrip = sprintf('SSA p<%.2f k=%d', p_val, k_ext);
        
        img = zeros(V.dim);
        A = spm_clusters(xSPM.XYZ);
        for i = 1:size(xSPM.XYZ, 2)
            xyz = xSPM.XYZ(:, i);
            img(xyz(1), xyz(2), xyz(3)) = A(i);
        end
        spm_write_vol(V, img);
    else
        fprintf('    (No significant clusters found)\n');
    end
end