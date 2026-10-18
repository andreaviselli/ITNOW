% Source definitions: definitions, calendar gaps, complete histories and real acquisition paths.
root=string(tempname); mkdir(root); oldPath=path; warningState=warning;
cleanup=onCleanup(@() clean(root,oldPath,warningState));
dates=[datetime(2020,3,1);datetime(2020,1,1);datetime(2020,4,1)];
values=[121;100;NaN];
for measure=["CCICP","BCICP"]
    file=fullfile(root,measure+".csv");
    text=chartCSV(measure,dates,values); write(file,text);
    [d,v]=read_oecd_confidence(file,measure,"2020-01-01");
    assert(isequal(d,(datetime(2020,1,1):calmonths(1):datetime(2020,4,1))') && ...
        isequaln(v,[100;NaN;121;NaN]));
    [fd,fv,source,info]=fetch_oecd_confidence(measure,"2020-01-01",weboptions('Timeout',1),file);
    assert(isequal(d,fd) && isequaln(v,fv) && source=="OECD chart CSV" && info.local_file==file);
    assert(contains(info.url,'www.oecd.org/en/data/indicators/') && ...
        contains(info.definition,'Amplitude adjusted') && info.fallback_reason=="");
    assertError(@() read_oecd_confidence(file,measure,"2019-12-01"),'read_oecd_confidence:IncompleteHistory');
    write(file,replace(text,'"Category","Italy"','"Category","OECD"'));
    assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'read_oecd_confidence:InvalidCountry');
    write(file,replace(text,'Long-term average = 100','2021 = 100'));
    assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'read_oecd_confidence:InvalidDefinition');
    write(file,chartCSV(measure,[dates;dates(1)],[values;120]));
    assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'confidence_grid:InvalidDates');
    for bad=[0,-1,Inf]
        write(file,chartCSV(measure,dates,[bad;100;NaN]));
        assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'confidence_grid:InvalidValues');
    end
    write(file,replace(text,',121',',not-a-number'));
    assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'read_oecd_confidence:InvalidValues');
    write(file,replace(text,'2020-03-01','2020-03-02'));
    assertError(@() read_oecd_confidence(file,measure,"2020-01-01"),'read_oecd_confidence:InvalidDates');
end
assertError(@() fetch_oecd_confidence("CCICP","2020-01-01",weboptions,fullfile(root,'absent.csv')), ...
    'read_oecd_confidence:MissingFile');

% Named API columns may be reordered. Omitted observations keep calendar gaps.
file=fullfile(root,'sdmx.csv');
text=sdmxCSV("CCICP"); write(file,text);
[d,v]=read_oecd_confidence(file,"CCICP","2020-01-01");
assert(isequal(d,(datetime(2020,1,1):calmonths(1):datetime(2020,4,1))') && isequaln(v,[100;NaN;121;NaN]));
for field=["REF_AREA","FREQ","MEASURE","UNIT_MEASURE","ACTIVITY","ADJUSTMENT","TRANSFORMATION","TIME_HORIZ","METHODOLOGY"]
    fields=split(extractBefore(text,newline),','); j=find(fields==field);
    lines=splitlines(text); parts=split(lines(2),','); parts(j)="WRONG"; lines(2)=join(parts,',');
    write(file,join(lines,newline));
    assertError(@() read_oecd_confidence(file,"CCICP","2020-01-01"),'read_oecd_confidence:InvalidDefinition');
end

% Exercise the API CSV and failed-API FRED branches without network requests.
mockDir=fullfile(root,'mocks'); mkdir(mockDir);
write(fullfile(mockDir,'webread.m'), ...
    "function content=webread(url,varargin)"+newline+ ...
    "global ITNOW_H10_FIXTURE; if ITNOW_H10_FIXTURE.fail; error('test_confidence:HTTP403','HTTP 403'); end"+newline+ ...
    "assert(contains(string(url),'ITA.M.CCICP.IX._Z.AA.IX._Z.H') && contains(string(url),'format=csvfile')); content=ITNOW_H10_FIXTURE.text; end");
write(fullfile(mockDir,'read_table_quiet.m'), ...
    "function data=read_table_quiet(url,varargin)"+newline+ ...
    "assert(contains(string(url),'CSCICP03ITM665S')); data=table([string('2020-01-01');string('2020-03-01')],[100;121]); end");
warning('off','MATLAB:dispatcher:nameConflict'); addpath(mockDir,'-begin'); clear webread read_table_quiet
global ITNOW_H10_FIXTURE
ITNOW_H10_FIXTURE=struct('fail',false,'text',text);
[d,v,s,info]=fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1));
assert(s=="OECD" && isequaln(v,[100;NaN;121;NaN]) && info.fallback_reason=="");
ITNOW_H10_FIXTURE.fail=true;
lastwarn(''); [d,v,s,info]=fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1));
[message,id]=lastwarn;
assert(s=="FRED mirror of OECD" && isequaln(v,[100;NaN;121]) && strlength(info.fallback_reason)>0 && ...
    string(id)=="fetch_oecd_confidence:UsingFREDFallback" && contains(message,'2020-03'));
% Explicit CSV files supply one complete history.
file=fullfile(root,'explicit.csv'); write(file,chartCSV("CCICP",dates,[122;101;NaN]));
[~,v,s]=fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1),file);
assert(s=="OECD chart CSV" && isequaln(v,[101;NaN;122;NaN]));
% Default acquisition prefers a valid API history, then a complete chart CSV.
ITNOW_H10_FIXTURE.fail=false;
[~,v,s]=fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1),file,"auto");
assert(s=="OECD" && isequaln(v,[100;NaN;121;NaN]));
ITNOW_H10_FIXTURE.fail=true;
[~,v,s,info]=fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1),file,"auto");
assert(s=="OECD chart CSV" && isequaln(v,[101;NaN;122;NaN]) && strlength(info.fallback_reason)>0);
write(file,replace(chartCSV("CCICP",dates,values),'"Category","Italy"','"Category","France"'));
assertError(@() fetch_oecd_confidence("CCICP","2020-01-01",weboptions('Timeout',1),file,"auto"), ...
    'read_oecd_confidence:InvalidCountry');
config=pipeline_config('base_path',root);
assert(config.oecd_confidence_mode=="auto" && config.oecd_confidence_csv.CCICP==fullfile(root,'DATA','OECD','ITCCI.csv'));
disp('PASS confidence: official definitions, named CSV dates, gaps, history, explicit exports, API and FRED provenance.');
clear cleanup

function text=chartCSV(measure,dates,values)
    if measure=="CCICP"; title="Consumer confidence index (CCI)";
    else; title="Business confidence index (BCI)"; end
    text=string(char(65279))+'"'+title+'"'+newline+ ...
        '"Amplitude adjusted, Long-term average = 100"'+newline+'"Category","Italy"'+newline;
    for k=1:numel(dates)
        text=text+'"'+string(dates(k),'uuuu-MM-dd')+' 00:00:00",'+string(sprintf('%.17g',values(k)))+newline;
    end
end

function text=sdmxCSV(measure)
    text="OBS_VALUE,TIME_PERIOD,MEASURE,REF_AREA,FREQ,UNIT_MEASURE,ACTIVITY,ADJUSTMENT,TRANSFORMATION,TIME_HORIZ,METHODOLOGY"+newline;
    for row=["121,2020-03,";"100,2020-01,";",2020-04,"]'
        text=text+row+measure+",ITA,M,IX,_Z,AA,IX,_Z,H"+newline;
    end
end

function assertError(action,identifier)
    try; action(); catch ME; assert(strcmp(ME.identifier,identifier),'Expected %s; got %s.',identifier,ME.identifier); return; end
    error('test_confidence_confidence:MissingError','Expected %s.',identifier);
end

function write(file,text)
    fid=fopen(file,'w','n','UTF-8'); assert(fid~=-1); fprintf(fid,'%s',text); fclose(fid);
end

function clean(root,oldPath,state)
    path(oldPath); warning(state); clear webread read_table_quiet
    clear global ITNOW_H10_FIXTURE
    if isfolder(root); rmdir(root,'s'); end
end
