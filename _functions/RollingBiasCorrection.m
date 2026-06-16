function [YHatAdj,YHatBias] = RollingBiasCorrection(YHat,Y,R,EffectiveTime)
% RollingBiasCorrection()   Moving window bias correction.
%
% Description:
%   This function corrects the nowcast series adding up the average bias
%   over the last nowcasting window.
%
% Input:
%   • YHat: table or timetable of the N nowcast series;
%   • Y: table or timetable of the (single) observed target variable;
%   • R: size of the moving window of R points;
% 
% (Optional input):
%   • EffectiveTime: integer time indexes for the periods where the bias
%   must be added. For example, the vectors 1:T and [1:fix(T/2),T].
%   
% Output:
%   • YHatAdj: table or timetable of the N bias-corrected nowcasts;
%   • YHatBias: table or timetable of the N bias series.
%   
% Format call: 
%   [YHatAdj,YHatBias] = RollingBiasCorrection(YHat,Y,R,EffectiveTime);

T = size(YHat,1);

if nargin < 4
    EffectiveTime = 2:T;
end

YHatAdj = YHat;
YHatBias = YHat{:,:}-Y{:,:};

tStart = find(sum(YHatBias,2,"omitmissing")~=0,1,"first");

for t = tStart:T
    
    % Replace missing nowcasts:
    MissingIndex = isnan(YHatBias(t,:));
    YHatBias(t,MissingIndex) = median(YHatBias(t,:),'omitmissing');
    
    % Copy intermediate months:
    if all(isnan(YHatBias(t,:)))
        YHatBias(t,:) = YHatBias(t-1,:);
    end
end

YHatBias = movmean(YHatBias,[R-1,0],1);

tStart = find(sum(YHatBias,2,"omitmissing")~=0,1,"first");
EffectiveTime(EffectiveTime<tStart) = [];

for t = EffectiveTime
    
    % Adjust by the moving mean bias estimate:
    YHatAdj{t,:} = YHat{t,:}-YHatBias(t,:);

end