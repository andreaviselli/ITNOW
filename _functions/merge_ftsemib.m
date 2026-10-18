function [daily, detail] = merge_ftsemib(stooq, yahoo, cutover, evalEnd, coveredThrough)
%merge_ftsemib Use Stooq before the monthly cutover and Yahoo afterwards.
cutover=datetime(cutover);
if ~isscalar(cutover) || cutover~=dateshift(cutover,'start','month')
    error('merge_ftsemib:InvalidCutover','The provider switch must start a calendar month.');
end
stooq=stooq(:,{'Date','Close'}); yahoo=yahoo(:,{'Date','Close'});
stooq.Date=datetime(stooq.Date); yahoo.Date=datetime(yahoo.Date);
if any(isnat(stooq.Date))
    error('merge_ftsemib:InvalidDaily','Invalid dates in the historical file.');
end
% The discarded cache tail, including its intraday/missing quotes, is unused.
stooq=stooq(stooq.Date<cutover,:);
for input={stooq,yahoo}
    t=input{1};
    if isempty(t) || any(isnat(t.Date)) || numel(unique(t.Date))~=height(t) || ...
            any(~isfinite(t.Close) | t.Close<=0)
        error('merge_ftsemib:InvalidDaily','Daily dates and closes must be valid and unique.');
    end
end
% Confirm the last complete Stooq month against the same Yahoo trading dates.
overlapStart=cutover-calmonths(1);
a=stooq(stooq.Date>=overlapStart & stooq.Date<cutover,:);
b=yahoo(yahoo.Date>=overlapStart & yahoo.Date<cutover,:);
a=sortrows(a,'Date'); b=sortrows(b,'Date');
if isempty(a) || ~isequal(a.Date,b.Date)
    error('merge_ftsemib:IncompleteOverlap','The preceding month must have identical trading dates.');
end
maxDifference=max(abs(a.Close-b.Close));
% Yahoo rounds index closes to whole points; Stooq provides two decimals.
if maxDifference>0.51
    error('merge_ftsemib:InconsistentOverlap','The overlap differs beyond rounding (%.4f index points).',maxDifference);
end
monthEnd=dateshift(evalEnd,'end','month');
if evalEnd>=cutover && coveredThrough<monthEnd
    error('merge_ftsemib:IncompleteMonth','Yahoo has not covered the requested complete month.');
end
daily=sortrows([stooq(stooq.Date<cutover,:);yahoo(yahoo.Date>=cutover,:)],'Date');
if numel(unique(daily.Date))~=height(daily)
    error('merge_ftsemib:DuplicateDate','The merged history has duplicate dates.');
end
detail=struct('cutover_month',string(cutover,'uuuu-MM-dd'), ...
    'overlap_start',string(overlapStart,'uuuu-MM-dd'), ...
    'overlap_observations',height(a),'overlap_max_difference',maxDifference, ...
    'covered_through',string(coveredThrough,'uuuu-MM-dd'));
end
