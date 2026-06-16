function [y,Z,B,H,Q,m_0,P_0,beta,Z_obs] = InitCond_ARDL(X,vars,py,xNameStart,xNameEnd)
% InitCond_ARDL()   Initialization of an ARDL model in state space 
%                   form for estimation by MLE or QMLE.
%
% Description:
%   This function returns the system matrices Z, B, and Q used as 
%   initial values for the first recursion of Kalman filter, that
%   is applied to the ARDL model in state space form. See the main
%   function 'ardl.m' for more information.


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Store the data dimensions:

[T,N] = size(X);

% Build the series of data and system variables:

y = X(:,1);                         % Series of data;
Z_obs = [ones(T,1),X];              % Exogenous series;
Z = [1,zeros(1,N)];                 % Measurement matrix;

B = zeros(py+1,py+1);               % Transition matrix;
B(1,1:py) = nan;
B(2:end,1:end-1) = eye(py);

H = 0;                              % Measurement covariance;

% Get the initial values of the
% exogenous and lagged series:
Z0 = nan(size(Z_obs));

% Spline the series to replace
% missing values:

for j = 1:size(Z_obs,2)

    timeAct = find(~isnan(Z_obs(:,j)));
    timeInt = find(~isnan(Z_obs(:,j)),1,"first"):find(~isnan(Z_obs(:,j)),1,"last");
    Z0(timeInt,j) = spline(timeAct,Z_obs(timeAct,j),timeInt);

end

% Imputation of the initial values with xNameStart:
xTemp = Z_obs(:,vars == xNameStart+string(0));


for j = 1:size(Z_obs,2)-1
    
    yTemp = Z0(:,1+j);
    dTemp = rmmissing([yTemp,ones(length(yTemp),1),xTemp]);

    yTemp = dTemp(:,1);
    XTemp = dTemp(:,2:end);
    
    betaTemp = (XTemp'*XTemp)\(XTemp'*yTemp);
    
    indexMissingTemp = isnan(Z0(:,1+j));
    onesTemp = ones(length(Z0(indexMissingTemp,1+j)),1);
    Z0(indexMissingTemp,1+j) = [onesTemp,xTemp(indexMissingTemp)]*betaTemp;

end

% Imputation of the ragged edge with xNameEnd:
xTemp = Z_obs(:,vars == xNameEnd+string(0));

for j = 1:size(Z_obs,2)-1
    
    yTemp = Z0(:,1+j);
    dTemp = rmmissing([yTemp,ones(length(yTemp),1),xTemp]);

    yTemp = dTemp(:,1);
    XTemp = dTemp(:,2:end);
    
    betaTemp = (XTemp'*XTemp)\(XTemp'*yTemp);
    
    indexMissingTemp = isnan(Z0(:,1+j));
    onesTemp = ones(length(Z0(indexMissingTemp,1+j)),1);
    Z0(indexMissingTemp,1+j) = [onesTemp,xTemp(indexMissingTemp)]*betaTemp;

end

% Dependent variable:
yt_0 = Z0(:,2);

% Lagged dependent variable:
yLagt_0 = Z0(:,3:3+py-1);

% Remove the dependent variable from
% amongst the observable predictors:
Z0(:,2:2+py) = [];
Z_obs(:,2:2+py) = [];

% Compute the initial transition parameters 
% values through a simple OLS regression:
X0 = [Z0(:,1),yLagt_0,Z0(:,2:end)];
betaOLS = (X0'*X0)\(X0'*yt_0);

% Compute the transition residuals:
e0 = y-X0*betaOLS;

% Set the initial value of beta:
beta = betaOLS([1,2+py:N]);

% Update the initial values in B:
B(1,1:py) = betaOLS(2:2+py-1);
B = [B,[Z0(1,:);zeros(py,N-py)]; ...
    zeros(N-py,1+py),eye(N-py)];

% Compute the states' error initial
% covariance matrix:
Q = diag([var(e0,"omitmissing"),zeros(1,N)]);

% Construct the measurements' error
% initial covariance matrix:
m_0 = [zeros(1+py,1);beta];

B1 = B(1:1+py,1:1+py);
Q1 = Q(1:1+py,1:1+py);
vec_P_0 = (eye((1+py)^2)-kron(B1,B1))\Q1(:);
P_0 = blkdiag(reshape(vec_P_0,1+py,1+py),zeros(N-py));