function out = dfm(X,q,p,method,varargin)
% dfm()         Estimation of mixed-frequency dynamic factor models (DFM)
%               for a quarterly-monthly mixture of data.
%
% Description:
%   This function estimates dynamic factor models (DFM) with time-invariant
%   loadings in presence of an arbitrary pattern of missing values and the
%   ragged edge. Three estimation methods are supported, namely by princi-
%   pal component analysis (PCA), two-step (2S), and quasi maximum likeli-
%   hood (QMLE), whose references are reported hereafter. The model allows
%   for a quarterly-monthly mixture of data and implements a proper aggre-
%   gation of the quarterly flow variable.
%
% Input:
%   • X: design matrix, a T x N array of N time series over T time periods
%   including variables with missing observations either at the beginning
%   or at the end of the sample, and a single quarterly variable that has
%   to be inserted as the N-th variable, i.e. X = [X_monthly,x_quarterly];
%   • q: number of factors, a positive integer;
%   • p: order of the lag polynomial in the factor, a positive integer;
%   • method: estimation method, that is one amongst the PCA estimator pro-
%   posed by Stock and Watson (2002), the 2S estimator of Doz et al. (2011),
%   and the QMLE estimator of Doz et al. (2012), which can be respectively 
%   selected as "PCA", "2S", and "QMLE".
%
% (Optional input):
%   • FObs: observable factor, a Tx1 vector. It can be any external vector
%   provided as a vector, or a column of X provided as a scalar in the ran-
%   ge 1:size(X,2) indicating the variable's location. Notice that, in the
%   latter case, any factor will still be produced based on that variable;
%   • RNaN: maximum percentage of missing observations in a column of X, a
%   double in the range [0.1,RMax], otherwise that is removed, where RMAX
%   is the percentage of missing observations in the quarterly variable. 
%   Such a requirement ensures good initial estimates for the system matri-
%   ces which are computed based on preliminary imputation by ordinary lea-
%   st squares (OLS). The default value is RMax-0.01;
%   • maxiter: maximum number of iteration for the EM algorithm if the "2S"
%   or "QMLE" estimation methods are chosen. The default value is 500;
%   • dispconv: display the convergence of the EM algorithm together with
%   the effective number of iterations performed; a binary indicator (0/1)
%   and the default value is 1.
%   
% Output as 'out', a structure array including:
%   • XHat: fitted values relative to the T x N array of N time series;
%   • F: smoothed values of the factors as represented in the state spa-
%   ce form (i.e. including the dynamics of the lagged factors and error 
%   terms given by the quarterly aggregation scheme, and the observable 
%   factor which appears as constant due to the peculiar representation)
%   if either the "2S" or "QMLE" were chosen for estimation , or the esti-
%   mated factors by "PCA";
%   • Z: matrix of the factor loadings, a N x max{5+q*5,5+q*(1+p)} matrix
%   if no observable factor is inserted, or a N x (1+q*5) matrix if an ob-
%   servable factor is inserted;
%   • B: autoregressive matrix for the factor, a square matrix with dimen-
%   sion max{5+q*5,5+q*(1+p)} if no observable factor is introduced, or 1+
%   q*5 if an observable factor is inserted;
%   • Q: covariance matrix for the innovations to the factors, a square ma-
%   trix with dimension max{5+q*5,5+q*(1+p)} if no observable factor is in-
%   troduced, or 1+q*5 if an observable factor is inserted;
%   • H: covariance matrix for the idiosyncratic terms, a NxN matrix;
%   • FObs: smoothed series for the observable factor (see the analogous
%   input for more information) obtained through the Kalman algorithm;
%   • logL: model log-likelihood computed through the Kalman algorithm.
%   
% Format call: 
%   out = dfm(X,q,p,method,'FObs',FObs,'maxiter',maxiter,'dispconv',dispconv);
%
% References:
%   • Doz, Catherine, Domenico Giannone, and Lucrezia Reichlin. "A two-step 
%   estimator for large approximate dynamic factor models based on Kalman 
%   filtering." Journal of Econometrics 164.1 (2011): 188-205;
%   • Doz, Catherine, Domenico Giannone, and Lucrezia Reichlin. "A quasi–
%   maximum likelihood approach for large, approximate dynamic factor models.
%   " Review of economics and statistics 94.4 (2012): 1014-1024;
%   • Harvey, Andrew C. "Forecasting, structural time series models and the 
%   Kalman filter." (1990). Chapter 3;
%   • Mariano, Roberto S., and Yasutomo Murasawa. "A new coincident index 
%   of business cycles based on monthly and quarterly series." Journal of 
%   applied Econometrics 18.4 (2003): 427-443.
%   • Stock, James H., and Mark W. Watson. "Macroeconomic forecasting 
%   using diffusion indexes." Journal of Business & Economic Statistics 
%   20.2 (2002): 147-162.

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

if nargin < 5
    maxiter = 500;
    dispconv = 1;
    FObs = [];
end

for n = 1:2:size(varargin,2)
    if strcmp('FObs',varargin(n))
        FObs = varargin{n+1};
    elseif strcmp('RNaN',varargin(n))
        RNaN = varargin{n+1};
    elseif strcmp('maxiter',varargin(n))
        maxiter = varargin{n+1};
    elseif strcmp('dispconv',varargin(n))
        dispconv = varargin{n+1};
    end
end

if ~exist('FObs','var')
    FObs = [];
end
if ~exist('RNaN','var')
    RMax = sum(~isnan(X(:,end)))/size(X,1);
    RNaN = RMax-0.01;
end
if ~exist('maxiter','var')
    maxiter = 500;
end
if ~exist('dispconv','var')
    dispconv = 1;
end

if isscalar(FObs)
    if FObs > 0 && FObs < size(X,2)
        FObs = X(:,FObs);
    end
elseif isvector(FObs)
    if size(FObs,1) ~= size(X,1)
        error("'FObs' and 'X' must have the same number of rows.")
    end
end

if method == "2S" && ~isempty(maxiter)
    warning('foo:bar',"No algorithm is working with the " + ...
        "2S estimator. 'maxiter' is ignored.")
end
if q > 1 && ~isempty(FObs)
    error('foo:bar',"Estimation of q > 1 factors with an observable factor " + ...
        "is not supported.\nSet 'q = 1' when 'FObs' is not empty.")
end
if (p > 1 || q > 1) && method == "QMLE"
    warning('foo:bar',"Estimation by QMLE with p > 1 or q > 1 may get stuck.")
end
if ~isempty(FObs) && method == "PCA"
    error('foo:bar',"Estimation by PCA with observable factors is not" + ...
        "supported.\nRemove the argument 'FObs' or insert 'FObs=[]'.")
end

% Remove series with more than R% of missing observations:
indexMissingVariables = sum(~isnan(X),1)/size(X,1)<RNaN;
X(:,indexMissingVariables) = [];

% Define input variables:
vars = [size(X,2)-1,1];

% Obtain the initial values for the system matrices:
inp = InitCond_DFM(X,FObs,q,p,vars);

% Pack the initialized system matrices for subsequent moves:
[X,Z,F_obs,B,H,Q,~,F_0,P_0] = deal(inp.X,inp.Z, ...
    inp.F_obs,inp.B,inp.H,inp.Q,inp.e_0,inp.F_0,inp.P_0);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% PCA ESTIMATOR
if method == "PCA"

    % Run the EM algorithm:
    [X_u,F_u,Z_u,~] = EM_PCA_DFM(X,Z,F_0,q,p,vars,maxiter,dispconv);

    % Collecting the output:
    out = struct('XHat',X_u,'F',F_u','Z',Z_u);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% 2S ESTIMATOR
elseif method == "2S"
    
    N_q = vars(2);      % Number of quarterly variables;                    
    F_obs = F_obs';     % Transpostion of F_obs and X are required 
    X = X';             % by the function running the Kalman filter;
    
    % Vector of initial states;
    F_0 = F_0(1,:)';

    % Kalman filter:
    [P,P_u,~,F_u,~,~,X_hat,K_end,logL,~] = kf_DFM(X,Z,B,H,Q,F_0,P_0,F_obs,N_q);
    
    % Kalman smoother:
    [F_s,~,~] = fis_DFM(F_u,P,P_u,B,K_end);
    
    % Collecting the output:
    out = struct('XHat',{X_hat'},'F',F_s','Z',Z,'FObs',F_obs', ...
        'B',B,'Q',Q,'H',H,'logL',logL);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% QMLE ESTIMATOR
elseif method == "QMLE"
    
    % Run estimation through the EM algorithm:
    [F_s,Z,B,H,Q,~,X_hat,logL] = EM_QMLE_DFM(vars,q,p,X,Z,B,H,Q, ...
        F_0,P_0,F_obs,dispconv,maxiter);

    % Collecting the output:
    out = struct('XHat',{X_hat'},'F',F_s','Z',Z,'FObs',F_obs','B',B, ...
        'Q',Q,'H',H,'logL',logL);

end