% Plot SA Power Network (SAPN) electricity usage data.
%
% Instructions:
% 1. Download usage data in NEM12 format.
% 2. Set 'folder' to be the path to the data folder.
% 3. Change 'output' folder if required.

example = 'Andrew';   folder = 'D:\MATLAB\enkit\sapn\data\Andrew';
% example = 'Jason SS'; folder = 'D:\MATLAB\enkit\sapn\data\Jason';
% example = 'Jenka';    folder = 'D:\MATLAB\enkit\sapn\data\Jenka';
% example = 'Serge';    folder = 'D:\MATLAB\enkit\sapn\data\Serge';
switch example
    case 'Andrew';          span = []; % 731 days

    case 'Jason';           span = []; % 424 days
    case 'Jason No PV';     span = ["2024-09-19" "2025-02-22"]; % 156 days
    case 'Jason low usage'; span = ["2025-03-13" "2025-05-16"]; %  64 days
    case 'Jason no SS';     span = ["2025-05-17" "2025-08-30"]; % 105 days
    case 'Jason SS';        span = ["2025-08-31" "2025-11-16"]; %  77 days

    case 'Jenka';           span = []; % 729 days

    case 'Serge';           span = [];
end
output = fullfile(folder, example); % output base file name

%% Load data
[T, header] = sapn().read(folder, span);
T.buy_kwh = fillmissing(T.buy_kwh, 'constant', 0);
T.sell_kwh = fillmissing(T.sell_kwh, 'constant', 0);

T.buy_kw = T.buy_kwh*60/header.Interval; % kW
T.sell_kw = T.sell_kwh*60/header.Interval;
T.total_kw = T.buy_kw - T.sell_kw;
controlled_load = hascolumn(T, 'buy2_kwh') && sum(T.buy2_kwh)>0;
if controlled_load
    T.buy2_kwh = fillmissing(T.buy2_kwh, 'constant', 0);
    T.buy2_kw = T.buy2_kwh*60/header.Interval;
    T.total_kw = T.total_kw + T.buy2_kw;
end
lbl2 = sprintf(' (%g days)', round(days(range(T.time))));

%% Plot
figmode(-1, 'dark', 'handy')

% Labels
if controlled_load
    labels = ["Buy" "Sell" "CL" "Total"];
else
    labels = ["Buy" "Sell" "Total"];
end

n = numel(labels);
for k = 1:numel(labels)

    % Plot settings
    switch labels(k)
        case "Buy",  prop = "buy_kw";   col = [1.0 0.3 0.3];
        case "Sell", prop = "sell_kw";  col = [0.0 0.8 0.0];
        case "CL",   prop = "buy2_kw";  col = [1.0 0.1 1.0];
        case "Total",prop = "total_kw"; col = [1.0 0.2 0.2;0.0 0.9 0.0];
    end

    % Axes position
    pos = [0 1-1/n*k 1 1/n]; % L B W H

    % Plot
    step = hours(mode(diff(T.time))); % time step in hours
    f1 = @(x)sum(x*step, 1, 'omitmissing'); % kW > kWh
    f2 = @(x)mean(x, 1, 'omitmissing');
    ax = plotheatmapsum(T, 'time', prop, col, labels(k), {'kW' 'kWh'}, pos, f1, f2);

end

linkallaxes
xlim(ax(1), datetime([min(T.time) max(T.time)], 'TimeZone', ax(1).XLim.TimeZone))

file = fullfile(folder, "SAPN usage - " + example + " - " + strjoin(labels) + ".png");
figsave(1, file, [1920 1080])


function ax = plotheatmapsum_(T, time, val, col, lbl, units, pos, f1, f2)
% Display time series data in a table as a tod vs date heat map, with
% supporting 'sum plots'.
%   ax = plotheatmapplus(T, time, val, col, lbl, inits, pos, f1, f2)

if nargin<4 || isempty(col), col = [1 0 0]; end
if nargin<5 || isempty(lbl), lbl = ''; end
if nargin<6 || isempty(units), units = ["" ""]; end
if nargin<7 || isempty(pos), pos = [0 0 1 1]; end
if nargin<8 || isempty(f1), f1 = @(x)sum(x, 1, 'omitmissing'); end
if nargin<9 || isempty(f2), f2 = @(x)sum(x, 1, 'omitmissing'); end

% Checks
[T.tod, T.date] = timeofday(T.(time));
units = string(units);
if isscalar(units)
    units = [units units];
end


left = pos(1);
bottom = pos(2);
width = pos(3);
height= pos(4);

% Main heatmap
ax(1) = axes('Position', [left+0.08 bottom+height*0.13 width*0.8 height*0.6]); % L B W H
plotheatmap(T.date, T.tod, T.(val))
colormap(gca, gradient(col));
if size(col, 1)==1
    clim([0 max(T.(val))])
else
    clim(max(abs(T.(val))).*[-1 1])
end
h = colorbar('Position', [0.04 bottom+height*0.13 width*0.01 height*0.6]);
h.Label.String = units(1);

% Daily plot (top)
G = groupsummary(T, 'date', f1, val);
y = G{:,3};
ax(2) = axes('Position', [left+0.08 bottom+height*0.73 width*0.8 height*0.2], 'XColor', 'none');
if any(y<0)
    plotstepspread(gca, G.date, max(y,0), [], col(1,:), sprintf('avg=%.2f', mean(max(y,0))))
    plotstepspread(gca, G.date, min(y,0), [], col(2,:), sprintf('avg=%.2f', mean(min(y,0))))
else
    plotstepspread(gca, G.date,        y, [], col(1,:), sprintf('avg=%.2f', mean(y)))
end
legend show location best
ylabel(units(2))
title(lbl)

% Time of day (right)
G = groupsummary(T, 'tod', f2, val);
y = G{:,3};
ax(3) = axes('Position',[left+width*0.8+0.08 bottom+height*0.13 width*0.1 height*0.6], 'YColor', 'none');
if any(y<0)
    plotstepspread(gca, G.tod, max(y,0), [], col(1,:), sprintf('avg=%.3f', mean(max(y,0))), 'yx')
    plotstepspread(gca, G.tod, min(y,0), [], col(2,:), sprintf('avg=%.3f', mean(min(y,0))), 'yx')
else
    plotstepspread(gca, G.tod,        y, [], col(1,:), sprintf('avg=%.3f', mean(y)), 'yx'); % kW
end
ylim(duration([0 24], 0, 0))
legend show location best
xlabel(units(1))
end

function cmap = gradient(col, n)
if nargin<2 || isempty(n), n = 265; end

if size(col,1) == 1
    c = [0 0 0; max(col-0.7, 0); col; 1 1 1];
    cmap = interp1([0 0.1 0.5 1], c, linspace(0,1,n));
else
    cmap = [flipud(gradient(col(2,:), n/2)); gradient(col(1,:), n/2)];
end
end
