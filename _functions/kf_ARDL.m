function [P,P_u,m,m_u,e,V,X_hat,KZ_end,logL,id_X] = kf_ARDL(X,Z,B,H,Q,m_0,P_0,Z_obs,beta)
% kf()    Kalman filter algorithm likelihood function computation.
%
% Syntax:
%   [P,P_u,m,m_u,e,V,X_hat,logL,id_X] = kf(X,Z,B,H,Q,m_0,P_0,Z_obs,N_q)
%
% For information regarding the notation, see Harvey (1989) 'Forecasting,
% structural time series models and the Kalman filter', Chapter 3. Note
% that the covariance matrices of the measurement and state errors H and 
% Q, respectively, must be provided as upper triangular matrices if the
% there are nonzero cross-covariances.

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

T = size(X,2);          % Number of data points;
N = size(X,1);          % Number of observed variables;
M = size(B,1);          % Number of state variables;
Mobs = size(beta,1);    % Number of observable variables;

P = NaN(M,M,T);         % Estimation error covariance;
P_u = NaN(M,M,T);       % Estimation error covariance update;

m = NaN(M,T);           % States' optimal estimator;
m_u = NaN(M,T);         % States' update;

id_X = cell(1,T);       % Index of complete obs. (for each period);
e = cell(1,T);          % Prediction error;
V = cell(1,T);          % Prediction error (MSE) covariance;

X_hat = NaN(N,T);       % Forecasts of observable variables;

logL = zeros(T,1);      % Log-likelihood vector;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% KALMAN FILTER ITERATIONS

% Replace missing observations with zeros;
Z_obs(isnan(Z_obs)) = 0;

for t = 1:T
    
    % Replace the observable variables;
    if ~isempty(Z_obs)
        B(1,end-Mobs+1:end) = Z_obs(:,t);
    end
    
    % Prediction equations;
    if t == 1
        m(:,t) = B*m_0;
        P(:,:,t) = B*P_0*B'+Q;
    else
        m(:,t) = B*m_u(:,t-1);
        P(:,:,t) = B*P_u(:,:,t-1)*B'+Q;
    end

    % Index of missing data;
    id_X{t} = find(~isnan(X(:,t)));
    id_X_t = id_X{t};
    
    % Prediction, prediction error, and prediction MSE;

    X_hat(:,t) = Z*m(:,t);
    X_t_hat = X_hat(id_X_t,t);

    % NOTE: X_t_hat only includes predictions for the variables that do
    % not have missing values at time t. This is necessary to compute
    % the prediction error decomposition.
    
    e{t} = X(id_X_t,t)-X_t_hat;
    V{t} = Z(id_X_t,:)*P(:,:,t)*Z(id_X_t,:)'+H(id_X_t,id_X_t);

    % NOTE: e (prediction error) and V (prediction MSE) may have
    % time-varying dimensions due to missing data.

    % Likelihood & updating;
    if all(isnan(X(:,t)))
        
        % Updates (equal to predicted);
        m_u(:,t) = m(:,t);
        P_u(:,:,t) = P(:,:,t);

    else

        % Update equations;
        m_u(:,t) = m(:,t) + P(:,:,t)*Z(id_X_t,:)'/V{t}*e{t};
        P_u(:,:,t) = P(:,:,t) - P(:,:,t)*Z(id_X_t,:)'/V{t}*Z(id_X_t,:)*P(:,:,t);
        
        % Dealing with eventual ill-conditioning
        % in the updated covariance matrix of the 
        % prediction error:
        P_u(:,:,t) = 1/2*(P_u(:,:,t)+P_u(:,:,t)');
        
        % Time (t) log-likelihood;
        logL(t) = log(det(V{t}))+e{t}'/V{t}*e{t};
        
    end
    
    % NOTE: computation of the log-likelihood and update equations accounts
    % for the case of absence of new observations. This way the algorithm 
    % effectively returns a pseudo-likelihood.

end

% (Total) log-likelihood:
logL = -0.5*sum(logL);

% Last-period Kalman gain:
id_X_T = id_X{T};
K_end = B*P(:,:,T)*Z(id_X_T,:)'/V{T};
KZ_end = K_end*Z(id_X_T,:);

% NOTE: the end-of-the-period Kalman gain is necessary to initialize the
% smoothing algorithm (cf. the function "fis").
