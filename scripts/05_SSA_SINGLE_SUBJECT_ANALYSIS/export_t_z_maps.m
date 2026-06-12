%% export T and Z maps
% copies existing SPM T maps and makes Z maps
%
% steps:
% 1. find subject contrast folders
% 2. copy spmT_0001.nii to output
% 3. convert T values to Z values
% 4. write Tmap.nii and Zmap.nii

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
spm('Defaults', 'PET');

%% config
% groups to process
cfg = ssa.default_config();
groups_to_process = {'AD', 'MCI'};
source_root = cfg.root_dir;
output_root = cfg.results_root;

%% main loop
for g = 1:length(groups_to_process)
    grpName = groups_to_process{g};
    grpPath = fullfile(source_root, grpName);
    
    fprintf('\nprocessing group: %s\n', grpName);
    
    % find subjects
    subj_dirs = dir(grpPath);
    subj_dirs = subj_dirs([subj_dirs.isdir] & ~startsWith({subj_dirs.name}, '.'));
    
    for i = 1:length(subj_dirs)
        subjID = subj_dirs(i).name;
        
        % skip Contrast folders appearing as subjects
        if contains(subjID, 'Contrast'), continue; end
        
        % locate Contrast folder
        contrastPath = fullfile(grpPath, [subjID 'Contrast']);
        if ~exist(contrastPath, 'dir')
            % fallback search
            candidates = dir(fullfile(grpPath, [subjID '*Contrast*']));
            if ~isempty(candidates)
                contrastPath = fullfile(grpPath, candidates(1).name);
            else
                continue; % no contrast folder, skip
            end
        end
        
        % locate SPM.mat and T-map
        spmFile = fullfile(contrastPath, 'SPM.mat');
        tmapFile = fullfile(contrastPath, 'spmT_0001.nii'); % contrast 1
        
        if ~exist(spmFile, 'file') || ~exist(tmapFile, 'file')
            fprintf('  skip: %s missing SPM.mat or spmT_0001.nii\n', subjID);
            continue;
        end
        
        % output directory
        subjOutDir = fullfile(output_root, subjID);
        if ~exist(subjOutDir, 'dir'), mkdir(subjOutDir); end
        
        fprintf('  processing %s...\n', subjID);
        
        try
            % copy T map
            copyfile(tmapFile, fullfile(subjOutDir, 'Tmap.nii'));
            
            % create Z map
            % load SPM to get degrees of freedom
            load(spmFile, 'SPM');
            df = SPM.xX.erdf;
            
            % load T-map data
            V_t = spm_vol(tmapFile);
            T_data = spm_read_vols(V_t);
            
            % convert T to Z
            % Z = inverseNormal( StudentT_CDF( T, df ) )
            % using SPM functions to handle nans/infinity safely
            P_val = spm_Tcdf(T_data, df);
            Z_data = spm_invNcdf(P_val);
            
            % mask out background (where T was NaN or 0)
            Z_data(isnan(T_data) | T_data == 0) = NaN;
            
            % cap extreme values if necessary
            Z_data(isinf(Z_data)) = sign(Z_data(isinf(Z_data))) * 10; % cap at Z=10
            
            % write Z-map
            V_z = V_t;
            V_z.fname = fullfile(subjOutDir, 'Zmap.nii');
            V_z.descrip = sprintf('Z-map calculated from T-map (df=%.2f)', df);
            spm_write_vol(V_z, Z_data);
            
            fprintf('    made Tmap.nii and Zmap.nii\n');
            
        catch ME
            fprintf('    => error: %s\n', ME.message);
        end
    end
end

fprintf('\ndone\n');
