function monthly = monthly_ftsemib(daily, evalEnd, runDate)
%monthly_ftsemib Average daily closes within each completed calendar month.

tradeDate = datetime(daily.Date(:));
closeValue = double(daily.Close(:));
if any(isnat(tradeDate))
    error("monthly_ftsemib:InvalidDate", ...
        "FTSE MIB contains a missing or invalid trading date.");
end

lastMonth = min(dateshift(evalEnd, "start", "month"), ...
    previous_completed_month(runDate));
monthDate = dateshift(tradeDate, "start", "month");
included = monthDate <= lastMonth;
tradeDate = tradeDate(included);
closeValue = closeValue(included);
monthDate = monthDate(included);

if numel(unique(tradeDate)) ~= numel(tradeDate)
    error("monthly_ftsemib:DuplicateDate", ...
        "FTSE MIB contains duplicate trading dates in completed months.");
end
if any(~isfinite(closeValue) | closeValue <= 0)
    error("monthly_ftsemib:InvalidClose", ...
        "FTSE MIB contains a missing or nonpositive close in completed months.");
end

[monthStart, ~, monthGroup] = unique(monthDate);
averageClose = accumarray(monthGroup, closeValue, [], @mean);
monthly = timetable(monthStart, averageClose, 'VariableNames', {'FTSEMIB'});
end
