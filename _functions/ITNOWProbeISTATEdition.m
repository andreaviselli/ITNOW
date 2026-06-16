function [ok, info] = ITNOWProbeISTATEdition(kind, edition, startDate, options)
%ITNOWProbeISTATEdition Probe one ISTAT GDP edition endpoint.

arguments
    kind (1, 1) string {mustBeMember(kind, ["final", "preliminary"])}
    edition (1, 1) string
    startDate (1, 1) string = "1990-01-01"
    options = weboptions("Timeout", 60)
end

info = struct("kind", kind, "edition", edition, "url", "", ...
    "latest_observation", "", "message", "");

if kind == "final"
    url = "https://esploradati.istat.it/SDMXWS/rest/data/" + ...
        "IT1,163_184_DF_DCCN_PILQ_1,1.0/Q.IT.B1GQ_B_W2_S1.L_2020.Y." + ...
        edition + "/ALL/?detail=full&startPeriod=" + startDate + ...
        "&dimensionAtObservation=TIME_PERIOD";
else
    url = "https://esploradati.istat.it/SDMXWS/rest/data/" + ...
        "IT1,163_156_DF_DCCN_SQCQ_3,1.0/Q.IT.B1GQ_B_W2_S1.L_2020.Y." + ...
        edition + "_1/ALL/?detail=full&startPeriod=" + startDate + ...
        "&dimensionAtObservation=TIME_PERIOD";
end
info.url = url;

try
    dataTemp = webread(url, options);
    obs = dataTemp.structure.dimensions.observation.values;
    latest = datetime(string(cell2mat({obs.end}'))) + caldays;
    info.latest_observation = string(max(latest), "uuuu-MM-dd");
    ok = true;
catch ME
    ok = false;
    info.message = ME.message;
end
end
