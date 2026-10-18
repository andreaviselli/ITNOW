% Yahoo monthly cutover, overlap validation and raw Close.
root=string(tempname); mkdir(root); cleanup=onCleanup(@() rmdir(root,'s'));
aug=(datetime(2026,8,1):caldays(1):datetime(2026,8,31))';
aug=aug(~ismember(weekday(aug),[1,7]));
sep=(datetime(2026,9,1):caldays(1):datetime(2026,9,30))';
sep=sep(~ismember(weekday(sep),[1,7]));
stooq=table([datetime(2026,7,31);aug;datetime(2026,9,15)], ...
    [99;100+(1:numel(aug))';999],'VariableNames',{'Date','Close'});
yahoo=table([aug;sep;datetime(2026,10,8)], ...
    [round(stooq.Close(2:end-1));120+(1:numel(sep))';200], ...
    'VariableNames',{'Date','Close'});
[daily,detail]=merge_ftsemib(stooq,yahoo,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,10,8));
assert(isequal(daily(daily.Date<datetime(2026,9,1),:),stooq(stooq.Date<datetime(2026,9,1),:)));
assert(isequal(daily(daily.Date>=datetime(2026,9,1),:),yahoo(yahoo.Date>=datetime(2026,9,1),:)));
assert(daily.Close(daily.Date==datetime(2026,9,15))~=999);
unusedBad=stooq; unusedBad.Close(end)=NaN;
assert(isequal(daily,merge_ftsemib(unusedBad,yahoo,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,10,8))));
assert(detail.overlap_observations==21 && numel(unique(daily.Date))==height(daily));
monthly=monthly_ftsemib(daily,datetime(2026,9,1),datetime(2026,10,9));
assert(monthly.FTSEMIB(monthly.Properties.RowTimes==datetime(2026,9,1))==mean(121:142));
expectError(@() merge_ftsemib(stooq,yahoo,datetime(2026,9,2),datetime(2026,9,1),datetime(2026,10,8)), ...
    'merge_ftsemib:InvalidCutover');
bad=yahoo; bad.Close(1)=bad.Close(1)+1;
expectError(@() merge_ftsemib(stooq,bad,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,10,8)), ...
    'merge_ftsemib:InconsistentOverlap');
bad=[yahoo;yahoo(1,:)];
expectError(@() merge_ftsemib(stooq,bad,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,10,8)), ...
    'merge_ftsemib:InvalidDaily');
bad=yahoo(2:end,:);
expectError(@() merge_ftsemib(stooq,bad,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,10,8)), ...
    'merge_ftsemib:IncompleteOverlap');
expectError(@() merge_ftsemib(stooq,yahoo,datetime(2026,9,1),datetime(2026,9,1),datetime(2026,9,15)), ...
    'merge_ftsemib:IncompleteMonth');

% Convert UTC timestamps to the Italian date and exclude today's intraday bar.
timestamps=posixtime(datetime([2026;2026],[10;10],[7;8],[23;23],30,0,'TimeZone','UTC'));
result=struct('meta',struct('symbol','FTSEMIB.MI','instrumentType','INDEX', ...
    'exchangeTimezoneName','Europe/Rome'),'timestamp',timestamps, ...
    'indicators',struct('quote',struct('close',[100;999],'adjclose',[77;77])));
response=struct('chart',struct('result',result));
[decoded,covered]=read_yahoo_ftsemib(response,datetime(2026,10,9));
assert(height(decoded)==1 && decoded.Date==datetime(2026,10,8) && decoded.Close==100);
assert(covered==datetime(2026,10,9));
bad=response; bad.chart.result.meta.symbol='OTHER';
expectError(@() read_yahoo_ftsemib(bad,datetime(2026,10,9)), 'read_yahoo_ftsemib:WrongSeries');
bad=response; bad.chart.result.indicators.quote.close(1)=NaN;
expectError(@() read_yahoo_ftsemib(bad,datetime(2026,10,9)), 'read_yahoo_ftsemib:InvalidClose');

% Exercise acquisition with a saved response; no live download in this test.
mockDir=fullfile(root,'mock'); mkdir(mockDir);
global ITNOW_YAHOO_FIXTURE
mockDates=[yahoo.Date;datetime(2026,10,9)];
result.timestamp=posixtime(datetime(mockDates,'TimeZone','Europe/Rome')+hours(9));
result.indicators.quote.close=[yahoo.Close;999];
ITNOW_YAHOO_FIXTURE=struct('chart',struct('result',result));
fid=fopen(fullfile(mockDir,'webread.m'),'w');
fprintf(fid,'function value=webread(varargin)\nglobal ITNOW_YAHOO_FIXTURE; value=ITNOW_YAHOO_FIXTURE;\nend\n'); fclose(fid);
cache=fullfile(root,'stooq.csv'); output=fullfile(root,'joined.csv'); writetable(stooq,cache);
oldPath=path; pathCleanup=onCleanup(@() path(oldPath)); addpath(mockDir,'-begin');
cfg=pipeline_config('run_date',datetime(2026,10,9),'ftsemib_fallback_file',cache);
info=fetch_ftsemib(output,cfg,weboptions('Timeout',1));
assert(info.source=="STOOQ history + Yahoo Finance" && info.join.overlap_observations==21);
assert(isequal(readtable(output),daily));
assert(isequal(readtable(cache),stooq));
clear pathCleanup
clear global ITNOW_YAHOO_FIXTURE
disp('PASS FTSE Yahoo: month boundary, overlap, missing/invalid closes, incomplete coverage, intraday exclusion and acquisition.');

function expectError(call,identifier)
try; call(); catch ME; assert(strcmp(ME.identifier,identifier),ME.message); return; end
error('Test:MissingError','Expected %s.',identifier);
end
