% ssa_batch.m
% Automates the SSA protocol (threshold clusters, make object map, sample PET)
% for a list of subjects using SPM12. Avoids GUI clicks.
%
% Requirements:
% - SPM12 on MATLAB path
% - For each subject:
%     * spm_mat: path to SPM.mat
%     * pet_img: path to PET image to sample
%     * mask_img (optional): path to mask (e.g., GMmask_HCNormBin_CB.nii)
%
% Usage (inside MATLAB):
%   subjects = {
%     struct('id','SUBJ1','spm_mat','/path/to/SPM.mat',...
%            'pet_img','/path/to/pet.nii','mask_img','/path/to/GMmask.nii')
%   };
%   ssa_batch(subjects, '/path/to/output_dir');
%
% Outputs per subject in output_dir/<id>/:
%   - Clusters.nii (binary suprathreshold map)
%   - Clusters_labels.nii (connected-component labels)
%   - Results.tsv (label, voxels, mean, mean*voxels)

function ssa_batch(subjects, out_root)
% ssa_batch(subjects, out_root)
% subjects: cell array of structs with fields id, spm_mat, pet_img, (optional) mask_img
% or a path to a CSV/TSV with columns: id, spm_mat, pet_img, (optional) mask_img
% out_root: folder where outputs will be written (one subfolder per subject)
%
% If called with no args, prints usage and returns.

if nargin == 0
    fprintf(['Usage:\n',...
        '  subjects = {struct(''id'',''SUBJ1'',''spm_mat'',''/path/SPM.mat'',...\n',...
        '                     ''pet_img'',''/path/pet.nii'', ''mask_img'',''/path/mask.nii'')};\n',...
        '  out_root = ''/path/to/output'';\n',...
        '  ssa_batch(subjects, out_root);\n',...
        '\nOr provide a CSV/TSV with columns: id, spm_mat, pet_img, (mask_img)\n',...
        '  ssa_batch(''/path/subjects.csv'', ''/path/to/output'');\n']);
    return;
end
if nargin < 2
    error('Provide subjects cell array (or CSV path) and out_root path');
end

% Accept a CSV/TSV path in place of the subjects cell
if ischar(subjects) || isstring(subjects)
    subj_path = char(subjects);
    opts = detectImportOptions(subj_path);
    tbl = readtable(subj_path, opts);
    required = {'id','spm_mat','pet_img'};
    for r = required
        if ~any(strcmpi(tbl.Properties.VariableNames, r{1}))
            error('Missing required column %s in %s', r{1}, subj_path);
        end
    end
    subjects = cell(height(tbl),1);
    for i = 1:height(tbl)
        S.id = string(tbl{i, find(strcmpi(tbl.Properties.VariableNames,'id'),1)}); 
        S.spm_mat = tbl{i, find(strcmpi(tbl.Properties.VariableNames,'spm_mat'),1)};
        S.pet_img = tbl{i, find(strcmpi(tbl.Properties.VariableNames,'pet_img'),1)};
        if any(strcmpi(tbl.Properties.VariableNames,'mask_img'))
            S.mask_img = tbl{i, find(strcmpi(tbl.Properties.VariableNames,'mask_img'),1)};
        end
        subjects{i} = S;
    end
end

spm('defaults','fmri'); spm_jobman('initcfg');

for i = 1:numel(subjects)
    subj = subjects{i};
    fprintf('\\n=== %s ===\\n', subj.id);
    out_dir = fullfile(out_root, subj.id);
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    spm_mat = subj.spm_mat;
    pet_img = subj.pet_img;
    mask_img = '';
    if isfield(subj, 'mask_img'), mask_img = subj.mask_img; end

    % 1) Threshold SPM results: p<0.05 (uncorr), extent>=50
    matlabbatch = [];
    matlabbatch{1}.spm.stats.results.spmmat = {spm_mat};
    matlabbatch{1}.spm.stats.results.conspec(1).titlestr = '';
    matlabbatch{1}.spm.stats.results.conspec(1).contrasts = Inf; % "All"
    matlabbatch{1}.spm.stats.results.conspec(1).threshdesc = 'none';
    matlabbatch{1}.spm.stats.results.conspec(1).thresh = 0.05;
    matlabbatch{1}.spm.stats.results.conspec(1).extent = 50;
    if ~isempty(mask_img)
        matlabbatch{1}.spm.stats.results.conspec(1).mask.image = {mask_img};
        matlabbatch{1}.spm.stats.results.conspec(1).mask.threshold = 0;
    else
        matlabbatch{1}.spm.stats.results.conspec(1).mask = struct('contrasts',{},'image',{},'threshold',{});
    end
    matlabbatch{1}.spm.stats.results.print = false;
    matlabbatch{1}.spm.stats.results.write.tspm.basename = 'Clusters';

    spm_jobman('run', matlabbatch);

    % The written image will be in the same folder as SPM.mat; move/copy to out_dir
    tspm_path = fullfile(fileparts(spm_mat), 'Clusters.nii');
    if ~exist(tspm_path, 'file')
        error('Clusters.nii not found for %s', subj.id);
    end
    copyfile(tspm_path, fullfile(out_dir, 'Clusters.nii'));

    % 2) Label connected clusters
    V = spm_vol(fullfile(out_dir, 'Clusters.nii'));
    Y = spm_read_vols(V);
    idx = find(Y > 0);
    labels = zeros(size(Y));
    if ~isempty(idx)
        CC = spm_clusters(idx');
        labels(idx) = CC;
    end
    Vlab = V;
    Vlab.fname = fullfile(out_dir, 'Clusters_labels.nii');
    spm_write_vol(Vlab, labels);

    % 3) Sample PET values per label
    Vpet = spm_vol(pet_img);
    P = spm_read_vols(Vpet);
    labs = unique(labels(:));
    labs(labs == 0) = [];
    results = [];
    for L = labs'
        m = P(labels == L);
        m = m(~isnan(m));
        vox = numel(m);
        if vox == 0, continue; end
        meanv = mean(m);
        results = [results; {L, vox, meanv, meanv * vox}]; %#ok<AGROW>
    end
    T = cell2table(results, 'VariableNames', {'Label','Voxels','Mean','Mean_times_Voxels'});
    writetable(T, fullfile(out_dir, 'Results.tsv'), 'FileType','text','Delimiter','\\t');
end
end
