%% run SSA from a subject table
% Use this if I already have a CSV/TSV with:
% id, spm_mat, pet_img, optional mask_img, threshold, extent, contrast_index.
% TODO: check the table columns before running, MATLAB errors here are annoying.
%
% steps:
% 1. point subject_table to the CSV/TSV
% 2. set output folder
% 3. call ssa_batch

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

subject_table = fullfile(pwd, 'example_data', 'ssa_subjects.csv');
out_root = fullfile(pwd, 'outputs', 'ssa');

ssa_batch(subject_table, out_root);
