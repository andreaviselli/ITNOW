function verify_bridge_refactor()
%VERIFY_BRIDGE_REFACTOR Reproduce every researched factor and model forecast.
root=fileparts(fileparts(mfilename('fullpath')));
reference=fullfile(root,'HISTORY','VALIDATION','combination-research-20261017','bridge_augmentation');
cfg=pipeline_config('run_date',datetime(2026,10,17),'eval_end',datetime(2026,9,1), ...
    'vintage',"20261009",'download',false);
result=estimate_nowcasts(cfg,cfg.vintage);
saved=readtable(fullfile(reference,'forecasts.csv'));
assert(isequal(result.forecasts.Time,datetime(saved.Time)));
expected=saved.Add_PCA2_Weights5;
assert(isequal(isfinite(result.forecasts.nowcast),isfinite(expected)));
delta=max(abs(result.forecasts.nowcast-expected),[],'omitnan');
assert(delta<1e-9,'The selected-model forecasts changed.');
factors=readtable(fullfile(reference,'pca_q2.csv'));
factors.origin=datetime(factors.origin); factors.month=datetime(factors.month);
factorDelta=0; monthCount=0;
for t=1:height(result.forecasts)
    rows=factors.origin==result.forecasts.Time(t);
    expectedFactors=factors{rows,{'F1','F2'}};
    actual=result.factor_history{t};
    assert(isequal(actual.Time,factors.month(rows)));
    assert(isequal(isfinite(actual{:,:}),isfinite(expectedFactors)));
    factorDelta=max(factorDelta,max(abs(actual{:,:}-expectedFactors),[],'all','omitnan'));
    monthCount=monthCount+height(actual);
end
assert(factorDelta<1e-8,'Factor histories changed.');
record=struct('forecast_months',height(result.forecasts),'maximum_forecast_difference',delta, ...
    'factor_history_months',monthCount,'maximum_factor_difference',factorDelta, ...
    'reference',reference,'model','ip_eurocoin_pca_2');
folder=fullfile(root,'HISTORY','VALIDATION','bridge_refactor_20261017');
if ~isfolder(folder);mkdir(folder);end
fid=fopen(fullfile(folder,'parity.json'),'w');fprintf(fid,'%s\n',jsonencode(record,'PrettyPrint',true));fclose(fid);
fprintf('PASS: %d forecasts match; maximum difference %.3g, factors %.3g.\n',height(result.forecasts),delta,factorDelta);
end
