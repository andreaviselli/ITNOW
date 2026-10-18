function monthly = read_eurostat(payload,name)
%read_eurostat Decode one monthly JSON-stat series without compacting gaps.
if nargin < 2; name = "Value"; end
name = string(name);
if ~isstruct(payload) || ~all(isfield(payload,{'id','size','dimension','value'}))
    error('read_eurostat:InvalidResponse','%s: expected a JSON-stat dataset, not an error or metadata-only response.',name);
end
ids = string(payload.id(:)); sizes = double(payload.size(:));
timeDim = find(ids == "time");
if numel(timeDim) ~= 1 || numel(ids) ~= numel(sizes) || ...
        numel(unique(ids)) ~= numel(ids) || any(~isfinite(sizes) | sizes < 0 | sizes ~= fix(sizes)) || ...
        any(sizes(ids ~= "time") ~= 1)
    error('read_eurostat:InvalidDimensions','%s: request exactly one monthly series; other dimensions must have size one.',name);
end
if ~any(ids == "freq") || ~isfield(payload.dimension,'freq')
    error('read_eurostat:InvalidFrequency','%s: the response must identify monthly frequency.',name);
end
freqIndex = payload.dimension.freq.category.index;
if isstruct(freqIndex); freqCodes = string(fieldnames(freqIndex)); else; freqCodes = string(freqIndex(:)); end
if numel(freqCodes) ~= 1 || freqCodes ~= "M"
    error('read_eurostat:InvalidFrequency','%s: expected monthly frequency M.',name);
end
n = sizes(timeDim);
category = payload.dimension.time.category;
if ~isfield(category,'index')
    error('read_eurostat:InvalidTimeIndex','%s: time category indices are required.',name);
end
index = category.index;
if isstruct(index)
    keys = fieldnames(index); codes = strings(numel(keys),1); positions = nan(numel(keys),1);
    for j = 1:numel(keys)
        token = regexp(keys{j},'^x?(\d{4})[-_](\d{2})$','tokens','once');
        if isempty(token)
            error('read_eurostat:InvalidDates','%s: expected YYYY-MM time codes.',name);
        end
        codes(j) = string(token{1})+"-"+string(token{2});
        position = index.(keys{j});
        if ~(isnumeric(position) && isscalar(position) && isreal(position))
            error('read_eurostat:InvalidTimeIndex','%s: invalid time category position.',name);
        end
        positions(j) = position;
    end
else
    codes = string(index(:)); positions = (0:numel(codes)-1)';
end
if numel(codes) ~= n || ~isequal(sort(positions),(0:n-1)')
    error('read_eurostat:InvalidTimeIndex','%s: time positions must cover 0,...,N-1 exactly once.',name);
end
if any(cellfun(@isempty,regexp(cellstr(codes),'^\d{4}-(0[1-9]|1[0-2])$','once')))
    error('read_eurostat:InvalidDates','%s: expected valid YYYY-MM time codes.',name);
end
dates = datetime(codes,'InputFormat','yyyy-MM');
if numel(unique(dates)) ~= n
    error('read_eurostat:InvalidDates','%s: duplicate calendar months.',name);
end
timeByPosition = NaT(n,1); timeByPosition(positions+1) = dates;
levels = nan(n,1); value = payload.value;
if isstruct(value)
    keys = fieldnames(value); seen = false(n,1);
    for j = 1:numel(keys)
        token = regexp(keys{j},'^x(\d+)$','tokens','once');
        if isempty(token)
            error('read_eurostat:InvalidValueIndex','%s: unexpected value index %s.',name,keys{j});
        end
        row = str2double(token{1})+1;
        if row > n || seen(row)
            error('read_eurostat:InvalidValueIndex','%s: duplicate or out-of-range value index.',name);
        end
        seen(row) = true; levels(row) = readNumber(value.(keys{j}),name);
    end
elseif isnumeric(value) && isreal(value) && (isvector(value) || isempty(value))
    if ~isempty(value) && numel(value) ~= n
        error('read_eurostat:InvalidValues','%s: dense values must match the declared time size.',name);
    end
    if ~isempty(value); levels = value(:); end
elseif iscell(value) && (isvector(value) || isempty(value))
    if numel(value) ~= n
        error('read_eurostat:InvalidValues','%s: dense values must match the declared time size.',name);
    end
    for j = 1:n; levels(j) = readNumber(value{j},name); end
else
    error('read_eurostat:InvalidValues','%s: invalid JSON-stat value representation.',name);
end
if any(isinf(levels))
    error('read_eurostat:InvalidValues','%s: observed values must be finite.',name);
end
% Non-time dimensions are singletons, so each cube position is one time slot.
monthly = sortrows(timetable(timeByPosition,levels,'VariableNames',cellstr(name)));
monthly.Properties.DimensionNames{1} = 'Time';
if n > 0
    monthly = retime(monthly,(monthly.Time(1):calmonths(1):monthly.Time(end))', ...
        'fillwithmissing');
end
end

function number = readNumber(value,name)
if isempty(value); number = NaN; return; end % JSON null.
if ~(isnumeric(value) && isscalar(value) && isreal(value)) || isinf(value)
    error('read_eurostat:InvalidValues','%s: values must be finite numbers or missing.',name);
end
number = value;
end
