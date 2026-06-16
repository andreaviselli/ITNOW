function [F_0,P_0,Z,B,H,Q,logL] = EM_DFM_step(vars,q,p,X,Z,B,H,Q,F_0,P_0,F_obs)
% EM_DFM_step()     Expectation-Maximization (EM) step for dynamic
%                   factor model estimated by quasi maximum likelihood.
%
% Description:
%   This function executes the expectation and maximization steps
%   as iterations of the algorithm; the parameter updates are com-
%   puted in presence of an arbitrary pattern of missing values a-
%   rising in mixed-frequency factor models. See Bańbura, M. and 
%   Modugno, M. (2014), MAXIMUM LIKELIHOOD ESTIMATION OF FACTOR 
%   MODELS ON DATASETS WITH ARBITRARY PATTERN OF MISSING DATA. J. 
%   Appl. Econ., 29: 133-160.
%
% Format call: [F_0,P_0,Z,B,H,Q,logL] = EM_DFM_step(vars,q,p,X,Z, ...
%                                               B,H,Q,F_0,P_0,F_obs).

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

T = size(X,2);      % Number of time periods;
N = size(X,1);      % Number of observed variables;

N_m = vars(1);      % Number of monthly variables;
N_q = vars(2);      % Number of quarterly variables;

id_m = logical([ones(N_m,1);zeros(N_q,1)]); % Index of monthly variables;
id_q = logical([zeros(N_m,1);ones(N_q,1)]); % Number of quarterly variables;

N_obs = size(F_obs,1);                      % Number of observable factors;


% Quarterly restrictions in the measurement (loadings') matrix:

w = [1; 2; 3; 2; 1];                % Weights on monthly factors;
N_w = length(w);                    % Number of the temporal weights;

Aeq_q = kron([w(2:end),-eye(N_w-1)],eye(q));        % Linear equality constraints;

% Adjust the matrix Aeq_q of restrictions for the presence of
% an arbitrary number of observable factors (when present):

Aeq_q = [Aeq_q, zeros(N_w-1,N_obs*N_q)];
beq_q = zeros(q*(N_w-1),1);                         % Constant terms;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% EXPECTATION STEP

% Kalman filtering:
[P,P_u,~,F_u,~,~,~,K_end,logL,~] = kf_DFM(X,Z,B,H,Q,F_0,P_0,F_obs,N_q);

% Kalman smoothing:
[F_s,P_s,PP_s] = fis_DFM(F_u,P,P_u,B,K_end);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %
    
% MAXIMIZATION STEP, Transition equation, Factors.

qp = q*p;
r = max(p,N_w);

FF_0 = F_s(1:r*q,2:end)*F_s(1:r*q,2:end)' + sum(P_s(1:r*q,1:r*q,2:end),3);
FF_1 = F_s(1:r*q,1:end-1)*F_s(1:r*q,1:end-1)' + sum(P_s(1:r*q, 1:r*q,1:end-1),3);
FF_01 = F_s(1:r*q,2:end)*F_s(1:r*q,1:end-1)' + sum(PP_s(1:r*q,1:r*q,:),3);

B_1 = FF_01(1:q,1:qp)/(FF_1(1:qp,1:qp));               % VAR(p);
Q_1 = (1/T)*(FF_0(1:q,1:q) - B_1*FF_01(1:q,1:qp)');    % Covariance of errors;

B(1:q,1:qp) = B_1;                                     % Updates;
Q(1:q,1:q) = Q_1;
P_0(1:r*q,1:r*q) = P_s(1:r*q,1:r*q,1);

% NOTE: FF_0, FF_1, FF_01 are parts of Eq. 6 and 8 in BM2010;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %
    
% MAXIMIZATION STEP, Transition equation, Idiosyncratic terms.

FF_0 = diag(diag(F_s(r*q+1:end-N_obs*N_q,2:end)*F_s(r*q+1:end-N_obs*N_q,2:end)')) + ...
    diag(diag(sum(P_s(r*q+1:end-N_obs*N_q,r*q+1:end-N_obs*N_q,2:end),3)));
FF_1 = diag(diag( F_s(r*q+1:end-N_obs*N_q,1:end-1)*F_s(r*q+1:end-N_obs*N_q,1:end-1)')) + ...
    diag(diag(sum(P_s(r*q+1:end-N_obs*N_q,r*q+1:end-N_obs*N_q,1:end-1),3)));
FF_01 = diag(diag( F_s(r*q+1:end-N_obs*N_q, 2:end)*F_s(r*q+1:end-N_obs*N_q, 1:end-1)')) + ...
    diag(diag(sum(PP_s(r*q+1:end-N_obs*N_q,r*q+1:end-N_obs*N_q,:),3)));

B_2 = FF_01*diag(1./diag((FF_1)));
Q_2 = (1/T)*(FF_0 - B_2*FF_01');


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% MAXIMIZATION STEP, Observation equation, Monthly variables.
    
denom = zeros(N_m*q,N_m*q);
nom = zeros(N_m,q);

for t = 1:T-1
    X_m_t = X(id_m,t);
    W_t = diag(~isnan(X_m_t));
    X_m_t(isnan(X_m_t)) = 0;

    denom = denom + kron(F_s(1:q,t+1)*F_s(1:q,t+1)' + P_s(1:q,1:q,t+1),W_t);
    nom = nom + W_t*X_m_t*F_s(1:q,t+1)';
end

Z_vec = denom\nom(:);
Z(id_m,1:q) = reshape(Z_vec,N_m,q);    
    

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% MAXIMIZATION STEP, Observation equation, Quarterly (flow) variables
% (notice that all quarterly variables are assumed to be flow variables).

id_q = find(id_q);
for j = id_q
    
    % Initialize the quantities needed to compute the least square
    % estimator, for each row associated to a quarterly variable:
    denom = zeros(q*N_w+N_obs*N_q,q*N_w+N_obs*N_q);
    nom = zeros(1,q*N_w+N_obs*N_q);            
       
    jj = j-N_m;                              % Index of quarterly variable;
    e_q_j = q*r+N_w*(jj-1)+1:q*r+N_w*jj;     % Index of idiosyncratic terms;
    
    % Update the system matrices:
    P_0(e_q_j,e_q_j) = P_s(e_q_j,e_q_j,1);
    Q(e_q_j(1),e_q_j(1)) = Q_2(e_q_j(1)-q*r,e_q_j(1)-q*r);
    
    % Indices of latent and observable factors:
    id_F_s_obs = [1:N_w*q, e_q_j(end)+1:e_q_j(end)+N_q*N_obs];
    
    for t = 1:T-1
        X_q_t = X(id_q,t);
        W_t = diag(~isnan(X_q_t));
        X_q_t(isnan(X_q_t)) = 0;
              
        denom = denom + kron(F_s(id_F_s_obs,t+1)*F_s(id_F_s_obs,t+1)' + ...
            P_s(id_F_s_obs,id_F_s_obs,t+1),W_t);
        nom = nom + W_t*X_q_t*F_s(id_F_s_obs,t+1)';

    end
    
    % Update the measurement matrix:
    Z_q_j = denom\nom';
    Z_q_j_r = Z_q_j - denom\Aeq_q'/(Aeq_q/denom*Aeq_q')*(Aeq_q*Z_q_j-beq_q);
    Z(j,id_F_s_obs) = Z_q_j_r;

end

% The final output of Z given by this program does not show 
% the last value (i.e. at time T) of the observable factors 
% because the Kalman filter does not return a new Z where 
% this parameter is updated.

H_p = H;                        % Measurement error covariance matrix (previous step);
H = zeros(N,N);                 % Measurement error covariance matrix;
for t = 1:T-1
    X_t = X(:,t);
    W_t = diag(~isnan(X_t));
    X_t(isnan(X_t)) = 0;
    
    % Update the measurement error covariance matrix:
    H = H + (X_t - W_t*Z*F_s(:,t+1))*(X_t - W_t*Z*F_s(:,t+1))' + ...
            W_t*Z*P_s(:,:,t+1)*Z'*W_t + (eye(N)-W_t)*H_p*(eye(N)-W_t);
end    

H_diag = (1/T)*diag(H);
H_diag(H_diag<1e-02) = 1e-02;   % Ensure non-zero variance;
H_diag(N_m+1:end) = 1e-04;      % Impose a small value;
H = diag(H_diag);

% Update the factor initial value;
F_0 = F_s(:,1);

end
