function run_processing_batch()
    % This script processes multimodal imaging data (T1, PET, DTI) for
    % multiple subjects. It performs segmentation, coregistration,
    % normalization, and creates a subject-specific SUVR map in MNI space.

    % --- Configuration ---
    % Base directory where 'organized_pet_dti' is located
    baseDir = pwd; 
    dataDir = fullfile(baseDir, 'organized_pet_dti');
    
    % Path to the SPM atlas (Neuromorphometrics)
    spm_dir = spm('Dir');
    spmAtlasFile = fullfile(spm_dir, 'tpm', 'labels_Neuromorphometrics.nii');

    if ~exist(spmAtlasFile, 'file')
        error('SPM atlas ''labels_Neuromorphometrics.nii'' not found in %s. Please check SPM installation.', fullfile(spm_dir, 'tpm'));
    end
    
    % --- Subject List (43 subjects) ---
    subjects = { ...
        'AD014', 'AD018', 'AD023', 'AD024', 'AD027', 'AD029', 'AD030', 'AD035', ...
        'AD036', 'AD042', 'C004', 'C008', 'C011', 'C012', 'C013', 'C018', ...
        'C023', 'C029', 'C030', 'C035', 'C036', 'C037', 'C041', 'C41(MCI181)', ...
        'MCI013', 'MCI024', 'MCI032', 'MCI037', 'MCI039', 'MCI040', 'MCI045', ...
        'MCI051', 'MCI057', 'MCI059', 'MCI084', 'MCI095', 'MCI100', 'MCI104', ...
        'MCI106', 'MCI141', 'MCI153', 'MCI156', 'MCI163' ...
    };

    fprintf('--- Starting processing batch (v4) for %d subjects ---\n', numel(subjects));
    spm('defaults', 'PET');
    spm_jobman('initcfg');

    % --- Main Loop ---
    for i = 1:numel(subjects)
        subj = subjects{i};
        subjDir = fullfile(dataDir, subj);
        fprintf('\n--- Processing Subject: %s (%d/%d) ---\n', subj, i, numel(subjects));

        % --- Find and decompress files ---
        t1File = find_file(subjDir, 'T1.nii*');
        petFile = find_file(subjDir, 'PET.nii*');
        faFile = find_file(subjDir, 'dti_FA.nii*');
        mdFile = find_file(subjDir, 'dti_MD.nii*');

        if isempty(t1File) || isempty(petFile) || isempty(faFile) || isempty(mdFile)
            fprintf('WARNING: Skipping %s. Missing one or more input files.\n', subj);
            continue;
        end
        
        % Decompress files for SPM (it prefers .nii)
        t1File = gzip_if_needed(t1File, false);
        petFile = gzip_if_needed(petFile, false);
        faFile = gzip_if_needed(faFile, false);
        mdFile = gzip_if_needed(mdFile, false);

        % --- Start SPM Batch ---
        matlabbatch = {};

        % --- Step 1: Segment T1 ---
        % This creates the deformation fields (y_ and iy_) and tissue maps (c1, c2, etc.)
        fprintf('Step 1: Segmenting T1...\n');
        matlabbatch{1}.spm.spatial.preproc.channel.vols = {char(t1File)};
        matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
        matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
        matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1]; % Save bias-corrected
        matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,1')};
        matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
        matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0]; % Native GM
        matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,2')};
        matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
        matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0]; % Native WM
        matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,3')};
        matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
        matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0]; % Native CSF
        matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,4')};
        matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
        matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,5')};
        matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
        matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {fullfile(spm_dir, 'tpm', 'TPM.nii,6')};
        matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
        matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
        matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
        matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
        matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
        matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
        matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
        matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
        matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1]; % Save y_ and iy_ warps

        % --- Step 2: Coregister & Reslice ---
        % Coregister PET, FA, MD all to the T1.
        % We also reslice them to match the T1's space for future calculations.
        fprintf('Step 2: Coregistering & Reslicing images to T1...\n');
        matlabbatch{2}.spm.spatial.coreg.estwrite.ref = {char(t1File)}; % Reference = T1
        matlabbatch{2}.spm.spatial.coreg.estwrite.source = {char(petFile)}; % Source = PET
        matlabbatch{2}.spm.spatial.coreg.estwrite.other = {
                                                          char(faFile)
                                                          char(mdFile)
                                                          }; % Other = FA, MD
        matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
        matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
        matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
        matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.interp = 4; % 4th Degree B-Spline
        matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
        matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.mask = 0;
        matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.prefix = 'r'; % Output: rPET.nii, rdti_FA.nii, etc.

        % --- Step 3: Warp Atlas to Subject's Native Space ---
        % Use the inverse deformation field (iy_T1) from Step 1 to bring
        % the SPM cerebellum atlas from MNI space into this subject's space.
        fprintf('Step 3: Warping MNI atlas to subject native space...\n');
        matlabbatch{3}.spm.spatial.normalise.write.subj.def.jobname = 'def';
        matlabbatch{3}.spm.spatial.normalise.write.subj.def.srcfield(1) = cfg_dep('Segment: Inverse Deform Field', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','inv', '()',{1}, '.','sn', '()',{1}, '.','inv', '()',{1}));
        matlabbatch{3}.spm.spatial.normalise.write.subj.def.im = 1; % 1 = Apply inverse
        matlabbatch{3}.spm.spatial.normalise.write.subj.resample = {char(spmAtlasFile)}; % Image to warp = atlas
        matlabbatch{3}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
        matlabbatch{3}.spm.spatial.normalise.write.woptions.vox = [1 1 1];
        matlabbatch{3}.spm.spatial.normalise.write.woptions.interp = 0; % 0 = Nearest Neighbour (critical for atlases)
        matlabbatch{3}.spm.spatial.normalise.write.woptions.prefix = 'w_native_';

        % --- Step 4: Create Native-Space Cerebellum WM Mask ---
        % Use ImCalc to combine the subject's *own* white matter (c2T1)
        % with the warped atlas (w_native_labels...) to create the final mask.
        fprintf('Step 4: Creating native-space cerebellum WM mask...\n');
        matlabbatch{4}.spm.util.imcalc.input(1) = cfg_dep('Segment: c2 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','c', '()',{1}));
        matlabbatch{4}.spm.util.imcalc.input(2) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
        matlabbatch{4}.spm.util.imcalc.output = 'native_cerebellum_WM_mask.nii';
        matlabbatch{4}.spm.util.imcalc.outdir = {char(subjDir)};
        % Expression: (i1 > 0.5) = is White Matter
        % (i2 == 4 | i2 == 5) = is Cerebellar WM in the atlas
        matlabbatch{4}.spm.util.imcalc.expression = '(i1 > 0.5) & ((i2 == 4) | (i2 == 5))';
        matlabbatch{4}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{4}.spm.util.imcalc.options.mask = 0;
        matlabbatch{4}.spm.util.imcalc.options.interp = 1;
        matlabbatch{4}.spm.util.imcalc.options.dtype = 2; % 8-bit

        % --- Step 5: Calculate SUVR in Native Space ---
        % Use the new native mask to calculate SUVR on the resliced PET scan.
        fprintf('Step 5: Calculating SUVR in native space...\n');
        matlabbatch{5}.spm.util.imcalc.input(1) = cfg_dep('Coregister: Reslice: Resliced Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles', '()',{1})); % rPET.nii
        matlabbatch{5}.spm.util.imcalc.input(2) = cfg_dep('Image Calculator: Output File', substruct('.','val', '{}',{4}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files')); % native_cerebellum_WM_mask.nii
        matlabbatch{5}.spm.util.imcalc.output = 'native_SUVR_PET.nii';
        matlabbatch{5}.spm.util.imcalc.outdir = {char(subjDir)};
        matlabbatch{5}.spm.util.imcalc.expression = 'i1 ./ spm_mean_vol(i1(i2 > 0.5))'; % SUVR = PET / mean(PET(mask))
        matlabbatch{5}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{5}.spm.util.imcalc.options.mask = 0;
        matlabbatch{5}.spm.util.imcalc.options.interp = 1;
        matlabbatch{5}.spm.util.imcalc.options.dtype = 16; % 16-bit float (for SUVR values)

        % --- Step 6: Normalize All Final Maps to MNI Space ---
        % Use the forward deformation field (y_T1) from Step 1 to push
        % all our final native-space maps into MNI space for group analysis.
        fprintf('Step 6: Normalizing all final maps to MNI space...\n');
        matlabbatch{6}.spm.spatial.normalise.write.subj.def.jobname = 'def';
        matlabbatch{6}.spm.spatial.normalise.write.subj.def.srcfield(1) = cfg_dep('Segment: Forward Deform Field', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','def', '()',{1}));
        matlabbatch{6}.spm.spatial.normalise.write.subj.def.im = 0; % 0 = Apply forward
        
        % Gather all images to be warped
        images_to_warp = {};
        % From Step 5: native_SUVR_PET.nii
        images_to_warp{1} = cfg_dep('Image Calculator: Output File', substruct('.','val', '{}',{5}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
        % From Step 2: rdti_FA.nii
        images_to_warp{2} = cfg_dep('Coregister: Reslice: Resliced Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles', '()',{2}));
        % From Step 2: rdti_MD.nii
        images_to_warp{3} = cfg_dep('Coregister: Reslice: Resliced Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles', '()',{3}));
        
        matlabbatch{6}.spm.spatial.normalise.write.subj.resample = images_to_warp;
        
        matlabbatch{6}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
        matlabbatch{6}.spm.spatial.normalise.write.woptions.vox = [2 2 2]; % 2mm output
        matlabbatch{6}.spm.spatial.normalise.write.woptions.interp = 4; % 4th Degree B-Spline
        matlabbatch{6}.spm.spatial.normalise.write.woptions.prefix = 'w_'; % Output: w_native_SUVR_PET.nii, etc.

        % --- Run Batch ---
        try
            spm_jobman('run', matlabbatch);
            
            % --- Final Cleanup & Gzip ---
            fprintf('--- Successfully processed Subject: %s ---\n', subj);
            fprintf('Cleaning up .nii files...\n');
            
            % Gzip the final outputs
            gzip_if_needed(fullfile(subjDir, 'w_native_SUVR_PET.nii'), true);
            gzip_if_needed(fullfile(subjDir, 'w_rdti_FA.nii'), true);
            gzip_if_needed(fullfile(subjDir, 'w_rdti_MD.nii'), true);
            
            % Delete intermediate .nii files
            delete(fullfile(subjDir, 'T1.nii'));
            delete(fullfile(subjDir, 'PET.nii'));
            delete(fullfile(subjDir, 'dti_FA.nii'));
            delete(fullfile(subjDir, 'dti_MD.nii'));
            delete(fullfile(subjDir, 'mT1.nii'));
            delete(fullfile(subjDir, 'c1T1.nii'));
            delete(fullfile(subjDir, 'c2T1.nii'));
            delete(fullfile(subjDir, 'c3T1.nii'));
            delete(fullfile(subjDir, 'rPET.nii'));
            delete(fullfile(subjDir, 'rdti_FA.nii'));
            delete(fullfile(subjDir, 'rdti_MD.nii'));
            delete(fullfile(subjDir, 'w_native_labels_Neuromorphometrics.nii'));
            delete(fullfile(subjDir, 'native_cerebellum_WM_mask.nii'));
            delete(fullfile(subjDir, 'native_SUVR_PET.nii'));
            delete(fullfile(subjDir, 'w_native_SUVR_PET.nii'));
            delete(fullfile(subjDir, 'w_rdti_FA.nii'));
            delete(fullfile(subjDir, 'w_rdti_MD.nii'));

        catch e
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
            fprintf('ERROR processing Subject: %s\n', subj);
            fprintf('Error message: %s\n', e.message);
            fprintf('At line: %d in file %s\n', e.stack(1).line, e.stack(1).file);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        end
    end
    
    fprintf('\n--- Batch processing finished ---\n');

end

% --- Helper Functions ---

function full_path = find_file(subjDir, pattern)
    % Finds a file matching a pattern, prioritizing .nii.gz
    fprintf('  DEBUG: find_file: Searching in %s for %s\n', subjDir, pattern);
    
    files_gz = dir(fullfile(subjDir, [pattern '.gz']));
    if ~isempty(files_gz)
        fprintf('  DEBUG: find_file: Found gzipped: %s\n', files_gz(1).name);
        full_path = fullfile(subjDir, files_gz(1).name);
        return;
    end
    
    files_nii = dir(fullfile(subjDir, pattern));
    if ~isempty(files_nii)
        fprintf('  DEBUG: find_file: Found unzipped: %s\n', files_nii(1).name);
        full_path = fullfile(subjDir, files_nii(1).name);
        return;
    end
    
    fprintf('  DEBUG: find_file: No file found in %s matching %s\n', subjDir, pattern);
    full_path = '';
end

function out_file = gzip_if_needed(file_path, force_gzip)
    % Decompresses .nii.gz to .nii for SPM, or recompresses
    [fpath, name, ext] = fileparts(file_path);
    
    if strcmp(ext, '.gz')
        % It's gzipped, decompress it
        fprintf('Decompressing: %s\n', file_path);
        gunzip(file_path);
        delete(file_path); % Delete the .nii.gz
        out_file = fullfile(fpath, name); % Return the .nii path
    elseif strcmp(ext, '.nii') && force_gzip
        % It's .nii and we want to gzip it
        fprintf('Compressing: %s\n', file_path);
        gzip(file_path);
        delete(file_path); % Delete the .nii
        out_file = [file_path '.gz'];
    else
        % It's already .nii and we're not forcing gzip, so just return it
        out_file = file_path;
    end
end

