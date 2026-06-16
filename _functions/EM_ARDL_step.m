function [m_0,P_0,Z,B,H,Q,beta,logL] = EM_ARDL_step(X,Z,B,H,Q,m_0,P_0,beta,Z_obs)
% EM_ARDL_step()    Expectation-Maximization (EM) step for ARDL models.
%
% Description:
%   This function executes the expectation and maximization steps of
%   the EM algorithm for estimation of autoregressive distributed lag
%   (ARDL) models cast in state space form. Notice that this model does 
%   not aggregate by default flow variables at lower frequencies (e.g. 
%   á la Mariano and Murasawa, 2003).


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% EXPECTATION STEP

% Kalman filtering:
[P,P_u,~,m_u,~,~,~,K_end,logL,~] = kf_ARDL(X,Z,B,H,Q,m_0,P_0,Z_obs,beta);

% Kalman smoothing:
[m_s,~,~] = fis_ARDL(m_u,P,P_u,B,K_end);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Preliminaries:

M = size(B,1);              % Number of state variables;
Mobs = size(beta,1);        % Number of observable variables;
p = sum(B(1,1:M-Mobs)~=0);  % Lags of the dependent variable;

% Replace missing observations with zeros;

Z_obs(isnan(Z_obs)) = 0;

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% MAXIMIZATION STEP

d = ~isnan(X);
yd = X(d)';

W = [Z_obs(1,:);m_s(2:2+p-1,:);Z_obs(2:end,:)]';
Wd = W(d,:);

b = (Wd'*Wd)\(Wd'*yd);    % sub X with y (all programs)

% Update B and beta:

B(1,1:p) = b(2:2+p-1);
beta = b([1,2+p:M-1]);

% Update Q:

Q = var(yd-Wd*b);
Q = diag([Q,zeros(1,M-1)]);

% Update H:

H = 0;

% Update the starting values:

m_0 = [mean(m_s(1:M-Mobs,:),2);beta];
B1 = B(1:1+p,1:1+p);
Q1 = Q(1:1+p,1:1+p);
vec_P_0 = (eye((1+p)^2)-kron(B1,B1))\Q1(:);
P_0 = blkdiag(reshape(vec_P_0,1+p,1+p),zeros(Mobs));