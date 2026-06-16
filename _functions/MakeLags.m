function Ylag = MakeLags(y, l)
%MAKELAGS Generate a matrix of lags of a time series.
%
%   Ylag = makeLags(y, l)
%
% INPUTS:
%   y : T×N numeric matrix or vector
%       - Each column is a separate time series (T observations, N variables).
%   l : integer scalar ≥ 1
%       - Number of lags to generate.
%
% OUTPUT:
%   Ylag : T×(N*l) numeric matrix
%       - Columns contain lagged versions of y:
%           [y(t-1)  y(t-2)  ...  y(t-l)]
%       - For multiple series, lags are stacked by variable:
%           [y1(t-1:l)  y2(t-1:l)  ...]
%       - Missing entries are filled with NaN.
%
% EXAMPLE:
%   y = (1:5)';             % [1;2;3;4;5]
%   Ylag = makeLags(y, 2);  % → [NaN NaN; 1 NaN; 2 1; 3 2; 4 3]
%
% SEE ALSO: lagmatrix (Econometrics Toolbox)

    if nargin < 2
        error('makeLags requires two inputs: y and l.');
    end
    if ~ismatrix(y) || ~isnumeric(y)
        error('Input y must be a numeric vector or matrix.');
    end
    if ~isscalar(l) || l < 1 || l ~= floor(l)
        error('l must be a positive integer scalar.');
    end

    [T, N] = size(y);
    Ylag = NaN(T, N*l);

    for i = 1:l
        Ylag(i+1:end, N*(i-1)+1:N*i) = y(1:end-i, :);
    end
end
