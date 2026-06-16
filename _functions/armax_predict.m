function y_pred = armax_predict(h, y_hist, coeff, labels, resid_hist, options)
%armax_predict Forecasts from an ARMAX model.
%
%   SYNTAX:
%   y_pred = armax_predict(h, y_hist, coeff, labels, resid_hist)
%   y_pred = armax_predict(h, y_hist, coeff, labels, resid_hist, 'X_hist', Xh, 'X_future', Xf, 'px', px_lags)
%
%   DESCRIPTION:
%   This function generates h-step-ahead point forecasts from an ARMA or
%   ARMAX model previously estimated using the 'armax.m' function. It uses
%   the estimated coefficients and historical data to recursively produce
%   out-of-sample predictions.
%
%   INPUTS:
%   h             - A positive integer specifying the forecast horizon.
%   y_hist        - A (T x 1) column vector of the historical time series
%                   data used for estimation.
%   coeff         - A vector of estimated coefficients from 'armax.m'.
%   labels        - A string array of coefficient labels from 'armax.m'.
%                   Used to parse the model structure.
%   resid_hist    - A vector of historical residuals from 'armax.m'.
%
%   OPTIONAL NAME-VALUE PAIR ARGUMENTS:
%   'X_hist'      - A (T x N) matrix of historical exogenous variables used
%                   during estimation. Required if the model is ARMAX.
%   'X_future'    - A (h x N) matrix of *future* values for the exogenous
%                   variables. This is required for out-of-sample ARMAX
%                   forecasting.
%   'px'          - An (N x 1) vector of lags for each exogenous series,
%                   consistent with the 'armax.m' estimation. Required if
%                   the model is ARMAX.
%
%   OUTPUTS:
%   y_pred        - An (h x 1) column vector of forecasts.
%
%   EXAMPLE 1: ARMA(2,1) Forecast
%   y = filter([1, 0.5], [1, -0.8, 0.1], randn(200,1));
%   [c, l, ~, r] = armax(y, 2, 1);
%   y_forecast = armax_predict(10, y, c, l, r);
%   plot([y; y_forecast]); legend('Historical Data', 'Forecast');
%
%   EXAMPLE 2: ARMAX(1,1,1) Forecast
%   X = randn(200, 1);
%   y = 5 + 0.7*lag(y) + 0.5*X + randn(200,1);
%   [c, l, ~, r] = armax(y, 1, 1, X, 0);
%   X_future_values = randn(10, 1); % We must provide future X
%   y_forecast = armax_predict(10, y, c, l, r, 'X_hist', X, ...
%                'X_future', X_future_values, 'px', 0);
%

% --- 1. Input Validation and Defaults ---
arguments
    h (1,1) double {mustBeInteger, mustBePositive}
    y_hist (:,1) double {mustBeNumeric, mustBeVector}
    coeff (:,1) double {mustBeNumeric, mustBeVector}
    labels (:,1) string
    resid_hist (:,1) double {mustBeNumeric, mustBeVector}
    options.X_hist (:,:) double {mustBeNumeric}
    options.X_future (:,:) double {mustBeNumeric}
    options.px (:,1) double {mustBeInteger, mustBeNonnegative}
end

% Custom validation for ARMAX case
is_armax = isfield(options, 'X_hist');
if is_armax
    is_armax = ~isempty(options.X_hist);
end
if is_armax
    if ~isfield(options, 'X_future') || ~isfield(options, 'px')
        error('For ARMAX models, ''X_hist'', ''X_future'', and ''px'' must all be provided.');
    end
    if size(options.X_future, 1) ~= h
        error('The number of rows in ''X_future'' must equal the forecast horizon h.');
    end
    if size(options.X_hist, 2) ~= size(options.X_future, 2)
        error('The number of columns in ''X_hist'' and ''X_future'' must match.');
    end
    if size(options.X_hist, 2) ~= length(options.px)
        error('The length of ''px'' must match the number of columns in ''X_hist''.');
    end
end

% --- 2. Parse Coefficients and Model Structure from Labels ---
c        = coeff(labels == "const");
phi      = coeff(startsWith(labels, "ar_"));
theta_ma = coeff(startsWith(labels, "ma_"));
beta     = coeff(startsWith(labels, "beta_"));

p = length(phi);
q = length(theta_ma);

% --- 3. Prepare Data for Recursive Forecasting ---
T_y = size(y_hist, 1);
T_resid = size(resid_hist, 1);
T_hist = min([T_y, T_resid]);
if is_armax
    T_X = size(options.X_hist, 1);
    T_hist = min([T_hist, T_X]);
end

% Append space for forecasts. Future values are initially NaN
y_full = [y_hist(end-T_hist+1:end); nan(h, 1)];

% Future unknown shocks are zero
resid_full = [resid_hist(end-T_hist+1:end); zeros(h, 1)];

% Prepare lagged exogenous matrix if it's an ARMAX model
Xlag_full = [];
if is_armax
    X_full = [options.X_hist(end-T_hist+1:end,:); options.X_future];
    px = options.px;
    N_exog = size(X_full, 2);
    
    Xlag_full = nan(T_hist + h, sum(1+px));
    col_idx = 1;
    for i = 1:N_exog
        for lag = 0:px(i)
            Xlag_full(:, col_idx) = [nan(lag,1); X_full(1:end-lag, i)];
            col_idx = col_idx + 1;
        end
    end
end

if size(Xlag_full, 2) ~= length(beta)
error('The number of columns in X_hist and X_future must match ''sum(1+px)''.');
end

% --- 4. Perform Recursive Forecasting ---
for t = 1:h
    current_idx = T_hist + t;
    
    % a) AR part: uses historical y and previously forecasted y
    ar_part = 0;
    if p > 0
        % flip to align coefficients with lagged data
        ar_part = dot(flip(phi), y_full(current_idx-p : current_idx-1));
    end
    
    % b) MA part: uses historical residuals and zeros for future residuals
    ma_part = 0;
    if q > 0
        ma_part = dot(flip(theta_ma), resid_full(current_idx-q : current_idx-1));
    end
    
    % c) Exogenous part: uses the future X values
    exog_part = 0;
    if is_armax
        exog_part = Xlag_full(current_idx, :) * beta;
    end
    
    % d) Combine parts to get the forecast for the current step
    y_forecast_t = c + ar_part + ma_part + exog_part;
    
    % e) Store the forecast in the full y vector so it can be used for the next step
    y_full(current_idx) = y_forecast_t;
end

% --- 5. Extract and Return the Forecasts ---
y_pred = y_full(T_hist+1 : end);

end