function shadePeriods(ax, periods, varargin)
% SHADEPERIODS Shades regions on a plot defined by start–end datetime pairs.
%
%   shadePeriods(gca, periods)
%   periods is an N×2 datetime (or numeric) matrix: [start end]
%
%   Optional name–value pairs are passed directly to PATCH, e.g.:
%       'FaceAlpha', 0.3, 'FaceColor', [0.8 0.8 0.8]

    if nargin < 1 || isempty(ax)
        ax = gca;
    end

    yl = ax.YLim;    % full height of the plot

    for k = 1:size(periods,1)
        patch(ax, ...
              [periods(k,1) periods(k,2) periods(k,2) periods(k,1)], ...
              [yl(1) yl(1) yl(2) yl(2)], ...
              [0.75 0.75 0.75], ...      % default grey color
              'FaceAlpha', 0.3, ...
              'EdgeColor','none', ...
              varargin{:});
    end

    % Ensure bars/lines are drawn on top of patches
    uistack(findobj(ax,'Type','patch','-not','FaceAlpha',0.3),'bottom');
end