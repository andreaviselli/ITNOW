function TTW = WinsorizeTimeTable(TT, DateVec, p1, p2)
%WinsorizeTimeTable Winsorizes specified rows of a timetable variable by variable.
%
%   SYNTAX:
%   TTW = WinsorizeTimeTable(TT, DateVec, p1, p2)
%
%   DESCRIPTION:
%   This function applies winsorization to a subset of a timetable, TT.
%   For each numeric variable in TT, it calculates the values at the p1-th
%   and p2-th percentiles based on the *entire* dataset for that variable.
%   It then caps the values that are outside these thresholds, but *only*
%   for the rows corresponding to the dates specified in DateVec. Rows with
%   dates not in DateVec are returned unchanged.
%
%   INPUTS:
%   TT            - A MATLAB timetable with one or more variables.
%   DateVec       - A datetime vector. The dates in this vector specify
%                   which rows of the timetable TT should be winsorized.
%                   These dates must be a subset of TT.Properties.RowTimes.
%   p1            - A scalar numeric value for the lower percentile
%                   (e.g., 5 for the 5th percentile). Must be between 0 and 100.
%   p2            - A scalar numeric value for the upper percentile
%                   (e.g., 95 for the 95th percentile). Must be greater than p1.
%
%   OUTPUTS:
%   TTW           - A new timetable of the same size as TT, with the data
%                   in the specified date range (DateVec) winsorized.
%
%   EXAMPLE:
%   % 1. Create a sample timetable with outliers
%   rng(1); % for reproducibility
%   Dates = datetime('2023-01-01') + calmonths(0:23)';
%   Var1 = 10 + randn(24, 1);
%   Var2 = 50 + 5*randn(24, 1);
%   TT = timetable(Dates, Var1, Var2);
%
%   % Introduce extreme outliers in a specific period
%   TT.Var1(6) = 100;  % Outlier
%   TT.Var1(7) = -50;  % Outlier
%   TT.Var2(6) = 250;  % Outlier
%   disp('Original Timetable (rows 4 to 8):');
%   disp(TT(4:8,:));
%
%   % 2. Define the date range to winsorize (just the two outlier dates)
%   DateVec_to_fix = TT.Dates(6:7);
%
%   % 3. Apply winsorization at the 5th and 95th percentiles
%   TTW = WinsorizeTimeTable(TT, DateVec_to_fix, 5, 95);
%
%   disp('Winsorized Timetable (rows 4 to 8):');
%   disp(TTW(4:8,:));
%   % Note: Only rows 6 and 7 are changed. The other rows are identical.
%

% --- 1. Input Validation ---
arguments
    TT timetable
    DateVec datetime
    p1 (1,1) double {mustBeNumeric, mustBeGreaterThanOrEqual(p1, 0), mustBeLessThanOrEqual(p1, 100)}
    p2 (1,1) double {mustBeNumeric, mustBeGreaterThanOrEqual(p2, 0), mustBeLessThanOrEqual(p2, 100)}
end

% Custom validation to ensure p1 < p2
if p1 >= p2
    error('Input `p1` must be strictly less than `p2`.');
end

% --- 2. Initialization ---

% Create a copy of the input timetable to modify. This is good practice
% to avoid modifying the original variable in the caller's workspace.
TTW = TT;

% Get the names of all variables in the timetable
variable_names = TT.Properties.VariableNames;

% Find the logical indices of the rows that need to be winsorized.
% This is much more efficient than looping through dates.
rows_to_winsorize_mask = ismember(TT.Properties.RowTimes, DateVec);

% Check if any of the dates in DateVec were found in the timetable
if ~any(rows_to_winsorize_mask)
    warning('None of the dates in DateVec were found in the timetable. Returning the original timetable.');
    return;
end

% --- 3. Loop Through Each Variable and Apply Winsorization ---

for i = 1:length(variable_names)
    var_name = variable_names{i};
    
    % Extract the entire column of data for the current variable
    full_data_column = TT.(var_name);
    
    % Skip non-numeric columns, as percentiles are not defined for them
    if ~isnumeric(full_data_column)
        fprintf('Skipping non-numeric variable: %s\n', var_name);
        continue;
    end
    
    % --- Core Logic ---
    
    % a) Calculate percentile thresholds using the ENTIRE dataset.
    %    The prctile function automatically ignores NaNs.
    thresholds = prctile(full_data_column, [p1, p2]);
    lower_threshold = thresholds(1);
    upper_threshold = thresholds(2);
    
    % b) Extract the SUBSET of data that needs to be modified using the
    %    pre-calculated logical mask.
    data_subset_to_modify = TTW.(var_name)(rows_to_winsorize_mask);
    
    % c) Apply capping to this subset.
    %    Find values below the lower threshold and replace them.
    data_subset_to_modify(data_subset_to_modify < lower_threshold) = lower_threshold;
    
    %    Find values above the upper threshold and replace them.
    data_subset_to_modify(data_subset_to_modify > upper_threshold) = upper_threshold;
    
    % d) Place the modified subset back into the correct rows of the
    %    output timetable.
    TTW.(var_name)(rows_to_winsorize_mask) = data_subset_to_modify;
end