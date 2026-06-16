function [f, Lambda, eigvals, mean_x, std_x] = PCA(x, k, y)
% Estimate factors by principal components.
%
% Reference: Stock and Watson, 2002b; Forecasting Using 
% Principal Components From a Large Number of Predictors; 
% Journal of the American Statistical Association.
%
% Inputs:
%   x   : T x N matrix of time series
%   y   : T x 1 series for identification
%   k   : number of factors to extract
%
% Outputs:
%   f       : T x k matrix of estimated factors
%   Lambda  : N x k matrix of factor loadings
%   eigvals : k x 1 vector of top k eigenvalues
%   mean_x  : 1 x N vector of means of x
%   std_x   : 1 x N vector of std devs of x

[~, N] = size(x);

% Standardize series
mean_x = mean(x, 1);
std_x = std(x, 0, 1);
x = (x - mean_x) ./ std_x;

% Compute the series covariance matrix
S = (x' * x) / N;

% Eigen-decomposition
[V, D] = eig(S);
[eigvals, idx] = sort(diag(D), 'descend');
V = V(:, idx);
eigvals = eigvals(1:k);

% Select k factors
Lambda = V(:, 1:k);         % N x k

% Compute factors [NO re-scaling as: (x * Lambda) / N]
f = (x * Lambda);           % T x k

% Optional: ensure y loads positively on first factor
if nargin > 2 && ~isempty(y)
    corr1 = corr(f(:,1), y);
    if corr1 < 0
        Lambda(:,1) = -Lambda(:,1);
        f(:,1) = -f(:,1);
    end
end
