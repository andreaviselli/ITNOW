function [gdp,selection] = select_gdp_vintage(finalGDP,preliminaryGDP,finalInfo,preliminaryInfo,cfg)
%select_gdp_vintage Select a complete GDP vintage and check quarterly coverage.
finalObserved = finalGDP.Time(isfinite(finalGDP.GDP));
preliminaryObserved = preliminaryGDP.Time(isfinite(preliminaryGDP.GDP));
if isempty(finalObserved) || isempty(preliminaryObserved)
    error('select_gdp_vintage:NoObservations','Both GDP responses must contain observed levels.');
end
if preliminaryObserved(end) > finalObserved(end)
    gdp = preliminaryGDP; info = preliminaryInfo; source = "preliminary";
else
    gdp = finalGDP; info = finalInfo; source = "national_accounts";
end

% A growth observation in the first model quarter needs the preceding level.
firstGrowthQuarter = dateshift(dateshift(cfg.factor_start,'end','quarter'),'start','month');
firstRequired = firstGrowthQuarter-calmonths(3);
% Fixed one-month pseudo publication lag; no actual release calendar is used.
publishedThrough = cfg.eval_end-calmonths(1);
lastRequired = dateshift(dateshift(publishedThrough,'end','quarter'),'start','month');
if lastRequired > publishedThrough; lastRequired = lastRequired-calmonths(3); end
retained = isfinite(gdp.GDP) & gdp.Time <= cfg.eval_end;
retainedDates = gdp.Time(retained);
if isempty(retainedDates) || retainedDates(end) < lastRequired
    error('select_gdp_vintage:MissingEndpoint', ...
        '%s GDP edition %s does not reach the required released quarter %s.', ...
        source,info.edition,string(lastRequired,'uuuu-MM-dd'));
end
lastChecked = max(lastRequired,retainedDates(end));
requiredDates = (firstRequired:calmonths(3):lastChecked)';
[found,rows] = ismember(requiredDates,gdp.Time);
missing = ~found;
missing(found) = ~isfinite(gdp.GDP(rows(found)));
if any(missing)
    firstMissing = requiredDates(find(missing,1));
    error('select_gdp_vintage:MissingHistory', ...
        '%s GDP edition %s lacks required quarter %s. No histories were spliced or gaps filled.', ...
        source,info.edition,string(firstMissing,'uuuu-MM-dd'));
end
selection = struct('rule',"whole_preliminary_if_later_quarter", ...
    'source',source,'edition',info.edition,'url',info.url, ...
    'first_quarter',info.first_quarter,'latest_quarter',info.latest_quarter, ...
    'observed_quarters',info.observed_quarters, ...
    'required_first_level_quarter',string(firstRequired,'uuuu-MM-dd'), ...
    'required_last_released_quarter',string(lastRequired,'uuuu-MM-dd'), ...
    'retained_first_quarter',string(retainedDates(1),'uuuu-MM-dd'), ...
    'retained_last_quarter',string(retainedDates(end),'uuuu-MM-dd'), ...
    'retained_quarters',numel(retainedDates), ...
    'national_accounts',finalInfo,'preliminary',preliminaryInfo);
end
