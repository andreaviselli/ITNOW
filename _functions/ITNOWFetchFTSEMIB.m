function ITNOWFetchFTSEMIB(filePath, cfg, options)
%ITNOWFetchFTSEMIB Fetch or request the FTSE MIB CSV input.

if nargin < 2 || isempty(cfg)
    cfg = ITNOWConfig();
end
if nargin < 3 || isempty(options)
    options = weboptions("Timeout", cfg.web_timeout);
end

mode = string(cfg.ftsemib_mode);

if mode == "stooq" || mode == "stooq_then_manual"
    try
        ITNOWDownloadStooq(cfg.stooq_url, filePath, cfg, options);
        ITNOWValidateFTSEMIB(filePath, cfg);
        return
    catch ME
        if isfile(filePath)
            delete(filePath);
        end
        if isfield(cfg, "ftsemib_fallback_file") && ...
                ITNOWIsValidFTSEMIB(cfg.ftsemib_fallback_file, cfg, true)
            warning("ITNOWFetchFTSEMIB:UsingFallbackFile", ...
                "Automatic STOOQ download failed; using cached FTSE MIB file: %s", ...
                cfg.ftsemib_fallback_file);
            copyfile(cfg.ftsemib_fallback_file, filePath);
            return
        end
        if mode == "stooq"
            error("ITNOWFetchFTSEMIB:StooqFailed", ...
                "Automatic STOOQ download failed: %s\nSave the STOOQ CSV from %s to %s and rerun.", ...
                ME.message, cfg.stooq_url, cfg.ftsemib_fallback_file);
        end
        warning("ITNOWFetchFTSEMIB:StooqFailed", ...
            "Automatic STOOQ download failed: %s", ME.message);
    end
end

if isfile(filePath) && ITNOWIsValidFTSEMIB(filePath, cfg, true)
    return
end

if isfield(cfg, "interactive") && cfg.interactive
    disp("Download FTSEMIB manually and save it as FTSEMIB.csv in the Temp folder:")
    disp(filePath)
    while ~isfile(filePath)
        input("File not found yet. After saving it, press Enter to check again...", "s");
    end
    return
end

error("ITNOWFetchFTSEMIB:FileMissing", ...
    "FTSEMIB.csv is missing and interactive mode is disabled: %s", filePath);
end

function ITNOWDownloadStooq(url, filePath, cfg, options)
downloader = string(cfg.stooq_downloader);
if isfile(downloader)
    cmd = "python3 " + quote(downloader) + " --url " + quote(url) + ...
        " --output " + quote(filePath) + " --timeout " + string(cfg.web_timeout);
    [status, output] = system(cmd);
    if status ~= 0
        error("ITNOWFetchFTSEMIB:DownloaderFailed", ...
            "STOOQ downloader failed: %s", output);
    end
else
    websave(filePath, url, options);
end
end

function ok = ITNOWIsValidFTSEMIB(filePath, cfg, showWarning)
if nargin < 3
    showWarning = false;
end
try
    ITNOWValidateFTSEMIB(filePath, cfg);
    ok = true;
catch ME
    if showWarning
        warning("ITNOWFetchFTSEMIB:InvalidFallbackFile", ...
            "FTSE MIB fallback file is not usable: %s", ME.message);
    end
    ok = false;
end
end

function ITNOWValidateFTSEMIB(filePath, cfg)
if ~isfile(filePath)
    error("ITNOWFetchFTSEMIB:FileMissing", ...
        "FTSE MIB file does not exist: %s", filePath);
end
raw = fileread(filePath);
rawPreview = lower(string(raw(1:min(end, 500))));
firstLine = lower(strip(extractBefore(string(raw) + newline, newline)));
if contains(firstLine, "<!doctype html") || contains(rawPreview, "<html")
    error("ITNOWFetchFTSEMIB:HtmlInsteadOfCsv", ...
        "STOOQ returned an HTML verification page instead of CSV.");
end

t = readtable(filePath, "Delimiter", ',', "VariableNamingRule", "preserve");
vars = string(t.Properties.VariableNames);
if ~all(ismember(["Date", "Close"], vars)) || height(t) == 0
    error("ITNOWFetchFTSEMIB:InvalidStooqFile", ...
        "Downloaded FTSE MIB file does not have Date and Close columns.");
end

seriesDate = datetime(t.Date);
latestDate = max(seriesDate);
if isfield(cfg, "allow_stale_ftsemib") && ~cfg.allow_stale_ftsemib && ...
        isfield(cfg, "eval_end") && latestDate < cfg.eval_end
    error("ITNOWFetchFTSEMIB:StaleFallbackFile", ...
        "FTSE MIB file ends at %s, before Eval_End %s.", ...
        string(latestDate, "uuuu-MM-dd"), string(cfg.eval_end, "uuuu-MM-dd"));
end
end

function out = quote(value)
s = char(string(value));
s = strrep(s, '"', '\"');
out = string(['"', s, '"']);
end
