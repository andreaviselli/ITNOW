function evalEnd = previous_completed_month(runDate)
%previous_completed_month Return first day of the previous calendar month.

if nargin == 0 || isempty(runDate)
    runDate = datetime("today");
end
if ~isdatetime(runDate)
    runDate = datetime(runDate);
end

evalEnd = dateshift(runDate, "start", "month") - calmonths(1);
evalEnd.Format = "uuuu-MM-dd";
end
