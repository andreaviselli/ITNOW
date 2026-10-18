function get_data(cfg)
%GET_DATA Download the source panel and record provider metadata.
if nargin == 0
    cfg = pipeline_config();
end
original_folder = pwd;
cleanup = onCleanup(@() cd(original_folder));
startDate_ALL = "1990-01-01";
startDate_INDIMPPRC = "2005-01-01";
startDate_CONSTRPROD = "1995-01-01";
runDate = cfg.run_date;
runDate.Format = "uuuu-MM-dd";
endDate = string(runDate);

edition = string(cfg.edition);
preliminary_ed = string(cfg.preliminary_ed);
if cfg.auto_discover_istat && ...
        (strlength(edition) == 0 || strlength(preliminary_ed) == 0)
    [edition, preliminary_ed, istat_metadata] = discover_istat_editions(cfg);
else
    istat_metadata = struct("final", edition, "preliminary", preliminary_ed);
end

options = weboptions('Timeout', cfg.web_timeout);

% Create and set the data output folders and temporary working directory
base_path = cfg.base_path;
data_dir = fullfile(base_path, "DATA");
temp_dir = fullfile(base_path, "DATA", "Temp");
data_dirs = [temp_dir, fullfile(data_dir, "GDP_History"), ...
    fullfile(data_dir, "VINTAGE_METADATA")];
for data_dir_index = 1:numel(data_dirs)
    if ~isfolder(data_dirs(data_dir_index))
        mkdir(data_dirs(data_dir_index))
    end
end
cd(temp_dir)

fprintf("Building data vintage %s.\n", strrep(endDate, "-", ""))
if cfg.interactive
    disp('Press any key to submit the job.')
    pause
end
fprintf("Source downloads:\n")

colNames = [];
source_info = struct();
seriesDate = datetime("1995-01-01","Format","uuuu-MM-dd"):calmonths(1): ...
    cfg.eval_end + calmonths(1);
dataTable = timetable(seriesDate');
data_progress("__reset__", "", 21);

% Quarterly Gross Domestic Product; Chain linked volumes (2020), million
% euro; SA; National accounts indicator (ESA 2010): Gross domestic product
% at market prices
data_progress("GDP", "ISTAT national-accounts edition " + edition, 21);
[gdpFinal, gdpFinalInfo] = fetch_gdp_vintage( ...
    "final", edition, startDate_ALL, options);
data_progress("GDP_PRELIM", "ISTAT preliminary edition " + preliminary_ed, 21);
[gdpPreliminary, gdpPreliminaryInfo] = fetch_gdp_vintage( ...
    "preliminary", preliminary_ed, startDate_ALL, options);
[seriesGDP, gdp_selection] = select_gdp_vintage( ...
    gdpFinal, gdpPreliminary, gdpFinalInfo, gdpPreliminaryInfo, cfg);
fprintf("Using complete %s GDP edition %s, through %s.\n", ...
    gdp_selection.source, gdp_selection.edition, gdp_selection.latest_quarter);
source_info.GDP = struct('source', "ISTAT " + gdp_selection.source, ...
    'url', gdp_selection.url, 'fallback_reason', "");

% Use release-month dates for assembly, then map GDP to its target quarter.
seriesGDP.Time = seriesGDP.Time + calmonths(1);
dataTable = synchronize(dataTable, seriesGDP);
colNames = [colNames, "GDP"];

% Production in industry; Index 2021=100; NACE Rev. 2: B-D; SCA
data_progress("INDPROD", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m?format=JSON&lang=en&freq=M&indic_bt=PRD&nace_r2=B-D&s_adj=SCA&unit=I21&geo=IT&sinceTimePeriod='+startDate_ALL;
[dataTemp, source_info.INDPROD] = fetch_source( ...
    "INDPROD", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "INDPROD");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDPROD"];

% Production in construction ; Index 2021=100; NACE Rev. 2: F; SCA
data_progress("CONSTRPROD", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_copr_m?format=JSON&lang=en&freq=M&indic_bt=PRD&nace_r2=F&s_adj=SCA&unit=I21&geo=IT&sinceTimePeriod='+startDate_CONSTRPROD;
[dataTemp, source_info.CONSTRPROD] = fetch_source( ...
    "CONSTRPROD", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "CONSTRPROD");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"CONSTRPROD"];

% Turnover in industry, total; Index 2021=100; NACE Rev. 2: B-D; SCA
data_progress("INDTURN", "ISTAT", 21);
source_url = 'https://esploradati.istat.it/SDMXWS/rest/data/IT1,114_191_DF_DCSC_ORDFATT_9,1.0/M..IND_TURN_21.Y.T.0020/ALL/?detail=full&startPeriod=1990-01-01&dimensionAtObservation=TIME_PERIOD';
[dataTemp, source_info.INDTURN] = fetch_source( ...
    "INDTURN", "ISTAT", source_url, options);
Time = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
seriesTable = timetable(Time,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDTURN"];

% Producer prices in industry, total; Index 2021=100
data_progress("INDPRODPRC", "ISTAT", 21);
source_url = 'https://esploradati.istat.it/SDMXWS/rest/data/IT1,145_360_DF_DCSC_PREZZPIND_1_4,1.0/M.IT.IND_PRIC_2021.N.D.0020/ALL/?detail=full&startPeriod='+startDate_ALL'+'&dimensionAtObservation=TIME_PERIOD';
[dataTemp, source_info.INDPRODPRC] = fetch_source( ...
    "INDPRODPRC", "ISTAT", source_url, options);
Time = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
for element = 1:size(seriesTable,1); seriesTable{element} = seriesTable{element}(1); end
seriesTable = timetable(Time,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDPRODPRC"];

% Import prices in industry; NSA
data_progress("INDIMPPRC", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpi_m?format=JSON&lang=en&freq=M&indic_bt=PRC_IMP&cpa2_1=CPA_B-D&s_adj=NSA&unit=I21&geo=IT&sinceTimePeriod='+startDate_INDIMPPRC;
[dataTemp, source_info.INDIMPPRC] = fetch_source( ...
    "INDIMPPRC", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "INDIMPPRC");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDIMPPRC"];

% Residential and non-residential buildings; Index 2021=100; NSA
data_progress("CONSTRCOST", "ISTAT", 21);
source_url = 'https://esploradati.istat.it/SDMXWS/rest/data/IT1,145_361_DF_DCSC_FABBRESID_1_7,1.0/M.IT.CONS_CST2_2021.N.I/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD';
[dataTemp, source_info.CONSTRCOST] = fetch_source( ...
    "CONSTRCOST", "ISTAT", source_url, options);
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0.observations);
for element = 1:size(seriesTable,1); seriesTable{element} = seriesTable{element}(1); end
seriesTable = timetable(seriesDate,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"CONSTRCOST"];

% HICP; All-items HICP; Index 2015=100
data_progress("HICPALL", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/prc_hicp_minr/1.0/*.*.*.*?c[freq]=M&c[unit]=I15&c[coicop18]=TOTAL&c[geo]=IT&c[TIME_PERIOD]=ge:1996-01&compress=false&format=json&lang=en';
[dataTemp, source_info.HICPALL] = fetch_source( ...
    "HICPALL", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "HICPALL");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"HICPALL"];

% Nominal EER-41/Euro; Broad EER group of trading partners
data_progress("EER41EUR", "ECB", 21);
filePath = fullfile(cd,'/EER41EUR.csv');
source_url = 'https://data-api.ecb.europa.eu/service/data/EXR/M.E03.EUR.EN00.A?format=csvdata';
[~, source_info.EER41EUR] = fetch_source( ...
    "EER41EUR", "ECB", source_url, options, @(url,opt) websave(filePath,url,opt));
dataTemp = readtable(filePath,"Delimiter",',',"VariableNamingRule","preserve");
seriesDate = datetime(dataTemp.TIME_PERIOD,"Format","uuuu-MM");
seriesTable = timetable(seriesDate,dataTemp.OBS_VALUE);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"EER41EUR"];

% Monthly arithmetic mean of daily closes, dated to the same month.
% From: https://stooq.com/q/d/l/?s=^fmib&d1=19900101&d2
filePath = fullfile(cd,'FTSEMIB.csv');
data_progress("FTSEMIB", "Configured daily-close source", 21);
source_info.FTSEMIB = fetch_ftsemib(filePath, cfg, options);
dataTemp = readtable(filePath,"Delimiter",',',"VariableNamingRule","preserve");
seriesTable = monthly_ftsemib(dataTemp, cfg.eval_end, runDate);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"FTSEMIB"];

% Nights spent at tourist accommodation establishments; NSA
data_progress("TOURNIGHT", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/tour_occ_nim?format=JSON&lang=en&freq=M&c_resid=TOTAL&unit=NR&nace_r2=I551-I553&geo=IT&sinceTimePeriod='+startDate_ALL;
[dataTemp, source_info.TOURNIGHT] = fetch_source( ...
    "TOURNIGHT", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "TOURNIGHT");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"TOURNIGHT"];

data_progress("NEWPCAREG", "ECB", 21);
filePath = fullfile(cd,'/NEWCARREG.csv');
source_url = 'https://data-api.ecb.europa.eu/service/data/CAR/M.I9.Y.CREG.PC0000.4F0.N.PN?format=csvdata';
[~, source_info.NEWPCAREG] = fetch_source( ...
    "NEWPCAREG", "ECB", source_url, options, @(url,opt) websave(filePath,url,opt));
dataTemp = readtable(filePath,"Delimiter",',',"VariableNamingRule","preserve");
seriesDate = datetime(dataTemp.TIME_PERIOD,"Format","uuuu-MM");
seriesTable = timetable(seriesDate,dataTemp.OBS_VALUE);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"NEWPCAREG"];

% Unemployment; Thousand persons; SA
data_progress("UNEMPLNUM", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_lmhu_m?format=JSON&lang=en&freq=M&unit=THS_PER&s_adj=SA&indic=LM-UN-T-TOT&geo=IT&sinceTimePeriod='+startDate_ALL;
[dataTemp, source_info.UNEMPLNUM] = fetch_source( ...
    "UNEMPLNUM", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "UNEMPLNUM");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"UNEMPLNUM"];

% EU27 international trade; SCA
data_progress("TRADEBAL", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_eteu27_2020_m?format=JSON&lang=en&freq=M&stk_flow=BAL_RT&unit=MIO-EUR-SA&partner=WORLD&indic=ET-T&geo=IT&sinceTimePeriod='+startDate_ALL;
[dataTemp, source_info.TRADEBAL] = fetch_source( ...
    "TRADEBAL", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "TRADEBAL");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"TRADEBAL"];

% Retail trade sales; Index 2021=100; SA
data_progress("RETLTRADE", "ISTAT", 21);
source_url = 'https://esploradati.istat.it/SDMXWS/rest/data/IT1,120_337_DF_DCSC_COMMDET_1_12,1.0/M.IT.RTD_TURN_VAL_21.Y.99..TOTAL/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD';
[dataTemp, source_info.RETLTRADE] = fetch_source( ...
    "RETLTRADE", "ISTAT", source_url, options);
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0_0.observations);
seriesTable = timetable(seriesDate,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"RETLTRADE"];

data_progress("ITESI", "Eurostat", 21);
source_url = 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bssi_m_r2?format=JSON&lang=en&freq=M&indic=BS-ESI-I&s_adj=SA&geo=IT&sinceTimePeriod='+startDate_ALL;
[dataTemp, source_info.ITESI] = fetch_source( ...
    "ITESI", "Eurostat", source_url, options);
seriesTable = read_eurostat(dataTemp, "ITESI");
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITESI"];

data_progress("ITCCI", "OECD API, CSV export or FRED mirror", 21);
[seriesDate, seriesValues, ~, source_info.ITCCI] = fetch_oecd_confidence( ...
    "CCICP", startDate_ALL, options, cfg.oecd_confidence_csv.CCICP, cfg.oecd_confidence_mode);
seriesTable = timetable(seriesDate,seriesValues);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITCCI"];

data_progress("ITCBC", "OECD API, CSV export or FRED mirror", 21);
[seriesDate, seriesValues, ~, source_info.ITCBC] = fetch_oecd_confidence( ...
    "BCICP", startDate_ALL, options, cfg.oecd_confidence_csv.BCICP, cfg.oecd_confidence_mode);
seriesTable = timetable(seriesDate,seriesValues);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITCBC"];

data_progress("ITACOIN", "Bank of Italy", 21);
source_url = 'https://www.bancaditalia.it/statistiche/tematiche/indicatori/indicatore-ciclico-coincidente/Itacoin_it.xlsx';
[dataTemp, source_info.ITACOIN] = fetch_source( ...
    "ITACOIN", "Bank of Italy", source_url, options, @(url,~) read_table_quiet(url));
seriesDate = dateshift(datetime(dataTemp.Date),'start','month');
seriesTable = array2table(dataTemp.Ita_coin);
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITACOIN"];

data_progress("EUROCOIN", "Bank of Italy", 21);
source_url = 'https://www.bancaditalia.it/statistiche/tematiche/indicatori/indicatore-euro-coin/Ecoin_realtime.xlsx';
[dataTemp, source_info.EUROCOIN] = fetch_source( ...
    "EUROCOIN", "Bank of Italy", source_url, options, @(url,~) read_table_quiet(url));
seriesDate = dateshift(datetime(dataTemp.Date),'start','month');
seriesTable = array2table(dataTemp.x_coinRealtime_NewEstimate);
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"EUROCOIN"];

fprintf("Source downloads completed.\n")

fprintf("Assembling dataset.\n")

dataTable.Properties.VariableNames = colNames;
dataTable.Properties.DimensionNames{1} = 'Time';
dataTable = dataTable(dataTable.Time <= cfg.eval_end + calmonths(1), :);
startIndex = max(1, find(~isnan(dataTable.GDP),1,"first") - 1);
dataTable = dataTable(startIndex:end,:);
dataTable = movevars(dataTable,"GDP","After",colNames(end));

% Source GDP is dated to the quarter it describes, not the following month.
sourceTable = dataTable;
hasGDP = isfinite(dataTable.GDP);
gdpQuarterDates = dataTable.Time(hasGDP) - calmonths(1);
[foundGDPDate, gdpRows] = ismember(gdpQuarterDates, sourceTable.Time);
if ~all(foundGDPDate)
    error("get_data:GDPDateMismatch", ...
        "GDP quarter-end dates must be present in the monthly source grid.");
end
sourceTable.GDP(:) = nan;
sourceTable.GDP(gdpRows) = dataTable.GDP(hasGDP);
sourceTable = sourceTable(sourceTable.Time <= cfg.eval_end, :);

fprintf("Validating publication delays and missingness.\n")

source_notices = struct();
if isfield(cfg, "source_notices"); source_notices = cfg.source_notices; end
statuses = source_status(sourceTable, source_info, cfg.eval_end, source_notices);
sourceStatusTable = struct2table(statuses);
disp(sourceStatusTable(:, {'indicator','source','last_observation', ...
    'expected_through','availability','lifecycle'}));
CheckPubDelay = [statuses.missing_last_five];
if any(CheckPubDelay)
    warning("get_data:StaleOrUnavailable", ...
        "No observations in the last five months: %s. Possible discontinuation; check the source report and provider notices.", ...
        strjoin(string({statuses(CheckPubDelay).indicator}), ", "));
end
confirmedDeprecated = startsWith(string({statuses.lifecycle}), "confirmed_");
if any(confirmedDeprecated)
    warning("get_data:ConfirmedDeprecation", ...
        "Provider-confirmed discontinuation or replacement: %s. See the recorded notice links.", ...
        strjoin(string({statuses(confirmedDeprecated).indicator}), ", "));
end

GDPSeries = sourceTable(:, "GDP");
GDPSeries.Properties.VariableNames = "Level";
GDPSeries.Growth = quarterly_log_growth(GDPSeries.Level, GDPSeries.Time);

% Change to the final data directory
newDir = fullfile(base_path, "DATA");
cd(newDir)

% Save the ready datasets
writetimetable(GDPSeries,append("GDP_History/GDP",strrep(endDate,"-",""),".csv"))
writetimetable(sourceTable,append("source",strrep(endDate,"-",""),".csv"))

metadataDir = fullfile(base_path, "DATA", "VINTAGE_METADATA");
metadata = struct();
metadata.vintage = strrep(endDate, "-", "");
metadata.run_date = endDate;
metadata.eval_end_default = string(cfg.eval_end);
metadata.edition = edition;
metadata.preliminary_ed = preliminary_ed;
metadata.istat = istat_metadata;
metadata.gdp = gdp_selection;
metadata.sources = statuses;
metadata.ftsemib = source_info.FTSEMIB;
metadata.ftsemib_mode = string(cfg.ftsemib_mode);
metadata.source_format = "origin_raw_v1";
metadata.source_cutoff = string(cfg.eval_end);
metadata.created_at = string(datetime("now", "Format", "uuuu-MM-dd HH:mm:ss"));
fid = fopen(fullfile(metadataDir, "vintage" + metadata.vintage + ".json"), "w");
fwrite(fid, jsonencode(metadata), "char");
fclose(fid);
fprintf("Data vintage %s saved.\n", metadata.vintage)

% Remove the temporary data folder
rmdir(temp_dir,'s');
end
