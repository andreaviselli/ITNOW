function [y_hat_comb, weights, topK_idx] = topk_bg_step( ...
    y, y_hat, t, h, K, nu, m, varargin)
% TOPK_BG_STEP Combine forecasts by selecting top-K models and weighting them
% using the Bates & Granger (1969) combination scheme.
%
% This version finds the most recent available (non-missing) target observation
% at or before t+h, then steps back in steps of m to collect the last nu observed
% target times. That handles the case where some target timestamps are missing.
%
% INPUT / OPTIONS summary (short):
%   y      : (T_obs x 1) observed target series (column vector). May contain NaN.
%   y_hat  : (T_forecast x N) forecasts; y_hat(s,i) is the forecast produced at
%            time s for y(s+h).
%   t      : scalar integer, combine time (we will use y_hat(t,:) to combine).
%   h      : horizon (integer, >= 0). h=0 for nowcasts.
%   K      : number of top models to keep.
%   nu     : number of observed target points to use.
%   m      : optional frequency mismatch (positive integer). If omitted or empty, m=1.
%
% Name/value options:
%   'weightType' : 'invSSE' (default) or 'invSqSum'
%   'eps'        : regularizer (default 1e-6)
%
% OUTPUTS:
%   y_hat_comb : scalar combined forecast for y(t+h)
%   weights    : (N x 1) weights (zero for non-selected models)
%   topK_idx   : indices (K x 1) of selected models
%
% Example:
%   [yhat, w, idx] = topk_bg_step(y, y_hat, 100, 0, 3, 4, 3, 'weightType','invSSE');

%% --------- parse optional args and defaults ----------
if nargin < 7 || isempty(m)
    m = 1;
end

p = inputParser;
validWt = @(s) ischar(s) && any(strcmp(s,{'invSSE','invSqSum'}));
addParameter(p,'weightType','invSSE', validWt);
addParameter(p,'eps',1e-6, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
parse(p,varargin{:});
weightType = p.Results.weightType;
eps_small  = p.Results.eps;

%% --------- basic checks ----------
if ~iscolumn(y)
    error('y must be a column vector (T_obs x 1).');
end
[T_fcast, N] = size(y_hat);
Tobs = length(y);

if ~(isscalar(t) && t==floor(t) && t>=1)
    error('t must be a positive integer.');
end
if ~(isscalar(h) && h==floor(h) && h>=0)
    error('h must be a non-negative integer.');
end
if ~(isscalar(K) && K==floor(K) && K>=1)
    error('K must be a positive integer.');
end
if ~(isscalar(nu) && nu==floor(nu) && nu>=1)
    error('nu must be a positive integer.');
end
if ~(isscalar(m) && m==floor(m) && m>=1)
    error('m must be a positive integer.');
end
if K > N
    error('K must be <= number of models N.');
end
if t > T_fcast
    error('t must be <= number of rows in y_hat (T_forecast).');
end

%% --------- find most recent observed target time <= t+h ----------
max_target_idx = min(t + h, Tobs);            % can't exceed available y
% find last non-missing y up to max_target_idx
last_obs = find(~isnan(y(1:max_target_idx)), 1, 'last');

if isempty(last_obs)
    error('No observed target values found at or before t+h = %d.', t+h);
end

% Build the nu target times by stepping back in steps of m from last_obs:
target_times = last_obs - (0:(nu-1))*m;   % 1 x nu, descending
if min(target_times) < 1
    error(['Not enough historical observed target values spaced by m=%d. ', ...
           'Earliest required target index would be %d.'], m, min(target_times));
end

% Corresponding forecast rows (when those forecasts were produced)
recent_rows = target_times - h;           % these are integers indicating rows in y_hat
if any(recent_rows < 1) || any(recent_rows > T_fcast)
    error(['Corresponding forecast rows (target_times - h) must be within 1..%d. ', ...
           'Check alignment of y and y_hat and the chosen h,nu,m.'], T_fcast);
end

% reorder to have most recent first (so E(1,:) = error for most recent target)
% currently target_times = [last_obs, last_obs-m, ...] (descending already),
% so recent_rows align accordingly. For clarity, make them column vectors:
recent_rows = recent_rows(:);   % nu x 1
target_times = target_times(:); % nu x 1

%% --------- construct error matrix E (nu x N) ----------
% E(k,i) = y(target_times(k)) - y_hat(recent_rows(k), i)
E = y(target_times) - y_hat(recent_rows, :);   % nu x N
E(isinf(E)) = NaN;    % treat Inf as missing

%% --------- compute SSE and handle missing ----------
SSE = sum(E.^2, 1, 'omitmissing');   % 1 x N
allMissing = all(isnan(E), 1);       % 1 x N
SSE(allMissing) = NaN;               % mark models with no valid errors as NaN

% sort and pick top-K (models with NaN SSE rank last)
SSE_for_sort = SSE;
SSE_for_sort(isnan(SSE_for_sort)) = Inf;
[~, order] = sort(SSE_for_sort, 'ascend');

%% --------- handle missing forecasts at time t+h ----------
% Available forecasts at time t: y_hat(t,i) must not be NaN
available = find(~isnan(y_hat(t,:)));

% Select top-K among available forecasts
topK_idx = [];
for k = 1:N
    i = order(k);
    if ismember(i, available)
        topK_idx(end+1,1) = i;   %#ok<AGROW>
    end
    if numel(topK_idx) == K
        break
    end
end

% If fewer than K are available, use all that are available
if isempty(topK_idx)
    warning('No available forecasts at time t. Returning NaN.');
end

%% --------- compute raw scores depending on weightType ----------
switch weightType
    case 'invSSE'
        raw = 1 ./ (SSE + eps_small);
    case 'invSqSum'
        raw = sum( 1 ./ (E.^2 + eps_small), 1, 'omitmissing');
end
raw(isnan(raw)) = 0;

%% --------- normalize over selected and valid models ----------
valid = ~isnan(y_hat(t,:))';    % N×1
mask = false(N,1);
mask(topK_idx) = true;

% usable = selected AND valid
usable = mask & valid;

if sum(usable)==0
    warning('No usable forecasts at time t. Returning NaN.')
    y_hat_comb = NaN;
    weights = zeros(N,1);
    return
end

denom = sum(raw(usable));

weights = zeros(N,1);
if denom <= 0
    warning('Denominator <= 0. Using uniform weights over usable models.');
    weights(usable) = 1 / sum(usable);
else
    weights(usable) = raw(usable)' ./ denom;
end

%% --------- combined forecast uses y_hat(t,:) ----------
y_hat_comb = y_hat(t, usable) * weights(usable);