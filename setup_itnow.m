% setup_itnow.m
% Load MATLAB paths for the ITNOW project

root = fileparts(mfilename('fullpath'));

addpath(root);
addpath(genpath(fullfile(root, '_functions')));
addpath(genpath(fullfile(root, '_programs')));

% Do NOT add these to the MATLAB path:
% DATA, HISTORY, _DEPRECATED

disp('ITNOW MATLAB path loaded.');