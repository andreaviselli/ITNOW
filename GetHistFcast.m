% Set the base path
clc; clear
base_path = "/path/to/ITNOW";

% Change working directory
cd(fullfile(base_path, "DATA"))

% Add required functions and programs to path
addpath(fullfile(base_path, "_functions"))
addpath(fullfile(base_path, "_programs"))

% -------------------------------------------------------------------
% PREFERENCES
% -------------------------------------------------------------------

vintage = "20260509";
RemoveCovid = 0;
H_max = 0;
save_fcast = 1;

Est_Start = datetime("1996-05-01");     % Start of estimation sample ("YYYY-mm-dd")
Est_End = datetime("2006-04-01");       % End of estimation sample ("YYYY-mm-dd")
Eval_End = datetime("2026-04-01");      % End of evaluation sample ("YYYY-mm-dd")


% -------------------------------------------------------------------
% INITIALIZATION
% -------------------------------------------------------------------

dataset = "data" + vintage + ".csv";
keepvars = {'vintage', 'dataset', 'RemoveCovid', 'Est_Start', 'Est_End', 'Eval_End', ...
    'spec_names', 'spec_names_all', 'y_predicted', 'H_max', 's', 'counter', ...
    'n_monthly', 'base_path', 'keepvars', 'save_fcast'};

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
y_actual = readtimetable("GDP_History/GDP"+vintage+".csv");

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
K1 = 5;     % top 5 nowcasts
K2 = 10;    % top 10 nowcasts
n_monthly = 39;    % monthly models

[y_bg, w] = topk_bg(y_actual.Growth, y_predicted, 0, K_all, nu, m);
[y_bg_m, w_m] = topk_bg(y_actual.Growth, y_predicted(:, 1:n_monthly), 0, n_monthly, nu, m);
[y_bg_K1, w_K1] = topk_bg(y_actual.Growth, y_predicted, 0, K1, nu, m);
[y_bg_K2, w_K2] = topk_bg(y_actual.Growth, y_predicted, 0, K2, nu, m);

% Create timetable of predictions
y_predicted = splitvars(timetable(y_actual.Time, y_predicted, ...
    y_bg, y_bg_m, y_bg_K1, y_bg_K2));
y_predicted.Properties.VariableNames = [spec_names_all, ...
    "BG_" + nu, "BG_m_" + nu, "BG_K1_" + nu, "BG_K2_" + nu];

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
% (NON-SMOOTHED) FORECAST EVALUATION
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

% -------------------------------------------------------------------
% (SMOOTHED) FORECAST EVALUATION
% -------------------------------------------------------------------

% Compute quarterly smoothed forecasts
y_predicted_smooth = y_predicted(:, [spec_names_all(1:n_monthly), ...
    "BG_" + nu, "BG_m_" + nu, "BG_K1_" + nu, "BG_K2_" + nu, "Mean", "Median"]);

y_predicted_smooth = varfun(@(x) movmean(x, [2 0], "omitnan"), y_predicted_smooth);
y_predicted_smooth.Properties.VariableNames = [spec_names_all(1:n_monthly), ...
    "BG_" + nu, "BG_m_" + nu, "BG_K1_" + nu, "BG_K2_" + nu, "Mean", "Median"];

y_predicted_smooth.Naive = y_predicted.Naive;

% Compute smoothed forecast RMSE & MAE by subperiod
fcast_errors_smooth = y_actual.Growth - y_predicted_smooth;
col_names_smooth = fcast_errors_smooth.Properties.VariableNames;

RMSEmat_smooth = nan(numel(col_names_smooth), numel(periods));
MAEmat_smooth  = nan(numel(col_names_smooth), numel(periods));
for ip = 1:numel(periods)
    fcast_errors_subp = table2array(fcast_errors_smooth(periods{ip}, :));
    rmse = sqrt( mean( fcast_errors_subp.^2, 1, 'omitnan' ) );
    mae  = mean( abs(fcast_errors_subp), 1, 'omitnan' );

    RMSEmat_smooth(:, ip) = rmse(:);
    MAEmat_smooth(:, ip)  = mae(:);
end

% Compute performance metrics relative to naive forecast
row_index_naive = find(fcast_errors_smooth.Properties.VariableNames == "Naive");
RMSEmat_smooth = RMSEmat_smooth ./ RMSEmat_smooth(row_index_naive, :);   % the smaller the better
MAEmat_smooth = MAEmat_smooth ./ MAEmat_smooth(row_index_naive, :);

RMSE_smooth_tbl = array2table(RMSEmat_smooth, 'VariableNames', periodNames, 'RowNames', col_names_smooth);
MAE_smooth_tbl  = array2table(MAEmat_smooth,  'VariableNames', periodNames, 'RowNames', col_names_smooth);

% Compute top 10 RMSE and MAE by subperiod
RMSE_smooth_cols = cell(topK, 2*numel(periods));
MAE_smooth_cols  = cell(topK, 2*numel(periods));
for ip = 1:numel(periods)

    % ----- RMSE -----
    colRMSE = RMSE_smooth_tbl{:, ip};
    [sortedRMSE, idxRMSE] = mink(colRMSE, topK);
    methodsRMSE = RMSE_smooth_tbl.Properties.RowNames(idxRMSE);

    RMSE_smooth_cols(:, 2*ip-1) = methodsRMSE;
    RMSE_smooth_cols(:, 2*ip)   = num2cell(sortedRMSE);

    % ----- MAE -----
    colMAE = MAE_smooth_tbl{:, ip};
    [sortedMAE, idxMAE] = mink(colMAE, topK);
    methodsMAE = MAE_smooth_tbl.Properties.RowNames(idxMAE);

    MAE_smooth_cols(:, 2*ip-1) = methodsMAE;
    MAE_smooth_cols(:, 2*ip)   = num2cell(sortedMAE);
end

% Main output tables
Top10_RMSE_smooth_tbl = cell2table(RMSE_smooth_cols, 'VariableNames', cellstr(varNames_RMSE));
Top10_MAE_smooth_tbl  = cell2table(MAE_smooth_cols,  'VariableNames', cellstr(varNames_MAE));

disp(Top10_RMSE_smooth_tbl)
disp(Top10_MAE_smooth_tbl)

% Save timetables with predictions and performance metrics
if save_fcast
writetable(RMSE_smooth_tbl, ...
    fullfile(base_path, "HISTORY", "HIST_TABLES", "rmse_smooth_all_" + vintage + "_" + covid_str + ".csv"), ...
    'WriteRowNames', true)

writetable(MAE_smooth_tbl, ...
    fullfile(base_path, "HISTORY", "HIST_TABLES", "mae_smooth_all_" + vintage + "_" + covid_str + ".csv"), ...
    'WriteRowNames', true)

writetable(Top10_RMSE_smooth_tbl, ...
    fullfile(base_path, "HISTORY", "HIST_TABLES", "rmse_smooth_top10_" + vintage + "_" + covid_str + ".csv"), ...
    'WriteRowNames', true)

writetable(Top10_MAE_smooth_tbl, ...
    fullfile(base_path, "HISTORY", "HIST_TABLES", "mae_smooth_top10_" + vintage + "_" + covid_str + ".csv"), ...
    'WriteRowNames', true)
end

% -------------------------------------------------------------------
% ANALYSIS OF COMBINATION WEIGHTS (TOP K1)
% -------------------------------------------------------------------

% Average skilled weight during Covid-19
covid_time = find(ismember(fcast_errors.Time, fcast_errors(covid, :).Time));
w_mean_covid = sum(w(covid_time, :), 1) / length(covid_time);
[~, max_K1_covid] = maxk(w_mean_covid, K1);
lambda_covid = sum(w_mean_covid(max_K1_covid));
skill_idx_covid = zeros(size(w, 2), 1);
skill_idx_covid(max_K1_covid) = 1;
v_covid = (w_mean_covid' .* skill_idx_covid) / lambda_covid;
u_covid = w_mean_covid' .* ~skill_idx_covid;
Sigma_covid = cov(fcast_errors{covid, 1:size(w, 2)}, "omitrows");
MSFE_ratio_skilled = (v_covid'*Sigma_covid*v_covid)/(w_mean_covid*Sigma_covid*w_mean_covid');
MSFE_diff_covid = (lambda_covid^2-1)*v_covid'*Sigma_covid*v_covid + ...
    u_covid'*Sigma_covid*u_covid + 2*lambda_covid*v_covid'*Sigma_covid*u_covid;
fprintf("Ratio of Skilled to Total forecast combination Covid-19 MSFE: %s.\n", ...
    string(round(MSFE_ratio_skilled, 4)))  % check whether this is less than 1
fprintf("Skilled vs. unskilled forecast combination Covid-19 MSFE differential: %s.\n", ...
    string(round(MSFE_diff_covid, 4)))  % check whether this is more than 1

% Analysis of model sum of weights over time during Covid-19
w_sum_tot_K1 = sum(w_K1(covid_time, :), 1);
w_sum_tot_K1_tbl = table(w_sum_tot_K1', 'VariableNames', {'Sum'}, 'RowNames', spec_names_all);

% Correlation analysis of top models during Covid-19
[~, max_sum_index] = maxk(w_sum_tot_K1, K1);
fcast_errors_covid = table2array(fcast_errors(covid, :));
corr_mat = corr(fcast_errors_covid(:, max_sum_index), 'rows', 'pairwise');
corr_mat_heatmap = heatmap(corr_mat, 'Colormap', sky(20), 'GridVisible', 'off');
corr_mat_heatmap.YDisplayLabels = replace(spec_names_all(max_sum_index), "_", "-");
corr_mat_heatmap.XDisplayLabels = replace(spec_names_all(max_sum_index), "_", "-");
corr_mat_heatmap.FontName = 'Times New Roman';
corr_mat_heatmap.FontSize = 20;

% Plot weight magnitude for selected models over time
w_K1_heatmap = heatmap(w_K1, 'Colormap', sky(20), 'GridVisible', 'off');
w_K1_heatmap.YDisplayLabels = repmat({''}, size(w_K1_heatmap.YData));
w_K1_heatmap.FontName = 'Times New Roman';
w_K1_heatmap.FontSize = 18;

% Plot forecast errors against selected models sum of weights
w_m_sorted = sort(w_m, 2, 'descend');   % exclude ARMA models
first_time = find(sum(w_m_sorted, 2) ~= 0, 1, "first");

rec = [datetime("2008-04-01"), datetime("2009-06-01"); ...  % Great Financial Crisis
      datetime("2011-04-01"), datetime("2013-03-01");...    % Sovereign Debt Crisis
      datetime("2019-07-01"), datetime("2020-09-01")];      % Covid-19

reset(gca); figure(1);
bar(y_predicted.Time(first_time:end), w_m_sorted(first_time:end, 1:K1), 'stacked', 'BarWidth', 1);
hold on; shadePeriods(gca, rec, 'FaceAlpha', 0.5);
grid on; set(gca, 'FontSize', 25, 'FontName', 'Times New Roman');


% -------------------------------------------------------------------
% VISUALIZATION
% -------------------------------------------------------------------

% (Non-smoothed) forecasts
reset(gca); figure(2);
plot(y_actual.Time, y_actual.Growth, '.', 'MarkerSize', 40); hold on;
if RemoveCovid == 1; plot(CovidPeriod, y_actual_covid.Growth(CovidPeriod), '.', 'MarkerSize', 40); hold on; end
h_pred = plot(y_predicted.Time, y_predicted{:, spec_names_all}, "LineWidth", 0.7, 'LineStyle', ':'); hold on;
plot(y_predicted.Time, y_predicted{:, "BG_K1_4"}, 'k-', "LineWidth", 2.2); hold on; 
shadePeriods(gca, rec, 'FaceAlpha', 0.5); uistack(h_pred, 'down', 1e6);
if RemoveCovid == 0; ylim([min(y_actual.Growth)-0.02, max(y_actual.Growth)+0.02]); 
elseif RemoveCovid == 1; ylim([min(y_actual_covid.Growth)-0.02, max(y_actual_covid.Growth)+0.02]); end
grid on; set(gca, 'FontSize', 25, 'FontName', 'Times New Roman');

% (Smoothed) forecasts
reset(gca); figure(3);
plot(y_actual.Time, y_actual.Growth, '.', 'MarkerSize', 40); hold on;
if RemoveCovid == 1; plot(CovidPeriod, y_actual_covid.Growth(CovidPeriod), '.', 'MarkerSize', 40); hold on; end
h_pred = plot(y_predicted_smooth.Time, y_predicted_smooth{:, spec_names_all(1:n_monthly)}, "LineWidth", 0.7, 'LineStyle', ':'); hold on;
plot(y_predicted_smooth.Time, y_predicted_smooth{:, "BG_K1_4"}, 'k-', "LineWidth", 2.2); hold on; 
shadePeriods(gca, rec, 'FaceAlpha', 0.5); uistack(h_pred, 'down', 1e6);
if RemoveCovid == 0; ylim([min(y_actual.Growth)-0.02, max(y_actual.Growth)+0.02]); 
elseif RemoveCovid == 1; ylim([min(y_actual_covid.Growth)-0.02, max(y_actual_covid.Growth)+0.02]); end
grid on; set(gca, 'FontSize', 25, 'FontName', 'Times New Roman');