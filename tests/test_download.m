% The complete source-download function with offline providers and temporary outputs.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
fixtureRoot=string(tempname); mkdir(fixtureRoot); mockDir=fullfile(fixtureRoot,'mocks'); mkdir(mockDir);
oldPath=path; oldFolder=pwd; warningState=warning;
cleanup=onCleanup(@() cleanupFixture(fixtureRoot,oldPath,oldFolder,warningState));
global SOURCE_FIXTURE
SOURCE_FIXTURE=struct('read',@fixtureWebread,'table',@fixtureTable,'save',@fixtureWebsave);
writeMock(fullfile(mockDir,'webread.m'), ...
    "function value=webread(url,varargin)"+newline+ ...
    "global SOURCE_FIXTURE; value=SOURCE_FIXTURE.read(url);"+newline+"end");
writeMock(fullfile(mockDir,'read_table_quiet.m'), ...
    "function value=read_table_quiet(url,varargin)"+newline+ ...
    "global SOURCE_FIXTURE; value=SOURCE_FIXTURE.table(url);"+newline+"end");
writeMock(fullfile(mockDir,'websave.m'), ...
    "function value=websave(filename,url,varargin)"+newline+ ...
    "global SOURCE_FIXTURE; SOURCE_FIXTURE.save(filename,url); value=filename;"+newline+"end");
warning('off','MATLAB:dispatcher:nameConflict'); addpath(mockDir,'-begin');
clear webread websave read_table_quiet
exerciseGetData(projectRoot,fixtureRoot,false);
csvRoot=fullfile(fixtureRoot,'csv_case'); mkdir(csvRoot);
exerciseGetData(projectRoot,csvRoot,true);
checkStockProvenance(fixtureRoot);
disp('PASS download: all 20 sources, real fallback branches, raw gaps, metadata, and temporary outputs.');
clear cleanup

function exerciseGetData(projectRoot,base_path,useCSV)
    global SOURCE_FIXTURE
    SOURCE_FIXTURE.forceConfidenceFail=useCSV;
    itnow_cfg=pipeline_config('base_path',base_path,'run_date',datetime(2006,7,1), ...
        'auto_discover_istat',false,'edition',"2006M6",'preliminary_ed',"2006M4", ...
        'ftsemib_mode',"manual",'interactive',false);
    if useCSV
        for measure=["CCICP","BCICP"]
            csvFile=fullfile(base_path,measure+".csv");
            tt=confidenceFixture(measure); value=tt{:,1};
            value(tt.Time==datetime(2000,4,1))=NaN;
            if measure=="CCICP"; title="Consumer confidence index (CCI)";
            else; title="Business confidence index (BCI)"; end
            fid=fopen(csvFile,'w'); assert(fid~=-1);
            fprintf(fid,'"%s"\n"Amplitude adjusted, Long-term average = 100"\n"Category","Italy"\n',title);
            for k=1:height(tt)
                fprintf(fid,'"%s 00:00:00",%.17g\n',string(tt.Time(k),'uuuu-MM-dd'),value(k));
            end
            fclose(fid); itnow_cfg.oecd_confidence_csv.(measure)=csvFile;
        end
    end
    mkdir(fullfile(base_path,'DATA','Temp'));
    writeStock(fullfile(base_path,'DATA','Temp','FTSEMIB.csv'));
    get_data(itnow_cfg);
    stored=readtimetable(fullfile(base_path,'DATA','source20060701.csv'));
    metadata=jsondecode(fileread(fullfile(base_path,'DATA','VINTAGE_METADATA','vintage20060701.json')));
    assert(width(stored)==20 && stored.Time(1)==datetime(1996,3,1) && stored.Time(end)==datetime(2006,6,1));
    names=string(stored.Properties.VariableNames);
    assert(numel(metadata.sources)==20 && isequal(string({metadata.sources.indicator}),names));
    for name=["INDPROD","CONSTRPROD","INDIMPPRC","HICPALL","TOURNIGHT","UNEMPLNUM","TRADEBAL","ITESI"]
        expected=monthlyFixture(name);
        inside=expected.Time>=stored.Time(1) & expected.Time<=stored.Time(end);
        actual=stored.(name); reference=expected{inside,1};
        assert(isequal(isnan(actual),isnan(reference)) && ...
            max(abs(actual(isfinite(reference))-reference(isfinite(reference))))<1e-10, ...
            '%s observations changed beyond CSV rounding.',name);
        row=metadata.sources(names==name); assert(string(row.source)=="Eurostat");
        assert(contains(string(row.url),"ec.europa.eu/eurostat/"));
    end
    gapDate=datetime(2000,4,1);
    assert(isnan(stored.ITESI(stored.Time==gapDate)) && isfinite(stored.ITESI(stored.Time==gapDate+calmonths(1))));
    confidence=metadata.sources(names=="ITCCI");
    business=metadata.sources(names=="ITCBC");
    if useCSV
        for name=["ITCCI","ITCBC"]
            row=metadata.sources(names==name);
            assert(string(row.source)=="OECD chart CSV" && strlength(string(row.local_file))>0 && ...
                contains(string(row.url),'www.oecd.org/en/data/indicators/'));
            assert(isnan(stored.(name)(stored.Time==gapDate)));
            assert(isfinite(stored.(name)(stored.Time==gapDate+calmonths(1))));
        end
    else
        assert(string(confidence.source)=="FRED mirror of OECD" && ...
            contains(string(confidence.url),"CSCICP03ITM665S") && strlength(string(confidence.fallback_reason))>0);
        assert(string(business.source)=="OECD" && strlength(string(business.fallback_reason))==0);
    end
    stock=metadata.sources(names=="FTSEMIB");
    assert(string(stock.source)=="Local FTSE MIB CSV");
    assert(all(string({metadata.sources.lifecycle})=="unconfirmed"));
    assert(string(metadata.gdp.source)=="national_accounts" && string(metadata.source_format)=="origin_raw_v1");
    assert(~isfolder(fullfile(base_path,'DATA','Temp')),'GetData did not remove its temporary download directory.');
end

function payload=fixtureWebread(url)
    global SOURCE_FIXTURE
    url=string(url);
    if contains(url,"ec.europa.eu/eurostat/")
        if contains(url,"sts_inpr_m"); name="INDPROD";
        elseif contains(url,"sts_copr_m"); name="CONSTRPROD";
        elseif contains(url,"sts_inpi_m"); name="INDIMPPRC";
        elseif contains(url,"prc_hicp_minr"); name="HICPALL";
        elseif contains(url,"tour_occ_nim"); name="TOURNIGHT";
        elseif contains(url,"ei_lmhu_m"); name="UNEMPLNUM";
        elseif contains(url,"ei_eteu27_2020_m"); name="TRADEBAL";
        elseif contains(url,"ei_bssi_m_r2"); name="ITESI";
        else; error('test_download:UnexpectedURL','Unexpected Eurostat request.'); end
        tt=monthlyFixture(name); dates=tt.Time;
        payload.id=["freq","geo","time"]; payload.size=[1,1,height(tt)];
        payload.dimension.freq.category.index=struct('M',0);
        payload.dimension.geo.category.index=struct('IT',0);
        index=struct(); observations=struct();
        for j=height(tt):-1:1
            index.(matlab.lang.makeValidName(char(string(dates(j),'uuuu-MM'))))=j-1;
            if isfinite(tt{j,1}); observations.("x"+(j-1))=tt{j,1}; end
        end
        payload.dimension.time.category.index=index; payload.value=observations;
    elseif contains(url,"sdmx.oecd.org")
        if contains(url,"CCICP") || SOURCE_FIXTURE.forceConfidenceFail
            error('test_download:OECD403','Synthetic OECD HTTP 403.');
        end
        tt=confidenceFixture("BCICP");
        payload="REF_AREA,FREQ,MEASURE,UNIT_MEASURE,ACTIVITY,ADJUSTMENT,TRANSFORMATION,TIME_HORIZ,METHODOLOGY,TIME_PERIOD,OBS_VALUE"+newline;
        for j=1:height(tt)
            payload=payload+"ITA,M,BCICP,IX,_Z,AA,IX,_Z,H,"+string(tt.Time(j),'uuuu-MM')+","+string(tt{j,1})+newline;
        end
    elseif contains(url,"esploradati.istat.it")
        if contains(url,"163_184") || contains(url,"163_156")
            dates=(datetime(1996,3,1):calmonths(3):datetime(2006,6,1))';
            if contains(url,"163_156"); dates(end)=[]; end
            levels=1000*exp(0.005*(1:numel(dates))');
            endDates=dateshift(dates,'end','month');
            periods=struct('id',cellstr(string(year(dates))+"-Q"+string(month(dates)/3)), ...
                'end',cellstr(string(endDates,'uuuu-MM-dd')+"T23:59:59"));
            payload.structure.dimensions.observation=struct('id',"TIME_PERIOD",'values',periods);
        else
            tt=monthlyFixture("ISTAT"); dates=tt.Time; levels=tt{:,1};
            periods=struct('end',cellstr(string(dateshift(dates,'end','month'),'uuuu-MM-dd')));
            payload.structure.dimensions.observation=struct('values',periods);
        end
        observations=struct(); for j=1:numel(levels); observations.("x"+(j-1))=levels(j); end
        if contains(url,"FABBRESID"); key="x0_0_0_0_0";
        elseif contains(url,"COMMDET"); key="x0_0_0_0_0_0_0";
        else; key="x0_0_0_0_0_0"; end
        payload.dataSets.series.(key).observations=observations;
    else
        error('test_download:UnexpectedURL','Unexpected source %s.',url);
    end
end

function value=fixtureTable(url)
    url=string(url); tt=monthlyFixture("TABLE");
    if contains(url,"fred.stlouisfed.org")
        value=table(string(tt.Time,'uuuu-MM-dd'),tt{:,1},'VariableNames',{'observation_date','confidence'});
    elseif contains(url,"Itacoin_it.xlsx")
        value=table(string(tt.Time,'uuuu-MM-dd'),tt{:,1},'VariableNames',{'Date','Ita_coin'});
    elseif contains(url,"Ecoin_realtime.xlsx")
        value=table(string(tt.Time,'uuuu-MM-dd'),tt{:,1},'VariableNames',{'Date','x_coinRealtime_NewEstimate'});
    else; error('test_download:UnexpectedURL','Unexpected table request %s.',url); end
end

function fixtureWebsave(filename,url)
    assert(contains(string(url),"data-api.ecb.europa.eu"));
    tt=monthlyFixture("ECB");
    value=table(string(tt.Time,'uuuu-MM'),tt{:,1},'VariableNames',{'TIME_PERIOD','OBS_VALUE'});
    writetable(value,filename);
end

function tt=monthlyFixture(name)
    dates=(datetime(1995,1,1):calmonths(1):datetime(2006,6,1))'; t=(1:numel(dates))';
    value=100+0.2*t+sin(t/7);
    if name=="TRADEBAL"; value=50*sin(t/7); end
    if name=="ITESI"; value(dates==datetime(2000,4,1))=NaN; end
    tt=timetable(dates,value,'VariableNames',cellstr(name)); tt.Properties.DimensionNames{1}='Time';
end

function tt=confidenceFixture(measure)
    dates=(datetime(1990,1,1):calmonths(1):datetime(2006,12,1))'; % Test CSV/API observations beyond the run cutoff.
    t=(1:numel(dates))'; value=100+0.1*t+sin(t/7);
    tt=timetable(dates,value,'VariableNames',cellstr(measure));
    tt.Properties.DimensionNames{1}='Time';
end

function checkStockProvenance(root)
    cache=fullfile(root,'cached.csv'); destination=fullfile(root,'downloaded.csv'); writeStock(cache);
    cfg=pipeline_config('run_date',datetime(2006,7,1),'ftsemib_mode',"stooq",'ftsemib_fallback_file',cache,'stooq_url',"https://example.test/stooq");
    failScript=fullfile(root,'fail.py');
    writeMock(failScript,"raise SystemExit('Synthetic STOOQ failure')");
    cfg.stooq_downloader=failScript;
    info=fetch_ftsemib(destination,cfg,weboptions('Timeout',1));
    assert(info.source=="STOOQ cached CSV" && info.url==cache && strlength(info.fallback_reason)>0);
    assert(strcmp(fileread(destination),fileread(cache)));
    successScript=fullfile(root,'success.py');
    writeMock(successScript,"import argparse, shutil"+newline+ ...
        "p=argparse.ArgumentParser(); p.add_argument('--url'); p.add_argument('--output'); p.add_argument('--timeout')"+newline+ ...
        "a=p.parse_args(); shutil.copyfile("+jsonencode(char(cache))+",a.output)");
    cfg.stooq_downloader=successScript;
    info=fetch_ftsemib(destination,cfg,weboptions('Timeout',1));
    assert(info.source=="STOOQ" && info.url==cfg.stooq_url && strlength(info.fallback_reason)==0);
end

function writeStock(filename)
    Date=[datetime(2006,5,2);datetime(2006,6,2);datetime(2006,6,3)];
    Close=[100;110;112]; writetable(table(Date,Close),filename);
end

function writeMock(filename,code)
    fid=fopen(filename,'w'); assert(fid~=-1); fprintf(fid,'%s\n',code); fclose(fid);
end

function cleanupFixture(root,oldPath,oldFolder,warningState)
    cd(oldFolder); path(oldPath); warning(warningState);
    clear webread websave read_table_quiet
    clear global SOURCE_FIXTURE
    if isfolder(root); rmdir(root,'s'); end
end
