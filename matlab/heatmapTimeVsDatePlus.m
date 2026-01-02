function ax = heatmapTimeVsDatePlus(T, tvar, vvar, col, ttl, units, pos, f1, f2)
% Display time series data as a heatmap, plus sumary plots using a panel.
%   heatmapTimeVsDatePlus(T, tvar, vvar)
%   heatmapTimeVsDatePlus(T, tvar, vvar, col, ttl, units, pos, f1, f2)
%   ax = heatmapTimeVsDatePlus(__)
%
% Output:
%   ax = axes handles [heatmap, daily sum, tod sum]
%
% Example:
%   time = (datetime('2020-01-01'):minutes(5):datetime('2020-07-01 23:55'))';
%   val = randn(size(time));
%   T = table(time, val);
%   clf, heatmapTimeVsDatePlus(T,'time','val')
%
% See also: heatmapTimeVsDate

arguments
    T table
    tvar (1,1) string = "time"
    vvar (1,1) string = "Var1"
    col double = [1 0 0; 0 1 0] % positive red, negative green
    ttl string = ""
    units string = ""
    pos double = [0 0 1 1]
    f1 = @(x)mean(x, 1, 'omitmissing')
    f2 = @(x)mean(x, 1, 'omitmissing')
end

% Check
if isrow(col)
    col = [col; col];
end
timestep = mode(diff(T.(tvar))); % Infer time step, assume its regular
if isscalar(units)
    if units == "kw"
        units = ["kW" "kWh"]; f1 = @(x)sum(x * hours(timestep), 1, 'omitmissing'); % Convert kW to kWh
    elseif ismember(units, {'c' '$' 'kwh'})
        units = [units units]; f1 = @(x)sum(x, 1, 'omitmissing'); % Sum common quantaties
    else
        units = [units units];
    end
end
if isdatetime(T.(vvar))
    T.missing = isnat(T.(vvar));
    vvar = "missing";
end

% Compute TOD + Date
[T.tod, T.date] = timeofday(T.(tvar));

% Main plot dimensions
L = 0.08; % left
B = 0.10; % bottom
W = 0.75; % width
H = 0.65; % height

% Position of each plot
posMain  = [L    B   W      H     ]; % main plot
posCbar  = [0.03 B   W*0.02 H*0.95]; % color bar
posTop   = [L    B+H W      0.2   ]; % top plot
posSide  = [L+W  B   0.15   H     ]; % side plot

% Scale and move plots
adjust = @(p)[p(1:2).*pos(3:4) + pos(1:2), p(3:4).*pos(3:4)];
posMain = adjust(posMain);
posCbar = adjust(posCbar);
posTop  = adjust(posTop);
posSide = adjust(posSide);

% Main plot
ax = axes('Position', posMain, 'YDir', 'reverse');
plotheatmap(T.date, T.tod, T.(vvar))
if all(T.(vvar) >= 0)
    clim(ax, [0 max(T.(vvar))+eps])
    cmap = makeCmap(col(1,:));
elseif all(T.(vvar) <= 0)
    clim(ax, [max(T.(vvar)) 0])
    cmap = flipud(makeCmap(col(2,:)));
else
    clim(ax, max(abs(T.(vvar))) .* [-1 1])
    cmap = makeCmap(col);
end
colormap(ax, cmap);
h = colorbar(ax, 'Location', 'manual', 'Position', posCbar);
title(h, units(1), 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold')

% Initialise side-plot (top)
ax2 = axes('Position', posTop);
ylabel(ax2, units(2), 'HandleVisibility', 'off')
set(ax2.XAxis, 'TickLength', [0.004 0])
set(ax2.YAxis, 'TickLength', [0.004 0])
title(ax2, ttl, 'FontSize', 12, 'HandleVisibility', 'off')

% Initialise side-plot (right)
ax3 = axes('Position', posSide, 'YDir', 'reverse');
xlabel(ax3, units(1), 'HandleVisibility', 'off')
set(ax3.XAxis, 'TickLength', [0.004 0])
set(ax3.YAxis, 'TickLength', [0.004 0])

% Set main plot appdata
setappdata(ax, 'axTop',  ax2);
setappdata(ax, 'axSide', ax3);
setappdata(ax, 'LastXLim', missing);
setappdata(ax, 'LastYLim', missing);

% Display side-plots
updateSidePlots()

% Use timer to avoid calling updateplot too often
delayTimer = timer('StartDelay', 0.05, 'TimerFcn', @(~,~)updateSidePlots());
addlistener(ax, {'XLim' 'YLim'}, 'PostSet', @(~,~)restartTimer(delayTimer));
    function restartTimer(h)
        try stop(h), end  %#ok<TRYNC> timer may already be running, abort it
        start(h)
    end

% Lock side-plots to have same limits as heatmap
addlistener(ax2, 'XLim', 'PostSet', @(~,~)restartTimer(delayTimer));
addlistener(ax3, 'YLim', 'PostSet', @(~,~)restartTimer(delayTimer));

drawnow
zoom(ax, 'reset')
zoom(ax2, 'reset')
zoom(ax3, 'reset')
linkaxes([ax ax2], 'x')
linkaxes([ax ax3], 'y')


% Update summary plots
    function updateSidePlots
        XLim = ax.XLim;
        YLim = ax.YLim;
        if ~isequal(getappdata(ax, 'LastYLim'), YLim) || ~isequal(getappdata(ax, 'LastXLim'), XLim)

            % Clear old side-plots
            cla(ax2)
            cla(ax3)
            setappdata(ax, 'LastXLim', XLim)
            setappdata(ax, 'LastYLim', YLim)

            % Find selected main plot data
            i = T.tod >= YLim(1) & T.tod + timestep <= YLim(2);
            j = T.date >= XLim(1) & T.date + days(1) <= XLim(2);
            Ti = T( i & j , :); 

            % Top plot
            if numel(unique(T.date(j))) >= 2
                hLine = plotLine(ax2, Ti, 'date', vvar, f1, units(2), 'xy');
                plotArea(ax2, Ti, 'date', vvar, @(x)f1(max(x, 0)), col(1, :), 'xy') % Positive values
                plotArea(ax2, Ti, 'date', vvar, @(x)f1(min(x, 0)), col(2, :), 'xy') % Negative values
                legend(ax2, hLine, 'Location', 'NE', 'FontSize', 12, 'EdgeColor', [.4 .4 .4], 'BackgroundAlpha', 0.5)
                set(ax2.XAxis, 'FontSize', 0.1)
                xlim(ax2, XLim)
            end

            % Right plot
            if numel(unique(T.tod(i))) >= 2
                hLine = plotLine(ax3, Ti, 'tod', vvar, f2 , units(1), 'yx');
                plotArea(ax3, Ti, 'tod', vvar, @(x)f2(max(x, 0)), col(1, :), 'yx')
                plotArea(ax3, Ti, 'tod', vvar, @(x)f2(min(x, 0)), col(2, :), 'yx')
                legend(ax3, hLine, 'Location', 'NE', 'FontSize', 12, 'EdgeColor', [.4 .4 .4], 'BackgroundAlpha', 0.5)
                set(ax3.YAxis, 'FontSize', 0.1)
                ax3.YAxis.TickLabelFormat = ax.YAxis.TickLabelFormat;
                ylim(ax3, YLim)
            end

            drawnow
            ax2.XTick = ax.XTick;
            ax3.YTick = ax.YTick;
        end
    end
end


function h = plotLine(axx, Ti, var, vvar, fun, units, mode)
G = groupsummary(Ti, var, fun, vvar);
h = plotsteps(axx, G.(var), G{:, 3}, 'y', sprintf('avg = %.3g %s', mean(G{:, 3}), units), [], mode, 'LineWidth', 1);
end


function plotArea(axx, Ti, var, vvar, fun, col, mode)
G = groupsummary(Ti, var, fun, vvar);
plotstepspread(axx, G.(var), G{:, 3}, [], col(1, :), [], mode)
end


function cmap = makeCmap(col)
if isrow(col)
    c = [0 0 0; max(col - 0.7, 0); col; 1 1 1];
    cmap = interp1([0 0.1 0.5 1], c, linspace(0, 1, 128));
else
    cmap = [flipud(makeCmap(col(2, :))); makeCmap(col(1, :))];
end
end


% function syncAxes(ax, ax2, mode)
% if mode == "x"
%     rand
%     ax2.XLim  = ax.XLim;
%     ax2.XTick = ax.XTick;
% else
%     ax2.YLim  = ax.YLim;
%     ax2.YTick = ax.YTick;
% end
% end