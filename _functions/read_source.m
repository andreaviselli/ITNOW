function source = read_source(dataset, basePath)
%read_source Read only the untransformed source-panel format.

if nargin < 2 || strlength(string(basePath)) == 0
    cfg = pipeline_config();
    basePath = cfg.base_path;
end
dataset = string(dataset);
token = regexp(dataset, "^source(\d{8})\.csv$", "tokens", "once");
if isempty(token)
    error("read_source:SourceFormat", ...
        "Expected an untransformed sourceYYYYMMDD.csv panel.");
end
vintage = string(token{1});
path = fullfile(string(basePath), "DATA", dataset);
metadataPath = fullfile(string(basePath), "DATA", "VINTAGE_METADATA", ...
    "vintage" + vintage + ".json");
if ~isfile(path) || ~isfile(metadataPath)
    error("read_source:MissingSource", ...
        "Missing source panel or metadata for %s. Rebuild data with get_data.", vintage);
end
metadata = jsondecode(fileread(metadataPath));
if ~isfield(metadata, "source_format") || ...
        string(metadata.source_format) ~= "origin_raw_v1"
    error("read_source:SourceFormat", ...
        "Source metadata must identify the origin_raw_v1 format.");
end
source = readtimetable(path);
publication_delays(source.Properties.VariableNames);
if any(source.Time(2:end) ~= source.Time(1:end-1) + calmonths(1)) || ...
        any(source.Time ~= dateshift(source.Time, "start", "month"))
    error("read_source:InvalidDates", ...
        "Source dates must be consecutive first days of months.");
end
end
