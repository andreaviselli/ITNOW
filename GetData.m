% -------------------------------------------------------------------
% 0. INITIAL SETUP
% -------------------------------------------------------------------
clc; clear


% -------------------------------------------------------------------
% 1. CONFIGURATION & PARAMETERS
% -------------------------------------------------------------------

% --- Date Parameters ---
startDate_ALL = "1990-01-01";
startDate_INDIMPPRC = "2005-01-01";
startDate_CONSTRPROD = "1995-01-01";
startDate_PRODPRCIND = "2000-01-01";
endDate = string(datetime("today","Format","uuuu-MM-dd"));

% --- Edition Parameters for ISTAT Data ---
edition = "2026M3";
preliminary_ed = "2026M4";

% --- Web Timeout Options ---
options = weboptions('Timeout', 60);


% -------------------------------------------------------------------
% 2. ENVIRONMENT SETUP
% -------------------------------------------------------------------

% Create and set a temporary folder as the working directory
% Define base directory once
base_path = "/path/to/ITNOW";
temp_dir = fullfile(base_path, "DATA", "Temp");
mkdir(temp_dir)
cd(temp_dir)


% -------------------------------------------------------------------
% 3. JOB SUBMISSION
% -------------------------------------------------------------------

fprintf("Downloading the dataset as of %s.\n",endDate)
disp('Press any key to submit the job.')
pause
disp("...")


% -------------------------------------------------------------------
% 4. DATA DOWNLOADING
% -------------------------------------------------------------------

% --- Initialize Data Storage ---
colNames = [];
seriesDate = datetime("1995-01-01","Format","uuuu-MM-dd"):calmonths(1):datetime("today","Format","uuuu-MM-dd");
dataTable = timetable(seriesDate');

% --- 4.1. Gross Domestic Product (GDP) --- 
% Quarterly Gross Domestic Product; Chain linked volumes (2020), million
% euro; SA; National accounts indicator (ESA 2010): Gross domestic product
% at market prices
disp("Downloading GDP...")
isAvailable = 1;
try   % Try to download the edition corresponding to the current month:
    dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,163_184_DF_DCCN_PILQ_1,1.0/Q.IT.B1GQ_B_W2_S1.L_2020.Y.'+edition+'/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD', options);
catch % If not available, change 'edition' manually and set an older month:
    isAvailable = 0;
    warning("Edition %s of GDP not available: select a previous edition.\n",edition);
end
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
seriesGDP = timetable(seriesDate,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesGDP);
colNames = [colNames,"GDP"];

% Quarterly Gross Domestic Product; Chain linked volumes (2020), million
% euro; SA; National accounts indicator (ESA 2010): Gross domestic product
% at market prices; Preliminary estimate
disp("Downloading preliminary GDP...")
try   % Try to download the edition corresponding to the current month:
    dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,163_156_DF_DCCN_SQCQ_3,1.0/Q.IT.B1GQ_B_W2_S1.L_2020.Y.'+preliminary_ed+'_1/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD', options);
catch % If not available, change 'preliminary_ed' manually and set an older month:           
    error("Edition %s of preliminary GDP not available: select a previous edition.\n",preliminary_ed);
end
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
seriesTable = timetable(seriesDate,cell2mat(seriesTable));
if seriesGDP.seriesDate(end) < seriesTable.seriesDate(end)
    disp("Preliminary estimate of GDP is incorporated.")
    dataTable = synchronize(dataTable,seriesTable);
    dataTable(:,1) = [];
end

% --- 4.2. Industrial Production (INDPROD) ---
% Production in industry; Index 2021=100; NACE Rev. 2: B-D; SCA
disp("Downloading INDPROD...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m?format=JSON&lang=en&freq=M&indic_bt=PRD&nace_r2=B-D&s_adj=SCA&unit=I21&geo=IT&sinceTimePeriod='+startDate_ALL, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
if length(seriesDate) > size(seriesTable, 2); seriesDate = seriesDate(1:end-1); end
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}');
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDPROD"];

% --- 4.3. Construction Production (CONSTRPROD) ---
% Production in construction ; Index 2021=100; NACE Rev. 2: F; SCA
disp("Downloading CONSTRPROD...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_copr_m?format=JSON&lang=en&freq=M&indic_bt=PRD&nace_r2=F&s_adj=SCA&unit=I21&geo=IT&sinceTimePeriod='+startDate_CONSTRPROD, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
DimDiff = size(seriesDate, 1) - size(seriesTable, 2);
seriesDate(end-DimDiff+1:end) = [];
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}');
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"CONSTRPROD"];

% --- 4.4. Industrial Turnover (INDTURN) ---
% Turnover in industry, total; Index 2021=100; NACE Rev. 2: B-D; SCA
disp("Downloading INDTURN...")
dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,114_191_DF_DCSC_ORDFATT_9,1.0/M..IND_TURN_21.Y.T.0020/ALL/?detail=full&startPeriod=1990-01-01&dimensionAtObservation=TIME_PERIOD', options);
Time = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
seriesTable = timetable(Time,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDTURN"];

% --- 4.5. Industrial Producer Prices (INDPRODPRC) ---
% Producer prices in industry, total; Index 2021=100
disp("Downloading INDPRODPRC...")
dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,145_360_DF_DCSC_PREZZPIND_1_4,1.0/M.IT.IND_PRIC_2021.N.D.0020/ALL/?detail=full&startPeriod='+startDate_ALL'+'&dimensionAtObservation=TIME_PERIOD', options);
Time = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0.observations);
for element = 1:size(seriesTable,1); seriesTable{element} = seriesTable{element}(1); end
seriesTable = timetable(Time,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDPRODPRC"];

% --- 4.6. Industrial Import Prices (INDIMPPRC) ---
% Import prices in industry; NSA
disp("Downloading INDIMPPRC...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpi_m?format=JSON&lang=en&freq=M&indic_bt=PRC_IMP&cpa2_1=CPA_B-D&s_adj=NSA&unit=I21&geo=IT&sinceTimePeriod='+startDate_INDIMPPRC, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
DimDiff = size(seriesDate, 1) - size(seriesTable, 2);
seriesDate(end-DimDiff+1:end) = [];
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}');
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"INDIMPPRC"];

% --- 4.7. Construction Costs (CONSTRCOST) ---
% Residential and non-residential buildings; Index 2021=100; NSA
disp("Downloading CONSTRCOST...")
dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,145_361_DF_DCSC_FABBRESID_1_7,1.0/M.IT.CONS_CST2_2021.N.I/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD', options);
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0.observations);
for element = 1:size(seriesTable,1); seriesTable{element} = seriesTable{element}(1); end
seriesTable = timetable(seriesDate,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"CONSTRCOST"];

% --- 4.8. Harmonized Index of Consumer Prices (HICPALL) ---
% HICP; All-items HICP; Index 2015=100
disp("Downloading HICPALL...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/prc_hicp_minr/1.0/*.*.*.*?c[freq]=M&c[unit]=I15&c[coicop18]=TOTAL&c[geo]=IT&c[TIME_PERIOD]=ge:1996-01&compress=false&format=json&lang=en', options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = NaN(length(seriesDate),1);
valueFields = fieldnames(dataTemp.value);
valueIdx = str2double(erase(valueFields,"x")) + 1;
seriesTable(valueIdx) = struct2array(dataTemp.value)';
seriesTable = timetable(seriesDate, seriesTable);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"HICPALL"];

% --- 4.9. Effective Exchange Rate (EER41EUR) ---
% Nominal EER-41/Euro; Broad EER group of trading partners
disp("Downloading EER41EUR...")
filePath = fullfile(cd,'/EER41EUR.csv');
websave(filePath,'https://data-api.ecb.europa.eu/service/data/EXR/M.E03.EUR.EN00.A?format=csvdata', options);
dataTemp = readtable(filePath,"Delimiter",',');
seriesDate = datetime(dataTemp.TIME_PERIOD,"Format","uuuu-MM");
seriesTable = timetable(seriesDate,dataTemp.OBS_VALUE);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"EER41EUR"];

% --- 4.10. FTSE MIB Stock Index (FTSEMIB) ---
% From: https://stooq.com/q/d/l/?s=^fmib&d1=19900101&d2
filePath = fullfile(cd,'FTSEMIB.csv');
disp("Download FTSEMIB manually and save it as FTSEMIB.csv in the Temp folder:")
disp(filePath)
while ~isfile(filePath)
    input("File not found yet. After saving it, press Enter to check again...","s");
end
disp("Loading FTSEMIB...")
dataTemp = readtable(filePath,"Delimiter",',');
seriesDate = dateshift(datetime(dataTemp.Date)+calmonths(),"start","month");
seriesTable = timetable(datetime(seriesDate),dataTemp.Close);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"FTSEMIB"];

% --- 4.11. Tourist Nights (TOURNIGHT) ---
% Nights spent at tourist accommodation establishments; NSA
disp("Downloading TOURNIGHT...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/tour_occ_nim?format=JSON&lang=en&freq=M&c_resid=TOTAL&unit=NR&nace_r2=I551-I553&geo=IT&sinceTimePeriod='+startDate_ALL, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
DimDiff = size(seriesDate, 1) - size(seriesTable, 2);
seriesDate(end-DimDiff+1:end) = [];
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}'); % or just seriesDate(1:end)
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"TOURNIGHT"];

% --- 4.12. New Passenger Car Registrations (NEWPCAREG) ---
disp("Downloading NEWPCAREG...")
filePath = fullfile(cd,'/NEWCARREG.csv');
websave(filePath,'https://data-api.ecb.europa.eu/service/data/CAR/M.I9.Y.CREG.PC0000.4F0.N.PN?format=csvdata');
dataTemp = readtable(filePath,"Delimiter",',');
seriesDate = datetime(dataTemp.TIME_PERIOD,"Format","uuuu-MM");
seriesTable = timetable(seriesDate,dataTemp.OBS_VALUE);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"NEWPCAREG"];

% --- 4.13. Unemployment Number (UNEMPLNUM) ---
% Unemployment; Thousand persons; SA
disp("Downloading UNEMPLNUM...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_lmhu_m?format=JSON&lang=en&freq=M&unit=THS_PER&s_adj=SA&indic=LM-UN-T-TOT&geo=IT&sinceTimePeriod='+startDate_ALL, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
DimDiff = size(seriesDate, 1) - size(seriesTable, 2);
seriesDate(end-DimDiff+1:end) = [];
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}');
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"UNEMPLNUM"];

% --- 4.14. Trade Balance (TRADEBAL) ---
% EU27 international trade; SCA
disp("Downloading TRADEBAL...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_eteu27_2020_m?format=JSON&lang=en&freq=M&stk_flow=BAL_RT&unit=MIO-EUR-SA&partner=WORLD&indic=ET-T&geo=IT&sinceTimePeriod='+startDate_ALL, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
seriesTable = timetable(seriesDate,seriesTable{:, 1:end}');
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"TRADEBAL"];

% --- 4.15. Retail Trade (RETLTRADE) ---
% Retail trade sales; Index 2021=100; SA
disp("Downloading RETLTRADE...")
dataTemp = webread('https://esploradati.istat.it/SDMXWS/rest/data/IT1,120_337_DF_DCSC_COMMDET_1_12,1.0/M.IT.RTD_TURN_VAL_21.Y.99..TOTAL/ALL/?detail=full&startPeriod='+startDate_ALL+'&dimensionAtObservation=TIME_PERIOD', options);
seriesDate = datetime(string(cell2mat({dataTemp.structure.dimensions.observation.values.end}')))+caldays;
seriesTable = struct2cell(dataTemp.dataSets.series.x0_0_0_0_0_0_0.observations);
seriesTable = timetable(seriesDate,cell2mat(seriesTable));
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"RETLTRADE"];

% --- 4.16. Economic Sentiment Indicator (ITESI) ---
disp("Downloading ITESI...")
dataTemp = webread('https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bssi_m_r2?format=JSON&lang=en&freq=M&indic=BS-ESI-I&s_adj=SA&geo=IT&sinceTimePeriod='+startDate_ALL, options);
seriesDate = datetime(append(string(struct2cell(dataTemp.dimension.time.category.label)),"-01"));
seriesTable = struct2table(dataTemp.value);
MissObsIndex = string(seriesTable.Properties.VariableNames)';
MissObsIndex = 1+str2double(eraseBetween(MissObsIndex,1,1));
MissObsIndex = find(~ismember(1:length(seriesDate),MissObsIndex));
seriesTable = [seriesTable{1,1:MissObsIndex-1}';nan;...
    seriesTable{1,MissObsIndex:end}'];
seriesTable = timetable(seriesDate,seriesTable);
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITESI"];

% --- 4.17. Consumer Confidence Indicator (ITCCI) ---
disp("Downloading ITCCI...")
dataTemp = webread('https://sdmx.oecd.org/public/rest/data/OECD.SDD.STES,DSD_STES@DF_CLI,4.1/ITA.M.CCICP...AA.IX..H?startPeriod='+startDate_ALL+'&dimensionAtObservation=AllDimensions', options);
seriesDate = datetime(append(string(cell2mat({dataTemp.structure.dimensions.observation(10).values.id}')),'-01'));
seriesTable = array2table(cell2mat(struct2cell(dataTemp.dataSets.observations)')');
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITCCI"];

% --- 4.18. Business Confidence Indicator (ITCBC) ---
disp("Downloading ITCBC...")
dataTemp = webread('https://sdmx.oecd.org/public/rest/data/OECD.SDD.STES,DSD_STES@DF_CLI,4.1/ITA.M.BCICP...AA.IX..H?startPeriod='+startDate_ALL+'&dimensionAtObservation=AllDimensions', options);
seriesDate = datetime(append(string(cell2mat({dataTemp.structure.dimensions.observation(10).values.id}')),'-01'));
seriesTable = array2table(cell2mat(struct2cell(dataTemp.dataSets.observations)')');
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITCBC"];

% --- 4.19. Ita-coin Indicator ---
disp("Downloading ITACOIN...")
dataTemp = readtable('https://www.bancaditalia.it/statistiche/tematiche/indicatori/indicatore-ciclico-coincidente/Itacoin_it.xlsx');
seriesDate = dateshift(datetime(dataTemp.Date),'start','month');
seriesTable = array2table(dataTemp.Ita_coin);
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"ITACOIN"];

% --- 4.20. Euro-coin Indicator ---
disp("Downloading EUROCOIN...")
dataTemp = readtable('https://www.bancaditalia.it/statistiche/tematiche/indicatori/indicatore-euro-coin/Ecoin_realtime.xlsx');
seriesDate = dateshift(datetime(dataTemp.Date),'start','month');
seriesTable = array2table(dataTemp.x_coinRealtime_NewEstimate);
seriesTable = timetable(seriesDate,seriesTable{:,1});
dataTable = synchronize(dataTable,seriesTable);
colNames = [colNames,"EUROCOIN"];

disp("All series were successfully downloaded.")


% -------------------------------------------------------------------
% 5. DATA ASSEMBLY & CLEANING
% -------------------------------------------------------------------
disp("Arranging the dataset...")

dataTable.Properties.VariableNames = colNames;
startIndex = find(~isnan(dataTable.GDP),1,"first");
dataTable = dataTable(startIndex:end,:);
dataTable = movevars(dataTable,"GDP","After",colNames(end));


% -------------------------------------------------------------------
% 6. DATA VALIDATION
% -------------------------------------------------------------------
disp("Looking for dismissed indicators...")

CheckPubDelay = sum(isnan(dataTable{end-4:end,:})) > 4;
if any(CheckPubDelay)
    DeprVars = string(dataTable.Properties.VariableNames(CheckPubDelay));
    warning("Presence of deprecated indicators.")
    disp(DeprVars)
end


% -------------------------------------------------------------------
% 7. DATA TRANSFORMATION
% -------------------------------------------------------------------

% --- Store original GDP series ---
GDPSeries = dataTable(:,end);       % at the end
GDPSeries.Properties.VariableNames = "Level";
GDPSeries.Properties.DimensionNames{1} = 'Time';

% --- Seasonally adjust raw series ---
dataTable.Properties.DimensionNames{1} = 'Time';
[LT, ~, R] = trenddecomp(log(dataTable.TOURNIGHT), "stl", 12);
dataTable.TOURNIGHT = LT + R;
period1 = timerange(dataTable.Time(1),"2000-12-01","closed");
[LT1, ~, R1] = trenddecomp(log(dataTable{period1, "HICPALL"}), "stl", 12);
period2 = timerange("2001-01-01","2009-12-01","closed");
[LT2, ~, R2] = trenddecomp(log(dataTable{period2, "HICPALL"}), "stl", 12);
period2 = timerange("2010-01-01","2020-12-01","closed");
[LT3, ~, R3] = trenddecomp(log(dataTable{period2, "HICPALL"}), "stl", 12);
period3 = timerange("2021-01-01",dataTable.Time(end),"closed");
[LT4, ~, R4] = trenddecomp(log(dataTable{period3, "HICPALL"}), "stl", 12);
LT = [LT1; LT2; LT3; LT4];
R = [R1; R2; R3; R4];
dataTable.HICPALL = LT + R;

% --- Apply transformations (log-differences, etc.) ---
dataTable.INDPROD = [nan;diff(log(dataTable.INDPROD))];
dataTable.CONSTRPROD = [nan;diff(log(dataTable.CONSTRPROD))];
dataTable.INDTURN = [nan;diff(log(dataTable.INDTURN))];
dataTable.INDPRODPRC = [nan;diff(log(dataTable.INDPRODPRC))];
dataTable.INDIMPPRC = [nan;diff(log(dataTable.INDIMPPRC))];
dataTable.CONSTRCOST = [nan;diff(log(dataTable.CONSTRCOST))];
dataTable.HICPALL = [nan;diff(dataTable.HICPALL)];
dataTable.EER41EUR = [nan;diff(log(dataTable.EER41EUR))];
dataTable.FTSEMIB = [nan;diff(log(dataTable.FTSEMIB))];
dataTable.TOURNIGHT = [nan;diff(dataTable.TOURNIGHT)];
dataTable.NEWPCAREG = [nan;diff(log(dataTable.NEWPCAREG))];
dataTable.UNEMPLNUM = [nan;diff(log(dataTable.UNEMPLNUM))];
dataTable.TRADEBAL = [nan;diff(log(1-min(dataTable.TRADEBAL)+dataTable.TRADEBAL))];
dataTable.RETLTRADE = [nan;diff(log(dataTable.RETLTRADE))]; 
dataTable.ITESI = [nan;diff(log(dataTable.ITESI))];
dataTable.ITCCI = [nan;diff(log(dataTable.ITCCI))];
dataTable.ITCBC = [nan;diff(log(dataTable.ITCBC))];
dataTable.GDP(~isnan(dataTable.GDP)) = [nan;diff(log(dataTable.GDP(~isnan(dataTable.GDP))))];

% --- Final adjustments ---
GDPSeries.Growth = dataTable.GDP;
dataTable(1, :) = [];

% Shift back GDP to the last month of the quarter
dataTable.GDP(1:end-1) = dataTable.GDP(2:end);
dataTable.GDP(end) = nan;
GDPSeries.Time = GDPSeries.Time-calmonths;
Level = nan; Growth = nan;
GDPSeries = [GDPSeries; timetable(GDPSeries.Time(end)+calmonths, Level, Growth)];

% Normalize to zero mean and unit standard deviation
dataTable.Variables = normalize(dataTable.Variables);

% -------------------------------------------------------------------
% 8. SAVE RESULTS & CLEANUP
% -------------------------------------------------------------------

% Change to the final data directory
newDir = fullfile(base_path, "DATA");
cd(newDir)

% Save the ready datasets
writetimetable(GDPSeries,append("GDP_History/GDP",strrep(endDate,"-",""),".csv"))
writetimetable(dataTable,append("data",strrep(endDate,"-",""),".csv"))
disp("And it's done!")

% Remove the temporary data folder
rmdir(temp_dir,'s');