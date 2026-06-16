function vintage = ITNOWLatestVintage(basePath)
%ITNOWLatestVintage Find the newest dataYYYYMMDD.csv vintage in DATA.

if nargin == 0 || strlength(string(basePath)) == 0
    cfg = ITNOWConfig();
    basePath = cfg.base_path;
end

dataDir = fullfile(string(basePath), "DATA");
files = dir(fullfile(dataDir, "data*.csv"));
if isempty(files)
    error("ITNOWLatestVintage:NoData", ...
        "No data*.csv files found in %s.", dataDir);
end

names = string({files.name});
tokens = regexp(names, "^data(\d{8})\.csv$", "tokens", "once");
isMatch = ~cellfun(@isempty, tokens);
if ~any(isMatch)
    error("ITNOWLatestVintage:NoVintage", ...
        "No files matching dataYYYYMMDD.csv found in %s.", dataDir);
end

vintages = strings(sum(isMatch), 1);
matched = tokens(isMatch);
for i = 1:numel(matched)
    vintages(i) = string(matched{i}{1});
end

vintages = sort(vintages);
vintage = vintages(end);
end
