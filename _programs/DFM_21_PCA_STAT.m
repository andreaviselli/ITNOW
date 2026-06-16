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
if ~is_declared
    RemoveCovid = 0;    % Whether to remove the Covid-19 period (1=yes, 0=no; 
end                     % works with is_declared = 0)

q = 2;                  % Number of factors
p = 1;                  % Order of the lag polynomial in the factor(s)
H = 0;                  % Max forecast horizon (H=0 is nowcasting)

% --- Prediction Method & Specification ---
method = "PCA";         % Estimation method
pred = "Stat";          % Prediction method ("Stat" or "Dynm")
max_py = 1;             % Max AR order in the augmented equation
max_qy = 1;             % Max MA order in the augmented equation
max_pf = 0;             % Max factor lag order in the augmented equation

% --- Estimation Options ---
RNaN = 0.2;             % Exclusion threshold for rows with missing obs
maxiter = 500;          % Maximum number of iterations for the EM algorithm
dispconv = 0;           % Display convergence for the EM algorithm

% --- Display Options ---
display_h = 0;          % Which prediction horizon to display (e.g., 0, 1, ...)


% -------------------------------------------------------------------
% 3. OUTPUT SETTINGS
% -------------------------------------------------------------------

save_res = 0;                                   % Save results (1=yes, 0=no)
outputFolderName = strcat("HISTORY/",dataset);  % Output folder


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

is = timerange(Est_Start,Est_End,"closed");     % First window
os = timerange(Est_End,Eval_End,"closed");      % Evaluation sample

% --- Set Series' Publication Delay (in months) ---
publicationDelay = [2,2,1,1,2,1,1,0,0,2,1,1,2,1,0,0,0,0,0,1];

% --- Pre-calculate Useful Quantities ---
N = size(d,2);                  % Number of variables
T_is = size(d(is,:),1);         % Estimation sample size
T_os = size(d(os,:),1);         % Evaluation sample size

% --- Pre-allocate Output Arrays ---
y = d.GDP(os);                  % Actual GDP growth
f_hat = nan(T_os,q);            % Estimated factors

if strcmp(pred, "Stat")         % Predicted GDP growth
    y_hat = nan(T_os, 1+H);
elseif strcmp(pred, "Dynm")
    y_hat = nan(T_os, (1+max_py)*(1+max_qy)*(1+max_pf), 1+H);
end

% --- Generate Model Specification Names ---
if strcmp(pred, "Dynm")
    model_spec = string(nan((1+max_py)*(1+max_qy)*(1+max_pf), 1));
    model_count = 0;
    for py = 0:max_py
        for qy = 0:max_qy
            for pf = 0:max_pf
                model_count = model_count + 1;
                model_spec(model_count) = "AR" + py + "_MA" + qy + "_PF" + pf;
            end
        end
    end
end


% -------------------------------------------------------------------
% 5. JOB SUBMISSION & EXECUTION
% -------------------------------------------------------------------

% --- Display Job Settings ---
fprintf('JOB: Running rolling window DFM estimation by %s with settings:\n', method);
fprintf('------------------------------------------------------------\n');
fprintf('  - Number of factors (q):              %d\n', q);
fprintf('  - Factor lag order (p):               %d\n', p);
fprintf('  - Prediction method:                  %s\n', pred);
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
    
    % Starting date:
    T0 = Est_Start+calmonths(t-1);

    % Ending date:
    T1 = Est_End+calmonths(t-1);
    
    % Set the new estimation set:
    is = timerange(T0,T1,"closed");
    X_t = table2array(d(is,:));
    
    % Adjust for publication delays to create a pseudo real-time vintage:
    if (t < T_os) || (t == T_os && is_declared)
        for i = 1:N
            X_t(end-publicationDelay(i)+1:end,i) = nan;
        end
    end

    % Estimation of the DFM:
    out_t = dfm(X_t,q,p,method,'RNaN',RNaN, ...
        'maxiter',maxiter,'dispconv',dispconv);

    % Store the current-period factor:
    f_hat(t,:) = out_t.F(1:q,end)';

    % Predict based on a method:
    if strcmp(pred, "Stat")
    
        y_hat(t,:) = out_t.XHat(end,end);
    
    elseif strcmp(pred, "Dynm")

    % Find the first and last available obs of the target variable
    first_y = find(~isnan(X_t(:, end)), 1, "first");
    last_y = find(~isnan(X_t(:, end)), 1, "last");
        
        for py = 0:max_py
            for qy = 0:max_qy
                for pf = 0:max_pf
                    for h = 0:H
                        
            % Arrange the target variable and factors
            y_t = X_t(first_y:3:last_y, end);
            f1_t = out_t.F(1:q, flip(last_y-2:-3:first_y))';
            f2_t = out_t.F(1:q, flip(last_y-1:-3:first_y))';
            f3_t = out_t.F(1:q, first_y:3:last_y)';
            T_th = min([length(y_t), length(f1_t), length(f2_t), length(f3_t)]);
            
            % Arrange the factors as a mixed frequency model
            X_th = [f1_t(end-T_th+1:end-h, :), ...
                f2_t(end-T_th+1:end-h, :), ...
                f3_t(end-T_th+1:end-h, :)];
            y_th = y_t(end-T_th+1+h:end);
            pfVec = repelem(pf, 3*q);
            
            % Compute lags of the factors (2 lags is fixed)
            X_mod_th = MakeLags(out_t.F(1:q, :)', 2);
            X_mod_th = [out_t.F(1:q, 1:end-h)', X_mod_th(1:end-h, :)];            
            
            % Shift the monthly factors to match the mixed-frequency model
            month_in_quarter = mod(T_is-last_y, 3);
            switch month_in_quarter 
                % case 1, e.g., Nowcasting in Jan. Use Jan(t), Dec(t-1), Nov(t-1)
                case 2 % e.g., Nowcasting in Feb. Use Feb(t), Jan(t), Dec(t-1)
                    X_mod_th = [X_mod_th(:, q+1:2*q), X_mod_th(:, 2*q+1:end), X_mod_th(:, 1:q)];
                case 3 % e.g., Nowcasting in Mar. Use Mar(t), Feb(t), Jan(t)
                    X_mod_th = [X_mod_th(:, 2*q+1:end), X_mod_th(:, 1:q), X_mod_th(:, q+1:2*q)];
            end

            % New estimation sample with months shifted dynamically
            X_out_th = X_mod_th(end-h, :);
            % Take only the last new data h periods ago (as the forecast is direct)
            X_mod_th = X_mod_th(end-T_th:end-h-1, :);
            
            % Perform the direct regression and predict
            [beta_th, labels, ~, e_hat] = armax(y_th, py, qy, X_th, pfVec);
            y_hat_t = armax_predict(1, y_th, beta_th, labels, e_hat, ...
                'X_hist', X_mod_th, 'X_future', X_out_th, 'px', pfVec);
    
            % Store the forecast
            model_count = (py * (max_qy + 1) + qy) * (max_pf + 1) + pf + 1;
            y_hat(t, model_count, 1+h) = y_hat_t;

                    end
                end
            end
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

% --- Restore the Covid-19 Period ---
if RemoveCovid == 1
    d(CovidPeriod, :) = dCovid;
end

% --- Assemble the Table of Predictions ---
if strcmp(pred, "Stat")
    y_hat_h = y_hat(:, 1+display_h);
    resTable = timetable(d.Time(os), y, ...
        [nan(display_h, 1); y_hat_h(1:end-display_h, :)]);
    resTable = splitvars(resTable);
elseif strcmp(pred, "Dynm")
    y_hat_h = y_hat(:, :, 1+display_h);
    resTable = timetable(d.Time(os), y, ...
        [nan(display_h, (1+max_py)*(1+max_qy)*(1+max_pf)); ...
    y_hat_h(1:end-display_h, :)]);
    resTable = splitvars(resTable);
    resTable.Properties.VariableNames(2:end) = model_spec;
end

% --- Calculate Empirical Prediction Intervals ---
if strcmp(pred, "Stat")     % only for "static" predictions
    
    e_hat = rmmissing( y_hat_h-y );
    a = 0.1;
    Q_eHat = quantile(e_hat(:,1),[a,1-a]);
    PI_yHat = y_hat_h+Q_eHat;

end


% -------------------------------------------------------------------
% 7. VISUALIZATION
% -------------------------------------------------------------------

reset(gca)
figure(1)

plot(resTable.Time,resTable.y,'.','MarkerSize',30); hold on
if RemoveCovid == 1
    plot(CovidPeriod,d.GDP(CovidPeriod),'.','MarkerSize',30); hold on
end

if strcmp(pred, "Stat")
    
    plot(resTable.Time,resTable{:,2},"LineWidth",2); hold on
    inBetweenCoord = [resTable.Time;flip(resTable.Time)];
    inBetween = [PI_yHat(:,1);flip(PI_yHat(:,2))];
    fill(inBetweenCoord,inBetween,[.7,.7,.7],'FaceAlpha',0.5,'EdgeColor', 'none');
    grid on
    
    li = 1;
    legendItem{1,li} = "GDP growth"; li = li+1;
    if RemoveCovid == 1; legendItem{1,li} = "GDP growth (Covid-19)"; li = li+1; end
    legendItem{1,li} = "Nowcast"; li = li+1;
    legendItem{1,li} = "95% Prediction Interval";

    ylabel('QoQ change','FontSize',30);
    legend(legendItem,'Location','southwest','Fontsize',30); 
    legend boxoff
    
    gotChildren = get(gca,'Children');
    set(gca,'Children',flip(gotChildren));
    set(gca,'FontSize',20);

elseif strcmp(pred, "Dynm")
    
    plot(resTable.Time,resTable{:,2:end},"LineStyle",':',"LineWidth",1.2);
    grid on

    li = 1;
    legendItem{1,li} = "GDP growth"; li = li+1;
    if RemoveCovid == 1; legendItem{1,li} = "GDP growth (Covid-19)"; li = li+1; end
    legendItem{1,li} = "Model forecast (h = " + display_h + ")"; li = li+1;
    
    ylabel('QoQ change','FontSize',30);
    legend(legendItem,'Location','southwest','Fontsize',30);
    legend boxoff

end


% -------------------------------------------------------------------
% 8. SAVE RESULTS
% -------------------------------------------------------------------

if save_res == 1

    dateToday = string(datetime("today","Format","uuuuMMdd"));
    p = string(p); q = string(q);
    
    predictionName = append(dateToday,"-DFM-",p,q,"-",method,"-",pred);
    pathPrediction = append("HISTORY/PREDICTION/",predictionName,".mat");

    smoothedFactorName = append(dateToday,"-DFM","-",method);
    pathSmoothedFactor = append("HISTORY/SMOOTHEDFACTOR/",smoothedFactorName,".mat");

    % MATLAB variable is "y_hat":
    save(pathPrediction,"y_hat");
    
    % MATLAB variable is "f_hat":
    save(pathSmoothedFactor,"f_hat");

end