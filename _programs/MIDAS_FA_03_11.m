% -------------------------------------------------------------------
% 0. INITIALIZATION
% -------------------------------------------------------------------
%clc; clear     % Uncomment to use this as a standalone script
is_flow = 1;    % Whether to run the script with no interruptions (1=yes, 0=no)
is_declared = 1;    % Whether the dataset file and Covid-19 option is already
                    % declared and called from outside this script (1=yes, 0=no)

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
% NOTE: For replication, set RemoveCovid=1 for Comb=0 (Factor-MIDAS) and
% RemoveCovid=0 for Comb=1 (Forecast Combination).
if ~is_declared
    RemoveCovid = 0;    % Whether to remove the Covid-19 period (1=yes, 0=no; 
end                     % works with is_declared = 0)

Comb = 0;       % Prediction Method (1 = Forecast Combination, 0 = Factor-MIDAS).
m = 3;          % Frequency mismatch (e.g., m=3 for quarterly/monthly).
py = 0;         % Lags of GDP growth (>= 0).
px = 3;         % Lags for the high-frequency predictors (>= 1).
H = 0;          % Max forecast horizon (including h=0 is nowcasting)

% --- Factor-MIDAS Specification (only used if Comb=0) ---
q = 1;          % Number of factors (>= 1).
p = 1;          % Lags for the factors (>= 1).

% --- Forecast Combination Specification (only used if Comb=1) ---
perc = [0.1, 0.5, 0.9]; % Percentiles for combined forecast distribution.
nu = 4;                 % Rolling window sizes for the BG scheme.

% --- Estimation Options ---
RNaN = 0.5;     % Exclusion threshold for variables with > RNaN% missing values.
maxiter = 500;  % Max. number of iterations for the EM algorithm.
dispconv = 0;   % Display the convergence of the EM algorithm (1=yes, 0=no).

% --- Display Options ---
display_p = 2;          % Which percentile forecast to plot (e.g., 0, 1, ..., length(perc))
display_pq = [1,3];     % Which percentile forecast to use as prediction intervals
display_nu = 1;         % Which rolling window size combination to plot for BG and DT (1, 2, ...)
display_h = 0;          % Which prediction horizon to display (e.g., 0, 1, ..., H)


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

% --- Get Variable Names ---
vars = string([d.Properties.VariableNames(end), ...
    d.Properties.VariableNames(1:end-1)]);

% --- Time (Rolling Window) Settings ---
if ~is_declared
    Est_Start = d.Time(1);              % Start of estimation sample
    Est_End = datetime("2006-04-01");   % End of estimation sample
    Eval_End = d.Time(end);             % End of evaluation sample
end

is = timerange(Est_Start,Est_End,"closed");     % First estimation window.
os = timerange(Est_End,Eval_End,"closed");      % Full evaluation sample.

% --- Set Series' Publication Delay (in months) ---
publicationDelay = [2,2,1,1,2,1,1,0,0,2,1,1,2,1,0,0,0,0,0,1];

% --- Pre-calculate Useful Quantities ---
T_is = size(d(is,:),1);         % Estimation sample size.
T_os = size(d(os,:),1);         % Evaluation sample size.

% --- Pre-calculate Useful Quantities ---
if Comb == 0; perc = []; end

% --- Pre-allocate Output Arrays ---
y = d.GDP(os);                  % Actual GDP growth.
if Comb == 0                    % Predicted GDP growth
    y_hat = nan(T_os, 1+H);
elseif Comb == 1
    y_hat = nan(T_os, length(perc)+length(nu), 1+H);
    y_hat_all = nan(T_os, length(vars)-1, 1+H);
end


% -------------------------------------------------------------------
% 5. JOB SUBMISSION & EXECUTION
% -------------------------------------------------------------------

% --- Display Job Settings ---
if Comb == 0; methodStr = "Factor-MIDAS"; else; methodStr = "Forecast Combination"; end
fprintf('JOB: Running rolling window MIDAS estimation via %s with settings:\n', methodStr);
fprintf('------------------------------------------------------------\n');
fprintf('  - Max Forecast horizon (h):           %d\n', H);
fprintf('  - Dependent variable lags (py):       %d\n', py);
fprintf('  - Predictor lags (px):                %d\n', px);
if Comb == 0
    fprintf('  - Number of factors (q):              %d\n', q);
    fprintf('  - Factor lag order (p):               %d\n', p);
end
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

    % Starting date for the current window:
    T0 = datetime(Est_Start)+calmonths(t-1);

    % Ending date for the current window:
    T1 = datetime(Est_End)+calmonths(t-1);
    
    % Set the new estimation dataset:
    is = timerange(T0,T1,"closed");
    X_t = table2array(d(is,:));
    N = size(X_t, 2);
    
    % Adjust for publication delays to create a pseudo real-time vintage:
    if (t < T_os) || (t == T_os && is_declared)
        for i = 1:N
            X_t(end-publicationDelay(i)+1:end,i) = nan;
        end
    end
    
    % Get the target variable and predictors:
    y_t = X_t(:,end);
    X_t(:,end) = [];
    
    for h = 0:H

        % Estimate the UMIDAS model (already adjusted for publication delays):
        [~,yHat_t,yHatAll_t,varsOut,~] = umidas(y_t,X_t,h,m,py,px,'comb',Comb,'q',q,'p',p, ...
            'r',RNaN,'vars',vars,'perc',perc,'maxiter',maxiter,'dispconv',dispconv);

        % Store the prediction:
        if Comb == 0
            y_hat(t,1+h) = yHat_t;
        elseif Comb == 1
            % Store percentiles of min BIC predictions
            y_hat(t,1:length(perc),1+h) = yHat_t;
            % Store all predictions based on available series
            varsOut(1) = [];
            vars_index = nan(1, length(varsOut));
            for i = 1:length(varsOut)
                index_i = find(varsOut(i) == vars(2:end));
                vars_index(i) = index_i;
            end
            y_hat_all(t,vars_index,1+h) = yHatAll_t;
        end
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

% --- Compute forecast combinations ---
if Comb == 1
    for h = 0:H
        y_hat(:, length(perc)+1:length(perc)+length(nu), 1+h) = ...
            [topk_bg(y(1+h:end), y_hat_all(1:end-h, :, 1+h), h, size(y_hat_all, 2), nu, m); nan(h, length(nu))];
    end
end

% --- Assemble the Table of Predictions ---
d_Time_os = d.Time(os);
if Comb == 0
    resTable = timetable(d_Time_os(1+h:end), y(1+h:end), y_hat(1:end-h, 1+display_h));
elseif Comb == 1
    to_display = [display_p, length(perc)+display_nu];
    resTable = timetable(d_Time_os(1+h:end), y(1+h:end), y_hat(1:end-h, to_display, 1+display_h));
end
resTable = splitvars(resTable);
if Comb == 0
    resTable.Properties.VariableNames = ["y", "y_hat"];
elseif Comb == 1
    resTable.Properties.VariableNames = ["y", "y_hat", "y_hat_bg"];
end

% --- Calculate Empirical Prediction Intervals ---
if Comb == 0
    a = 0.1;
    Q_eHat = quantile(rmmissing( y_hat(1:end-h, 1+display_h)-y(1+h:end) ),[a,1-a]);
    PI_yHat = y_hat(1:end-h,:)+Q_eHat;
elseif Comb == 1
    PI_yHat = [y_hat(1:end-h, display_pq(1), 1+display_h), ...
        y_hat(1:end-h, display_pq(2), 1+display_h)]; % e.g. 10th and 90th percentiles
end


% -------------------------------------------------------------------
% 7. VISUALIZATION
% -------------------------------------------------------------------

reset(gca);
figure(1);

plot(resTable.Time,resTable.y,'.','MarkerSize',30); hold on;
if RemoveCovid == 1
    plot(CovidPeriod,d.GDP(CovidPeriod),'.','MarkerSize',30); hold on;
end
    
plot(resTable.Time,resTable.y_hat,"LineWidth",2); hold on;
if Comb == 1
    plot(resTable.Time,resTable.y_hat_bg,"LineWidth",2); hold on;
end

inBetweenCoord = [resTable.Time;flip(resTable.Time)];
inBetween = [PI_yHat(:,1);flip(PI_yHat(:,2))];
fill(inBetweenCoord,inBetween,[.7,.7,.7],'FaceAlpha',0.5,'EdgeColor', 'none');
grid on;
    
li = 1;
legendItem{1,li} = "GDP growth"; li = li+1;
if RemoveCovid == 1; legendItem{1,li} = "GDP growth (Covid-19)"; li = li+1; end
if Comb == 0
    legendItem{1,li} = "Forecast (h=" + string(display_h) + ")"; li = li+1;
    ConfLev = 1-2*a;
    interval_detail = " (factor-augmented UMIDAS)";
elseif Comb == 1
    legendItem{1,li} = "Forecast (perc=" + display_p + "; h=" + string(display_h) + ")"; 
    li = li+1;
    ConfLev = perc(display_pq(2))-perc(display_pq(1));
    interval_detail = " (" + string(perc(display_pq(1))) + " and " + ...
        string(perc(display_pq(2))) + " perc.)";
end
legendItem{1,li} = string(ConfLev*100) + "% Prediction Interval" + interval_detail;
if Comb == 1
    legendItem{1,li} = "BG combination (h=" + string(display_h) + ")"; li = li+1;
end

ylabel('QoQ change','FontSize',30);
legend(legendItem,'Location','southwest','Fontsize',30);
legend boxoff;

gotChildren = get(gca,'Children');
set(gca,'Children',flip(gotChildren));
set(gca,'FontSize',20);


% -------------------------------------------------------------------
% 8. SAVE RESULTS
% -------------------------------------------------------------------

if save_res == 1

    dateToday = string(datetime("today","Format","uuuuMMdd"));
    if Comb == 0; modelType = "FA"; elseif Comb == 1; modelType = "COMB"; end

    predictionName = append(dateToday,"-MIDAS-",modelType,"-",py,px,"-",p,q);
    pathPrediction = append("HISTORY/PREDICTION/",predictionName,".mat");
    
    % MATLAB variable to save is "y_hat":
    save(pathPrediction,"y_hat");

end