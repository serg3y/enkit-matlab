% PLOT AMBER ENERGY FORECAST DATA
% Visualizes how energy buy/sell forecast prices change as the forecast
% time approaches actual time.
% 
% Setup:
% - Forecast prices must first be logged, for a few days or longer, using
%   amber().downloadForecastPeriodicaly 
%
% Dependencies:
% - amber().getForecastData, plotmode, plotheatmap, figsave
%
% Configuration:
% - Set x_field for x-axis to: 'start' or 'query'
% - Set v_field for price to: 'sell_price' or 'buy_price'

%%
value_field = 'sell_price'; % 'buy_price' or 'sell_price'
time_field = 'start'; % 'start' or 'query'

% Load data
T = amber().getForecastData({'2025-04-03' '2025-04-10'}, 30, 24);
% T = amber().getForecastData({'2025-04-03' '2025-04-10'}, 5, 0.51); % 5 min data

% Condition data
T = table(T.(time_field), T.forecast, T.(value_field), 'VariableNames', {'time' 'forecast' 'value'});
T = groupsummary(T, {'time' 'forecast'}, @(x)median(x, 'omitmissing'), 'value');
T.value = T.('fun1_value');

% Compute price changes
[~, j, i] = unique(T.time, 'stable');
T.change = T.value - T.value(j(i));

% Prepare plot
plotmode dark handy
figure(1), clf

%% Values (heatmap)
a1 = subplot(411);
title(strrep(value_field, '_', ' '))
plotheatmap(T, 'time', 'forecast', 'value');
xline(unique(dateshift(T.time, 'end', 'day')), 'w')
yline(duration(0, 0, 0), 'w')
ylabel 'Forecast period'
colormap(gca, jet)
set(colorbar().Label, 'String', 'Price (cent)')
clim([-20 60])

%% Values (line)
a2 = subplot(412);
[i, j] = findgroups(T.forecast);
col = [1 1 1; flipud(parula(max(i)))];
for k = max(i):-1:1
    plotLine(gca, T.time(i==k), T.value(i==k), col(k,:))
end
ylabel 'Price (cent)'
yline(0, 'w')
colormap(gca, col)
h = colorbar;
set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'hh:mm')))
set(h.Label, 'String', 'Forecast period')

%% Change (heatmap)
a3 = subplot(413);
title 'price change'
plotheatmap(T, 'time', 'forecast', 'change');
colormap(gca, rbg), 
xline(unique(dateshift(T.time, 'end', 'day')), 'w')
yline(duration(0, 0, 0), 'w')
ylabel('Forecast period')
set(colorbar().Label, 'String', 'Price (cent)')
clim([-50 50])

%% Change (line)
a4 = subplot(414);
i = findgroups(T.forecast);
col = [1 1 1; flipud(parula(max(i)))];
for k = max(i):-1:1
    plotLine(gca, T.time(i==k), T.change(i==k), col(k,:))
end
xlabel(['Time (' T.time.TimeZone ')'])
ylabel 'Price (cent)'
yline(0, 'w')
colormap(gca, col)
h = colorbar;
set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'hh:mm')))
set(h.Label, 'String', 'Forecast period')

%% Finalise
linkaxes([a1 a2 a3], 'x')
linkaxes([a1 a3], 'y')
figsave(1, ['plots\Amber_' value_field '_forecast.png'], [1000 1000])