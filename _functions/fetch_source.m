function [response,info] = fetch_source(name,source,url,options,reader)
%fetch_source Attribute download failures and record the actual request.
if nargin < 5; reader = @webread; end
info = struct('source',string(source),'url',string(url),'fallback_reason',"");
try
    response = reader(url,options);
catch ME
    failure = MException('fetch_source:DownloadFailed', ...
        '%s: %s download failed (%s). This does not establish deprecation.', ...
        string(name),string(source),string(url));
    throw(addCause(failure,ME));
end
end
