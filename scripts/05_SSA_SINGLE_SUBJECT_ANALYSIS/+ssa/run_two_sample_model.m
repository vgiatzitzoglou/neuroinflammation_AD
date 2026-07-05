function ran_model = run_two_sample_model(out_dir, control_scans, target_scan, mask_file, cfg)
% build and estimate the SSA two-sample SPM model

spm_file = fullfile(out_dir, 'SPM.mat');
if exist(spm_file, 'file') && ~cfg.overwrite_models
    fprintf('  SPM.mat exists; skipping model estimation.\n');
    ran_model = false;
    return;
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
if exist(spm_file, 'file') && cfg.overwrite_models
    delete(spm_file);
end

matlabbatch = {};
matlabbatch{1}.spm.stats.factorial_design.dir = {out_dir};
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = control_scans;
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = {target_scan};
matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0;
matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1;
matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0;
matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0;
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {mask_file};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_mean = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_yes.gmscv = 50;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 2;

matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep( ...
    'Factorial design specification: SPM.mat File', ...
    substruct('.','val','{}',{1},'.','val','{}',{1},'.','val','{}',{1}), ...
    substruct('.','spmmat'));
matlabbatch{2}.spm.stats.fmri_est.write_residuals = double(cfg.write_residuals);
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep( ...
    'Model estimation: SPM.mat File', ...
    substruct('.','val','{}',{2},'.','val','{}',{1},'.','val','{}',{1}), ...
    substruct('.','spmmat'));
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Hypometabolism (Controls > Subject)';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Hypermetabolism (Subject > Controls)';
matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.delete = 1;

spm_jobman('run', matlabbatch);
ran_model = true;
end
