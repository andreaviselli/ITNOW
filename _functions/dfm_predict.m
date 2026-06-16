function [X_pred, F_pred] = dfm_predict(out, options)
%dfm_predict forecast and backcast from a Dynamic Factor Model.
%
%   SYNTAX:
%   [X_pred, F_pred] = dfm_predict(out)
%   [X_pred, F_pred] = dfm_predict(out, 'hAhead', 5)
%   [X_pred, F_pred] = dfm_predict(out, 'hAhead', 5, 'hBack', 3)
%
%   DESCRIPTION:
%   This is a post-estimation function that generates h-step-ahead forecasts,
%   a nowcast, and backcasts for a dynamic factor model previously estimated
%   using the 'dfm.m' function.
%
%   INPUTS:
%   out           - The output structure from the main estimation function 'dfm.m'.
%                   It must contain the estimated parameters (Z, B) and the
%                   smoothed factors (F).
%
%   OPTIONAL NAME-VALUE PAIR ARGUMENTS:
%   'hAhead'      - A non-negative integer specifying the number of steps
%                   ahead for the forecasts. A nowcast (h=0) is always produced.
%                   (Default: 0)
%   'hBack'       - A non-negative integer specifying the number of steps
%                   back for the backcasts.
%                   (Default: 0)
%
%   OUTPUTS:
%   X_pred        - An N x (hBack + 1 + hAhead) matrix of predictions for the
%                   observable variables, where N is the number of variables.
%                   The columns correspond to time points from t-hBack to t+hAhead.
%   F_pred        - An m x (hBack + 1 + hAhead) matrix of the underlying
%                   factors, where m is the number of factors. The columns
%                   correspond to the same time points as X_pred.
%
%   EXAMPLE:
%   % Create a dummy 'out' structure for a model with N=10, m=2 factors
%   T = 100; N = 10; m = 2; p = 1;
%   out.Z = randn(N, m);      % Loading matrix
%   out.B = [0.8 0; 0 0.5];   % Transition matrix
%   out.F = randn(T, m);      % Smoothed factors
%
%   % Generate a 3-step-ahead forecast and a 2-step backcast
%   [X_predictions, F_predictions] = dfm_predict(out, 'hAhead', 3, 'hBack', 2);
%
%   % The output X_predictions will be a 10x6 matrix for times:
%   % [t-2, t-1, t (nowcast), t+1, t+2, t+3]
%

% --- 1. Input Validation and Defaults ---
arguments
    out (1,1) struct
    options.hAhead (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    options.hBack (1,1) double {mustBeInteger, mustBeNonnegative} = 0
end

% --- 2. Initialization ---
% Extract necessary parameters and data from the input structure
Z = out.Z;          % Loading matrix
B = out.B;          % Transition matrix
F_s = out.F';       % Smoothed factors (m x T), transposed for state-space form

% Get dimensions
[N, m] = size(Z);   % N variables, m factors
T = size(F_s, 2);   % Number of time periods in the smoothed factors

% Extract horizon values from the options
hAhead = options.hAhead;
hBack = options.hBack;

% --- 3. Compute Backcasts (for t-hBack, ..., t-1) ---
if hBack > 0
    % Ensure we don't request more backcasts than available data
    if hBack >= T
        error('hBack (%d) must be smaller than the number of time periods in the data (%d).', hBack, T);
    end
    
    % Identify the indices of the smoothed factors needed for backcasting
    backcast_indices = (T - hBack) : (T - 1);
    
    % Extract the relevant historical factors
    F_back = F_s(:, backcast_indices);
    
    % Compute the backcasted observable variables
    X_back = Z * F_back;
else
    % If no backcast is requested, create empty matrices
    F_back = [];
    X_back = [];
end

% --- 4. Compute Nowcast (t) and Forecasts (t+1, ..., t+hAhead) ---

% Pre-allocate matrix for nowcast and forecasts
% The +1 is for the nowcast at horizon h=0
F_fore = zeros(m, 1 + hAhead);

% The forecast starts from the last available smoothed factor (at time T)
F_fore(:, 1) = F_s(:, end); % This is F_hat(t|T)

% Iterate forward to produce forecasts for horizons h=1 to hAhead
if hAhead > 0
    for h = 1:hAhead
        % State transition: F(t+h) = B * F(t+h-1)
        F_fore(:, 1 + h) = B * F_fore(:, h);
    end
end

% Compute the nowcasted and forecasted observable variables in one step
X_fore = Z * F_fore;

% --- 5. Combine All Predictions ---

% Concatenate backcasted and forecasted factors
F_pred = [F_back, F_fore];

% Concatenate backcasted and forecasted observables
X_pred = [X_back, X_fore];

end