%% SSA BATCH PROCESSING SCRIPT V2 (Fixed for Contrast Subfolders)
% Use this script to process subjects where SPM.mat is in a 'Contrast' subfolder
% and PET images are in the parent folder.
%
% INSTRUCTIONS:
% 1. Update 'data_root' to your specific group folder (e.g., ...\HC or ...\AD)
% 2. Run the script.

clear; clc;

%% ==== CONFIGURATION ====
data_root = fullfile(pwd, 'example_data', 'pet_subjects', 'HC');          % Target Group Folder
output_root = fullfile(pwd, 'outputs', 'results');            % Where to save results

% Specific mask file you mentioned earlier
mask_file_path = fullfile(pwd, 'masks', 'GMmask_HCNormBin_CB_VENT_PERI_masked.nii');

% Thresholds
p_thresh = 0.05;
min_extent = 50;

%% ==== MAIN PROCESSING LOOP ====
fprintf('Scanning %s for subjects...\n', data_root);

% Get list of subject folders (excluding . and ..)
subj_dirs = dir(data_root);
subj_dirs = subj_dirs([subj_dirs.isdir]);
subj_dirs = subj_dirs(~startsWith({subj_dirs.name}, '.'));

count = 0;

for i = 1:length(subj_dirs)
    subjID = subj_dirs(i).name;
    subjPath = fullfile(data_root, subjID);
    
    % skip if this is the "Contrast" folder itself appearing as a subject
    if contains(subjID, 'Contrast')
        continue;
    end

    fprintf('\nChecking Subject: %s\n', subjID);

    % 1. LOCATE SPM.MAT (Look for Sibling Contrast Folder)
    % Structure seen: AD/AD014 and AD/AD14Contrast are in the same folder.
    
    % Construct path to sibling contrast folder: e.g. ./example_data/pet_subjects/AD/AD014Contrast
    contrastPath = fullfile(data_root, [subjID 'Contrast']);
    
    % If strict naming fails (e.g. AD14 vs AD014Contrast), try searching the data_root
    if ~exist(contrastPath, 'dir')
        % Search for any folder in root starting with SubjectID and containing Contrast
        candidates = dir(fullfile(data_root, [subjID '*Contrast*']));
        if ~isempty(candidates)
            contrastPath = fullfile(data_root, candidates(1).name);
        else
            % Fallback: Check inside the subject folder just in case (old structure)
            innerContrast = fullfile(subjPath, [subjID 'Contrast']);
            if exist(innerContrast, 'dir')
                contrastPath = innerContrast;
            end
        end
    end
    
    spmFile = fullfile(contrastPath, 'SPM.mat');
    
    if ~exist(spmFile, 'file')
        fprintf('  - Skipping: No SPM.mat found in %s\n', contrastPath);
        continue;
    end

    % 2. LOCATE PET IMAGE (Look in Parent Subject Folder)
    % Look for the specific naming convention you showed in screenshots
    petFiles = dir(fullfile(subjPath, '*Realign*.nii*'));
    
    % Fallback if Realign not found: Look for any NIfTI that isn't a mask
    if isempty(petFiles)
        allNii = dir(fullfile(subjPath, '*.nii'));
        % Filter out masks and clusters
        validIdx = ~contains({allNii.name}, 'GMmask') & ...
                   ~contains({allNii.name}, 'Clusters') & ...
                   ~contains({allNii.name}, 'Skull');
        petFiles = allNii(validIdx);
    end
    
    if isempty(petFiles)
        fprintf('  - Skipping: No valid PET image found in %s\n', subjPath);
        continue;
    end
    
    petFile = fullfile(subjPath, petFiles(1).name);
    fprintf('  + Found SPM: ...%s\n', spmFile(end-20:end));
    fprintf('  + Found PET: %s\n', petFiles(1).name);

    % 3. RUN ANALYSIS
    outDir = fullfile(output_root, subjID);
    try
        run_ssa_single(spmFile, petFile, outDir, p_thresh, min_extent, mask_file_path);
        fprintf('  => SUCCESS! Results saved.\n');
        count = count + 1;
    catch ME
        fprintf('  => ERROR: %s\n', ME.message);
    end
end

fprintf('\n=== DONE: Processed %d subjects ===\n', count);


%% ==== WORKER FUNCTION ====
function run_ssa_single(spm_path, pet_path, out_dir, p_val, k_ext, mask_p)

    % Initialize
    spm('Defaults', 'PET');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    % 1. Extract Clusters
    load(spm_path, 'SPM');
    xSPM = struct();
    xSPM.swd = fileparts(spm_path);
    xSPM.Ic = 1; % Contrast 1
    xSPM.u = p_val;
    xSPM.k = k_ext;
    xSPM.thresDesc = 'none';
    xSPM.title = 'SSA';
    
    % Apply Mask if provided
    if ~isempty(mask_p) && exist(mask_p, 'file')
        xSPM.Im = [];
        xSPM.pm = mask_p;
        xSPM.Ex = 1; % Inclusive mask
    end
    
    [SPM, xSPM] = spm_getSPM(xSPM);
    
    if isempty(xSPM.XYZ)
        warning('No significant clusters found for this subject.');
        return;
    end

    % 2. Create Cluster Map
    cluster_file = fullfile(out_dir, 'Clusters.nii');
    A = spm_clusters(xSPM.XYZ);
    num_clusters = max(A);
    
    V = struct();
    V.fname = cluster_file;
    V.dim = SPM.xVol.DIM';
    V.dt = [16 0]; % Float32
    V.mat = SPM.xVol.M;
    V = spm_create_vol(V);
    img = zeros(V.dim);
    
    for i = 1:size(xSPM.XYZ, 2)
        xyz = xSPM.XYZ(:, i);
        img(xyz(1), xyz(2), xyz(3)) = A(i);
    end
    spm_write_vol(V, img);

    % 3. Extract Intensity from PET
    V_pet = spm_vol(pet_path);
    pet_data = spm_read_vols(V_pet);
    
    results = [];
    for c = 1:num_clusters
        mask = (img == c);
        vals = pet_data(mask);
        
        row = struct();
        row.ClusterID = c;
        row.Voxels = length(vals);
        row.Mean = mean(vals);
        row.Sum = sum(vals);
        row.SSA_Value = mean(vals) * length(vals); % Mean * Voxels
        results = [results; row]; %#ok<AGROW>
    end

    % 4. Save CSV
    if ~isempty(results)
        T = struct2table(results);
        writetable(T, fullfile(out_dir, 'Results.csv'));
    end
end
