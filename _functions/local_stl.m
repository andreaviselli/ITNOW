function adjusted = local_stl(level, dates, breaks)
%local_stl Adjust only observations available at a forecast origin.
% breaks is a vector of first-month dates for later HICP regimes.

level = level(:);
dates = dates(:);
if any(isfinite(level) & level <= 0)
    error("local_stl:InvalidLevel", ...
        "Locally adjusted levels must be positive.");
end
adjusted = nan(size(level));
starts = [dates(1); breaks(:)];
ends = [breaks(:) - calmonths(1); dates(end)];
for k = 1:numel(starts)
    inPeriod = find(dates >= starts(k) & dates <= ends(k) & isfinite(level));
    if isempty(inPeriod)
        continue
    end
    first = inPeriod(1);
    last = inPeriod(end);
    fitFirst = first;
    while sum(isfinite(level(fitFirst:last))) < 24 && fitFirst > 1
        fitFirst = fitFirst - 1;
    end
    if sum(isfinite(level(fitFirst:last))) < 24
        error("local_stl:ShortHistory", ...
            "Local seasonal adjustment requires two years of past observations.");
    end
    fitLog = log(level(fitFirst:last));
    [trend, ~, remainder] = trenddecomp(fitLog, "stl", 12);
    segment = trend + remainder;
    periodRows = first:last;
    adjusted(periodRows) = segment(periodRows - fitFirst + 1);
    adjusted(periodRows(~isfinite(level(periodRows)))) = nan;
end
end
