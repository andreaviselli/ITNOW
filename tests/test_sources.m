% GDP sources: preserve coherent GDP vintages, required history and source provenance.
cfg=pipeline_config('run_date',datetime(2026,9,15));
quarters=(datetime(1995,3,1):calmonths(3):datetime(2026,6,1))';
levels=400000*exp(cumsum(0.002+0.004*sin((1:numel(quarters))'/5)));
national=makePayload(quarters,levels);
preliminary=makePayload(quarters(5:end),levels(5:end)*1.01);
finalEdition="2026M9"; preliminaryEdition="2026M7";
options=weboptions('Timeout',1);
[finalGDP,finalInfo]=fetch_gdp_vintage("final",finalEdition,"1990-01-01", ...
    options,@(~,~) national);
[preliminaryGDP,preliminaryInfo]=fetch_gdp_vintage("preliminary", ...
    preliminaryEdition,"1990-01-01",options,@(~,~) preliminary);
assert(contains(finalInfo.url,"B1GQ_B_W2_S1.L_2020.Y.2026M9/ALL/"));
assert(contains(preliminaryInfo.url,"B1GQ_B_W2_S1.L_2020.Y.2026M7_1/ALL/"));
assert(finalInfo.latest_quarter=="2026-06-01" && ...
    finalInfo.latest_observation=="2026-07-01");

% Same-quarter and older preliminary releases keep national accounts.
[chosen,info]=select_gdp_vintage(finalGDP,preliminaryGDP,finalInfo,preliminaryInfo,cfg);
assert(isequaln(chosen,finalGDP) && info.source=="national_accounts");
older=preliminary; older.dataSets.series.x0_0_0_0_0_0.observations= ...
    rmfield(older.dataSets.series.x0_0_0_0_0_0.observations,"x"+(height(preliminaryGDP)-1));
[oldGDP,oldInfo]=fetch_gdp_vintage("preliminary",preliminaryEdition, ...
    "1990-01-01",options,@(~,~) older);
[chosen,info]=select_gdp_vintage(finalGDP,oldGDP,finalInfo,oldInfo,cfg);
assert(isequaln(chosen,finalGDP) && info.source=="national_accounts", ...
    'A missing trailing observation was mistaken for a newer quarter.');

% Use a complete preliminary vintage, including its base level.
shortFinal=makePayload(quarters(1:end-1),levels(1:end-1));
[shortGDP,shortInfo]=fetch_gdp_vintage("final",finalEdition,"1990-01-01", ...
    options,@(~,~) shortFinal);
[chosen,info]=select_gdp_vintage(shortGDP,preliminaryGDP,shortInfo,preliminaryInfo,cfg);
assert(isequaln(chosen,preliminaryGDP) && info.source=="preliminary");
assert(info.required_first_level_quarter=="1996-03-01" && ...
    info.required_last_released_quarter=="2026-06-01");
assert(chosen.Time(1)==datetime(1996,3,1), ...
    'Normal flash coverage from 1996 Q1 must remain usable.');
assert(abs(log(chosen.GDP(end)/chosen.GDP(end-1))- ...
    log(preliminaryGDP.GDP(end)/preliminaryGDP.GDP(end-1)))<1e-15);
assert(abs(log(chosen.GDP(end)/shortGDP.GDP(end))- ...
    log(chosen.GDP(end)/chosen.GDP(end-1)))>0.009, ...
    'The example must distinguish a coherent vintage from a level splice.');

% Required starts, internal gaps, actual endpoints and the one-month GDP lag.
tooShort=preliminaryGDP(9:end,:);
expectError(@() select_gdp_vintage(shortGDP,tooShort,shortInfo,preliminaryInfo,cfg), ...
    'select_gdp_vintage:MissingHistory');
gapped=preliminaryGDP; gapped.GDP(20)=NaN;
expectError(@() select_gdp_vintage(shortGDP,gapped,shortInfo,preliminaryInfo,cfg), ...
    'select_gdp_vintage:MissingHistory');
gapped=preliminaryGDP; gapped(20,:)=[];
expectError(@() select_gdp_vintage(shortGDP,gapped,shortInfo,preliminaryInfo,cfg), ...
    'select_gdp_vintage:MissingHistory');
expectError(@() select_gdp_vintage(shortGDP,oldGDP,shortInfo,oldInfo,cfg), ...
    'select_gdp_vintage:MissingEndpoint');
september=cfg; september.eval_end=datetime(2026,9,1);
select_gdp_vintage(finalGDP,preliminaryGDP,finalInfo,preliminaryInfo,september);
october=cfg; october.eval_end=datetime(2026,10,1);
expectError(@() select_gdp_vintage(finalGDP,preliminaryGDP,finalInfo,preliminaryInfo,october), ...
    'select_gdp_vintage:MissingEndpoint');
historical=cfg; historical.eval_end=datetime(2010,4,1);
laterGap=preliminaryGDP; laterGap.GDP(laterGap.Time==datetime(2020,6,1))=NaN;
[~,info]=select_gdp_vintage(shortGDP,laterGap,shortInfo,preliminaryInfo,historical);
assert(info.retained_last_quarter=="2010-03-01" && ...
    info.required_last_released_quarter=="2010-03-01");

% SDMX time indices, rather than field order, determine GDP dates.
decoded=read_gdp_response(national);
assert(isequal(decoded.Time,quarters) && isequal(decoded.GDP,levels));
bad=national; bad.structure.dimensions.observation.values(2).end= ...
    bad.structure.dimensions.observation.values(1).end;
expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidDates');
bad=national; bad.structure.dimensions.observation.values(2).id="1995-Q1";
expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidDates');
bad=national; bad.structure.dimensions.observation.values(1).end="1995-02-28T23:59:59";
expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidDates');
bad=national; bad.dataSets.series.other=bad.dataSets.series.x0_0_0_0_0_0;
expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidSeries');
bad=national; bad.dataSets.series.x0_0_0_0_0_0.observations.x999=[1;0];
expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidIndex');
for invalid=[0,-1,Inf]
    bad=national; bad.dataSets.series.x0_0_0_0_0_0.observations.x0=[invalid;0];
    expectError(@() read_gdp_response(bad),'read_gdp_response:InvalidLevel');
end
bad=national; bad.dataSets.series.x0_0_0_0_0_0.observations=struct();
expectError(@() read_gdp_response(bad),'read_gdp_response:NoObservations');
expectError(@() fetch_gdp_vintage("final",finalEdition,"1990-01-01",options, ...
    @failedReader),'fetch_gdp_vintage:DownloadFailed');

disp('PASS sources: coherent GDP vintages, quarterly coverage and source parsing.');

function payload=makePayload(quarters,levels)
    n=numel(quarters);
    periods=repmat(struct('id',"",'end',""),n,1);
    observations=struct();
    for j=n:-1:1 % Reverse field order deliberately; alternate numeric/cell values.
        periods(j).id=string(year(quarters(j)))+"-Q"+string(month(quarters(j))/3);
        periods(j).end=string(dateshift(quarters(j),'end','month'),'uuuu-MM-dd')+"T23:59:59";
        if mod(j,2)==0; value={levels(j),0}; else; value=[levels(j);0]; end
        observations.("x"+(j-1))=value;
    end
    payload.structure.dimensions.observation=struct('id',"TIME_PERIOD",'values',periods);
    payload.dataSets.series.x0_0_0_0_0_0.observations=observations;
end

function expectError(action,identifier)
    try
        action();
    catch ME
        assert(strcmp(ME.identifier,identifier),'Unexpected error: %s: %s',ME.identifier,ME.message);
        return
    end
    error('test_sources:ExpectedError','Expected %s.',identifier);
end

function result=failedReader(~,~)
    error('test_sources:DownloadFixture','Synthetic failed download.');
    result=[]; %#ok<UNRCH>
end
