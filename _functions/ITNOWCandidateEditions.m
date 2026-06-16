function editions = ITNOWCandidateEditions(runDate, lookbackMonths)
%ITNOWCandidateEditions Build ISTAT edition candidates like 2026M4.

if nargin < 1 || isempty(runDate)
    runDate = datetime("today");
end
if nargin < 2 || isempty(lookbackMonths)
    lookbackMonths = 12;
end
if ~isdatetime(runDate)
    runDate = datetime(runDate);
end

monthStart = dateshift(runDate, "start", "month");
editions = strings(lookbackMonths + 1, 1);
for i = 0:lookbackMonths
    d = monthStart - calmonths(i);
    editions(i + 1) = string(year(d)) + "M" + string(month(d));
end
end
