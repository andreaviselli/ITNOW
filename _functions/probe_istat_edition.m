function [ok, info] = probe_istat_edition(kind, edition, startDate, options)
%probe_istat_edition Probe one ISTAT GDP edition endpoint.

arguments
    kind (1, 1) string {mustBeMember(kind, ["final", "preliminary"])}
    edition (1, 1) string
    startDate (1, 1) string = "1990-01-01"
    options = weboptions("Timeout", 60)
end

info = struct("kind", kind, "edition", edition, "url", "", ...
    "latest_observation", "", "message", "");
try
    [~, info] = fetch_gdp_vintage(kind, edition, startDate, options);
    ok = true;
catch ME
    ok = false;
    info.message = ME.message;
end
end
