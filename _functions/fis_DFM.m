function [F_s,P_s,PP_s] = fis_DFM(F_u,P,P_u,B,KZ_end)
% fis_DFM()      Smoothing algorithm (fixed interval smoothing).
%
% Description:
%   This function runs the fixed interval smoother from the pre-
%   vious output of the Kalman filter. The implementation is ba-
%   sed on Harvey (1989), 'Forecasting, structural time series 
%   models and the Kalman filter', Chapter 3.
%
% Format call: [F_s,P_s,PP_s] = fis_DFM(F_u,P,P_u,B,KZ_end).

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

T = size(F_u,2);            % Number of data points;
m = size(F_u,1);            % Number of state variables;

F_s = NaN(m,T);             % Smoothed estimates of states;
P_s = NaN(m,m,T);           % Smoothed estimation MSE;
P_star = NaN(m,m,T-1);      % Auxiliary matrix;
PP_s = NaN(m,m,T);          % Smoothed one-period lagged estimation MSE;

F_s(:,T) = F_u(:,T);
P_s(:,:,T) = P_u(:,:,T);
P_star(:,:,T-1) = P_u(:,:,T-1)*B'*pinv(P(:,:,T));

PP_s(:,:,1) = zeros(m,m);
PP_s(:,:,T) = (eye(m) - KZ_end)*B*P(:,:,T);

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Smoothing algorithm:

for t = T-1:-1:1
    
    F_s(:,t) = F_u(:,t) + P_star(:,:,t)*(F_s(:,t+1) - B*F_u(:,t));
    P_s(:,:,t) = P_u(:,:,t) + P_star(:,:,t)*(P_s(:,:,t+1) - ...
        P(:,:,t+1))*P_star(:,:,t)';
    
    if t > 1
        P_star(:,:,t-1) = P_u(:,:,t-1)*B'*pinv(P(:,:,t));
        PP_s(:,:,t) = P(:,:,t)*P_star(:,:,t-1)' + ...
            P_star(:,:,t)*(PP_s(:,:,t+1) - B*P(:,:,t))*P_star(:,:,t-1)';
    end
end
