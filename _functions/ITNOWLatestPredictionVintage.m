function vintage = ITNOWLatestPredictionVintage(basePath)
%ITNOWLatestPredictionVintage Find latest saved covid forecast CSV vintage.

if nargin == 0 || strlength(string(basePath)) == 0
    cfg = ITNOWConfig();
    basePath = cfg.base_path;
end

predictionDir = fullfile(string(basePath), "HISTORY", "PREDICTION");
files = dir(fullfile(predictionDir, "*_fcasts_covid.csv"));
if isempty(files)
    error("ITNOWLatestPredictionVintage:NoPredictions", ...
        "No *_fcasts_covid.csv files found in %s.", predictionDir);
end

names = string({files.name});
tokens = regexp(names, "^(\d{8})_fcasts_covid\.csv$", "tokens", "once");
isMatch = ~cellfun(@isempty, tokens);
if ~any(isMatch)
    error("ITNOWLatestPredictionVintage:NoVintage", ...
        "No files matching YYYYMMDD_fcasts_covid.csv found in %s.", predictionDir);
end

vintages = strings(sum(isMatch), 1);
matched = tokens(isMatch);
for i = 1:numel(matched)
    vintages(i) = string(matched{i}{1});
end

vintages = sort(vintages);
vintage = vintages(end);
end
