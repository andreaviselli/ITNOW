function [gdp,info] = fetch_gdp_vintage(kind,edition,startDate,options,reader)
%fetch_gdp_vintage Fetch and decode GDP in a local workspace, without reuse.
if nargin < 5; reader = @webread; end
kind = string(kind); edition = string(edition); startDate = string(startDate);
if kind == "final"
    flow = "IT1,163_184_DF_DCCN_PILQ_1,1.0"; editionKey = edition;
elseif kind == "preliminary"
    flow = "IT1,163_156_DF_DCCN_SQCQ_3,1.0"; editionKey = edition+"_1";
else
    error('fetch_gdp_vintage:InvalidKind','GDP source must be final or preliminary.');
end
url = "https://esploradati.istat.it/SDMXWS/rest/data/"+flow+ ...
    "/Q.IT.B1GQ_B_W2_S1.L_2020.Y."+editionKey+ ...
    "/ALL/?detail=full&startPeriod="+startDate+"&dimensionAtObservation=TIME_PERIOD";
try
    payload = reader(url,options);
catch ME
    failure = MException('fetch_gdp_vintage:DownloadFailed', ...
        'Could not download %s GDP edition %s. No GDP response was reused.',kind,edition);
    throw(addCause(failure,ME));
end
gdp = read_gdp_response(payload);
observed = gdp.Time(isfinite(gdp.GDP));
info = struct('kind',kind,'edition',edition,'url',url, ...
    'first_quarter',string(observed(1),'uuuu-MM-dd'), ...
    'latest_quarter',string(observed(end),'uuuu-MM-dd'), ...
    'observed_quarters',numel(observed), ...
    'latest_observation',string(observed(end)+calmonths(1),'uuuu-MM-dd'), ...
    'message',"");
end
