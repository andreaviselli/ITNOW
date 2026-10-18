function [dates,values] = confidence_grid(dates,values,startDate)
%confidence_grid Preserve actual calendar months and missing values.
dates = dates(:); values = values(:);
if isempty(dates) || numel(dates) ~= numel(values) || ...
        any(isnat(dates)) || any(dates ~= dateshift(dates,'start','month')) || ...
        numel(unique(dates)) ~= numel(dates)
    error('confidence_grid:InvalidDates','Confidence observations must have unique monthly dates.');
end
if ~isnumeric(values) || ~isreal(values) || any(~isnan(values) & (~isfinite(values) | values <= 0))
    error('confidence_grid:InvalidValues','Confidence levels must be positive finite numbers or missing.');
end
[dates,order] = sort(dates); values = values(order);
start = datetime(startDate,'InputFormat','uuuu-MM-dd');
if start ~= dateshift(start,'start','month')
    error('confidence_grid:InvalidStart','Confidence history must start at a calendar month.');
end
first = max(start,dates(1)); last = dates(end);
if first > last || ~any(isfinite(values(dates >= first)))
    error('confidence_grid:NoObservations','No observed confidence levels in the requested history.');
end
grid = (first:calmonths(1):last)';
filled = nan(numel(grid),1);
[found,rows] = ismember(dates,grid); filled(rows(found)) = values(found);
dates = grid; values = filled;
end
