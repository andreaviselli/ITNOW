function [coeff, labels, fitted, resid, loglik] = armax(y, p, q, X, px)
%armax estimates ARMA(p,q) or ARMAX(p,q,px) models by Maximum Likelihood,
% enforcing model stationarity and invertibility using the Monahan transformation.
% 
% INPUTS:
%   y  : (T x 1) series of interest
%   p  : AR order
%   q  : MA order
%   X  : (T x N) exogenous series (optional)
%   px : (N x 1) lags for exogenous series (required if X provided). It
%   includes the zero (contemporaneous) lag
% 
% OUTPUTS:
%   coeff  : estimated coefficients (intercept, AR, MA, exogenous)
%   labels : coefficient labels
%   fitted : fitted values
%   resid  : residuals
%   loglik : log-likelihood at optimum

% Ensure column vector
y = y(:);
T = length(y);

if nargin < 4
    X = [];
end
if nargin < 5
    px = [];
end

if ~isempty(X)
    [TX, N] = size(X);
    if TX ~= T
        error('X must have the same number of rows as y');
    end
    if isempty(px) || length(px) ~= N
        error('px must be provided with length equal to columns of X');
    end
    Xlag = nan(T, sum(1+px));
    for i = 1:N
        for lag = 0:px(i)
            Xlag(:, sum(1+px(1:i-1))+lag+1) = [nan(lag,1); X(1:end-lag,i)];
        end
    end
else
    Xlag = [];
end

maxLag = max([p, px]);
y_trim = y(maxLag+1:end);
Xlag_trim = Xlag(maxLag+1:end, :);
T_eff = length(y_trim);

function phi = monahan_inv_transform(kappa)
    % Convert PACF (kappa) to AR coefficients using Levinson-Durbin
    p_ord = length(kappa);
    phi = zeros(p_ord,1);
    PHI = zeros(p_ord);
    for m = 1:p_ord
        phi_m = kappa(m);
        if m > 1
            phi(1:m-1) = PHI(m-1,1:m-1) - phi_m * flip(PHI(m-1,1:m-1));
        end
        phi(m) = phi_m;
        PHI(m,1:m) = phi(1:m);
    end
end

function [nll, e] = arma_nll(theta)
    c = theta(1);
    kappa_raw = theta(2:1+p);
    theta_raw = theta(2+p:1+p+q);
    if ~isempty(Xlag_trim)
        beta = theta(2+p+q:end);
    else
        beta = [];
    end
    
    % Apply tanh to enforce |kappa|<1 (guaranteeing stationarity)
    kappa = tanh(kappa_raw);
    phi = monahan_inv_transform(kappa);
    
    % Apply tanh for MA to enforce invertibility
    theta_ma = tanh(theta_raw);
    
    e = zeros(T_eff,1);
    yhat = zeros(T_eff,1);
    
    for t = 1:T_eff
        ar_part = 0;
        ma_part = 0;
        if p > 0
            for j = 1:min(p,t-1)
                ar_part = ar_part + phi(j)*y_trim(t-j);
            end
        end
        if q > 0
            for j = 1:min(q,t-1)
                ma_part = ma_part + theta_ma(j)*e(t-j);
            end
        end
        exog_part = 0;
        if ~isempty(Xlag_trim)
            exog_part = Xlag_trim(t,:) * beta;
        end

        yhat(t) = c + ar_part + ma_part + exog_part;
        e(t) = y_trim(t) - yhat(t);
    end
    
    sigma2 = mean(e.^2);
    nll = 0.5*T_eff*log(2*pi*sigma2) + 0.5*sum(e.^2)/sigma2;
end

% Initialization
init_theta = [mean(y_trim); zeros(p+q,1)];
if ~isempty(Xlag_trim)
    init_theta = [init_theta; zeros(size(Xlag_trim,2),1)];
end

% Optimization using quasi-Newton
options = optimoptions('fminunc','Display','off','Algorithm','quasi-newton');
[theta_hat,~,~,~] = fminunc(@(theta) arma_nll(theta), init_theta, options);

% Recompute outputs
[nll_final, e] = arma_nll(theta_hat);
loglik = -nll_final;

% Recover estimated parameters
c = theta_hat(1);
kappa = tanh(theta_hat(2:1+p));
phi = monahan_inv_transform(kappa);
theta_ma = tanh(theta_hat(2+p:1+p+q));
if ~isempty(Xlag_trim)
    beta = theta_hat(2+p+q:end);
else
    beta = [];
end
coeff = [c; phi; theta_ma; beta];

labels = strings(length(coeff),1);
labels(1) = "const";
for j = 1:p
    labels(1+j) = "ar_" + j;
end
for j = 1:q
    labels(1+p+j) = "ma_" + j;
end
if ~isempty(Xlag_trim)
    counter = 1;
    for i = 1:N
        for lag = 0:px(i)
            labels(1+p+q+counter) = "beta_" + i + "_lag" + lag;
            counter = counter + 1;
        end
    end
end

% Compute fitted and resid
fitted = y_trim - e;
resid = e;
end
