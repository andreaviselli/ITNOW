function growth = quarterly_log_growth(level, dates)
%quarterly_log_growth Quarterly GDP log growth on quarter-end months.

level = level(:);
dates = dates(:);
if numel(level) ~= numel(dates)
    error("quarterly_log_growth:SizeMismatch", ...
        "GDP levels and dates must have the same length.");
end
if any(isfinite(level) & ~ismember(month(dates), [3, 6, 9, 12])) || ...
        any(isfinite(level) & level <= 0)
    error("quarterly_log_growth:InvalidLevels", ...
        "GDP levels must be positive and dated to quarter-end months.");
end

growth = nan(size(level));
q = find(isfinite(level));
for j = 2:numel(q)
    if dates(q(j)) == dates(q(j-1)) + calmonths(3)
        growth(q(j)) = log(level(q(j)) / level(q(j-1)));
    end
end
end
