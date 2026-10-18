function [daily, coveredThrough] = read_yahoo_ftsemib(response, runDate)
%read_yahoo_ftsemib Decode unadjusted FTSE MIB daily closes in Italian time.
result=response.chart.result;
if iscell(result); result=result{1}; end
if isempty(result) || numel(result)~=1 || ...
        string(result.meta.symbol)~="FTSEMIB.MI" || ...
        string(result.meta.instrumentType)~="INDEX" || ...
        string(result.meta.exchangeTimezoneName)~="Europe/Rome"
    error('read_yahoo_ftsemib:WrongSeries','Expected the FTSEMIB.MI index in Europe/Rome.');
end
quote=result.indicators.quote;
if iscell(quote); quote=quote{1}; end
Date=datetime(double(result.timestamp(:)),'ConvertFrom','posixtime','TimeZone','Europe/Rome');
Date=dateshift(Date,'start','day'); Date.TimeZone='';
Close=double(quote.close(:));
if isempty(Date) || numel(Date)~=numel(Close) || any(isnat(Date)) || ...
        numel(unique(Date))~=numel(Date) || any(diff(Date)<=days(0))
    error('read_yahoo_ftsemib:InvalidDates','Invalid or duplicate daily dates.');
end
coveredThrough=max(Date);
% Today's quote can be intraday. It never supplies a completed daily close.
keep=Date<dateshift(runDate,'start','day');
Date=Date(keep); Close=Close(keep);
if any(~isfinite(Close) | Close<=0)
    error('read_yahoo_ftsemib:InvalidClose','Missing or nonpositive Yahoo closing price.');
end
daily=table(Date,Close);
end
