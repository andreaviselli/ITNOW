function YHatSmooth = SmoothNowcast(YHat,K)
% SmoothForecast()    Smoothing for nowcast series.
%
% Description:
%   This function permits to smooth nowcast series. Currently, only
%   smoothing using the simple moving (rolling window) average is
%   implemented.
%
% Input:
%   • YHat: table or timetable of the T x N nowcast series;
%   • K: scalar indicating the size of the rolling window including
%   the last data point. For example, if K=2, then the average of
%   the current and previous two data points is computed.
%   
% Output:
%   • YHat: table or timetable of the T x 2N nowcast series, where
%   the corresponding smoothed nowcast series are added.
%   
% Format call: 
%   YHat = SmoothNowcast(YHat,K);

YHatSmooth = YHat;

KWindow = [K,0];
M = size(YHat,2);

for m = 1:M
    
    % Perform smoothing:
    SmoothedSeries = movmean(YHat{:,m},KWindow);
    YHatSmooth{:,m} = SmoothedSeries;
    
    % Rename the nowcast in the new table:
    YHatSmooth.Properties.VariableNames(m) = ...
        YHat.Properties.VariableNames(m) + "_Smooth";
    
end