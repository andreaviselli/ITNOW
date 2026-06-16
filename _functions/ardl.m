function [yHat,Z,B,Q,beta,e,logL,varNames] = ardl(y,yName,X,XName,py,px,method,xNameStart,xNameEnd)
% ardl()    Estimation of autoregressive distributed lag model (ARDL).
%
% Description:
%   This function estimates autoregressive distributed lag (ARDL)models
%   with an arbitrary number of lags of the dependent and independent va-
%   riables. The model is cast in state space form to deal with missing
%   observations in the past and on the ragged edge, and estimation can
%   be either performed by maximum likelihood (MLE) or by MLE with the
%   Expectation-Maximization (EM) algorithm.
%
% Input:
%   • y: dependent variable, a vector of Tx1 observations.
%   • yName: identifier or name of y;
%   • X: design matrix with the predictors, a matrix of TxK observations;
%   • XName: identifiers or names of X, a Kx1 string vector. Importantly,
%   this procedure relies on a predictor that displays no missing observa-
%   tions starting from the first time period in the sample and another, 
%   not necessarily distinguished, predictor that displays no missing ob-
%   servations up to the last time period in the sample (i.e. it displays 
%   no publication delay) for computing the initial values of the system 
%   matrices and state variables for estimation. In particular, missing
%   observations at the beginning and at the end of the sample are impu-
%   ted by ordinary least squares (OLS) using the above predictors.
%   • py: order of the lag polynomial in the dependent variable, integer
%   value >=1;
%   • px: order of the lag polynomial in the predictors. It can be either
%   a scalar integer or a Kx1 vector of integers, >=0. In the first case,
%   all predictors have the same number of lags, while in the second case
%   the number of lags is variable-specific;
%   • method: estimation method, either by maximum likelihood ("MLE") using
%   the Matlab routine 'fmincon' and the Interior-Point Algorithm with the 
%   Hessian computed using the 'bfgs' or dense quasi-Newton approximation,
%   or by MLE with the Expectation-Maximization (EM) algorithm ("QMLE"). In 
%   particular, the model is estimated after being cast in state space form
%   where the predictors are treated as observable state variables in the
%   transition equation (the state space form is reported below);
%   • xNameStart: identifier or name of the predictor that displays no mis-
%   sing observations starting from the first time period in the sample (but
%   not necessarility at the end) for imputation of missing observations in 
%   the remaining predictors. Such an identifier must be a string and al-
%   ready included in XName, and the corresponding variable must have no
%   missing observations where the other variables are not complete.
%   • xNameEnd: identifier or name of the predictor that displays no miss-
%   ing observations up to the last time period of the sample (but not ne-
%   cessairily at the beginning) for imputation of missing observations in 
%   the remaining predictors. Such an identifier must be a string and al-
%   ready included in XName, and might be the same as xNameStart, provided 
%   it displays no missing observations both at the beginning and at the end 
%   of the sample, and the corresponding variable must have no missing ob-
%   servations where the other variables are not complete.   
%
% Output:
%   • yHat: fitted values of y, of dimension Tx1.
%   • Z: measurement vector that links the state variables to the observa-
%   ble target variable, of dimension 1x[2+py+length(px)+sum(px)] since it 
%   includes a constant and (1+py) counts the current and past lags of y.
%   • B: transition matrix describing the dynamics of the state variables,
%   of dimension (2+py+length(px)+sum(px))x(2+py+length(px)+sum(px)).
%   • Q: covariance matrix for the errors in the transition equation;
%   • beta: coefficients of the observable state variables, i.e. the pre-
%   dictors, treated as state variables (whereas the observable state va-
%   riables are treated as time-varying parameters in B);
%   • e: error term in the transition equation, of dimension Tx1.
%   • logL: value of the log-likelihood for the estimated model;
%   • vars: identifiers for all variables, including y, X, and their lags.
%
% State space form:
%                           y_t = Z*m_t;
%                           m_t = B*m_{t-1}+R*e;
%   where:
%   • Z = [1,zeros(1+py+length(px)+sum(px))];
%   • m_t = [y_t,...,y_{t-py},beta];
%   • B = [phi_1,...,phi_{py},0,X_t,...,X_{t-px}; ...
%          eye(py),zeros(py,1+length(px)+sum(px));...
%          zeros(1+length(px)+sum(px)),1+py),eye(1+length(px)+sum(px))];        
%   • Cov(R*e) = Q, e is 1x1 and R is (2+py+length(px)+sum(px))x1.
%
% Format call:
%   [yHat,Z,B,H,Q,beta,e,logL,vars] = ardl(y,yName,X,XName,py,px,method,...
%                                           xNameStart,xNameEnd);
%
% References:
%   • Shumway, Robert H., and David S. Stoffer. "An approach to time series 
%   smoothing and forecasting using the EM algorithm." Journal of time 
%   series analysis 3.4 (1982): 253-264.
%   • Harvey, Andrew C. "Forecasting, structural time series models and the 
%   Kalman filter." (1990). Chapter 3.

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

if py == 0
    error("The order of the lag polynomial 'py' in the dependent " + ...
        "variable (GDP) must be greater or equal than 1.")
end
if length(px) == 1
    px = repelem(px,size(X,2));
elseif length(px) ~= 1 && length(px) ~= size(X,2)
    error('foo:bar',"The length of 'px' must be equal to the column dimension\n" + ...
        "of the design matrix X, i.e. size(X,2).")
end

if ~(any(XName == xNameStart) && any(XName == xNameEnd))
    error('foo:bar',"Make sure that the set of observable variables includes " + ...
        "two predictors used \nto impute missing observations at the beginning " + ...
        "and end of the sample. See \nthe documentation in 'ardl.m' for more" + ...
        "information.")
else
    NanIdxImput = (isnan(X(:,XName == xNameStart))+isnan(X(:,XName == xNameEnd))) == 2;
    NanIdxMatch = any(sum(isnan(X(:,~logical(double(XName == xNameStart)+double(XName == xNameEnd)))),2),2);
    if any(NanIdxImput+NanIdxMatch==2)
        error('foo:bar',"The predictors in xNameStart and xNameEnd are not jointly" + ...
            " complete for the \nremaining predictors (that is, they should display " + ...
            "no missing observations \nwhere the remaining predictors do have missing" + ...
            " observations). See the \ndocumentation in 'ardl.m' for more information.")
    end
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Constructing the dataset with selected lags:

[T,N] = size(X);

yLag = nan(T,py);
vars_yLag = [];

for l = 1:py
    yLag(:,l) = [nan(l,1);y(1:end-l)];
    vars_yLag = [vars_yLag,append(yName,string(l))];
end

xLag = nan(T,length(px)+sum(px));
vars_xLag = [];

for j = 1:N
    for l = 0:px(j)
        xLag(:,(j-1)+sum(px(1:j-1))+l+1) = [nan(l,1);X(1:end-l,j)];
        vars_xLag = [vars_xLag,append(XName(j),string(l))];
    end
end

% Create the vector of variable names:
vars = ["Const",yName,vars_yLag,vars_xLag];
% Create the dataset for initialization:
X = [y,yLag,xLag];

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Build the series of data and system variables:
[y,Z,B,H,Q,m_0,P_0,beta_0,Z_t] = InitCond_ARDL(X,vars,py,xNameStart,xNameEnd);

% Store the vector of variable names:
varNames = vars(2:end);

if method == "QMLE"

    % Run the Quasi-MLE estimation through the EM algorithm:
    [yHat,Z,B,~,Q,beta,e,~,logL] = EM_ARDL(y,Z,B,H,Q,m_0,P_0,beta_0,Z_t,0,500);

elseif method == "MLE"
    
    % Run the MLE estimation (Interior-Point Algorithm with the Hessian
    % computed using the 'bfgs' or dense quasi-Newton approximation):
    [yHat,Z,B,~,Q,beta,e,~,logL] = MLE_ARDL(y,Z,B,H,Q,m_0,P_0,beta_0,Z_t);

end

% Select the smoothed dependent variable:
yHat = yHat(1,:)';