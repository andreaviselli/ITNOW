function [P,P_u,F,F_u,e,V,X_hat,KZ_end,logL,id_X] = kf_DFM(X,Z,B,H,Q,F_0,P_0,F_obs,N_q)
% kf_DFM()      Kalman filter algorithm.
%
% Descroption:
%   This function operates the prediction error decomposition with the
%   Kalman filter, returning the log-likelihood and initial values for
%   the Kalman smoother. The implementation is based on Harvey (1989),
%   'Forecasting, structural time series models and the Kalman filter', 
%   Chapter 3.
%
% Format call: [P,P_u,F,F_u,e,V,X_hat,KZ_end,logL,id_X] = kf_DFM(X,Z, ...
%                                               B,H,Q,F_0,P_0,F_obs,N_q).   

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

T = size(X,2);          % Number of data points;
N = size(X,1);          % Number of observed variables;
m = size(B,1);          % Number of state variables;

P = NaN(m,m,T);         % Estimation error covariance;
P_u = NaN(m,m,T);       % Estimation error covariance update;

F = NaN(m,T);           % States' optimal estimator;
F_u = NaN(m,T);         % States' update;

id_X = cell(1,T);       % Index of complete obs. (for each period);
e = cell(1,T);          % Prediction error;
V = cell(1,T);          % Prediction error (MSE) covariance;

X_hat = NaN(N,T);       % Forecasts of observable variables;

logL = zeros(T,1);      % Log-likelihood vector;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Filtering algorithm:

for t = 1:T
    
    if ~isempty(F_obs)
        
        % ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
        % NOTE: this could be more general, allowing
        % more than one observable variable).
        % ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
    
        N_obs = size(F_obs,1);
        N_m = N-N_q;
        Z(N_m+1:end,m-N_obs+1:end) = kron(eye(N_q),F_obs(:,t)');
    
    end
    
    % Prediction equations;
    if t == 1
        F(:,t) = B*F_0;
        P(:,:,t) = B*P_0*B'+Q;
    else
        F(:,t) = B*F_u(:,t-1);
        P(:,:,t) = B*P_u(:,:,t-1)*B'+Q;
    end

    % Index of missing data;
    id_X{t} = find(~isnan(X(:,t)));
    id_X_t = id_X{t};
    
    % Prediction, prediction error, and prediction MSE;
    X_hat(:,t) = Z*F(:,t);
    X_t_hat = X_hat(id_X_t,t);
    
    e{t} = X(id_X_t,t)-X_t_hat;
    V{t} = Z(id_X_t,:)*P(:,:,t)*Z(id_X_t,:)'+H(id_X_t,id_X_t);

    % Likelihood & updating;
    if all(isnan(X(:,t)))
        
        % Updates (equal to predicted);
        F_u(:,t) = F(:,t);
        P_u(:,:,t) = P(:,:,t);

        % Time (t) log-likelihood (null);
        logL(t) = 0;

    else

        % Update equations;
        F_u(:,t) = F(:,t) + P(:,:,t)*Z(id_X_t,:)'/V{t}*e{t};
        P_u(:,:,t) = P(:,:,t) - P(:,:,t)*Z(id_X_t,:)'/V{t}*Z(id_X_t,:)*P(:,:,t);
        
        % Dealing with ill-conditionining in the
        % update of the MSE covariance matrix:        
        P_u(:,:,t) = 1/2*(P_u(:,:,t)+P_u(:,:,t)');
        
        % Time (t) log-likelihood;
        logL(t) = log(det(V{t}))+e{t}'/V{t}*e{t};
        
    end
end

% (Total) log-likelihood:
logL = -0.5*sum(logL);

% Last-period Kalman gain:
id_X_T = id_X{T};
K_end = B*P(:,:,T)*Z(id_X_T,:)'/V{T};
KZ_end = K_end*Z(id_X_T,:);