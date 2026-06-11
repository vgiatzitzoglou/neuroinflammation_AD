% run_ssa_all.m
% Wrapper to call ssa_batch with the prepared CSV and output folder.
% Usage: run this in MATLAB (SPM12 on path).

addpath(fileparts(mfilename('fullpath'))); % ensure ssa_batch.m is visible
ssa_batch(fullfile(pwd, 'example_data', 'ssa_subjects.csv'), fullfile(pwd, 'outputs', 'ssa'));

% After completion, results will be under ./outputs/ssa/<subject>/
