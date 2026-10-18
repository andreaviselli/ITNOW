function factors = monthly_factors(panel)
%MONTHLY_FACTORS Impute the available panel and extract two static PCs.
panel(:,sum(isfinite(panel),1)/size(panel,1)<0.2)=[];
[T,N]=size(panel);
complete=panel;
% Interpolate the quarterly auxiliary GDP series and interior monthly gaps.
for j=1:N
    observed=find(isfinite(panel(:,j)));
    if j==N || numel(observed)>2
        if numel(observed)<2; error('monthly_factors:History','Insufficient history in column %d.',j); end
        rows=observed(1):observed(end);
        complete(rows,j)=spline(observed,panel(observed,j),rows);
    end
end
% Endpoint gaps use the same five most correlated auxiliary indicators.
for j=1:N
    training=rmmissing(complete);
    y=training(:,j); training(:,j)=[];
    correlations=corr(y,training);
    ordered=rmmissing(sort(abs(correlations),'descend'));
    if numel(ordered)<5; error('monthly_factors:Auxiliaries','Five varying auxiliary indicators are required.'); end
    selected=ismember(abs(correlations),ordered(1:5));
    design=[ones(size(training,1),1),training(:,selected)];
    beta=(design'*design)\(design'*y);
    predictors=complete; predictors(:,j)=[]; predictors=predictors(:,selected);
    predictors(~isfinite(predictors))=0;
    fitted=beta(1)+predictors*beta(2:end);
    missing=~isfinite(complete(:,j)); complete(missing,j)=fitted(missing);
end
monthly=complete(:,1:end-1);
[vectors,values]=eigs(cov(monthly),2,'LM');
vectors=vectors*diag(sign(vectors(1,:))');
factors=monthly*vectors/sqrt(values);
% Exclude the four initialization months from the bridge regressors.
factors(1:min(4,T),:)=NaN;
end
