function report = source_status(source,provenance,evalEnd,notices)
%source_status Report freshness; confirm deprecation only with a notice.
% notices.(indicator): status ('discontinued'/'replaced'), source_url,
% notice_url (provider notice), verified_on (YYYY-MM-DD), and optional replacement.
% Notices are previously verified evidence, not inferred from missing data.
if nargin < 4; notices = struct(); end
names = string(source.Properties.VariableNames);
delays = publication_delays(names);
blank = struct('indicator',"",'source',"",'url',"",'fallback_reason',"", ...
    'local_file',"",'definition',"", ...
    'last_observation',"",'expected_through',"",'months_behind',NaN, ...
    'missing_last_five',false,'availability',"",'lifecycle',"unconfirmed", ...
    'notice_url',"",'verified_on',"",'replacement',"");
report = repmat(blank,numel(names),1);
tailDates = (evalEnd-calmonths(4):calmonths(1):evalEnd)';
for j = 1:numel(names)
    name = names(j);
    if ~isfield(provenance,name) || ...
            ~all(isfield(provenance.(name),{'source','url'}))
        error('source_status:MissingProvenance','%s: record the downloaded source and URL.',name);
    end
    info = provenance.(name); row = blank;
    row.indicator = name; row.source = string(info.source); row.url = string(info.url);
    if isfield(info,'fallback_reason'); row.fallback_reason = string(info.fallback_reason); end
    if isfield(info,'local_file'); row.local_file = string(info.local_file); end
    if isfield(info,'definition'); row.definition = string(info.definition); end
    observed = source.Time(isfinite(source.(name)) & source.Time <= evalEnd);
    expected = evalEnd-calmonths(delays(j));
    if name == "GDP"
        expectedQuarter = dateshift(dateshift(expected,'end','quarter'),'start','month');
        if expectedQuarter > expected; expectedQuarter = expectedQuarter-calmonths(3); end
        expected = expectedQuarter;
    end
    row.expected_through = string(expected,'uuuu-MM-dd');
    row.missing_last_five = ~any(ismember(tailDates,observed));
    if isempty(observed)
        row.availability = "unavailable";
    else
        latest = max(observed); row.last_observation = string(latest,'uuuu-MM-dd');
        row.months_behind = max(0,12*(year(expected)-year(latest))+month(expected)-month(latest));
        if row.missing_last_five; row.availability = "stale";
        elseif latest < expected; row.availability = "behind_pseudo_lag";
        else; row.availability = "within_pseudo_lag"; end
    end
    if isfield(notices,name)
        notice = notices.(name);
        if ~all(isfield(notice,{'status','source_url','notice_url','verified_on'})) || ...
                ~any(string(notice.status) == ["discontinued","replaced"]) || ...
                string(notice.source_url) ~= row.url || ...
                isempty(regexp(char(string(notice.notice_url)),'^https?://','once')) || ...
                isempty(regexp(char(string(notice.verified_on)),'^\d{4}-\d{2}-\d{2}$','once'))
            error('source_status:InvalidNotice', ...
                '%s: confirmed deprecation requires a verified provider notice for the exact source URL.',name);
        end
        verifiedDate = datetime(notice.verified_on,'InputFormat','yyyy-MM-dd'); %#ok<NASGU>
        row.lifecycle = "confirmed_"+string(notice.status);
        row.notice_url = string(notice.notice_url); row.verified_on = string(notice.verified_on);
        if isfield(notice,'replacement'); row.replacement = string(notice.replacement); end
        if notice.status == "replaced" && strlength(row.replacement) == 0
            error('source_status:InvalidNotice','%s: record the replacement named by the provider.',name);
        end
    end
    report(j) = row;
end
end
