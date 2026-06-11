%% SPECIFICITY CHECK: PROCESS REMAINING HEALTHY CONTROLS
% Uses Mask-Based Intensity Scaling to fix "Wrong Pic" issues.
% Processes only HCs not in the Normative Database.

clear; clc;
spm('Defaults', 'PET');
spm_jobman('initcfg');

%% ==== CONFIGURATION ====
root_dir = fullfile(pwd, 'example_data', 'pet_subjects'); 
target_group = 'HC'; 
mask_file = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');
p_thresh = 0.05;
min_extent = 50;
target_mean = 39.0;

%% ==== STEP 0: SAFE MASK HANDLING ====
if ~exist(mask_file, 'file'), error('Mask not found: %s', mask_file); end
[p, n, e] = fileparts(mask_file);
safe_mask = fullfile(p, 'Safe_GMmask.nii');
if ~exist(safe_mask, 'file'), copyfile(mask_file, safe_mask); end
mask_file = safe_mask;

%% ==== STEP 1: IDENTIFY NORMATIVE DB (LOWEST 10) ====
fprintf('Step 1: Identifying Normative Database...\n');
ctrl_path = fullfile(root_dir, target_group);
ctrl_subs = dir(ctrl_path);
ctrl_subs = ctrl_subs([ctrl_subs.isdir] & ~startsWith({ctrl_subs.name}, '.'));
ctrl_subs = ctrl_subs(startsWith({ctrl_subs.name}, 'C', 'IgnoreCase', true));

Vm = spm_vol(mask_file);
M_dat = spm_read_vols(Vm);
mask_idx = (M_dat > 0.5);

c_stats = [];
for i = 1:length(ctrl_subs)
    subDir = fullfile(ctrl_path, ctrl_subs(i).name);
    f = dir(fullfile(subDir, 'Nor_Cor_*.nii'));
    if ~isempty(f)
        try
            V = spm_vol(fullfile(subDir, f(1).name));
            dat = spm_read_vols(V);
            % Robust Mean Calculation
            brain_vals = dat(mask_idx);
            brain_vals = brain_vals(brain_vals > 0);
            c_stats(end+1).mean = mean(brain_vals); %#ok<AGROW>
            c_stats(end).path = fullfile(subDir, f(1).name);
            c_stats(end).id = ctrl_subs(i).name;
        catch; end
    end
end

if isempty(c_stats), error('No control images found!'); end
[~, idx] = sort([c_stats.mean]);
selected_ctrls = c_stats(idx(1:min(10, end)));
reference_ids = {selected_ctrls.id};
ref_img_path = selected_ctrls(1).path;

control_scans = {};
for k=1:length(selected_ctrls)
    control_scans{end+1, 1} = [selected_ctrls(k).path ',1']; %#ok<AGROW>
end
fprintf('  Identified %d reference subjects.\n', length(selected_ctrls));

%% ==== STEP 2: PROCESS REMAINING CONTROLS ====
fprintf('\nStep 2: Processing REMAINING Healthy Controls...\n');

grpDir = fullfile(root_dir, target_group);
pat_subs = dir(grpDir);
pat_subs = pat_subs([pat_subs.isdir] & ~startsWith({pat_subs.name}, '.'));

for p = 1:length(pat_subs)
    subID = pat_subs(p).name;
    if contains(subID, 'Contrast'), continue; end
    if ismember(subID, reference_ids), continue; end % SKIP REFERENCE
    
    subjPath = fullfile(grpDir, subID);
    outDir = fullfile(grpDir, [subID 'Contrast']);
    
    fprintf('\n------------------------------------------------\n');
    fprintf('Processing Remaining HC: %s\n', subID);
    
    raw_pet = dir(fullfile(subjPath, 'Nor_Cor_*.nii'));
    if isempty(raw_pet), fprintf('  [SKIP] No PET image.\n'); continue; end
    pet_file = fullfile(subjPath, raw_pet(1).name);
    
    final_file = check_and_reslice(pet_file, ref_img_path);
    final_file = check_and_rescale(final_file, target_mean, mask_file);
    
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    if exist(fullfile(outDir, 'SPM.mat'), 'file'), delete(fullfile(outDir, 'SPM.mat')); end
    
    try
        run_spm_stats_job(outDir, control_scans, [final_file ',1'], mask_file);
        fprintf('  [OK] Model Estimated\n');
    catch ME
        fprintf('  [FAIL] Stats failed: %s\n', ME.message);
        continue;
    end
    
    try
        generate_clusters(outDir, p_thresh, min_extent);
        fprintf('  [OK] Clusters created\n');
    catch ME
        fprintf('  [FAIL] Cluster generation failed: %s\n', ME.message);
    end
end

fprintf('\n=== DONE ===\n');

%% HELPER FUNCTIONS
function f_out = check_and_reslice(f_in, f_ref)
    V_src = spm_vol(f_in); V_ref = spm_vol(f_ref);
    if isequal(V_src.dim, V_ref.dim) && isequal(V_src.mat, V_ref.mat)
        f_out = f_in; 
    else
        fprintf('    ...Reslicing\n');
        flags.mean=0; flags.which=1; flags.interp=1; spm_reslice({f_ref, f_in}, flags);
        [p,n,e]=fileparts(f_in); f_out=fullfile(p,['r' n e]);
    end
end

function f_out = check_and_rescale(f_in, target, mask_p)
    V=spm_vol(f_in); Y=spm_read_vols(V);
    Vm=spm_vol(mask_p); M=spm_read_vols(Vm);
    vals = Y(M>0.5); vals = vals(vals>0);
    curr_mean = mean(vals);
    if curr_mean < 1.0 
        factor = target/curr_mean;
        fprintf('    ...Rescaling (x%.1f)\n', factor);
        Y_scaled = Y * factor;
        [p,n,e]=fileparts(f_in); f_out=fullfile(p,['sc' n e]);
        V.fname=f_out; V.dt=[16 0]; spm_write_vol(V, Y_scaled);
    else
        f_out=f_in;
    end
end

function run_spm_stats_job(out_dir, grp1, grp2, mask_p)
    matlabbatch={};
    matlabbatch{1}.spm.stats.factorial_design.dir={out_dir};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1=grp1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2={grp2};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept=0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance=1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca=0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova=0;
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none=1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im=1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em={mask_p};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_mean=1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_yes.gmscv=50;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm=2;
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1)=cfg_dep('Factorial design specification: SPM.mat File',substruct('.','val','{}',{1},'.','val','{}',{1},'.','val','{}',{1}),substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals=1;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical=1;
    matlabbatch{3}.spm.stats.con.spmmat(1)=cfg_dep('Model estimation: SPM.mat File',substruct('.','val','{}',{2},'.','val','{}',{1},'.','val','{}',{1}),substruct('.','spmmat'));
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name='Hypometabolism';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights=[1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep='none';
    matlabbatch{3}.spm.stats.con.delete=1;
    spm_jobman('run',matlabbatch);
end

function generate_clusters(spm_dir, p_val, k_ext)
    load(fullfile(spm_dir, 'SPM.mat'), 'SPM');
    xSPM=struct('swd',spm_dir,'title','SSA','Ic',1,'n',1,'u',p_val,'k',k_ext,'thresDesc','none');
    xSPM.units={'mm'}; xSPM.Im=[]; xSPM.pm=[]; xSPM.Ex=[];
    [SPM,xSPM]=spm_getSPM(xSPM);
    if ~isempty(xSPM.XYZ)
        V=SPM.xVol.VRpv; V.fname=fullfile(spm_dir,'Clusters.nii'); V.dt=[16 0];
        img=zeros(V.dim); A=spm_clusters(xSPM.XYZ);
        for i=1:size(xSPM.XYZ,2), xyz=xSPM.XYZ(:,i); img(xyz(1),xyz(2),xyz(3))=A(i); end
        spm_write_vol(V,img);
    end
end