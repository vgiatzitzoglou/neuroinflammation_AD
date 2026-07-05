function run_pet_processing_v3()
    % PBR28 SUVR processing.
    % Needs the SPM segmentation/deformation files already beside the T1.
    % TODO: check whether the _2 suffix is still needed before rerunning.
    %
    % steps:
    % 1. find T1/PET and existing SPM segmentation files
    % 2. coregister PET to T1
    % 3. bring cerebellum atlas labels into native space
    % 4. make cerebellar WM reference mask
    % 5. create native SUVR, warp to MNI, smooth

    fprintf('starting PBR28 SUVR batch\n');

    % paths and subjects
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fileparts(script_dir));
    dataDir = fullfile(pwd, 'example_data', 'pbr28');
    
    spm_path = spm('Dir');
    atlas_file = fullfile(spm_path, 'tpm', 'labels_Neuromorphometrics.nii');
    if ~exist(atlas_file, 'file'), fprintf('error: Atlas file not found.\n'); return; end
    
    smooth_fwhm = [8 8 8];
    
    subjects = list_subject_directories(dataDir);

    fprintf('found %d subjects to process...\n', numel(subjects));
    
    spm('defaults', 'PET');
    spm_jobman('initcfg');
    
    % loop subjects
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        fprintf('\nsubject %s (%d/%d)\n', subjectID, i, numel(subjects));
        
        subjectDir = find_subject_directory(dataDir, subjectID);
        if isempty(subjectDir), fprintf('warning: Directory not found. Skipping.\n'); continue; end
        
        % find inputs
        t1_file = find_t1_file(subjectDir, subjectID);
        if isempty(t1_file), fprintf('warning: T1 scan not found. Skipping.\n'); continue; end
        
        pet_file = find_pet_file(subjectDir, subjectID);
        if isempty(pet_file), fprintf('warning: PET scan not found. Skipping.\n'); continue; end
        
        [~, t1_name, t1_ext] = fileparts(t1_file);
        if strcmp(t1_ext, '.gz'), [~, t1_name, ~] = fileparts(t1_name); end
        
        c2_file = fullfile(subjectDir, ['c2' t1_name '.nii']);
        y_file  = fullfile(subjectDir, ['y_' t1_name '.nii']);
        iy_file = fullfile(subjectDir, ['iy_' t1_name '.nii']);
        
        if ~exist(c2_file, 'file') || ~exist(y_file, 'file') || ~exist(iy_file, 'file')
            fprintf('warning: segmentation files missing for %s. skipping.\n', subjectID);
            continue;
        end
        
        % intermediate names
        [pet_path, pet_name, pet_ext] = fileparts(pet_file);
        if strcmp(pet_ext, '.gz'), [~, pet_name, ~] = fileparts(pet_name); end
        resliced_pet_file = fullfile(pet_path, ['r' pet_name '.nii']);
        
        temp_atlas_file = fullfile(subjectDir, 'temp_atlas_for_warping.nii');
        warped_atlas_file = fullfile(subjectDir, 'w_native_temp_atlas_for_warping.nii');
        mask_file = fullfile(subjectDir, 'native_cerebellum_WM_mask.nii');
        
        native_suvr_file = fullfile(subjectDir, 'native_SUVR_PET_2.nii');
        warped_suvr_file = fullfile(subjectDir, 'wnative_SUVR_PET_2.nii');
        final_suvr_file = fullfile(subjectDir, 'swnative_SUVR_PET_2.nii');
        
        
        % run steps
        try
            % step 1: PET to T1
            fprintf('step 1: PET to T1\n');
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

            % step 2a: copy atlas locally
            fprintf('step 2a: copy atlas locally\n');
            copyfile(atlas_file, temp_atlas_file);
            if ~exist(temp_atlas_file, 'file'), error('Failed to copy atlas locally.'); end
            
            % step 2b: atlas to native space
            fprintf('step 2b: atlas to native space\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {iy_file};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {[temp_atlas_file, ',1']};
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [1 1 1];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 0;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w_native_';
            spm_jobman('run', matlabbatch);
            
            if ~exist(warped_atlas_file, 'file'), error('Warped atlas file not created.'); end

            % step 3: cerebellum WM mask
            fprintf('step 3: cerebellum WM mask\n');
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

            % step 4a: mean reference value
            fprintf('step 4a: reference mean\n');
            Vpet = spm_vol(resliced_pet_file);
            Vmask = spm_vol(mask_file);
            pet_data = spm_read_vols(Vpet);
            mask_data = spm_read_vols(Vmask);
            
            ref_voxels = pet_data(mask_data > 0.5 & isfinite(pet_data));
            if isempty(ref_voxels)
                error('Reference region mask is empty or contains no valid data.');
            end
            mean_ref_value = mean(ref_voxels);
            fprintf('mean reference value: %f\n', mean_ref_value);
            if mean_ref_value == 0
                error('Mean reference value is 0. Cannot divide.');
            end

            % step 4b: native SUVR
            fprintf('step 4b: native SUVR\n');
            clear matlabbatch;
            matlabbatch{1}.spm.util.imcalc.input = {resliced_pet_file};
            matlabbatch{1}.spm.util.imcalc.output = native_suvr_file; % (now '..._2.nii')
            matlabbatch{1}.spm.util.imcalc.outdir = {subjectDir};
            matlabbatch{1}.spm.util.imcalc.expression = sprintf('i1 / %f', mean_ref_value);
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = 1;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 16;
            spm_jobman('run', matlabbatch);
            if ~exist(native_suvr_file, 'file'), error('native SUVR file not created.'); end

            % step 5: native SUVR to MNI
            fprintf('step 5: SUVR to MNI\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {y_file};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {native_suvr_file};
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
            spm_jobman('run', matlabbatch);
            
            if ~exist(warped_suvr_file, 'file'), error('warped SUVR file not created.'); end

            % step 6: smooth final map
            fprintf('step 6: smooth SUVR map\n');
            clear matlabbatch;
            matlabbatch{1}.spm.spatial.smooth.data = {warped_suvr_file};
            matlabbatch{1}.spm.spatial.smooth.fwhm = smooth_fwhm;
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 0;
            matlabbatch{1}.spm.spatial.smooth.prefix = 's';
            spm_jobman('run', matlabbatch);
            
            if ~exist(final_suvr_file, 'file'), error('smoothed SUVR file not created.'); end
            
            fprintf('done PET for %s\n', subjectID);
            
            % clean intermediates
            fprintf('cleaning intermediates\n');
            delete(resliced_pet_file);
            delete(temp_atlas_file);
            delete(warped_atlas_file);
            delete(mask_file);
            delete(native_suvr_file);
            delete(warped_suvr_file);
            
        catch e
            fprintf('error processing %s: %s\n', subjectID, e.message);
            fprintf('line %d in %s\n', e.stack(1).line, e.stack(1).name);
        end
        
    end
    
    fprintf('\nPBR28 SUVR batch done\n');

end % main function

% small path helpers
function subjects = list_subject_directories(dataDir)
    if ~exist(dataDir, 'dir')
        error('PBR28 data directory not found: %s', dataDir);
    end

    entries = dir(dataDir);
    entries = entries([entries.isdir]);
    subjects = sort(setdiff({entries.name}, {'.', '..'}));

    if isempty(subjects)
        warning('No subject directories found under %s', dataDir);
    end
end

function full_dir_path = find_subject_directory(baseDir, subjectID)
    full_dir_path = '';
    path1 = fullfile(baseDir, subjectID);
    if exist(path1, 'dir'), full_dir_path = path1; return; end
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
