function [seriesDate, seriesValues, source, info] = fetch_oecd_confidence(measure, startDate, options, csvFile, mode)
%fetch_oecd_confidence Read one complete OECD history, without splicing.
arguments
    measure (1,1) string {mustBeMember(measure,["CCICP","BCICP"])}
    startDate (1,1) string = "1990-01-01"
    options = weboptions("Timeout",60)
    csvFile (1,1) string = ""
    mode (1,1) string {mustBeMember(mode,["auto","csv"])} = "csv"
end
if measure == "CCICP"
    indicator = "ITCCI"; fredID = "CSCICP03ITM665S";
    page = "https://www.oecd.org/en/data/indicators/consumer-confidence-index-cci.html";
else
    indicator = "ITCBC"; fredID = "BSCICP03ITM665S";
    page = "https://www.oecd.org/en/data/indicators/business-confidence-index-bci.html";
end

% An explicit export selects its whole history, including OECD revisions.
% Invalid or absent requested files fail; they never silently select FRED.
if strlength(csvFile) > 0 && mode == "csv"
    [seriesDate,seriesValues] = read_oecd_confidence(csvFile,measure,startDate);
    source = "OECD chart CSV";
    info = struct('source',source,'url',page,'fallback_reason',"", ...
        'local_file',csvFile,'definition',"Amplitude adjusted, long-term average = 100");
    return
end

oecdURL = "https://sdmx.oecd.org/public/rest/data/" + ...
    "OECD.SDD.STES,DSD_STES@DF_CLI,4.1/ITA.M." + measure + ...
    ".IX._Z.AA.IX._Z.H?startPeriod=" + startDate + "&format=csvfile";
csvOptions = weboptions('Timeout',options.Timeout,'ContentType','text');
try
    [content,info] = fetch_source(indicator,"OECD",oecdURL,csvOptions);
    [seriesDate,seriesValues] = readDownloadedCSV(content,measure,startDate);
    source = "OECD";
    info.definition = "Amplitude adjusted, long-term average = 100";
    return
catch ME
    failure = string(ME.message);
end

if mode == "auto" && strlength(csvFile) > 0 && isfile(csvFile)
    [seriesDate,seriesValues] = read_oecd_confidence(csvFile,measure,startDate);
    source = "OECD chart CSV";
    info = struct('source',source,'url',page,'fallback_reason',failure, ...
        'local_file',csvFile,'definition',"Amplitude adjusted, long-term average = 100");
    warning('fetch_oecd_confidence:UsingCSVFallback', ...
        '%s: OECD API failed; using the complete official CSV %s. Check its last observation in the source report.',indicator,csvFile);
    return
end

fredURL = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=" + fredID;
[dataTemp,info] = fetch_source(indicator,"FRED mirror of OECD",fredURL,options, ...
    @(url,~) read_table_quiet(url,"VariableNamingRule","preserve"));
seriesDate = datetime(string(dataTemp{:,1}),'InputFormat','uuuu-MM-dd');
seriesValues = dataTemp{:,2};
[seriesDate,seriesValues] = confidence_grid(seriesDate,seriesValues,startDate);
source = "FRED mirror of OECD"; info.fallback_reason = failure;
latest = seriesDate(find(isfinite(seriesValues),1,'last'));
warning('fetch_oecd_confidence:UsingFREDFallback', ...
    '%s: OECD API failed; using FRED history through %s. Check its freshness; an official OECD chart CSV can supply newer data. %s', ...
    indicator,string(latest,'uuuu-MM'),failure);
end

function [dates,values] = readDownloadedCSV(content,measure,startDate)
file = string(tempname)+".csv";
cleanup = onCleanup(@() delete(file));
fid = fopen(file,'w','n','UTF-8');
if fid < 0; error('fetch_oecd_confidence:TemporaryFile','Cannot save the OECD CSV response.'); end
fprintf(fid,'%s',string(content)); fclose(fid);
[dates,values] = read_oecd_confidence(file,measure,startDate);
end
