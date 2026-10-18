function test_model()
%TEST_MODEL Quarterly timing, released gaps, factor weights and expanding OLS.
dates = (datetime(2019,10,1):calmonths(1):datetime(2020,6,1))';
values = [100;100;100;110;120;130;140;150;160];
origin = datetime(2020,4,1);
[history,current] = quarterly_signal(dates,values,origin,2,'logqoq');
% Q1 uses Jan/Feb plus a flat projection for March; Q2 stays at February.
assert(abs(current-log(120/mean([110,120,120]))) < 1e-14);
assert(isnan(history.value(end)));
gapped = values;
gapped(5) = NaN;
[~,missing] = quarterly_signal(dates,gapped,origin,2,'logqoq');
assert(isnan(missing),'A released source gap was filled.');
future = values;
future(dates > origin-calmonths(2)) = 1e9;
[~,same] = quarterly_signal(dates,future,origin,2,'logqoq');
assert(same == current,'Unreleased IP affected the current predictor.');

factor_dates = (datetime(2020,1,1):calmonths(1):datetime(2020,4,1))';
factors = [(1:4)',(11:14)'];
[~,signal] = factor_signals(factor_dates,factors,origin);
% June and May repeat April, giving [4,4,4,3,2] for factor one.
assert(isequal(signal,[1,2,3,2,1]*[4,14;4,14;4,14;3,13;2,12]));
rng(17);
X = randn(24,4);
beta = [0.01;0.5;0.02;-0.001;0.003];
y = [ones(24,1),X]*beta;
[prediction,estimated] = bridge_regression(X,y,[1,2,3,4]);
assert(max(abs(estimated-beta)) < 1e-12);
assert(abs(prediction-[1,1,2,3,4]*beta) < 1e-12);
[short,~] = bridge_regression(X(1:11,:),y(1:11),[1,2,3,4]);
assert(isnan(short),'Fewer than twelve quarters should not produce a fit.');

% A later raw observation must leave the earlier transformed panel unchanged.
dates = (datetime(1995,1,1):calmonths(1):datetime(2006,12,1))';
t = (1:numel(dates))';
names = ["INDPROD","CONSTRPROD","INDTURN","INDPRODPRC","INDIMPPRC", ...
    "CONSTRCOST","HICPALL","EER41EUR","FTSEMIB","TOURNIGHT", ...
    "NEWPCAREG","UNEMPLNUM","TRADEBAL","RETLTRADE","ITESI", ...
    "ITCCI","ITCBC","ITACOIN","EUROCOIN","GDP"];
data = repmat(100+.2*t+3*sin(2*pi*t/12),1,20);
data(:,13) = 50*sin(t/7);
data(:,20) = NaN;
q = mod(month(dates),3)==0;
data(q,20) = 1000+(1:sum(q))';
source = array2timetable(data,'RowTimes',dates,'VariableNames',cellstr(names));
origin = datetime(2006,4,1);
first = datetime(1996,5,1);
scale = trade_scale(source,first,origin);
panel = origin_panel(source,origin,first,scale);
revised = source;
revised{dates > origin,:} = 1e9;
same = origin_panel(revised,origin,first,scale);
assert(isequaln(panel,same));
assert(isfinite(panel.GDP(panel.Time==datetime(2006,3,1))));
march = origin_panel(source,datetime(2006,3,1),first,scale);
assert(isnan(march.GDP(end)));
disp('PASS model: timing, source gaps, five-month factors, OLS and causal preprocessing.');
end
