function [history,current] = quarterly_signal(dates,values,origin,delay,transform)
%QUARTERLY_SIGNAL Complete quarterly history and the current-quarter signal.
% Only months beyond the publication cutoff are projected at the last level.
cutoff=origin-calmonths(delay);
keep=dates<=cutoff; dates=dates(keep); values=values(keep);
quarter=dateshift(dates,'start','quarter')+calmonths(2);
ends=unique(quarter); means=NaN(numel(ends),1);
for k=1:numel(ends)
    x=values(quarter==ends(k));
    if numel(x)==3 && all(isfinite(x)); means(k)=mean(x); end
end
switch transform
    case 'logqoq'
        signal=[NaN;diff(log(means))];
    case 'level'
        signal=means;
    otherwise
        error('quarterly_signal:Transform','Unknown transform: %s',transform);
end
history=timetable(ends,signal,'VariableNames',{'value'});
history.Properties.DimensionNames{1}='Time';
target=dateshift(origin,'start','quarter')+calmonths(2);
first=dateshift(origin,'start','quarter');
if strcmp(transform,'logqoq'); first=first-calmonths(3); end
months=(first:calmonths(1):target)';
x=NaN(numel(months),1); [found,rows]=ismember(months,dates); x(found)=values(rows(found));
last=find(isfinite(values),1,'last');
if ~isempty(last); x(months>cutoff)=values(last); end
current=NaN;
if all(isfinite(x))
    if strcmp(transform,'logqoq'); current=log(mean(x(4:6))/mean(x(1:3)));
    else; current=mean(x); end
end
end
