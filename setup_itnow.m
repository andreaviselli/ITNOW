function setup_itnow(varargin)
%setup_itnow Load MATLAB paths for the ITNOW project.

quiet = false;
if nargin >= 2
    for k = 1:2:nargin
        if strcmpi(string(varargin{k}), "quiet")
            quiet = logical(varargin{k + 1});
        end
    end
end

root = fileparts(mfilename('fullpath'));

addpath(root);
addpath(genpath(fullfile(root, '_functions')));
addpath(genpath(fullfile(root, '_programs')));

% Do NOT add these to the MATLAB path:
% DATA, HISTORY, _DEPRECATED

if ~quiet
    disp('ITNOW MATLAB path loaded.');
end
end
