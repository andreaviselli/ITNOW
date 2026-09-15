% Set the base path
if ~exist("itnow_cfg", "var")
    clc; clearvars
    itnow_cfg = ITNOWConfig();
else
    clc
end
base_path = itnow_cfg.base_path;

% Change working directory
cd(base_path)

% Add required functions and programs to path
addpath(fullfile(base_path, "_functions"))
addpath(fullfile(base_path, "_programs"))

% Create shared output folders required by the model scripts.
history_dirs = [fullfile(base_path, "HISTORY", "PREDICTION"), ...
    fullfile(base_path, "HISTORY", "HIST_TABLES"), ...
    fullfile(base_path, "HISTORY", "SMOOTHEDFACTOR")];
for history_dir_index = 1:numel(history_dirs)
    if ~isfolder(history_dirs(history_dir_index))
        mkdir(history_dirs(history_dir_index))
    end
end

% -------------------------------------------------------------------
% PREFERENCES
% -------------------------------------------------------------------

if ~exist("vintage", "var") || strlength(string(vintage)) == 0
    vintage = ITNOWLatestVintage(base_path);
end
RemoveCovid = itnow_cfg.remove_covid;
H_max = itnow_cfg.h_max;
save_fcast = itnow_cfg.save_fcast;

Est_Start = itnow_cfg.est_start;        % Start of estimation sample ("YYYY-mm-dd")
Est_End = itnow_cfg.est_end;            % End of estimation sample ("YYYY-mm-dd")
if ~exist("Eval_End", "var") || isempty(Eval_End)
    Eval_End = itnow_cfg.eval_end;      % End of evaluation sample ("YYYY-mm-dd")
end


% -------------------------------------------------------------------
% INITIALIZATION
% -------------------------------------------------------------------

dataset = "data" + vintage + ".csv";
keepvars = {'vintage', 'dataset', 'RemoveCovid', 'Est_Start', 'Est_End', 'Eval_End', ...
    'spec_names', 'spec_names_all', 'y_predicted', 'H_max', 's', 'counter', ...
    'n_monthly', 'base_path', 'keepvars', 'save_fcast', 'itnow_cfg'};

spec_names_all = [];
y_predicted = [];
counter = 0;


% -------------------------------------------------------------------
% FORECASTING PIPELINE
% -------------------------------------------------------------------

% DYNAMIC FACTOR MODELS (2S AND QMLE ESTIMATION)
spec_names = [...
    "DFM_11_2S_NONE_NONE", "DFM_11_2S_THRESH_LGDP", "DFM_11_2S_THRESH_NONE", ...
    "DFM_11_QMLE_NONE_LGDP", "DFM_11_QMLE_NONE_NONE", "DFM_11_QMLE_THRESH_LGDP", ...
    "DFM_11_QMLE_THRESH_NONE", "DFM_12_2S_NONE_NONE", "DFM_12_2S_THRESH_NONE", ...
    "DFM_13_2S_NONE_NONE", "DFM_13_2S_THRESH_NONE", 
];

disp("Starting the forecasting pipeline.")
for s = 1:length(spec_names)
    fprintf("Script %d: %s.m is starting.\n", counter+1, spec_names(s))
    run(spec_names(s) + ".m");
    for h = 1:1+H_max
        y_predicted(:, end+1, h) = y_hat(:, h);
    end
    counter = counter+1; close all
    fprintf("Script %d: %s.m concluded.\n", counter, spec_names(s))
    cmd = ['clearvars -except ' strjoin(keepvars,' ')]; eval(cmd);
end
spec_names_all = [spec_names_all, spec_names];


% DYNAMIC FACTOR MODELS (PCA ESTIMATION)
spec_names = [...
    "DFM_11_PCA_DYNM", "DFM_21_PCA_DYNM", "DFM_31_PCA_DYNM", ...
    "DFM_11_PCA_STAT", "DFM_21_PCA_STAT", "DFM_31_PCA_STAT"
    ];

for s = 1:length(spec_names)
    fprintf("Script %d: %s.m is starting.\n", counter+1, spec_names(s))
    run(spec_names(s) + ".m");
    for h = 1:1+H_max
        if any(s == 4:6)
            y_predicted(:, end+1, h) = y_hat(:, h);
            if h == 1; spec_names_all = [spec_names_all, spec_names(s)]; end
        elseif any(s == 1:3)
            y_predicted(:, end+1:end+size(y_hat, 2), h) = y_hat(:, :, h);
            if h == 1; spec_names_all = [spec_names_all, spec_names(s) + "_" + model_spec']; end
        end
    end
    counter = counter+1; close all
    fprintf("Script %d: %s.m concluded.\n", counter, spec_names(s))
    cmd = ['clearvars -except ' strjoin(keepvars,' ')]; eval(cmd);
end

% UNRESTRICTED MIDAS (FACTOR-AUGMENTED & COMBINED)
spec_names = [...
    "MIDAS_FA_03_11", "MIDAS_FA_03_21", "MIDAS_FA_13_11", ...
    "MIDAS_FA_13_21", "MIDAS_COMB_03", "MIDAS_COMB_13"
    ];

for s = 1:length(spec_names)
    fprintf("Script %d: %s.m is starting.\n", counter+1, spec_names(s))
    run(spec_names(s) + ".m");
    for h = 1:1+H_max
        if any(s == 1:4)
            y_predicted(:, end+1, h) = y_hat(:, h);
            if h == 1; spec_names_all = [spec_names_all, spec_names(s)]; end
        elseif any(s == 5:6)
            y_predicted(:, end+1:end+size(y_hat, 2)-2, h) = y_hat(:, [2, 4], h);
            if h == 1; spec_names_all = [spec_names_all, spec_names(s) + ...
                    ["ME", "BG"]]; end
        end
    end
    counter = counter+1; close all
    fprintf("Script %d: %s.m concluded.\n", counter, spec_names(s))
    cmd = ['clearvars -except ' strjoin(keepvars,' ')]; eval(cmd);
end

%{
% ARDL
spec_names = [...
    "ARDL_10_SPEC1", "ARDL_10_SPEC2", "ARDL_10_SPEC4", ...
    "ARDL_10_SPEC7", "ARDL_10_SPEC8"
    ];

%spec_names = ["ARDL_10_SPEC4"]

for s = 1:length(spec_names)
    fprintf("Script %d: %s.m is starting.\n", counter+1, spec_names(s))
    run(spec_names(s) + ".m");
    for h = 1:1+H_max
        y_predicted(:, end+1, h) = y_hat(:, :, h);
        if h == 1; spec_names_all = [spec_names_all, spec_names(s)]; end
    end
    counter = counter+1; close all
    fprintf("Script %d: %s.m concluded.\n", counter, spec_names(s))
    cmd = ['clearvars -except ' strjoin(keepvars,' ')]; eval(cmd);
end
%}

% ARMA
n_monthly = length(spec_names_all);
spec_names = "ARMA_ALL_221";

for s = 1:length(spec_names)
    fprintf("Script %d: %s.m is starting.\n", counter+1, spec_names(s))
    run(spec_names(s) + ".m");
    for h = 1:1%1+H_max % exclude as not for nowcasting
        y_predicted(:, end+1:end+size(y_hat, 2), h) = y_hat(:, :, h);
        if h == 1; spec_names_all = [spec_names_all, model_spec, comb_spec]; end
    end
    counter = counter+1; close all
    fprintf("Script %d: %s.m concluded.\n", counter, spec_names(s))
    cmd = ['clearvars -except ' strjoin(keepvars,' ')]; eval(cmd);
end
disp("Forecasting pipeline ended.")


% -------------------------------------------------------------------
% FORECAST COMBINATIONS
% -------------------------------------------------------------------

% Load historical GDP growth and level series
y_actual = readtimetable(fullfile(base_path, "DATA", "GDP_History", "GDP"+vintage+".csv"));

% Restore original scale for GDP growth predictions
mean_y = mean(y_actual.Growth, 'omitmissing');
std_y = std(y_actual.Growth, 'omitmissing');
y_predicted = mean_y + std_y .* y_predicted;

% Save re-scaled nowcasts and forecasts
if RemoveCovid == 0; covid_str = "covid"; elseif RemoveCovid == 1; covid_str = "nocovid"; end
if save_fcast
save(base_path+"/HISTORY/PREDICTION/"+vintage+"_fcasts_"+covid_str+".mat", "y_predicted")
save(base_path+"/HISTORY/PREDICTION/"+vintage+"_fcasts_names_"+covid_str+".mat", "spec_names_all")
end
y_predicted = y_predicted(:, :, 1); % only keep nowcasts from now on

% Create timetable of actuals
eval_sample = timerange(Est_End, Eval_End, "closed");
y_actual = y_actual(eval_sample, :);

% Perform nowcast combinations
m = 3;      % frequency mismatch
nu = 4;     % past periods to compute weights
K_all = size(y_predicted, 2);   % all nowcasts
n_monthly = 39;    % monthly models

[y_bg, ~] = topk_bg(y_actual.Growth, y_predicted, 0, K_all, nu, m);
[y_bg_m, ~] = topk_bg(y_actual.Growth, y_predicted(:, 1:n_monthly), 0, n_monthly, nu, m);

% Create timetable of predictions
y_predicted = splitvars(timetable(y_actual.Time, y_predicted, ...
    y_bg, y_bg_m));
y_predicted.Properties.VariableNames = [spec_names_all, ...
    "BG_" + nu, "BG_m_" + nu];

% Add mean and median forecasts
y_predicted.Mean = mean(y_predicted{:,1:length(spec_names_all)}, 2, "omitmissing");
y_predicted.Median = median(y_predicted{:,1:length(spec_names_all)}, 2, "omitmissing");

% Winsorize GDP growth if Covid-19 is treated
if RemoveCovid == 1
    CovidPeriod = datetime("2020-03-01"):calmonths:datetime("2020-09-01");
    y_actual_covid = y_actual(CovidPeriod,:);   % save for later
    y_actual(:, "Growth") = WinsorizeTimeTable(y_actual(:, "Growth"), CovidPeriod, 5, 95);
end

% Add naive prediction given by the previous realization of GDP growth
y_predicted.Naive = [ nan(2, 1); mean_y + std_y .* 0.0898125825923365; ...  % first obs
    nan(2, 1); y_actual.Growth(Est_End + calmonths(2):Eval_End - calmonths(3)) ];

% Save predictions in a csv file
writetimetable(y_predicted, base_path+"/HISTORY/PREDICTION/"+vintage+"_fcasts_"+covid_str+".csv")

% -------------------------------------------------------------------
% FORECAST EVALUATION
% -------------------------------------------------------------------

% Evaluation subperiods
pre_gfc = timerange(Est_End, "2008-03-01", "closed");
gfc = timerange("2008-04-01", "2009-06-01", "closed");      % Great Financial Crisis
pre_sdc = timerange("2009-07-01", "2011-03-01", "closed");
sdc = timerange("2011-04-01", "2013-03-01", "closed");      % Sovereign Debt Crisis
pre_covid = timerange("2013-04-01", "2019-06-01", "closed");
covid = timerange("2019-07-01", "2020-09-01", "closed");    % Covid-19
post_covid = timerange("2020-10-01", Eval_End, "closed");

periods = { pre_gfc, gfc, pre_sdc, sdc, pre_covid, covid, post_covid };
periodNames = {'pre_gfc','gfc','pre_sdc','sdc','pre_covid','covid','post_covid'};

% Compute forecast RMSE & MAE by subperiod
fcast_errors = y_actual.Growth - y_predicted;
col_names = fcast_errors.Properties.VariableNames;

periods_length = nan(1, numel(periods));
vol_fcast_errors = nan(1, numel(periods));

RMSEmat = nan(numel(col_names), numel(periods));
MAEmat  = nan(numel(col_names), numel(periods));
for ip = 1:numel(periods)
    fcast_errors_subp = table2array(fcast_errors(periods{ip}, :));
    vol_fcast_errors(ip) = std(fcast_errors_subp, 0, [1,2], "omitmissing");
    periods_length(ip) = size(fcast_errors_subp, 1);

    rmse = sqrt( mean( fcast_errors_subp.^2, 1, 'omitnan' ) );
    mae  = mean( abs(fcast_errors_subp), 1, 'omitnan' );

    RMSEmat(:, ip) = rmse(:);
    MAEmat(:, ip)  = mae(:);
end

% Compute the number of quarters for each subperiod:
quarters_length = periods_length/3;

% Compute performance metrics relative to naive forecast
row_index_naive = find(fcast_errors.Properties.VariableNames == "Naive");
RMSEmat = RMSEmat ./ RMSEmat(row_index_naive, :);   % the smaller the better
MAEmat = MAEmat ./ MAEmat(row_index_naive, :);

RMSE_tbl = array2table(RMSEmat, 'VariableNames', periodNames, 'RowNames', col_names);
MAE_tbl  = array2table(MAEmat,  'VariableNames', periodNames, 'RowNames', col_names);

% Compute volatility in the cross-section of forecasts by period
std(RMSE_tbl)
std(MAE_tbl)

% Compute top 10 RMSE and MAE by subperiod
topK = 10;

RMSE_cols = cell(topK, 2*numel(periods));
MAE_cols  = cell(topK, 2*numel(periods));
for ip = 1:numel(periods)

    % ----- RMSE -----
    colRMSE = RMSE_tbl{:, ip};
    [sortedRMSE, idxRMSE] = mink(colRMSE, topK);
    methodsRMSE = RMSE_tbl.Properties.RowNames(idxRMSE);

    RMSE_cols(:, 2*ip-1) = methodsRMSE;
    RMSE_cols(:, 2*ip)   = num2cell(sortedRMSE);

    % ----- MAE -----
    colMAE = MAE_tbl{:, ip};
    [sortedMAE, idxMAE] = mink(colMAE, topK);
    methodsMAE = MAE_tbl.Properties.RowNames(idxMAE);

    MAE_cols(:, 2*ip-1) = methodsMAE;
    MAE_cols(:, 2*ip)   = num2cell(sortedMAE);
end

% Assign column names in tables
varNames_RMSE = strings(1, 2*numel(periods));
varNames_MAE  = strings(1, 2*numel(periods));
for ip = 1:numel(periods)
    varNames_RMSE(2*ip-1) = "ID_" + periodNames(ip);
    varNames_RMSE(2*ip)   = "RMSE_" + periodNames(ip);

    varNames_MAE(2*ip-1)  = "ID_" + periodNames(ip);
    varNames_MAE(2*ip)    = "MAE_" + periodNames(ip);
end

% Main output tables
Top10_RMSE_tbl = cell2table(RMSE_cols, 'VariableNames', cellstr(varNames_RMSE));
Top10_MAE_tbl  = cell2table(MAE_cols,  'VariableNames', cellstr(varNames_MAE));

disp(Top10_RMSE_tbl)
disp(Top10_MAE_tbl)

% Save tables with performance metrics
if save_fcast
writetable(RMSE_tbl, base_path+"/HISTORY/HIST_TABLES/rmse_all_"+vintage+"_"+covid_str+".csv", 'WriteRowNames', true)
writetable(MAE_tbl, base_path+"/HISTORY/HIST_TABLES/mae_all_"+vintage+"_"+covid_str+".csv", 'WriteRowNames', true)
writetable(Top10_RMSE_tbl, base_path+"/HISTORY/HIST_TABLES/rmse_top10_"+vintage+"_"+covid_str+".csv", 'WriteRowNames', true)
writetable(Top10_MAE_tbl, base_path+"/HISTORY/HIST_TABLES/mae_top10_"+vintage+"_"+covid_str+".csv", 'WriteRowNames', true)
end

rec = [datetime("2008-04-01"), datetime("2009-06-01"); ...  % Great Financial Crisis
      datetime("2011-04-01"), datetime("2013-03-01");...    % Sovereign Debt Crisis
      datetime("2019-07-01"), datetime("2020-09-01")];      % Covid-19


% -------------------------------------------------------------------
% VISUALIZATION
% -------------------------------------------------------------------

% Forecasts
reset(gca); figure(1);
plot(y_actual.Time, y_actual.Growth, '.', 'MarkerSize', 40); hold on;
if RemoveCovid == 1; plot(CovidPeriod, y_actual_covid.Growth(CovidPeriod), '.', 'MarkerSize', 40); hold on; end
h_pred = plot(y_predicted.Time, y_predicted{:, spec_names_all}, "LineWidth", 0.7, 'LineStyle', ':'); hold on;
plot(y_predicted.Time, y_predicted{:, "BG_4"}, 'k-', "LineWidth", 2.2); hold on;
shadePeriods(gca, rec, 'FaceAlpha', 0.5); uistack(h_pred, 'down', 1e6);
if RemoveCovid == 0; ylim([min(y_actual.Growth)-0.02, max(y_actual.Growth)+0.02]); 
elseif RemoveCovid == 1; ylim([min(y_actual_covid.Growth)-0.02, max(y_actual_covid.Growth)+0.02]); end
grid on; set(gca, 'FontSize', 25, 'FontName', 'Times New Roman');
