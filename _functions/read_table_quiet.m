function data = read_table_quiet(varargin)
%read_table_quiet Read a table while suppressing known header-normalization noise.

state = warning("off", "MATLAB:table:ModifiedAndSavedVarnames");
cleanup = onCleanup(@() warning(state));
data = readtable(varargin{:});
end
