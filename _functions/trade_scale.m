function scale = trade_scale(source, estStart, estEnd)
%trade_scale Fixed asinh scale from the initial available training span.

names = string(source.Properties.VariableNames);
delays = publication_delays(names);
tradeDelay = delays(names == "TRADEBAL");
initial = source.Time >= estStart & ...
    source.Time <= estEnd - calmonths(tradeDelay);
values = source.TRADEBAL(initial);
values = values(isfinite(values));
scale = median(abs(values));
if isempty(scale) || ~isfinite(scale) || scale <= 0
    error("trade_scale:InvalidScale", ...
        "Initial available trade balance needs a positive median magnitude.");
end
end
