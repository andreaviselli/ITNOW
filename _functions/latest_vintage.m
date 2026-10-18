function vintage = latest_vintage(basePath)
%latest_vintage Find the newest sourceYYYYMMDD.csv vintage in DATA.

if nargin == 0 || strlength(string(basePath)) == 0
    cfg = pipeline_config();
    basePath = cfg.base_path;
end

dataDir = fullfile(string(basePath), "DATA");
files = dir(fullfile(dataDir, "source*.csv"));
if isempty(files)
    error("latest_vintage:NoData", ...
        "No source*.csv files found in %s. Rebuild data with get_data.", dataDir);
end

names = string({files.name});
tokens = regexp(cellstr(names), "^source(\d{8})\.csv$", "tokens", "once");
isMatch = ~cellfun(@isempty, tokens);
if ~any(isMatch)
    error("latest_vintage:NoVintage", ...
        "No files matching sourceYYYYMMDD.csv found in %s.", dataDir);
end

vintages = strings(sum(isMatch), 1);
matched = tokens(isMatch);
for i = 1:numel(matched)
    vintages(i) = string(matched{i}{1});
end

vintages = sort(vintages);
vintage = vintages(end);
end
