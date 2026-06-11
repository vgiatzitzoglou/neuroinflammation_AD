%% RUN SSA FROM A SUBJECT TABLE
% Wrapper for users who already have a CSV/TSV with:
% id, spm_mat, pet_img, optional mask_img, threshold, extent, contrast_index.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

subject_table = fullfile(pwd, 'example_data', 'ssa_subjects.csv');
out_root = fullfile(pwd, 'outputs', 'ssa');

ssa_batch(subject_table, out_root);
