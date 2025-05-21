% Show how the forecast buy/sell price changes as the forecast time
% approaches actual time.
%
% Usage:
% 1.Run amber().downloadForecastPeriodicaly to collect several days of data
% 2.Set v_field for price to: 'sell_price' or 'buy_price'
% 3.Set x_field for x-axis to: 'start' or 'query'

%% Copy data
% !xcopy "\\sk\MATLAB\enkit\amber\sa_forecast_30min\raw\*" "D:\MATLAB\enkit\amber\sa_forecast_30min\raw\" /D /E /Y
% !xcopy "\\sk\MATLAB\enkit\amber\sa_forecast_5min\raw\*" "D:\MATLAB\enkit\amber\sa_forecast_5min\raw\" /D /E /Y

%% Load data
value_field = ["spot_price" "general_price" "feedIn_price"] % ["general_price" "feedIn_price" "spot_price"];
time_field = 'start'; % 'start' or 'query'
T = amber().readForecastData({'2025-04-14' '2025-05-14'}, 30, 24);
% T = amber().readForecastData({'2025-04-03' '2025-04-10'}, 5, 0.51); % 5 min data

% Limit forecast period
T(T.forecast>16/24,:) = [];

% Calc median
T = groupsummary(T, {time_field 'forecast'}, @(x)median(x, 'omitmissing'), value_field);
T = renamevars(T, T.Properties.VariableNames, strrep(T.Properties.VariableNames, 'fun1_', ''));

%% Plot
fig(1, 'dark', 'handy')

for p = 1:numel(value_field)
    % Calculate how much has forecast changed from actual
    T.value = T.(value_field{p});
    [~, j, i] = unique(T.(time_field), 'stable');
    T.change = T.value - T.value(j(i));
    
    %% 1. Values (heatmap)
    axis_stack(1, 4, p, numel(value_field))
    title(strrep(value_field{p}, '_', ' '))
    [h, A, x, y] = plotheatmap(T.(time_field), T.forecast, T.value);
    xline(unique(dateshift(x, 'end', 'day')), 'w:')
    yline(duration(0, 0, 0), 'w')
    colormap(gca, cold2hot)
    clim([-200 200])
    if p == 1
        ylabel 'Forecast period'
    elseif p == numel(value_field)
        colorbarsml 'Price (c)'
    end

    %% 2. Values (line)
    axis_stack(2, 4, p, numel(value_field))
    col = flipud(hot(numel(y)));
    for k = numel(y):-1:1
        h = plotsteps(gca, x([1:end end]), [A(k,:) nan], [col(k,:) 0.3], '', NaN);
    end
    set(h, 'LineWidth', 1.5, 'Color', [col(k,:) 1])
    yline(0, 'w')
    colormap(gca, col)
    if p == 1
        ylabel 'Price (c)'
    elseif p == numel(value_field)
        h = colorbarsml('Forecast period');
        set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'h')))
    end

    %% 3. Change (heatmap)
    axis_stack(3, 4, p, numel(value_field))
    [~, A, x, y] = plotheatmap(T.(time_field), T.forecast, T.change);
    colormap(gca, cold2hot),
    xline(unique(dateshift(x, 'end', 'day')), 'w:')
    yline(duration(0, 0, 0), 'w')
    clim([-200 200])
    if p == 1
        ylabel 'Forecast period'
    elseif p == numel(value_field)
        colorbarsml 'Price change (c)'
    end

    %% 4. Change (line)
    axis_stack(4, 4, p, numel(value_field))
    i = findgroups(T.forecast);
    col = flipud(hot(max(i)));
    for k = numel(y):-1:1
        h = plotsteps(gca, x([1:end end]), [A(k,:) nan], [col(k,:) 0.3], '', NaN);
    end
    set(h, 'LineWidth', 1.5, 'Color', [col(k,:) 1])
    xlabel(['Time (' T.(time_field).TimeZone ')'])
    colormap(gca, col)
    if p == 1
        ylabel 'Price change (c)'
    elseif p == numel(value_field)
        h = colorbarsml('Forecast period');
        set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'h')))
    end
end

%% Finalise
linkaxes_all
figsave(1, 'plots\amber_forecast.png', [1000 1000])