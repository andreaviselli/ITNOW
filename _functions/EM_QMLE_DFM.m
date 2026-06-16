function [F_s,Z,B,H,Q,e,X_hat,logL] = EM_QMLE_DFM(vars,q,p,X,Z,B,H,Q,F_0,P_0,F_obs,dispconv,maxiter)
% EM_QMLE_DFM()     Estimation by quasi maximum likelihood.
%
% Description:
%   This function returns the estimates of the dynamic factor
%   model from the quasi maximum likelihood estimator, i.e. by
%   maximum likelihood with the expectation-maximization (EM) 
%   algorithm. For more details, see C. Doz, D. Giannone, and 
%   L. Reichlin. "A quasi–maximum likelihood approach for large, 
%   approximate dynamic factor models." Review of economics and 
%   statistics 94.4 (2012): 1014-1024.
%    
% Format call: [F_s,Z,B,H,Q,e,X_hat,logL] = EM_QMLE_DFM(vars, ...
%                   q,p,X,Z,B,H,Q,F_0,P_0,F_obs,dispconv,maxiter).


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

N_q = vars(2);

logL = [];                      % Vector of log-likelihoods;
logL_p = -inf;                  % Starting value of the log-likelihood;

F_0 = F_0(1,:)';                % Vector of initial states;
F_obs = F_obs';                 % Transpostion of F_obs and X are required 
X = X';                         % by the function running the Kalman filter;

conv = 0;                       % Logical: 1 if converged;

threshold = 1e-5;               % Stopping threshold;
iter = 1;                       % Iteration number;

% Run the EM algorithm:
while (iter < maxiter) && ~conv
    
    % Expectation & Maximization steps:
    [F_0_u,P_0_u,Z_u,B_u,H_u,Q_u,logL_u] = ...
        EM_DFM_step(vars,q,p,X,Z,B,H,Q,F_0,P_0,F_obs);
    
    % Real-valued check:
    if isreal(logL_u)
        
        % Monotonicity check (1st):
        if logL_u > logL_p

            Z = Z_u;
            B = B_u;
            H = H_u;
            Q = Q_u;
            F_0 = F_0_u;
            P_0 = P_0_u;

        end
        
        % Convergence check:
        if iter > 1
            delta_logL = abs(logL_u - logL_p);
            avg_logL = (abs(logL_u) + abs(logL_p) + eps)/2;
    
            if (delta_logL / avg_logL) < threshold
                conv = 1;
            end
        end
        
        % Monotonicity check (2nd):
        if logL_u > logL_p

            logL = [logL logL_u];
            logL_p = logL_u;
            iter =  iter+1;

        else 
            conv = 1;
        end
    end
end


% Convergence message:
if dispconv
    disp(['The EM algorithm has successfully converged at ', ...
        num2str(iter),' iterations.'])
end


% Kalman filter (using the EM estimates):
[P,P_u,~,F_u,e,~,X_hat,K_end,logL,~] = kf_DFM(X,Z,B,H,Q,F_0,P_0,F_obs,N_q);

% Kalman smoother:
[F_s,~] = fis_DFM(F_u,P,P_u,B,K_end);
