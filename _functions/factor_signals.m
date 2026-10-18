function [history,current] = factor_signals(dates,factors,origin)
%FACTOR_SIGNALS Quarterly sums with weights [1,2,3,2,1], latest month first.
weights=[1;2;3;2;1];
ends=dates(mod(month(dates),3)==0);
signals=NaN(numel(ends),2);
for k=1:numel(ends)
    months=ends(k)-calmonths(0:4);
    [found,rows]=ismember(months,dates);
    if all(found); signals(k,:)=weights'*factors(rows,:); end
end
history=timetable(ends,signals(:,1),signals(:,2),'VariableNames',{'factor_1','factor_2'});
history.Properties.DimensionNames{1}='Time';
target=dateshift(origin,'start','quarter')+calmonths(2);
months=target-calmonths(0:4);
x=NaN(5,2); [found,rows]=ismember(months,dates); x(found,:)=factors(rows(found),:);
x(months>origin,:)=repmat(factors(end,:),sum(months>origin),1);
current=weights'*x;
end
