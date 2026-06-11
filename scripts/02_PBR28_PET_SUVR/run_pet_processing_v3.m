function run_pet_processing_v3()
    % This script runs the full SUVR processing pipeline for the PET scans.
    % It uses the outputs from your VBM segmentation (the deformation
    % fields and tissue maps) to create a final, smoothed SUVR map
    % that is in the exact same space as your VBM files.
    %
    % v3 Fix: Fixes the "spm_mean" undefined function error by 
    % calculating the mean in MATLAB first, then passing it to ImCalc.
    % AND fixes the 'mask_.file' typo.
    %
    % ---!! NEW (User Request): Appending '_2' to output files !! ---

    fprintf('--- Starting PET-SUVR Processing Batch (v3 - suffix _2) ---\n');

    % --- 1. Setup Paths and Subjects ---
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));
    dataDir = fullfile(pwd, 'example_data', 'pbr28');
    
    spm_path = spm('Dir');
    atlas_file = fullfile(spm_path, 'tpm', 'labels_Neuromorphometrics.nii');
    if ~exist(atlas_file, 'file'), fprintf('ERROR: Atlas file not found.\n'); return; end
    
    SMOOTH_FWHM = [8 8 8];
    
    subjects = pipeline.default_subjects();

    fprintf('Found %d subjects to process...\n', numel(subjects));
    
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    % --- 2. Loop Through Each Subject ---
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        fprintf('\n--- Processing Subject: %s (%d/%d) ---\n', subjectID, i, numel(subjects));
        
        subjectDir = find_subject_directory(dataDir, subjectID);
        if isempty(subjectDir), fprintf('WARNING: Directory not found. Skipping.\n'); continue; end
        
        % --- 3. Find All Necessary Files ---
        t1_file = find_t1_file(subjectDir, subjectID);
        if isempty(t1_file), fprintf('WARNING: T1 scan not found. Skipping.\n'); continue; end
        
        pet_file = find_pet_file(subjectDir, subjectID);
        if isempty(pet_file), fprintf('WARNING: PET scan not found. Skipping.\n'); continue; end
        
        [~, t1_name, t1_ext] = fileparts(t1_file);
        if strcmp(t1_ext, '.gz'), [~, t1_name, ~] = fileparts(t1_name); end
        
        c2_file = fullfile(subjectDir, ['c2' t1_name '.nii']);
        y_file  = fullfile(subjectDir, ['y_' t1_name '.nii']);
        iy_file = fullfile(subjectDir, ['iy_' t1_name '.nii']);
        
        if ~exist(c2_file, 'file') || ~exist(y_file, 'file') || ~exist(iy_file, 'file')
            fprintf('WARNING: VBM outputs (c2, y_, iy_) not found for %s. Did segmentation run? Skipping.\n', subjectID);
            continue;
        end
        
        % --- 4. Define Intermediate Filenames ---
        [pet_path, pet_name, pet_ext] = fileparts(pet_file);
        if strcmp(pet_ext, '.gz'), [~, pet_name, ~] = fileparts(pet_name); end
        resliced_pet_file = fullfile(pet_path, ['r' pet_name '.nii']);
        
        temp_atlas_file = fullfile(subjectDir, 'temp_atlas_for_warping.nii');
        warped_atlas_file = fullfile(subjectDir, 'w_native_temp_atlas_for_warping.nii');
        mask_file = fullfile(subjectDir, 'native_cerebellum_WM_mask.nii');
        
        % ---!! FILENAME CHANGE HERE !! ---
        native_suvr_file = fullfile(subjectDir, 'native_SUVR_PET_2.nii');
        warped_suvr_file = fullfile(subjectDir, 'wnative_SUVR_PET_2.nii');
        final_suvr_file = fullfile(subjectDir, 'swnative_SUVR_PET_2.nii');
        
        
        % --- 5. Run Pipeline Step-by-Step ---
        try
            % Step 1: Coregister PET to T1 (Estimate & Reslice)
            fprintf('Step 1: Coregistering PET to T1...\n');
            matlabbatch = {};
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {[t1_file, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = {[pet_file, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
            spm_jobman('run', matlabbatch);
            
            if ~exist(resliced_pet_file, 'file'), error('Coregistered PET file not created.'); end

            % Step 2a: Copy atlas to subject directory
            fprintf('Step 2a: Copying atlas locally...\n');
            copyfile(atlas_file, temp_atlas_file);
            if ~exist(temp_atlas_file, 'file'), error('Failed to copy atlas locally.'); end
            
            % Step 2b: Warp Atlas from MNI to Native Space (using Inverse Warp)
            fprintf('Step 2b: Warping atlas to native space...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {iy_file};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {[temp_atlas_file, ',1']};
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [1 1 1];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 0;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w_native_';
            spm_jobman('run', matlabbatch);
            
            if ~exist(warped_atlas_file, 'file'), error('Warped atlas file not created.'); end

            % Step 3: Create Native Cerebellum WM Mask
            fprintf('Step 3: Creating native cerebellum WM mask...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.util.imcalc.input = {
                                                   resliced_pet_file
                                                   c2_file
                                                   warped_atlas_file
                                                   };
            matlabbatch{1}.spm.util.imcalc.output = mask_file;
            matlabbatch{1}.spm.util.imcalc.outdir = {subjectDir};
            matlabbatch{1}.spm.util.imcalc.expression = '(i2 > 0.5) & ((i3 == 4) | (i3 == 5) | (i3 == 43) | (i3 == 44))';
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = 1;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 2;
            spm_jobman('run', matlabbatch);
            
            if ~exist(mask_file, 'file'), error('Cerebellum mask file not created.'); end 

            % Step 4a: Calculate mean of reference region in MATLAB
            fprintf('Step 4a: Calculating mean of reference region...\n');
            Vpet = spm_vol(resliced_pet_file);
            Vmask = spm_vol(mask_file);
            pet_data = spm_read_vols(Vpet);
            mask_data = spm_read_vols(Vmask);
            
            ref_voxels = pet_data(mask_data > 0.5 & isfinite(pet_data));
            if isempty(ref_voxels)
                error('Reference region mask is empty or contains no valid data.');
            end
            mean_ref_value = mean(ref_voxels);
            fprintf('Mean reference value: %f\n', mean_ref_value);
            if mean_ref_value == 0
                error('Mean reference value is 0. Cannot divide.');
            end

            % Step 4b: Calculate Native SUVR
            fprintf('Step 4b: Calculating native SUVR...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.util.imcalc.input = {resliced_pet_file};
            % ---!! FILENAME CHANGE HERE !! ---
            matlabbatch{1}.spm.util.imcalc.output = native_suvr_file; % (now '..._2.nii')
            matlabbatch{1}.spm.util.imcalc.outdir = {subjectDir};
            matlabbatch{1}.spm.util.imcalc.expression = sprintf('i1 / %f', mean_ref_value);
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = 1;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 16;
            spm_jobman('run', matlabbatch);
            if ~exist(native_suvr_file, 'file'), error('Native SUVR file not created.'); end

            % Step 5: Normalize Native SUVR to MNI Space (using Forward Warp)
            fprintf('Step 5: Normalizing SUVR map to MNI space...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {y_file};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {native_suvr_file};
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
            spm_jobman('run', matlabbatch);
            
            if ~exist(warped_suvr_file, 'file'), error('Warped SUVR file not created.'); end

            % Step 6: Smooth the final, warped SUVR map
            fprintf('Step 6: Smoothing final SUVR map...\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.smooth.data = {warped_suvr_file};
            matlabbatch{1}.spm.spatial.smooth.fwhm = SMOOTH_FWHM;
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 0;
            matlabbatch{1}.spm.spatial.smooth.prefix = 's';
            spm_jobman('run', matlabbatch);
            
            if ~exist(final_suvr_file, 'file'), error('Smoothed SUVR file not created.'); end
            
            fprintf('--- Successfully processed PET for Subject: %s ---\n', subjectID);
            
            % --- 6. Cleanup Intermediate Files ---
            fprintf('Cleaning up intermediate files...\n');
            delete(resliced_pet_file);
            delete(temp_atlas_file);
            delete(warped_atlas_file);
            delete(mask_file);
            delete(native_suvr_file);
            delete(warped_suvr_file);
            
        catch e
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
            fprintf('ERROR processing Subject: %s\n', subjectID);
            fprintf('Error message: %s\n', e.message);
            fprintf('At line: %d in file %s\n', e.stack(1).line, e.stack(1).name);
            fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        end
        
    end
    
    fprintf('\n--- PET-SUVR Processing Batch Finished! ---\n');

end % End of main function

% --- Helper Functions ---
function full_dir_path = find_subject_directory(baseDir, subjectID)
    full_dir_path = '';
    path1 = fullfile(baseDir, subjectID);
    if exist(path1, 'dir'), full_dir_path = path1; return; end
    if strcmp(subjectID, 'C41(MCI181)'), path2 = fullfile(baseDir, 'C41');
        if exist(path2, 'dir'), full_dir_path = path2; return; end; end
    if startsWith(subjectID, 'C00'), altID = strrep(subjectID, 'C00', 'C0'); 
        path3 = fullfile(baseDir, altID);
        if exist(path3, 'dir'), full_dir_path = path3; return; end; end
    if startsWith(subjectID, 'AD0'), altID = strrep(subjectID, 'AD0', 'AD'); 
        path4 = fullfile(baseDir, altID);
        if exist(path4, 'dir'), full_dir_path = path4; return; end; end
end

function full_file_path = find_t1_file(directory, subjectID)
    full_file_path = ''; id_list = {};
    if startsWith(subjectID, 'AD0'), id_list = {subjectID, strrep(subjectID, 'AD0', 'AD')};
    elseif startsWith(subjectID, 'C00'), id_list = {subjectID, strrep(subjectID, 'C00', 'C0'), strrep(subjectID, 'C00', 'C')};
    elseif startsWith(subjectID, 'C0'), id_list = {subjectID, strrep(subjectID, 'C0', 'C')};
    else, id_list = {subjectID}; end
    name_patterns = {'_T1.nii*', '_MR_cc_reor.nii*'};
    for id = id_list, for pattern_base = name_patterns
        pattern = sprintf('%s%s', id{1}, pattern_base{1});
        files = dir(fullfile(directory, pattern)); files = files(~[files.isdir]);
        if ~isempty(files) && exist(fullfile(directory, files(1).name), 'file')
            full_file_path = fullfile(directory, files(1).name); return; 
        end
    end, end
end

function full_file_path = find_pet_file(directory, subjectID)
    full_file_path = ''; id_list = {};
    if startsWith(subjectID, 'AD0'), id_list = {subjectID, strrep(subjectID, 'AD0', 'AD')};
    elseif startsWith(subjectID, 'C00'), id_list = {subjectID, strrep(subjectID, 'C00', 'C0'), strrep(subjectID, 'C00', 'C')};
    elseif startsWith(subjectID, 'C0'), id_list = {subjectID, strrep(subjectID, 'C0', 'C')};
    else, id_list = {subjectID}; end
    name_patterns = {
        '_PET.nii*',
        '_Realign_PBR28_6090_add.nii*',
        '_Realign_PrePBR28_6090_add.nii*'
    };
    for id = id_list, for pattern_base = name_patterns
        pattern = sprintf('%s%s', id{1}, pattern_base{1});
        files = dir(fullfile(directory, pattern)); files = files(~[files.isdir]);
        if ~isempty(files) && exist(fullfile(directory, files(1).name), 'file')
            full_file_path = fullfile(directory, files(1).name); return;
        end
    end, end
end
