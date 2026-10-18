function info = fetch_ftsemib(filePath, cfg, options)
%fetch_ftsemib Fetch or request the FTSE MIB CSV input.

if nargin < 2 || isempty(cfg)
    cfg = pipeline_config();
end
if nargin < 3 || isempty(options)
    options = weboptions("Timeout", cfg.web_timeout);
end

mode = string(cfg.ftsemib_mode);
info = struct('source',"STOOQ",'url',string(cfg.stooq_url),'fallback_reason',"");

if mode == "stooq_yahoo"
    cutover=datetime(cfg.ftsemib_yahoo_start);
    if cfg.eval_end<cutover
        validate_ftsemib(cfg.ftsemib_fallback_file,cfg);
        copyfile(cfg.ftsemib_fallback_file,filePath);
        info=struct('source',"STOOQ cached CSV",'url',string(cfg.ftsemib_fallback_file), ...
            'fallback_reason',"Historical reference month precedes the Yahoo switch.");
        return
    end
    startTime=posixtime(datetime(cutover-calmonths(1),'TimeZone','UTC'));
    endTime=posixtime(datetime(cfg.run_date+caldays(1),'TimeZone','UTC'));
    url=sprintf('https://query1.finance.yahoo.com/v8/finance/chart/FTSEMIB.MI?period1=%.0f&period2=%.0f&interval=1d',startTime,endTime);
    yahooOptions=weboptions('Timeout',options.Timeout,'ContentType','json', ...
        'HeaderFields',{'User-Agent','Mozilla/5.0'});
    response=webread(url,yahooOptions);
    [yahoo,coveredThrough]=read_yahoo_ftsemib(response,cfg.run_date);
    stooq=readtable(cfg.ftsemib_fallback_file,'Delimiter',',','VariableNamingRule','preserve');
    [daily,detail]=merge_ftsemib(stooq,yahoo,cutover,cfg.eval_end,coveredThrough);
    writetable(daily,filePath);
    info=struct('source',"STOOQ history + Yahoo Finance",'url',string(url), ...
        'fallback_reason',"",'historical_file',string(cfg.ftsemib_fallback_file), ...
        'symbol',"FTSEMIB.MI",'definition',"FTSE MIB price-index daily Close; monthly arithmetic mean", ...
        'local_file',string(cfg.ftsemib_fallback_file),'join',detail);
    return
end


if mode == "stooq" || mode == "stooq_then_manual"
    try
        download_stooq(cfg.stooq_url, filePath, cfg, options);
        validate_ftsemib(filePath, cfg);
        return
    catch ME
        if isfile(filePath)
            delete(filePath);
        end
        if isfield(cfg, "ftsemib_fallback_file") && ...
                is_valid_ftsemib(cfg.ftsemib_fallback_file, cfg, true)
            warning("fetch_ftsemib:UsingFallbackFile", ...
                "Automatic STOOQ download failed; using cached FTSE MIB file: %s", ...
                cfg.ftsemib_fallback_file);
            copyfile(cfg.ftsemib_fallback_file, filePath);
            info = struct('source',"STOOQ cached CSV",'url',string(cfg.ftsemib_fallback_file), ...
                'fallback_reason',string(ME.message));
            return
        end
        if mode == "stooq"
            error("fetch_ftsemib:StooqFailed", ...
                "Automatic STOOQ download failed: %s\nSave the STOOQ CSV from %s to %s and rerun.", ...
                ME.message, cfg.stooq_url, cfg.ftsemib_fallback_file);
        end
        warning("fetch_ftsemib:StooqFailed", ...
            "Automatic STOOQ download failed: %s", ME.message);
    end
end

if isfile(filePath) && is_valid_ftsemib(filePath, cfg, true)
    info = struct('source',"Local FTSE MIB CSV",'url',string(filePath),'fallback_reason',"");
    return
end

if isfield(cfg, "interactive") && cfg.interactive
    disp("Download FTSEMIB manually and save it as FTSEMIB.csv in the Temp folder:")
    disp(filePath)
    while ~isfile(filePath)
        input("File not found yet. After saving it, press Enter to check again...", "s");
    end
    info = struct('source',"Manual FTSE MIB CSV",'url',string(filePath),'fallback_reason',"");
    return
end

error("fetch_ftsemib:FileMissing", ...
    "FTSEMIB.csv is missing and interactive mode is disabled: %s", filePath);
end

function download_stooq(url, filePath, cfg, options)
downloader = string(cfg.stooq_downloader);
if isfile(downloader)
    cmd = strjoin(shell_quote([string(cfg.python),downloader,"--url", ...
        string(url),"--output",string(filePath),"--timeout",string(cfg.web_timeout)]),' ');
    [status, output] = system(cmd);
    if status ~= 0
        error("fetch_ftsemib:DownloaderFailed", ...
            "STOOQ downloader failed: %s", output);
    end
else
    websave(filePath, url, options);
end
end

function ok = is_valid_ftsemib(filePath, cfg, showWarning)
if nargin < 3
    showWarning = false;
end
try
    validate_ftsemib(filePath, cfg);
    ok = true;
catch ME
    if showWarning
        warning("fetch_ftsemib:InvalidFallbackFile", ...
            "FTSE MIB fallback file is not usable: %s", ME.message);
    end
    ok = false;
end
end

function validate_ftsemib(filePath, cfg)
if ~isfile(filePath)
    error("fetch_ftsemib:FileMissing", ...
        "FTSE MIB file does not exist: %s", filePath);
end
raw = fileread(filePath);
rawPreview = lower(string(raw(1:min(end, 500))));
firstLine = lower(strip(extractBefore(string(raw) + newline, newline)));
if contains(firstLine, "<!doctype html") || contains(rawPreview, "<html")
    error("fetch_ftsemib:HtmlInsteadOfCsv", ...
        "STOOQ returned an HTML verification page instead of CSV.");
end

t = readtable(filePath, "Delimiter", ',', "VariableNamingRule", "preserve");
vars = string(t.Properties.VariableNames);
if ~all(ismember(["Date", "Close"], vars)) || height(t) == 0
    error("fetch_ftsemib:InvalidStooqFile", ...
        "Downloaded FTSE MIB file does not have Date and Close columns.");
end

seriesDate = datetime(t.Date);
latestDate = max(seriesDate);
if isfield(cfg, "allow_stale_ftsemib") && ~cfg.allow_stale_ftsemib && ...
        isfield(cfg, "eval_end") && latestDate < cfg.eval_end
    error("fetch_ftsemib:StaleFallbackFile", ...
        "FTSE MIB file ends at %s, before Eval_End %s.", ...
        string(latestDate, "uuuu-MM-dd"), string(cfg.eval_end, "uuuu-MM-dd"));
end
end
