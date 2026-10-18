function panel = origin_panel(source, originDate, windowStart, tradeScale)
%origin_panel Build one forecast month's causal, standardized panel.

if originDate > source.Time(end) || windowStart < source.Time(1) || ...
        windowStart > originDate || ...
        ~any(source.Time == originDate) || ~any(source.Time == windowStart)
    error("origin_panel:InvalidWindow", ...
        "The forecast month and window start must occur in the source panel.");
end
if ~(isscalar(tradeScale) && isfinite(tradeScale) && tradeScale > 0)
    error("origin_panel:InvalidTradeScale", ...
        "Trade-balance scale must be positive and fixed.");
end

panel = source(source.Time <= originDate, :);
names = string(panel.Properties.VariableNames);
delays = publication_delays(names);
for j = 1:numel(names)
    unavailable = panel.Time > originDate - calmonths(delays(j));
    panel{unavailable, j} = nan;
end

logSeries = ["INDPROD", "CONSTRPROD", "INDTURN", "INDPRODPRC", ...
    "INDIMPPRC", "CONSTRCOST", "EER41EUR", "FTSEMIB", ...
    "NEWPCAREG", "UNEMPLNUM", "RETLTRADE", "ITESI", "ITCCI", "ITCBC"];
for name = logSeries
    level = panel.(name);
    if any(isfinite(level) & level <= 0)
        error("origin_panel:InvalidLevel", ...
            "%s must be positive for its log change.", name);
    end
    panel.(name) = [nan; diff(log(level))];
end

panel.TOURNIGHT = [nan; diff(local_stl( ...
    panel.TOURNIGHT, panel.Time, NaT(0, 1)))];
panel.HICPALL = [nan; diff(local_stl( ...
    panel.HICPALL, panel.Time, ...
    [datetime(2001, 1, 1); datetime(2010, 1, 1); datetime(2021, 1, 1)]))];
panel.TRADEBAL = [nan; diff(asinh(panel.TRADEBAL / tradeScale))];
panel.GDP = quarterly_log_growth(panel.GDP, panel.Time);

inWindow = panel.Time >= windowStart & panel.Time <= originDate;

mu = zeros(1, numel(names));
sigma = ones(1, numel(names));
for j = 1:numel(names)
    values = panel{inWindow, j};
    values = values(isfinite(values));
    if names(j) == "GDP" && (numel(values) < 2 || std(values) <= 0)
        error("origin_panel:MissingGDPScale", ...
            "At least two varying released GDP growth observations are needed.");
    end
    if ~isempty(values)
        mu(j) = mean(values);
        if numel(values) > 1
            candidate = std(values);
            if isfinite(candidate) && candidate > 0
                sigma(j) = candidate;
            end
        end
    end
    panel{:, j} = (panel{:, j} - mu(j)) / sigma(j);
end
gdpColumn = find(names == "GDP");
if gdpColumn ~= numel(names)
    error("origin_panel:MissingGDPScale", ...
        "GDP must be the last source-panel variable.");
end
end
