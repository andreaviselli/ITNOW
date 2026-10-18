function [prediction,beta] = bridge_regression(X,y,current)
%BRIDGE_REGRESSION Expanding OLS with an intercept, returned in source units.
prediction=NaN; beta=NaN(5,1);
if size(X,1)<12; return; end
mu=mean(X,1); sigma=std(X,1,1);
if any(~isfinite(sigma) | sigma<=0); error('bridge_regression:Variation','Covariates must vary.'); end
design=[ones(size(X,1),1),(X-mu)./sigma];
if rank(design)<size(design,2); error('bridge_regression:Rank','The training design is not full rank.'); end
standard=design\y;
slopes=standard(2:end)./sigma';
beta=[standard(1)-mu*slopes;slopes];
if all(isfinite(current)); prediction=[1,current]*beta; end
end
