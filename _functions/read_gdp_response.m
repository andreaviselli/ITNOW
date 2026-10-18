function gdp = read_gdp_response(payload)
%read_gdp_response Decode the single requested ISTAT GDP series by time key.
dimensions = payload.structure.dimensions.observation;
if numel(dimensions) ~= 1 || string(dimensions.id) ~= "TIME_PERIOD"
    error('read_gdp_response:InvalidDimensions','GDP must have TIME_PERIOD as its observation dimension.');
end
periods = dimensions.values;
if isempty(periods) || ~isfield(periods,'end')
    error('read_gdp_response:InvalidDates','GDP response has no quarterly period dates.');
end
ends = string({periods.end}');
if any(cellfun(@isempty,regexp(cellstr(ends),'^\d{4}-\d{2}-\d{2}','once')))
    error('read_gdp_response:InvalidDates','GDP period ends must contain calendar dates.');
end
periodEnd = datetime(extractBetween(ends,1,10),'InputFormat','yyyy-MM-dd');
quarterDates = dateshift(periodEnd,'start','month');
if any(~ismember(month(quarterDates),[3,6,9,12])) || ...
        any(periodEnd ~= dateshift(quarterDates,'end','month')) || ...
        numel(unique(quarterDates)) ~= numel(quarterDates)
    error('read_gdp_response:InvalidDates','GDP periods must be distinct quarter ends.');
end
if isfield(periods,'id')
    expected = string(year(quarterDates))+"-Q"+string(month(quarterDates)/3);
    if any(string({periods.id}') ~= expected)
        error('read_gdp_response:InvalidDates','GDP period labels and quarter-end dates disagree.');
    end
end
if numel(payload.dataSets) ~= 1
    error('read_gdp_response:InvalidSeries','Expected one ISTAT GDP dataset.');
end
seriesNames = fieldnames(payload.dataSets.series);
if numel(seriesNames) ~= 1
    error('read_gdp_response:InvalidSeries','Expected exactly one requested GDP series.');
end
observations = payload.dataSets.series.(seriesNames{1}).observations;
keys = fieldnames(observations);
level = nan(numel(quarterDates),1);
for j = 1:numel(keys)
    index = regexp(keys{j},'^x(\d+)$','tokens','once');
    if isempty(index)
        error('read_gdp_response:InvalidIndex','Unexpected GDP observation key %s.',keys{j});
    end
    row = str2double(index{1})+1; % SDMX observation indices start at zero.
    if row > numel(level)
        error('read_gdp_response:InvalidIndex','GDP observation index is outside its period list.');
    end
    value = observations.(keys{j});
    if iscell(value)
        if isempty(value); continue; end
        value = value{1};
    elseif isnumeric(value)
        if isempty(value); continue; end
        value = value(1); % Remaining elements are SDMX attributes, not GDP.
    end
    if isempty(value); continue; end
    if ~(isnumeric(value) && isscalar(value) && isreal(value)) || ...
            (~isnan(value) && (~isfinite(value) || value <= 0))
        error('read_gdp_response:InvalidLevel','GDP levels must be positive finite numbers or missing.');
    end
    level(row) = value;
end
if ~any(isfinite(level))
    error('read_gdp_response:NoObservations','GDP response contains no observed levels.');
end
gdp = sortrows(timetable(quarterDates,level,'VariableNames',{'GDP'}));
gdp.Properties.DimensionNames{1} = 'Time';
end
