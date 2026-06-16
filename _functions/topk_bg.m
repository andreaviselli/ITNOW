function [y_hat_comb, w] = topk_bg(y, y_hat, h, K, nu, m, varargin)
% TOPK_BG Apply top-K Bates-Granger forecast combination over full sample.
%
% This wrapper applies the topk_bg_step function at each time t where a 
% forecast is available, producing combined forecasts for the entire series 
% and the associated weights.
%
% INPUT / OPTIONS summary (short):
%   y      : (T_obs x 1) observed target series (column vector). May contain NaN.
%   y_hat  : (T_forecast x N) forecasts; y_hat(t,i) is the forecast produced at time t for y(t+h)
%   h      : horizon (integer, >=0). h=0 for nowcasts.
%   K      : number of top models to select at each time.
%   nu     : number of observed target points to use for computing errors.
%   m      : optional frequency step (positive integer). Default is 1.
%
% Name/value options:
%   All options supported by topk_bates_granger are passed through, e.g.:
%     'weightType' : 'invSSE' (default) or 'invSqSum'
%     'eps'        : regularizer (default 1e-6)
%
% OUTPUTS:
%   y_hat_comb : (T_forecast x 1) combined forecast at each time t
%   w          : (T_forecast x N) weights used at each time. Rows sum to 1 over usable models.
%
% EXAMPLE:
%   [Yc, Wc] = topk_bg(y, y_hat, 0, 3, 4, 3, 'weightType','invSSE');

if nargin < 6 || isempty(m)
    m = 1;
end

[T_fcast, N] = size(y_hat);
y_hat_comb = NaN(T_fcast,1);
w = zeros(T_fcast,N);

for t = 1:T_fcast
    try
        [y_hat_comb_t, weights, ~] = topk_bg_step(y, y_hat, t, h, K, nu, m, varargin{:});
        y_hat_comb(t) = y_hat_comb_t;
        w(t,:) = weights';
    catch
        % If topk_bates_granger fails (e.g., not enough historical points), leave NaN
        continue
    end
end