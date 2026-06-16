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
% (Do not change for replication purposes)
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
h = 0;                  % Forecast horizons

% --- Estimation Method ---
method = "2S";                  % Estimation method ("2S" or "QMLE")
dispconv = 0;                   % Display convergence (only for "QMLE")

% --- Advanced Options ---
threshRule = "None";            % Threshold model for GDP ("Thresh" or "None")                         
threshValue = 4;                % Value of the threshold (e.g. 4)
obsFactor = "None";             % Observable factor ("None", "LaggedGDP", or a variable name)
RNaN = 0.2;                     % Exclusion threshold for rows with missing obs


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

% --- Observable Factor Setup ---
if obsFactor == "LaggedGDP"
    F_obs = [nan(4,1); d.GDP(2:end)];

elseif obsFactor ~= "LaggedGDP" && obsFactor ~= "None"
    exprToEval_1 = append("F_obs = d.",obsFactor,";");
    exprToEval_2 = append("d.",obsFactor," = [];");
    
    eval(exprToEval_1)
    eval(exprToEval_2)

elseif obsFactor == "None"
    F_obs = [];
end

% --- Set Specification for Threshold ---
if threshRule == "None"; threshValue = threshRule; end

% --- Set Iterations for EM Algorithm ---
if method ~= "2S"; maxiter = 500; else; maxiter = []; end

% --- Set Series' Publication Delay (in months) ---
publicationDelay = [2,2,1,1,2,1,1,0,0,2,1,1,2,1,0,0,0,0,0,1];

% --- Pre-calculate Useful Quantities ---
N = size(d,2);                  % Number of variables
T = size(d,1);                  % Sample size
T_is = size(d(is,:),1);         % Estimation sample size
T_os = size(d(os,:),1);         % Evaluation sample size
H = h+1;                        % Number of prediction horizons

% --- Pre-allocate Output Arrays ---
y = d.GDP(os);                  % Actual GDP growth
y_hat = zeros(T_os,H);          % Predicted GDP growth
f_hat = zeros(T,q);             % Predicted factors


% -------------------------------------------------------------------
% 5. JOB SUBMISSION & EXECUTION
% -------------------------------------------------------------------

% --- Display Job Settings ---
fprintf('JOB: Running 10y rolling window DFM estimation by %s with settings:\n', method);
fprintf('------------------------------------------------------------\n');
fprintf('  - Number of factors (q):              %d\n', q);
fprintf('  - Factor lag order (p):               %d\n', p);
fprintf('  - Threshold:                          %s\n', string(threshValue));
fprintf('  - Observable factor:                  %s\n', obsFactor);
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

    % Handle extreme shocks through the threshold:
    if threshRule == "Thresh"
        
        % GDP growth regime, based on the threshold:
        regimeIndicator = abs(X_t(:,end)) > threshValue;

        if sum(regimeIndicator) ~= 0
            
            % Include the regime indicator as a predictor:
            X_t = [X_t(:,1:size(X_t,2)-1),regimeIndicator, ...
                X_t(:,end)];

        end
    end
    
    % Match the observable factor with the current window:
    if ~isempty(F_obs)

        % Subset the factor:
        F_obs_t = F_obs(t:t+T_is-1);

    else
        % If not included:
        F_obs_t = [];
    end
    
    % Estimation of the DFM:
    out_t = dfm(X_t,q,p,method,'FObs',F_obs_t,'RNaN',RNaN, ...
        'maxiter',maxiter,'dispconv',dispconv);

    % Store the predictions (for the 2S and QMLE method):
    [XHat_t,~] = dfm_predict(out_t,'hAhead',h,'hBack',0);
    y_hat(t,:) = XHat_t(end,:);

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
resTable = timetable(d.Time(os),y,y_hat);
resTable = splitvars(resTable);

% --- Calculate Empirical Prediction Intervals ---
e_hat = rmmissing( y_hat-y );
a = 0.1;
Q_eHat = quantile(e_hat(:,1),[a,1-a]);
PI_yHat = y_hat+Q_eHat;


% -------------------------------------------------------------------
% 7. VISUALIZATION
% -------------------------------------------------------------------

reset(gca)
figure(1)

plot(resTable.Time,resTable.y,'.','MarkerSize',30); hold on
if RemoveCovid == 1
    plot(CovidPeriod,d.GDP(CovidPeriod),'.','MarkerSize',30); hold on
end
plot(resTable.Time,resTable{:,2},"LineWidth",2); hold on

inBetweenCoord = [resTable.Time;flip(resTable.Time)];
inBetween = [PI_yHat(:,1);flip(PI_yHat(:,2))];
fill(inBetweenCoord,inBetween,[.7,.7,.7],'FaceAlpha',0.5,'EdgeColor', 'none');
grid on

li = 0; li = li+1;
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


% -------------------------------------------------------------------
% 8. SAVE RESULTS
% -------------------------------------------------------------------

if save_res == 1

    dateToday = string(datetime("today","Format","uuuuMMdd"));
    
    threshRule = upper(threshRule);
    if obsFactor == "LaggedGDP"; obsFactor = "LGDP";
    else; obsFactor = upper(obsFactor); end    
    p = string(p); q = string(q);

    predictionName = append(dateToday,"-DFM-",p,q,"-",method,"-",threshRule,"-",obsFactor);
    pathPrediction = append("HISTORY/PREDICTION/",predictionName,".mat");

    smoothedFactorName = append(dateToday,"-DFM-",p,q,"-",method,"-",threshRule,"-",obsFactor);
    pathSmoothedFactor = append("HISTORY/SMOOTHEDFACTOR/",smoothedFactorName,".mat");

    % MATLAB variable is "y_hat":
    save(pathPrediction,"y_hat");

    % MATLAB variable is "f_hat":
    save(pathSmoothedFactor,"f_hat");

end