function [m_s,P_s,PP_s] = fis_ARDL(m_u,P,P_u,B,KZ_end)
% fis()    Fixed interval smoother for an ARDL model;
%
% Syntax:
%   [m_s,P_s,PP_s] = fis(m_u,P,P_u,KZ_end)
%
% For more information, see Harvey (1989) 'Forecasting, structural time
% series models and the Kalman filter', Chapter 3, and Shumway and 
% Stoffer (1988, 2000).

T = size(m_u,2);      % Number of data points;
M = size(m_u,1);      % Number of state variables;

m_s = NaN(M,T);             % Smoothed estimates of states;
P_s = NaN(M,M,T);           % Smoothed estimation MSE;
P_star = NaN(M,M,T-1);      % Auxiliary matrix;
PP_s = NaN(M,M,T);          % Smoothed one-period lagged estimation MSE;

% Starting (ending) values:
m_s(:,T) = m_u(:,T);
P_s(:,:,T) = P_u(:,:,T);
P_star(:,:,T-1) = P_u(:,:,T-1)*B'*pinv(P(:,:,T));

PP_s(:,:,1) = zeros(M,M);
PP_s(:,:,T) = (eye(M) - KZ_end)*B*P(:,:,T);

% Smoothing algorithm:
for t = T-1:-1:1
    
    m_s(:,t) = m_u(:,t) + P_star(:,:,t)*(m_s(:,t+1) - B*m_u(:,t));
    P_s(:,:,t) = P_u(:,:,t) + P_star(:,:,t)*(P_s(:,:,t+1) - ...
        P(:,:,t+1))*P_star(:,:,t)';
    
    if t > 1
        P_star(:,:,t-1) = P_u(:,:,t-1)*B'*pinv(P(:,:,t));
        PP_s(:,:,t) = P(:,:,t)*P_star(:,:,t-1)' + ...
            P_star(:,:,t)*(PP_s(:,:,t+1) - B*P(:,:,t))*P_star(:,:,t-1)';
    end

    % NOTE: cf. Shumway and Stoffer (1988) for the formulas of PP_s
    % (including the initial value).

end

end
