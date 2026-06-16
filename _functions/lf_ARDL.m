function logL = lf_ARDL(par0,id_par,inp)
% lf()    Optimization function for the likelihood via Kalman filter.
%
% Syntax:
%   logL = lf(par,id_par)
%
% Description:
%   This function is only a wrapper used to reshape the system matrices 
%   that are input to kf(), that is the Kalman filter function, and then 
%   is optimized by the MATLAB's optimization routine fmincon.

[X,Z_t,Z,B,H,Q,m_0,P_0,beta] = deal(inp.X,inp.Z_t,inp.Z,inp.B,inp.H,inp.Q,inp.m_0,inp.P_0,inp.beta);

% Assemble system matrices;
sm = smReshape_ARDL(par0,id_par,struct('Z',Z,'B',B,'H',H,'Q',Q,'beta',beta));

[Z,B,H,Q,beta] = deal(sm.Z,sm.B,sm.H,sm.Q,sm.beta);

[~,~,~,~,~,~,~,~,logL,~] = kf_ARDL(X',Z,B,H,Q,m_0,P_0,Z_t',beta);
logL = -logL;

% NOTE: the Kalman filter is used to carry out the prediction error
% decomposition. The log-likelihood is computed through the recursions.

% NOTE: the log-likelihood is changed in sign because MATLAB's fmincon
% routine performs minimization of the objective.
end