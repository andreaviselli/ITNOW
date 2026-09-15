function [seriesDate, seriesValues, source] = ITNOWFetchOECDConfidence(measure, startDate, options)
%ITNOWFetchOECDConfidence Fetch an OECD confidence series with a FRED fallback.

arguments
    measure (1, 1) string {mustBeMember(measure, ["CCICP", "BCICP"])}
    startDate (1, 1) string = "1990-01-01"
    options = weboptions("Timeout", 60)
end

oecdURL = "https://sdmx.oecd.org/public/rest/data/" + ...
    "OECD.SDD.STES,DSD_STES@DF_CLI,4.1/ITA.M." + measure + ...
    "...AA.IX..H?startPeriod=" + startDate + ...
    "&dimensionAtObservation=AllDimensions";

try
    dataTemp = webread(oecdURL, options);
    seriesDate = datetime(append(string(cell2mat( ...
        {dataTemp.structure.dimensions.observation(10).values.id}')), '-01'));
    observations = array2table(cell2mat( ...
        struct2cell(dataTemp.dataSets.observations)')');
    seriesValues = observations{:, 1};
    source = "OECD";
    return
catch ME
    warning("ITNOWFetchOECDConfidence:UsingFREDFallback", ...
        "OECD download failed; using the FRED mirror for %s: %s", ...
        measure, ME.message);
end

if measure == "CCICP"
    fredID = "CSCICP03ITM665S";
else
    fredID = "BSCICP03ITM665S";
end

fredURL = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=" + fredID;
dataTemp = ITNOWReadTableQuiet(fredURL, "VariableNamingRule", "preserve");
seriesDate = datetime(string(dataTemp{:, 1}), "InputFormat", "uuuu-MM-dd");
seriesValues = dataTemp{:, 2};

keep = seriesDate >= datetime(startDate, "InputFormat", "uuuu-MM-dd");
seriesDate = seriesDate(keep);
seriesValues = seriesValues(keep);
source = "FRED mirror of OECD";
end
