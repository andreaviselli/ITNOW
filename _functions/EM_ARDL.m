function [m_s,Z,B,H,Q,beta,e,X_hat,logL] = EM_ARDL(X,Z,B,H,Q,m_0,P_0,beta,Z_obs,dispconv,maxiter)
% EM_ARDL   Wrapper for estimation of ARDL models using the EM algorithm.
%
% Description:
%   This function is a wrapper for running estimation of autoregres-
%   sive distributed lag (ARDL) models by Maximum Likelihood (MLE)
%   through the Expectation-Maximization (EM) algorithm. See the main
%   function 'ardl.m' for more information.


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

logL = [];                      % Vector of log-likelihoods;
logL_p = -inf;                  % Starting value of the log-likelihood;

Z_obs = Z_obs';                 % Transpostion of Z_obs and X are required 
X = X';                         % by the function running the Kalman filter;

conv = 0;                       % Logical: 1 if converged;

threshold = 1e-5;               % Stopping threshold;
iter = 1;                       % Iteration number;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% EM algorithm:

while (iter < maxiter) && ~conv
    
    % Expectation & Maximization steps:
    [m_0_u,P_0_u,Z_u,B_u,H_u,Q_u,beta_u,logL_u] = EM_ARDL_step(X,Z,B,H,Q,m_0,P_0,beta,Z_obs);

    Z = Z_u;
    B = B_u;
    H = H_u;
    Q = Q_u;
    beta = beta_u;
    m_0 = m_0_u;
    P_0 = P_0_u;

    % Convergence check:
    if iter > 1
        delta_logL = abs(logL_u - logL_p);
        avg_logL = (abs(logL_u) + abs(logL_p) + eps)/2;

        if (delta_logL / avg_logL) < threshold
            conv = 1;
        end
    end
    
    logL = [logL logL_u];
    logL_p = logL_u;
    iter = iter+1;
    
end


% Convergence message:
if dispconv
    disp(['The EM algorithm has successfully ' ...
        'converged at ',num2str(iter),' iterations.'])
end

% Kalman filter:
[P,P_u,~,m_u,e,~,X_hat,KZ_end,logL,~] = kf_ARDL(X,Z,B,H,Q,m_0,P_0,Z_obs,beta);

% Kalman smoother:
[m_s,~] = fis_ARDL(m_u,P,P_u,B,KZ_end);
