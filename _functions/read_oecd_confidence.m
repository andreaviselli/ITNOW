function [dates,values] = read_oecd_confidence(file,measure,startDate)
%read_oecd_confidence Validate an Italy OECD chart or named SDMX CSV.
arguments
    file (1,1) string
    measure (1,1) string {mustBeMember(measure,["CCICP","BCICP"])}
    startDate (1,1) string = "1990-01-01"
end
if ~isfile(file)
    error('read_oecd_confidence:MissingFile','The requested OECD CSV does not exist: %s.',file);
end
lines = readlines(file,'Encoding','UTF-8');
lines = erase(lines,char(65279));
if isempty(lines)
    error('read_oecd_confidence:InvalidCSV','The OECD CSV is empty.');
end
if measure == "CCICP"; title = "Consumer confidence index (CCI)";
else; title = "Business confidence index (BCI)"; end
chart = strip(lines(1),'both','"') == title;
if chart
    if numel(lines) < 4 || strip(lines(2),'both','"') ~= "Amplitude adjusted, Long-term average = 100"
        error('read_oecd_confidence:InvalidDefinition','Expected the OECD amplitude-adjusted confidence index.');
    end
    skip = 2;
else
    skip = 0;
end
opts = detectImportOptions(file,'FileType','text','Delimiter',',', ...
    'NumHeaderLines',skip,'VariableNamingRule','preserve','Encoding','UTF-8');
opts = setvartype(opts,opts.VariableNames,'string');
data = readtable(file,opts); names = string(data.Properties.VariableNames);
if chart
    if ~isequal(names,["Category","Italy"])
        error('read_oecd_confidence:InvalidCountry','Export exactly the Italy confidence series.');
    end
    periods = data.Category;
    if any(ismissing(periods)) || any(cellfun(@isempty,regexp(cellstr(periods), ...
            '^\d{4}-\d{2}-01( 00:00:00)?$','once')))
        error('read_oecd_confidence:InvalidDates','Expected monthly OECD chart dates.');
    end
    dates = datetime(extractBetween(periods,1,10),'InputFormat','uuuu-MM-dd');
    raw = data.Italy;
else
    required = ["REF_AREA","FREQ","MEASURE","UNIT_MEASURE","ACTIVITY", ...
        "ADJUSTMENT","TRANSFORMATION","TIME_HORIZ","METHODOLOGY","TIME_PERIOD","OBS_VALUE"];
    if ~all(ismember(required,names))
        error('read_oecd_confidence:InvalidCSV','Expected an OECD chart export or named SDMX CSV columns.');
    end
    expected = ["ITA","M",measure,"IX","_Z","AA","IX","_Z","H"];
    for j = 1:numel(expected)
        if any(ismissing(data.(required(j)))) || any(data.(required(j)) ~= expected(j))
            error('read_oecd_confidence:InvalidDefinition','Unexpected OECD %s; do not mix confidence definitions.',required(j));
        end
    end
    periods = data.TIME_PERIOD;
    if any(ismissing(periods)) || any(cellfun(@isempty,regexp(cellstr(periods),'^\d{4}-\d{2}$','once')))
        error('read_oecd_confidence:InvalidDates','Expected monthly SDMX periods.');
    end
    dates = datetime(periods+"-01",'InputFormat','uuuu-MM-dd');
    raw = data.OBS_VALUE;
end
missing = ismissing(raw) | raw == "" | raw == "." | raw == "NaN";
values = str2double(raw);
if any(isnan(values) & ~missing)
    error('read_oecd_confidence:InvalidValues','The OECD CSV contains nonnumeric confidence levels.');
end
if isempty(dates) || min(dates) > datetime(startDate,'InputFormat','uuuu-MM-dd')
    error('read_oecd_confidence:IncompleteHistory', ...
        'Expand the OECD chart to include the requested history starting %s.',startDate);
end
[dates,values] = confidence_grid(dates,values,startDate);
end
