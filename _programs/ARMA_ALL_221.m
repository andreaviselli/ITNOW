% -------------------------------------------------------------------
% 0. INITIALIZATION
% -------------------------------------------------------------------
%clc; clear         % Uncomment to use this as a standalone script
is_flow = 1;        % Whether to run the script with no interruptions (1=yes, 0=no)
is_declared = 1;    % Whether the dataset file and Covid-19 option is already
                    % declared and called from outside this script (1=yes, 0=no)

% Warning: this script is not tested for h>1 step ahead forecasts.

% -------------------------------------------------------------------
% 1. ENVIRONMENT SETUP
% -------------------------------------------------------------------

% Set the base path
%basePath = "";

% Set the workspace:
%cd(fullfile(basePath, "DATA"))

% Add the MFDFM estimation program path:
%addpath(fullfile(basePath, "_functions"))


% -------------------------------------------------------------------
% 2. MODEL & ESTIMATION PREFERENCES
% -------------------------------------------------------------------

% --- Input Data ---
if ~is_declared
    dataset = "data20251114.csv";   % Set the dataset (works with is_declared = 0)
end
d = readtimetable(append("DATA/",dataset));

% --- Model Specification ---
if ~is_declared
    RemoveCovid = 0;    % Whether to remove the Covid-19 period (1=yes, 0=no; 
end                     % works with is_declared = 0)
maxp = 2;           % Max. order of the AR lag polynomial (p).
maxq = 2;           % Max. order of the MA lag polynomial (q).
maxpx = 1;          % Max. order of the exogenous variable lag polynomial (px).
H = 1;              % Max forecast horizon (H>0).

% --- Exogenous Variable Specification ---
XName = "ITCBC";    % Predictor to augment the ARMA model.

% --- Combination Scheme Specification ---
nu = 4;             % Rolling window sizes for the combination schemes.

% --- Display Options ---
display_h = 1;      % Which prediction horizon to display in the final plot (must be <= H).


% -------------------------------------------------------------------
% 3. OUTPUT SETTINGS
% -------------------------------------------------------------------

save_res = 0;                                   % Save results (1=yes, 0=no).
outputFolderName = strcat("HISTORY/",dataset);  % Output folder.


% -------------------------------------------------------------------
% 4. DATA PREPARATION & PRE-COMPUTATION
% (Do not change for replication purposes)
% -------------------------------------------------------------------

% --- Handle the Covid-19 Instability ---
if RemoveCovid == 1
    CovidPeriod = datetime("2020-03-01"):calmonths:datetime("2020-09-01");
    dCovid = d(CovidPeriod,:);
    d = WinsorizeTimeTable(d, CovidPeriod, 5, 95);
end

% --- Time (Rolling Window) Settings ---
if ~is_declared
    Est_Start = d.Time(1);              % Start of estimation sample
    Est_End = datetime("2006-04-01");   % End of estimation sample
    Eval_End = d.Time(end);             % End of evaluation sample
end

is = timerange(Est_Start,Est_End,"closed");     % First window.
os = timerange(Est_End,Eval_End,"closed");      % Evaluation sample.

% --- Publication Delay Settings ---
pub_delay_all = [2,2,1,1,2,1,1,0,0,2,1,1,2,1,0,0,0,0,0,1];
pub_delay_gdp = 1;

XName_index = find(strcmp(d.Properties.VariableNames, XName));
if pub_delay_all(XName_index) > 0 % Check if augmenting variable has publication delay
    error("Error: Cannot augment the ARMA model with predictors published with a delay.")
end
if H > 1                % Warning for multi-step forecasting
    warning("Warning: Since px includes the contemporaneous (zero) lag, make sure the " + ...
        "predictor is available at the forecasting horizon.")
end

% --- Pre-calculate Useful Quantities ---
T_is = size(d(is,:),1);     % Estimation sample size.
T_os = size(d(os,:),1);     % Evaluation sample size.

% --- Generate Model Specification Names ---
M = (1+maxp)*(1+maxq)*(2+maxpx)-2;  % Total number of models
model_spec = string(nan(1, M));
model_spec(end) = "ARMA_minBIC";
counter = 0;
for p = 0:maxp
    for q = 0:maxq
        for px = -1:maxpx
            if p ~= 0 || q ~= 0
                counter = counter+1;
                if px >= 0
                    model_spec(counter) = "ARMAX_"+string(p)+string(q)+string(px);
                else
                    model_spec(counter) = "ARMA_"+string(p)+string(q);
                end
            end
        end
    end
end

% --- Pre-allocate Output Arrays ---
y = d.GDP(os);                      % Actual GDP growth.
y_hat = nan(T_os, M, H);            % Predicted GDP growth.
loglik = nan(T_os, M);              % Model log-likelihood.
bic = nan(T_os, M);                 % Model BIC criterion.
bic_model = string(nan(T_os, 1));   % Name of the model with the minimum BIC.


% -------------------------------------------------------------------
% 5. JOB SUBMISSION & EXECUTION
% -------------------------------------------------------------------

% --- Display Job Settings ---
fprintf('JOB: Running rolling window ARMA/ARMAX estimation with settings:\n');
fprintf('------------------------------------------------------------\n');
fprintf('  - Max AR order (maxp):                %d\n', maxp);
fprintf('  - Max MA order (maxq):                %d\n', maxq);
fprintf('  - Exogenous variable:                 %s\n', XName);
fprintf('  - Max exogenous order (maxpx):        %d\n', maxpx);
fprintf('  - Max forecast horizon (H):           %d\n', H);
fprintf('  - Save results:                       %d\n', save_res);
fprintf('------------------------------------------------------------\n');

% --- User Confirmation to Start ---
if ~is_flow
    prompt = 'Do you want to proceed with the job? (Y/N): ';
    userInput = input(prompt, 's');
    if ~strcmpi(userInput, 'Y')
        error('Job aborted by user.');
    end
end

% --- Start Timer and Estimation Loop ---
fprintf('\nEstimation in progress...\n');
startTime = tic; % Start timer

for t = 1:T_os

    % Start and end date for the current window:
    T0 = datetime(Est_Start)+calmonths(t-1);
    T1 = datetime(Est_End)+calmonths(t-1);
    
    % Set the new estimation dataset:
    is = timerange(T0,T1,"closed");
    X_t = table2array(d(is,["GDP", XName]));
    
    % Impute missing observations through a factor model if needed:
    if any(isnan(X_t(:, 2)))
        for i = 1:size(X_t, 2)  % Real-time alignment for all series
            X_t(end-pub_delay_all(i)+1:end,i) = nan;
        end
        
        % Estimate a factor model in the presence of missing data
        init = InitCond_DFM(d{is,:},[],1,1,[size(d(is,:), 2)-1, 1]);
        yInit_not_nan =  ~isnan(X_t(:, 2));
        XInit = [ones(size(X_t(yInit_not_nan, :), 1), 1), init.F_0(yInit_not_nan, 1)];
        beta_init = (XInit'*XInit)\(XInit'*X_t(yInit_not_nan, 2));
        
        % Impute the missing observations
        n_nan = sum(~yInit_not_nan);
        X_t(~yInit_not_nan, 2) = [ones(n_nan, 1), init.F_0(~yInit_not_nan, 1)]*beta_init;

    else
        % Real-time alignment (GDP only if no missing values in X)
        X_t(end-pub_delay_gdp+1:end, 1) = nan;
    end
    
    % Transform data from monthly to quarterly frequency:
    tmStart = find(~isnan(X_t(:, 1)),1,"first");
    tmEnd = find(~isnan(X_t(:, 1)),1,"last");
    tm = tmStart:3:size(X_t, 1);
    
    counter = 0;
    % We do not compute nowcasts for the 1st and 2md month in the quarter 
    % (though they can be computed)
    if tm(end) == size(X_t, 1)

        % Set estimation and prediction samples
        y_t = X_t(tmStart:3:tmEnd, 1);
        XPred_t = X_t(size(X_t, 1), 2);
        XExog_t = X_t(tmStart:3:tmEnd, 2);

        for p = 0:maxp
            for q = 0:maxq
                for px = -1:maxpx
                    if p ~= 0 || q ~= 0
    
                        counter = counter+1;
                        if px == -1
                            XExog = []; XPred = []; px_temp = []; 
                        else
                            XExog = XExog_t; XPred = XPred_t; px_temp = px;
                        end
    
                        % Estimate augmented ARMAX(p,q,px) models
                        [coeff, labels, ~, resid, loglik_t] = armax(y_t, p, q, XExog, px_temp);
                        
                        % Store the log-likelihood and BIC
                        loglik(t,counter) = loglik_t;
                        bic(t,counter) = -2*loglik(t,counter) + ...
                            log(length(y_t))*(p+q+(~isempty(px_temp))*px);
    
                        for h = 1:H
                            % Compute h-step-ahead predictions
                            y_hat_th = armax_predict(h, y_t, coeff, labels, resid, ...
                                'X_hist', XExog, 'X_future', XPred, 'px', px_temp);
                            % Store the prediction
                            y_hat(t,counter,h) = y_hat_th;
                        end
                    end    
                end
            end
        end

        counter = counter+1;
        % Store the prediction and info from the model with the minimum BIC
        min_bic_index = find(min(bic(t, :)) == bic(t, :));
        loglik(t, counter) = loglik(t, min_bic_index);
        bic(t, counter) = bic(t, min_bic_index);
        bic_model(t) = model_spec(min_bic_index);
        y_hat(t, counter, :) = y_hat(t, min_bic_index, :);

    end

    % Progress check:
    if rem(t,10) == 0
        fprintf('Progress: %d of %d steps concluded.\n',t,T_os)
    end
end

% --- Stop Timer and Display Elapsed Time ---
elapsedTime = toc(startTime);
fprintf('\nAll steps concluded.\n');
fprintf('Total elapsed time: %s (hh:mm:ss).\n', string(duration(0,0,elapsedTime,'Format','hh:mm:ss')));


% -------------------------------------------------------------------
% 6. POST-PROCESSING & RESULTS
% -------------------------------------------------------------------

% --- Restore the Covid-19 Period if Altered ---
if RemoveCovid == 1
    d(CovidPeriod, :) = dCovid;
end

% --- Compute Bates-Granger and Dynamic Threshold Combination Schemes ---
tmStart = find(~isnan(y), 1, "first");
tmEnd = find(~isnan(y), 1, "last");
tm = tmStart:3:tmEnd;

% Transform results to quarterly for plotting and combinations
time = d.Time(os); time = time(tm);
yq = y(tm);
yq_hat = y_hat(tm, :, :);

% Generate combination model names
comb_spec = string(nan(1, length(nu)));
comb_names = "ARMA_BG";
counter = 0;
for k = 1:length(comb_names)
    for l = 1:length(nu)
        counter = counter+1;
        comb_spec(counter) = comb_names(k) + "_" + string(nu(l));
    end
end

y_hat(:, M+1:M+length(nu), :) = nan;
for h = 1:H
    % Compute the forecast combinations
    yq_hat(:, M+1:M+length(nu), h) = ...
        [topk_bg(yq(h:end), yq_hat(1:end-h+1, 1:M-1, h), h, M-1, nu, 1); ...
        nan(h-1, length(nu))];
        %[BatesGranger(yq_hat(1:end-h+1, 1:M-1, h), yq(h:end), h, nu); ...
        %nan(h-1, length(nu))];
    
    % Store quarterly combinations back into the main monthly-indexed matrix
    y_hat(tm, M+1:M+length(nu), h) = yq_hat(:, M+1:M+length(nu), h);
    y_hat(tm, M+length(nu)+1:M+length(nu), h) = yq_hat(:, M+length(nu)+1:M+length(nu), h);
end

% --- Assemble the Final Table for Plotting ---
resTable = timetable(time(h:end), yq(h:end), yq_hat(1:end-h+1, :, display_h));
resTable = splitvars(resTable);
resTable.Properties.VariableNames = ["GDP", model_spec, comb_spec];


% -------------------------------------------------------------------
% 7. VISUALIZATION
% -------------------------------------------------------------------

reset(gca);
figure(1);

h1 = plot(resTable.Time,resTable.GDP,'.','MarkerSize',30); hold on;
if RemoveCovid == 1
    h2 = plot(CovidPeriod,d.GDP(CovidPeriod),'.','MarkerSize',30); hold on;
end
h3 = plot(resTable.Time,resTable{:,2:end-1},"LineWidth",0.7,"LineStyle",":"); hold on;
h4 = plot(resTable.Time,resTable{:,"ARMA_minBIC"},"LineWidth",1.5,"Color",[0.4660, 0.6740, 0.1880]);
h5 = plot(resTable.Time,resTable{:,"ARMA_BG_4"},"LineWidth",1.5,"Color",[0.8500, 0.3250, 0.0980]);
grid on;

li = 1;
legendItem{1,li} = "GDP growth"; li = li+1;
if RemoveCovid == 1; legendItem{1,li} = "GDP growth (Covid-19)"; li = li+1; end
legendItem{1,li} = "Min BIC models ("+string(display_h)+"-step-ahead forecast)"; li = li+1;
legendItem{1,li} = "BG combination (nu = 1; "+string(display_h)+"-step-ahead forecast)"; li = li+1;

if RemoveCovid == 1
    legend([h1 h2 h4 h5], legendItem, 'Location', 'southwest', 'FontSize', 30);
else
    legend([h1 h4 h5], legendItem, 'Location', 'southwest', 'FontSize', 30);
end

legend boxoff;
set(gca,'FontSize',20);


% -------------------------------------------------------------------
% 8. SAVE RESULTS
% -------------------------------------------------------------------

if save_res == 1

    dateToday = string(datetime("today","Format","uuuuMMdd"));
    
    predictionName = append(dateToday,"-ARMA-ALL-",string(maxp),string(maxq),string(maxpx));
    pathPrediction = append("HISTORY/PREDICTION/",predictionName,".mat");

    % MATLAB variable to save is "y_hat":
    save(pathPrediction,"y_hat");

end