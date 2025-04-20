% Show how the forecast buy/sell price changes as the forecast time
% approaches actual time.
% 
% Usage:
% 1.Run amber().downloadForecastPeriodicaly to collect several days of data
% 2.Set v_field for price to: 'sell_price' or 'buy_price'
% 3.Set x_field for x-axis to: 'start' or 'query'

%
value_field = 'buy_price'; % 'buy_price' or 'sell_price'

% Load data
time_field = 'start'; % 'start' or 'query'
T = amber().getForecastData({'2025-04-03' '2025-04-10'}, 30, 24);
% T = amber().getForecastData({'2025-04-03' '2025-04-10'}, 5, 0.51); % 5 min data
T = table(T.(time_field), T.forecast, T.(value_field), 'VariableNames', {'time' 'forecast' 'value'});
T = groupsummary(T, {'time' 'forecast'}, @(x)median(x, 'omitmissing'), 'value');
T.value = T.fun1_value;
[~, j, i] = unique(T.time, 'stable');
T.change = T.value - T.value(j(i));

% Plot
figmode(-1, 'dark', 'handy')

% Values (heatmap)
a1 = subplot(411);
title(strrep(value_field, '_', ' '))
plotheatmap(T, 'time', 'forecast', 'value');
xline(unique(dateshift(T.time, 'end', 'day')), 'w')
yline(duration(0, 0, 0), 'w')
ylabel 'Forecast period'
colormap(gca, jet)
set(colorbar().Label, 'String', 'Price (cent)')
clim([-20 60])

% Values (line)
a2 = subplot(412);
[i, j] = findgroups(T.forecast);
col = [1 1 1; flipud(parula(max(i)))];
for k = max(i):-1:1
    plotsteps(gca, T.time(i==k), T.value(i==k), col(k,:), '')
end
ylabel 'Price (cent)'
yline(0, 'w')
colormap(gca, col)
h = colorbar;
set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'hh:mm')))
set(h.Label, 'String', 'Forecast period')

% Change (heatmap)
a3 = subplot(413);
title 'price change'
plotheatmap(T, 'time', 'forecast', 'change');
colormap(gca, rbg), 
xline(unique(dateshift(T.time, 'end', 'day')), 'w')
yline(duration(0, 0, 0), 'w')
ylabel('Forecast period')
set(colorbar().Label, 'String', 'Price (cent)')
clim([-50 50])

% Change (line)
a4 = subplot(414);
i = findgroups(T.forecast);
col = [1 1 1; flipud(parula(max(i)))];
for k = max(i):-1:1
    plotsteps(gca, T.time(i==k), T.change(i==k), col(k,:), '')
end
xlabel(['Time (' T.time.TimeZone ')'])
ylabel 'Price (cent)'
yline(0, 'w')
colormap(gca, col)
h = colorbar;
set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'hh:mm')))
set(h.Label, 'String', 'Forecast period')

% Finalise
linkaxes([a1 a2 a3], 'x')
linkaxes([a1 a3], 'y')
figsave(1, ['plots\amber_forecast_' value_field '.png'], [1000 1000])