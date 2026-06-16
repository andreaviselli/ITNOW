function data = ITNOWReadTableQuiet(varargin)
%ITNOWReadTableQuiet Read a table while suppressing known header-normalization noise.

state = warning("off", "MATLAB:table:ModifiedAndSavedVarnames");
cleanup = onCleanup(@() warning(state));
data = readtable(varargin{:});
end
