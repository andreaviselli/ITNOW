function [cd, lambda, out] = topk_cd(omega, Sigma, K)
% TOPK_CD   Compute the condition cd = (T > 0) and return 
%           lambda, and T, T1, T2, T3 in a structure.
%
%   Inputs:
%       omega : n×1 vector of weights
%       Sigma : n×n covariance matrix of forecast errors
%       K     : number of forecasts to select
%
%   Outputs:
%       cd    : boolean condition (T > 0)
%       lambda: scalar, double
%       out   : structure with fields T, T1, T2, T3

% Get indices of the K largest weights
[~, maxk_index] = maxk(omega, K);

% Construct indicator vector J (skilled set)
J = zeros(size(omega, 1), 1);
J(maxk_index) = 1;

% Compute lambda
lambda = J' * omega;

% v and u components
v = (J .* omega) ./ (J' * omega);
u = (~J) .* omega;

% Compute T1, T2, T3
T1 = (lambda^2 - 1) * (v' * Sigma * v);
T2 = u' * Sigma * u;
T3 = 2 * lambda * (v' * Sigma * u);

% Total T
T = T1 + T2 + T3;

% Condition
cd = (T > 0);

% Structure output
out = struct('T', T, 'T1', T1, 'T2', T2, 'T3', T3);
