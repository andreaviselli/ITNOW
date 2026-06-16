function [m_s,Z,B,H,Q,beta,e,X_hat,logL] = MLE_ARDL(X,Z,B,H,Q,m_0,P_0,beta,Z_obs)
% MLE_ARDL()    Estimation of ARDL models by maximum likelihood.
%
% Description:
%   This function performs estimation of autoregressive distributed 
%   lag (ARDL) models by maximum likelihood (MLE) using the Matlab 
%   routine 'fmincon' and the Interior-Point Algorithm where the 
%   Hessian computed using the 'bfgs' or dense quasi-Newton approxi-
%   mation. The user might change the optimization algorithm through
%   the object 'options' in the code hereafter, see the Matlab docu-
%   mentation on 'fmincon' and the main function 'ardl.m' for more
%   information.


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Collect the free parameters:
all_par = [Z(:);B(:);H(:);Q(:);beta];
id_par = all_par == 0 | all_par == 1;
par0 = all_par(~id_par);

% Create the structures as inputs for the optimization:
inp = struct('X',X,'Z_t',Z_obs,'Z',Z,'B',B,'H',H,'Q',Q,'m_0',m_0,'P_0',P_0,'beta',beta);
sm = struct('Z',Z,'B',B,'H',H,'Q',Q,'beta',beta);

% Number of parameters:
N_p = length(par0);

% Set the parameters domain:

idVariance = ismember(par0,H) | ismember(par0,Q);
%idCoeff = ismember(par0,B) | ismember(par0,Z);

lb = -Inf*ones(N_p,1);          % Lower bounds
lb(idVariance) = 0;             % (0 for variances);
ub = Inf*ones(N_p,1);           % Upper bounds;
   
% Maximize the log-likelihood, after choosing
% appropriate settings, using fmincon(•):

options = optimset('display','off');        
objfun = @(par)lf_ARDL(par,id_par,inp);
[par_hat,~] = fmincon(objfun,par0,[],[],[],[],lb,ub,[],options);

% Assemble back the estimated system matrices;

sm = smReshape_ARDL(par_hat,id_par,sm);
[Z,B,H,Q,beta] = deal(sm.Z,sm.B,sm.H,sm.Q,sm.beta);

% Kalman filter:
[P,P_u,~,m_u,e,~,X_hat,KZ_end,logL,~] = kf_ARDL(X',Z,B,H,Q,m_0,P_0,Z_obs',beta);

% Kalman smoother:
[m_s,~] = fis_ARDL(m_u,P,P_u,B,KZ_end);