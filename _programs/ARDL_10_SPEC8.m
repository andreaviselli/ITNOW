% -------------------------------------------------------------------
% 0. INITIALIZATION
% -------------------------------------------------------------------
%clc; clear         % Uncomment to use this as a standalone script
is_flow = 1;        % Whether to run the script with no interruptions (1=yes, 0=no)
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
% Select the set of explanatory variables (1-8):
% 1. "INDPROD","ITACOIN"
% 2. "INDPROD","FTSEMIB","ITACOIN"
% 3. "INDPROD","FTSEMIB","INDPRODPRC","ITACOIN"
% 4. "INDPROD","FTSEMIB","CONSTRPROD","ITCBC","ITACOIN"
% 5. "INDPROD","FTSEMIB","CONSTRPROD", "INDPRODPRC","ITACOIN"
% 6. "INDPROD","FTSEMIB","INDPRODPRC","RETLTRADE","ITACOIN"
% 7. "INDPROD","FTSEMIB","INDPRODPRC","RETLTRADE","ITCBC","ITACOIN"
% 8. "INDPROD","FTSEMIB","CONSTRPROD","INDPRODPRC","RETLTRADE","ITCBC","ITACOIN"
XSpec = 8;                  % Selected predictor set from the list above.

if ~is_declared
    RemoveCovid = 0;    % Whether to remove the Covid-19 period (1=yes, 0=no; 
end                     % works with is_declared = 0)

method = "QMLE";            % Estimation method ("MLE" or "QMLE").
py = 1;                     % Lags of GDP growth (>= 1).
px = 0;                     % Lags for the high-frequency predictors (>= 0).
H = 0;                      % Max forecast horizon (H=0 is nowcasting).

% --- Display Options ---
display_h = 0;              % Which prediction horizon to display in the final plot.


% -------------------------------------------------------------------
% 3. OUTPUT SETTINGS
% -------------------------------------------------------------------

save_res = 0;                                   % Save results (1=yes, 0=no).
outputFolderName = strcat("HISTORY/",dataset);  % Output folder.


% -------------------------------------------------------------------
% 4. DATA PREPARATION & PRE-COMPUTATION
% (Do not change for replication purposes)
% -------------------------------------------------------------------

% --- Define Predictor Set and Publication Delays based on XSpec ---
if XSpec == 1
    XName = ["INDPROD","ITACOIN"];
    publicationDelay = [1,2,0];
elseif XSpec == 2
    XName = ["INDPROD","FTSEMIB","ITACOIN"];
    publicationDelay = [1,2,0,0];
elseif XSpec == 3
    XName = ["INDPROD","FTSEMIB","INDPRODPRC","ITACOIN"];
    publicationDelay = [1,2,0,1,0];
elseif XSpec == 4
    XName = ["INDPROD","FTSEMIB","CONSTRPROD","ITCBC","ITACOIN"];
    publicationDelay = [1,2,0,2,0,0];
elseif XSpec == 5
    XName = ["INDPROD","FTSEMIB","CONSTRPROD","INDPRODPRC","ITACOIN"];
    publicationDelay = [1,2,0,2,1,0];
elseif XSpec == 6
    XName = ["INDPROD","FTSEMIB","INDPRODPRC","RETLTRADE","ITACOIN"];
    publicationDelay = [1,2,0,1,1,0];
elseif XSpec == 7
    XName = ["INDPROD","FTSEMIB","INDPRODPRC","RETLTRADE","ITCBC","ITACOIN"];
    publicationDelay = [1,2,0,1,1,0,0];
elseif XSpec == 8
    XName = ["INDPROD","FTSEMIB","CONSTRPROD","INDPRODPRC","RETLTRADE","ITCBC","ITACOIN"];
    publicationDelay = [1,2,0,2,1,1,0,0];
end

% --- Subset Data and Define Variable Roles ---
yName = "GDP";
xNameStart = "INDPROD";             % Start of the sample imputation variable.
xNameEnd = "ITACOIN";               % End of the sample imputation variable.
px = repelem(px,length(XName));     % Expand predictor lags to match XName length.

d = splitvars(timetable(d.Time,[d.GDP,d{:,XName}]));
d.Properties.VariableNames = [yName,XName];

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

% --- Pre-calculate Useful Quantities ---
T_is = size(d(is,:),1);         % Estimation sample size.
T_os = size(d(os,:),1);         % Evaluation sample size.

% --- Pre-allocate Output Arrays ---
y = d.GDP(os);                  % Actual GDP growth.
y_hat = nan(T_os, 1, 1+H);      % Predicted GDP growth.


% -------------------------------------------------------------------
% 5. JOB SUBMISSION & EXECUTION
% -------------------------------------------------------------------

% --- Display Job Settings ---
fprintf('JOB: Running rolling window ARDL estimation by %s with settings:\n', method);
fprintf('------------------------------------------------------------\n');
fprintf('  - Predictor specification (XSpec):    %d\n', XSpec);
fprintf('  - AR order (py):                      %d\n', py);
fprintf('  - Max forecast horizon (H):           %d\n', H);
fprintf('  - Variables:                          %s\n', strjoin(XName, ", "));
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
   
    for h = 0:H

        % Construct the estimation sample based on the horizon (direct forecast):
        y_th = X_t(1+h:end,1);
        X_th = X_t(1:end-h,2:end);

        % Estimate the ARDL model:
        [yHat,Z,B,~,beta,~,~,~] = ardl(y_th,yName, ...
            X_th,XName,py,px,method,xNameStart,xNameEnd);

        % Store the prediction for the current horizon:
        y_hat(t, :, 1+h) = yHat(end);

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

% --- Assemble the Table of Predictions for the specified display horizon ---
d_Time_os = d.Time(os);
resTable = timetable(d_Time_os(1+h:end), y(1+h:end), y_hat(1:end-h, :, 1+display_h));
resTable = splitvars(resTable);

% --- Calculate Empirical Prediction Intervals ---
a = 0.1; % Corresponds to an 80% prediction interval
e_hat = rmmissing(y_hat(1:end-h, :, 1+display_h) - y(1+h:end));
Q_eHat = quantile(e_hat, [a, 1-a]);
PI_yHat = y_hat(1:end-h, :, 1+display_h) + Q_eHat;


% -------------------------------------------------------------------
% 7. VISUALIZATION
% -------------------------------------------------------------------

reset(gca);
figure(1);

plot(resTable.Time,resTable{:,1},'.','MarkerSize',30); hold on;
if RemoveCovid == 1
    plot(CovidPeriod,d.GDP(CovidPeriod),'.','MarkerSize',30); hold on;
end
    
plot(resTable.Time,resTable{:,2},"LineWidth",2); hold on;
inBetweenCoord = [resTable.Time;flip(resTable.Time)];
inBetween = [PI_yHat(:,1);flip(PI_yHat(:,2))];
fill(inBetweenCoord,inBetween,[.7,.7,.7],'FaceAlpha',0.5,'EdgeColor', 'none');
grid on;
    
li = 1;
legendItem{1,li} = "GDP growth"; li = li+1;
if RemoveCovid == 1; legendItem{1,li} = "GDP growth (Covid-19)"; li = li+1; end
legendItem{1,li} = string(display_h) + "-step-ahead forecast"; li = li+1;
legendItem{1,li} = string((1-2*a)*100) + "% Prediction Interval";

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

    predictionName = append(dateToday,"-ARDL-",string(py), string(px), ...
        "-SPEC",string(XSpec),"-",method);
    pathPrediction = append("HISTORY/PREDICTION/",predictionName,".mat");
    
    % MATLAB variable to save is "y_hat":
    save(pathPrediction,"y_hat");

end