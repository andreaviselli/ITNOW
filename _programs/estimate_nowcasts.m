function result = estimate_nowcasts(cfg,vintage)
%ESTIMATE_NOWCASTS IP + EUROCOIN + two quarterly weighted static PCA factors.
source=read_source("source"+vintage+".csv",cfg.base_path);
if cfg.eval_end>source.Time(end); error('estimate_nowcasts:SourceEnd','Source ends before the reference month.'); end
origins=(cfg.first_forecast:calmonths(1):cfg.eval_end)';
scale=trade_scale(source,cfg.factor_start,cfg.first_forecast);
growth=quarterly_log_growth(source.GDP,source.Time);
predicted=NaN(numel(origins),1); coefficients=NaN(numel(origins),5); counts=zeros(numel(origins),1);
factor_history=cell(numel(origins),1); training_quarters=cell(numel(origins),1);
for t=1:numel(origins)
    origin=origins(t);
    panel=origin_panel(source,origin,cfg.factor_start,scale);
    panel=panel(panel.Time>=cfg.factor_start,:);
    factors=monthly_factors(panel{:,:});
    [f,current_f]=factor_signals(panel.Time,factors,origin);
    [ip,current_ip]=quarterly_signal(source.Time,source.INDPROD,origin,2,'logqoq');
    [euro,current_euro]=quarterly_signal(source.Time,source.EUROCOIN,origin,0,'level');
    ip.Properties.VariableNames={'ip'}; euro.Properties.VariableNames={'eurocoin'};
    gdp=timetable(source.Time,growth,'VariableNames',{'gdp'}); gdp.Properties.DimensionNames{1}='Time';
    training=synchronize(ip,euro,f,gdp,'intersection');
    training=training(training.Time+calmonths(1)<=origin,:);
    training=rmmissing(training);
    [predicted(t),beta]=bridge_regression(training{:,1:4},training.gdp,[current_ip,current_euro,current_f]);
    coefficients(t,:)=beta';
    counts(t)=height(training); training_quarters{t}=training.Time;
    factor_history{t}=timetable(panel.Time,factors(:,1),factors(:,2),'VariableNames',{'factor_1','factor_2'});
    if mod(t,20)==0 || t==numel(origins)
        fprintf('Bridge: %d/%d forecast months, through %s.\n',t,numel(origins),string(origin,'yyyy-MM'));
    end
end
forecast=timetable(origins,predicted,'VariableNames',{'nowcast'}); forecast.Properties.DimensionNames{1}='Time';
folder=fullfile(cfg.base_path,'HISTORY','PREDICTION'); if ~isfolder(folder); mkdir(folder); end
path=fullfile(folder,vintage+"_bridge.csv"); writetimetable(forecast,path);
diagnostics=array2table([coefficients,counts],'VariableNames',{'intercept','ip','eurocoin','factor_1','factor_2','ntrain'});
diagnostics=addvars(diagnostics,origins,'Before',1,'NewVariableNames','Time');
writetable(diagnostics,fullfile(folder,vintage+"_bridge_coefficients.csv"));
root=fileparts(fileparts(mfilename('fullpath')));
code_version=strtrim(fileread(fullfile(root,'VERSION')));
metadata=struct('model','ip_eurocoin_pca_2','model_version','2026-10-17','code_version',code_version, ...
    'vintage',vintage,'eval_end',string(cfg.eval_end,'yyyy-MM-dd'), ...
    'factor_start',string(cfg.factor_start,'yyyy-MM-dd'),'factor_count',2, ...
    'factor_weights',[1,2,3,2,1],'produced_at',string(datetime('now','TimeZone','Europe/Rome','Format',"yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    'forecast_scale','decimal quarterly log growth','covid_sign_restriction',false);
fid=fopen(replace(path,'.csv','.json'),'w'); fprintf(fid,'%s\n',jsonencode(metadata,'PrettyPrint',true)); fclose(fid);
result=struct('forecasts',forecast,'coefficients',coefficients,'counts',counts, ...
    'factor_history',{factor_history},'training_quarters',{training_quarters},'metadata',metadata);
save(fullfile(folder,vintage+"_bridge_diagnostics.mat"),'result');
end
