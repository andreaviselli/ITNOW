function ITNOWDataProgress(name, detail, total)
%ITNOWDataProgress Print compact progress messages for data ingestion.

persistent counter seriesTotal

if string(name) == "__reset__"
    counter = 0;
    seriesTotal = total;
    return
end

if isempty(counter)
    counter = 0;
end
if isempty(seriesTotal)
    seriesTotal = total;
end
if nargin < 2
    detail = "";
end

counter = counter + 1;
fprintf("  [%02d/%02d] %-12s %s\n", counter, seriesTotal, string(name), string(detail));
end
