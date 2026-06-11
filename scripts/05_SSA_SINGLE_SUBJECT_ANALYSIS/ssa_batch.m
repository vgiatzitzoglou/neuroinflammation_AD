function ssa_batch(subjects, out_root)
%SSA_BATCH Extract SSA clusters and PET summaries for a subject list.
%
% subjects can be:
% - a cell array of structs with id, spm_mat, pet_img, optional mask_img
% - a CSV/TSV path with columns id, spm_mat, pet_img, optional mask_img
%
% Outputs per subject:
% - Clusters.nii
% - Results.tsv

if nargin == 0
    fprintf(['Usage:\n', ...
        '  S = struct(''id'',''SUBJ1'',''spm_mat'',''/path/SPM.mat'',', ...
        '''pet_img'',''/path/pet.nii'');\n', ...
        '  ssa_batch({S}, ''/path/to/output'');\n', ...
        '  ssa_batch(''/path/subjects.csv'', ''/path/to/output'');\n']);
    return;
end
if nargin < 2
    error('Provide subjects and out_root.');
end

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

subjects = normalize_subjects(subjects);
cfg = ssa.default_config();

spm('Defaults', 'PET');
spm_jobman('initcfg');

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

for i = 1:numel(subjects)
    subj = subjects{i};
    fprintf('\n=== %s ===\n', subj.id);

    out_dir = fullfile(out_root, char(subj.id));
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    p_threshold = get_optional(subj, 'threshold', cfg.p_threshold);
    extent_threshold = get_optional(subj, 'extent', cfg.extent_threshold);
    contrast_index = get_optional(subj, 'contrast_index', cfg.contrast_index);
    mask_img = get_optional(subj, 'mask_img', '');

    cluster_file = fullfile(out_dir, 'Clusters.nii');
    has_clusters = ssa.write_clusters(subj.spm_mat, cluster_file, ...
        p_threshold, extent_threshold, contrast_index, mask_img);

    if ~has_clusters
        continue;
    end

    ssa.write_cluster_results(cluster_file, subj.pet_img, ...
        fullfile(out_dir, 'Results.tsv'));
end
end

function subjects = normalize_subjects(subjects)
if ischar(subjects) || isstring(subjects)
    subjects = read_subject_table(char(subjects));
elseif isstruct(subjects)
    subjects = num2cell(subjects);
end

if ~iscell(subjects)
    error('subjects must be a cell array, struct array, or CSV/TSV path.');
end
end

function subjects = read_subject_table(path)
opts = detectImportOptions(path);
tbl = readtable(path, opts);
names = tbl.Properties.VariableNames;
required = {'id', 'spm_mat', 'pet_img'};

for i = 1:numel(required)
    if ~any(strcmpi(names, required{i}))
        error('Missing required column "%s" in %s.', required{i}, path);
    end
end

subjects = cell(height(tbl), 1);
for i = 1:height(tbl)
    subj = struct();
    subj.id = read_cell(tbl, names, i, 'id');
    subj.spm_mat = read_cell(tbl, names, i, 'spm_mat');
    subj.pet_img = read_cell(tbl, names, i, 'pet_img');
    subj.mask_img = read_cell(tbl, names, i, 'mask_img');
    subj.threshold = read_cell(tbl, names, i, 'threshold');
    subj.extent = read_cell(tbl, names, i, 'extent');
    subj.contrast_index = read_cell(tbl, names, i, 'contrast_index');
    subjects{i} = subj;
end
end

function value = read_cell(tbl, names, row, column)
idx = find(strcmpi(names, column), 1);
if isempty(idx)
    value = [];
    return;
end
value = tbl{row, idx};
if iscell(value)
    value = value{1};
end
if isstring(value)
    value = char(value);
end
end

function value = get_optional(subj, field, default_value)
value = default_value;
if isfield(subj, field) && ~isempty(subj.(field))
    value = subj.(field);
end
if iscell(value)
    value = value{1};
end
if isstring(value)
    value = char(value);
end
end
