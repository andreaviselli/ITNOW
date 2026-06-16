function [betaHat,yHat,yHatVec,vars,bic] = umidas(y,X,h,m,py,px,varargin)
% umidas()       Estimation of unrestricted mixed data sampling (MIDAS)
%                regression models.
%
% Description:
%   This function estimates the MIxed DAta Sampling (MIDAS) model where
%   the parametrization of the lag polynomial is left unrestricted (i.e.
%   U-MIDAS) which is convenient for mixtures of quarterly-monthly data.
%   By default, the function estimates a factor-MIDAS model, where the
%   user extracts an arbitrary number of factors and estimates the loa-
%   dings by Principal Component Analysis (PCA) through the Expectation-
%   Maximization (EM) algorithm to deal with missing data. Alternative-
%   ly, the user can estimate simple MIDAS regressions and then compute
%   forecast combinations from the percentiles of their distribution.
%   
% Input:
%   • y: dependent variable;
%   • X: design matrix; it must not include the constant;
%   • h: forecast horizon; e.g. set h=0 for nowcasting;
%   • m: frequency mismatch between y and X; e.g. if y is quarterly
%   and all variables in X are monthly, then m=3;
%   • py: order of the lag polynomial in y; it must be >= 0;
%   • px: order of the lag polynomial in the X's provided as a scalar
%   or as a vector with length equal to the number of predictors. In
%   the first case, all variables have the same number of lags whereas
%   in the second case the number of lags is variable-specific.
%
% (Optional input):
%   • vars: variable identifiers for y and X; it must have length equal
%   to size(X,2)+1;
%   • comb: binary parameter, either equal to 0 or 1. In the first case
%   (default), a factor-MIDAS is estimated, while in the second case, a
%   simple MIDAS regression, i.e. with only one predictor in turn, is
%   estimated and then the forecasts are aggregated via forecast combi-
%   nations (in this case, the BIC criterion is used to perform model
%   selection, px is the maximum lag order to test [px models are tested]
%   and each specification counts 1:m:px lags in the predictor);
%   • q: number of factors. The default value is 1;
%   • p: order of the lag polynomial in the factor. The default value is 1;
%   • perc: percentiles of the forecast distribution provided as a vector
%   of numbers between 0 and 1; its length must not be greater than the
%   number of univariate MIDAS equations to be estimated. The default is
%   to use the [0.1,0.5,0.9] percentiles;
%   • r: threshold parameter, between 0 and 1, to discard the variables
%   which present more than r% of their values as missing; the default
%   value is 0.5;
%   • maxiter: maximum number of iterations for the EM algorithm in the
%   estimation of the factor-MIDAS; the default value is 500;
%   • dispconv: binary parameter, either equal to 0 or 1, to display the
%   convergence of the EM algorithm to estimate the factor-MIDAS.
%
% Output:
%   • betaHat: vector of estimated coefficients. If comb=0 is chosen, it
%   includes the coefficients on the factors, while it is empty if comb=1
%   is chosen as different lags may be used with individual predictors;
%   • yHat: forecast. If comb=0 is chosen, this is the forecast obtained
%   from the factor-MIDAS, while if comb=1 it is a forecast combination
%   based on the percentiles of the forecast distribution;
%   • yHatVec: vector of forecasts from univariate simple MIDAS regres-
%   sions (i.e. it is not empty when comb=1, but it is empty when comb=0);
%   • vars: variables being used for estimation. For example, if 2 lags of
%   'INDPROD' are used, then INDPROD0, INDPROD1 and INDPROD2 are included.
%   • bic: bayesian information criterium, computed under the assumption
%   of i.i.d. errors. This is only returned when comb=0, while if comb=1
%   the function uses an automatic lag selection procedure using the bic
%   of the model with individual predictors.
%  
% Format call:
%   [betaHat,yHat,yHatVec,vars] = umidas(y,X,h,m,py,px, ...
%       'comb',comb,'q',q,'p',p,'r',r,'vars',vars,'perc',perc, ...
%       'maxiter',maxiter,'dispconv',dispconv);
%
% References:
%   • Foroni, Claudia, Massimiliano Marcellino, and Dalibor Stevanovic. 
%   "Mixed‐frequency models with moving‐average components." Journal of 
%   Applied Econometrics 34.5 (2019): 688-706.
%   • Ghysels, Eric, Pedro Santa-Clara, and Rossen Valkanov. "The MIDAS 
%   touch: Mixed data sampling regression models." (2004).


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

for n = 1:2:size(varargin,2)
    if strcmp('vars',varargin(n))
        vars = varargin{n+1};
    elseif strcmp('r',varargin(n))
        r = varargin{n+1};
    elseif strcmp('comb',varargin(n))
        comb = varargin{n+1};
    elseif strcmp('perc',varargin(n))
        perc = varargin{n+1};
    elseif strcmp('p',varargin(n))
        p = varargin{n+1};
    elseif strcmp('q',varargin(n))
        q = varargin{n+1};
    elseif strcmp('dispconv',varargin(n))
        dispconv = varargin{n+1};
    elseif strcmp('maxiter',varargin(n))
        maxiter = varargin{n+1};
    end
end
if p == 0 || q == 0
    error("For factor-augmented MIDAS 'p' and 'q' must be greater than 0.")
end
if all(px == 0)
    error("At least one element of 'px' must be greater than 0.")
end
if ~exist('vars','var')
    vars = "Variable identifiers not provided.";
end
if ~exist('comb','var')
    comb = 0;
end 
if (~exist('p','var') || ~exist('q','var'))
    if comb == 0
        warning("'p' and/or 'q' not provided. Proceeding with q=1 and p=1.")
        p = 1;
        q = 1;
    elseif comb == 1
        warning("'p' and/or 'q' ignored. Proceeding with forecast combination (comb==1).")
    end
end
if ~isstring(vars)
    if length(vars) ~= size(X,2)+1
        error("foo:bar","The length of 'vars' is not equal to size(X,2)+1," + ...
            " i.e. the column dimension of X plus y.")
    end
end
if exist('perc','var')
    if comb == 0 && ~isempty(perc)
        warning("'perc' ignored as comb == 0. Proceeding with comb == 0.")
    elseif any(perc < 0) || any(perc > 1)
        error("'perc' must be bounded between 0 and 1.")
    end
end
if ~exist('r','var')
    r = 0.5;
end
if ~exist('perc','var')
    perc = [0.1,0.5,0.9];
end
if ~exist('maxiter','var')
    maxiter = 500;
end
if ~exist('dispconv','var')
    dispconv = 1;
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Discard the variables with more than
% r% of missing observations:

varsId = ~(sum(isnan(X)) > r*size(X,1));
vars = vars(logical([1,varsId]));

X = X(:,varsId);

% Dataset dimensions:

[T,N] = size(X);

% Generate the lags of the dependent variable:

yLag = nan(T,py);
yLagId = cell(1,py);

for l = m:m:m*py
    yLag(:,l/m) = [nan(l,1);y(1:end-l)];
    yLagId{:,l/m} = append(vars(1),"-",string(l));
end

% Generate the lags of the predictors:

if length(px) == 1
    px = repelem(px,N);
end

xLag = nan(T,sum(m*px));
xLagId = cell(1,sum(m*px));

if 1 < length(px) && length(px) < N

    error("foo:bar","The variable 'px' must either be equal to a vector " + ...
        "with length equal \n to the number of variables (except GDP) or to a " + ...
        "scalar which indicates \n the same lag order for all variables.")

elseif comb == 0
% Model with no forecast combinations:

    for j = 1:N
        for l = 0:m*px(j)-1
            xLag(:,sum(m*px(1:j-1))+l+1) = [nan(l,1);X(1:end-l,j)];
            xLagId{sum(m*px(1:j-1))+l+1} = append(vars(1+j),"-",string(l));
        end
    end

elseif comb == 1
% Model with forecast combinations:
    
    for j = 1:N
        lUpd = 0;
        lMax = m*px(j)-1;
        for l = 0:lMax
            xLagTemp = [nan(l,1);X(1:end-l,j)];
            if isnan(xLagTemp(end))
                lMax = lMax+1;
            else
                xLag(:,sum(m*px(1:j-1))+lUpd+1) = [nan(l,1);X(1:end-l,j)];
                xLagId{sum(m*px(1:j-1))+lUpd+1} = append(vars(1+j),"-",string(l));
                lUpd = lUpd+1;
            end
        end
        for l = l+1:lMax
            xLag(:,sum(m*px(1:j-1))+lUpd+1) = [nan(l,1);X(1:end-l,j)];
            xLagId{sum(m*px(1:j-1))+lUpd+1} = append(vars(1+j),"-",string(l));
            lUpd = lUpd+1;
        end
    end
end

% Align the lagged target variable:
if ~isempty(yLag)
    tEndyLag = find(~isnan(yLag(:,1)),1,"last");
    yLag = [nan(T-tEndyLag,py);yLag(1:tEndyLag,:)];
end

% Align the target variable:

tEndy = find(~isnan(y),1,"last");
tmEndy = T:-m:tEndy;
shift = tmEndy(end)-tEndy;
y = [nan(shift,1);y(1:tEndy);nan(T-tEndy-shift,1)];


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

if comb == 0
% Model with no forecast combinations:

    % Spline arbitrary missing data in the cross-section:

    xLag0 = xLag;
    
    for j = 1:size(xLag,2)
        if sum(~isnan(xLag(:,j))) > 2    
            tm = find(~isnan(xLag(:,j)));
            xLag_j = rmmissing(xLag(tm(1):tm(end),j));
            xLag_j = spline(tm,xLag_j,tm(1):tm(end));
            xLag0(tm(1):tm(end),j) = xLag_j;            
        end
    end

    % Variable imputation:

    K = 3;

    for j = 1:size(xLag,2)

        xLag_j = rmmissing(xLag);   
        xDep = xLag_j(:,j);
        xLag_j(:,j) = [];
        
        % Choose the predictors as the K most correlated variables:
    
        rj = corr(xDep,xLag_j);
        rjAbs = rmmissing(sort(abs(rj),'descend'));
        rjAbs = rjAbs(1:K);
        rjId = ismember(abs(rj),rjAbs);
        
        xLag_j = [ones(size(xLag_j,1),1),xLag_j(:,rjId)];
    
        % Impute by an OLS regression:
    
        betaj = (xLag_j'*xLag_j)\(xLag_j'*xDep);        
        
        xLag_j = xLag;
        xLag_j(:,j) = [];
        xLag_j = [ones(T,1),xLag_j(:,rjId)];    
        xLag_j(isnan(xLag_j)) = 0;
        
        xDep = xLag_j*betaj;        
        xLag0(isnan(xLag(:,j)),j) = xDep(isnan(xLag(:,j)));

    end
    
    % Compute the initial values:
    
    V = cov(xLag0);                 % Covariance matrix;
    [W,D] = eigs(V,q,'LM');         % Eigendecomposition;
    W = W*diag(sign(W(1,:))');      % Identification;
    L0 = W*sqrt(D);                 % Factor loadings;
    F0 = xLag0*W/sqrt(D);           % Common factors;

    % Estimate the factor:

    [~,FHat,~,] = EM_PCA_MIDAS(xLag,L0,F0,q, ...
        'maxiter',maxiter,'dispconv',dispconv);

    % Construct the lags of the factors:
    
    p = p*m;
    F = nan(T,q*p);
    for l = 1:p
        F(:,q*(l-1)+1:q*l) = [nan(l-1,q);FHat(1:end-l+1,:)];
        if l > 1
            for qq = 1:q
                F(isnan(F(:,q*(l-1)+qq)),q*(l-1)+qq) = ...
                mean(F(:,q*(l-1)+qq),'omitmissing');
            end
        end
    end
   
    % Find available observations for y
    tmStart = find(~isnan(y),1,"first");
    tmEnd = find(~isnan(y),1,"last");
    tm = tmStart+py*m:m:tmEnd;

    % Construct the prediction set:
    XPred = [1,yLag(tmEnd,:),F(end-h,:)];
    
    % Construct the estimation set:
    y = y(tm);
    yLag = yLag(tm,:);
    F = F(tm,:);
    X = [yLag,F];
    
    % Adjust with a h-step mismatch:
    y = y(h+1:end);
    X = [ones(size(y,1),1),X(1:end-h,:)];

    [T,K] = size(X);
    
    % Error check (identification):
    if size(X,2) > size(X,1)
        error('foo:bar',"The column dimension is greater than the row dimension " + ...
            "in factor-augmented MIDAS.\nEither reduce py, q, or p. Otherwise, " + ...
            "consider to increase the sample size.")
    end
    
    % Ordinary least squares:
    betaHat = (X'*X)\(X'*y);

    % Compute the BIC:    
    bic = T*log( (T-1)^(-1)*sum((y-X*betaHat).^2) ) + K*log(T);
    
    % h-step-ahead forecast:
    yHat = XPred*betaHat;
    
    % Empty output (case):
    yHatVec = nan;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

elseif comb == 1
% Model with forecast combinations:
   
    tmStart = find(~isnan(y),1,"first");
    tmEnd = find(~isnan(y),1,"last");
    tm = tmStart+py*m:m:tmEnd;

    % Construct the prediction set:
    yLagPred = yLag(tmEnd,:);
    xLagPred = xLag(end-h,:);
    
    % Construct the estimation set:
    y = y(tm);
    yLag = yLag(tm,:);
    xLag = xLag(tm,:);

    y = y(1+h:end);
    yLag = yLag(1:end-h,:);
    xLag = xLag(1:end-h,:);
    T = size(xLag, 1);
    bic = nan;     % Set as nan

    % Estimation & prediction (individual predictor):    
    betaHat = nan;
    yHatVec = nan(1,N);

    for n = 1:N

        % Recover the columns of variable n:
        pxnIndex = sum(px(1:n).*m)-px(n)*m+1:sum(px(1:n).*m);
        
        % Spec-specific prediction:
        yHatVecn = nan(1,px(n));

        % Spec-specific BIC:
        bicn = nan(1,px(n));

        for j = 1:px(n)

            pxnjIndex = pxnIndex(1):pxnIndex(1)+j*m-1;
        
            XPred = [1,yLagPred,xLagPred(:,pxnjIndex)];        
            Xnj = [ones(T,1),yLag,xLag(:,pxnjIndex)];
            
            % Delete missing obs. at the beginning of the sample:
            MaxNanIndex = find(max(sum(isnan(Xnj)))==sum(isnan(Xnj)));
            MaxNanIndex = isnan(Xnj(:,MaxNanIndex(1)));
    
            % Replace missing obs. in the middle of the sample:
            for c = 1:size(Xnj,2)
                Xnj(isnan(Xnj(:,c)),c) = mean(Xnj(:,c),"omitmissing");
            end
    
            if size(Xnj,2) > size(Xnj,1)
                error('foo:bar',"The column dimension is greater than the row dimension " + ...
                    "in MIDAS\nwith forecast combinations. Either reduce py or px q." + ...
                    " Otherwise,\nconsider to increase the sample size for short predictors.")
            end
            
            yn = y(~MaxNanIndex);
            Xnj(MaxNanIndex,:) = [];
            
            % Estimate by OLS and compute the prediction:
            betaHatnj = (Xnj'*Xnj)\(Xnj'*yn);
            yHatVecn(j) = XPred*betaHatnj;
            
            % Compute the BIC (normal approximation):
            [Tnj,Knj] = size(Xnj);
            bicn(j) = Tnj*log( (Tnj-1)^(-1)*sum((yn-Xnj*betaHatnj).^2) ) + Knj*log(Tnj);
        
        end
        
        % Model selection via BIC:
        yHatVec(n) = yHatVecn(min(bicn) == bicn);

    end

    % Forecast combination:    
    yHat = nan(1,length(perc));
    for pp = 1:length(perc)
        yHat(pp) = quantile(yHatVec,perc(pp));
    end
end