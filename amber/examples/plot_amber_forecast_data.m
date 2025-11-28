% Show how the forecasted buy and sell prices evolve as the forecasted time
% nears actual time.
%
% Usage:
% 1.Run amber().downloadForecastPeriodicaly to collect several days of data
% 2.Set value_field for price to: 'sell_price' or 'buy_price'
% 3.Set time_field for x-axis to: 'start' or 'query'

%% Copy data
% !xcopy "\\sk\MATLAB\enkit\amber\sa_forecast_30min\raw\*" "D:\MATLAB\enkit\amber\sa_forecast_30min\raw\" /D /E /Y
% !xcopy "\\sk\MATLAB\enkit\amber\sa_forecast_5min\raw\*" "D:\MATLAB\enkit\amber\sa_forecast_5min\raw\" /D /E /Y

%% Inputs
value_field = ["spot_price"] % eg ["general_price" "feedIn_price" "spot_price"];
time_field = 'start'; % 'start' or 'query'

%%
for dt = datetime('2025-06-13') % datetime('today')
    myplot(time_field, value_field, {dt dt+1}, 30)

    t = get(gca, 'XTickLabel');
    t{end} = strrep(t{end}, '00:00', '24:00');
    set(gca, 'XTickLabel', t)
    
    figsave(1, ['plots\forecast\' char(dt,'yyyyMMdd') '.png'], [1000 1000])
end

%%
rez = 30;
while true
    span = {datetime-0.5 datetime+2};
    myplot(time_field, value_field, span, rez)

    t = get(gca, 'XTickLabel');
    t{end} = strrep(t{end}, '00:00', '24:00');
    set(gca, 'XTickLabel', t)

    xline(datetime('now','TimeZone','+10:00'),'w:','Now')
    figsave(1, ['G:\My Drive\Share\enkit\amber\forecast_current_' num2str(rez) 'min.png'], [1000 1000])

    pause(mod(300 - mod(seconds(datetime - dateshift(datetime,'start','hour')), 300), 300))
end



function myplot(time_field, value_field, span, rez)

T = amber().readForecastData(span, rez, 24);

% Progress
fprintf(' %s', char(span{1}, 'yyyy-MM-dd'))
if isempty(T)
    fprintf(' (No data)\n')
    return
end

% Limit forecast period
T(T.forecast>16/24,:) = [];
if isempty(T)
    fprintf(' (No data)\n')
    return
else
    fprintf(' (n=%g)\n', size(T, 1))
end

% Calc median for each row with same start time
T = groupsummary(T, {time_field 'forecast'}, @(x)median(x), value_field);
T = renamevars(T, T.Properties.VariableNames, strrep(T.Properties.VariableNames, 'fun1_', ''));

%% Plot
figmode(1, 'dark', 'handy')
margins = [0.1 0.04 0.1 0.06];

for p = 1:numel(value_field)
    % Calculate how much has forecast changed from actual
    T.value = T.(value_field{p});
    [~, j, i] = unique(T.(time_field), 'stable');
    T.change = T.value - T.value(j(i));

    %% 1. Values (heatmap)
    axis_stack(1, 2, p, numel(value_field), margins, [0 0])
    title(strrep(value_field{p}, '_', ' '))
    [h, A, x, y] = plotheatmap(T.(time_field), T.forecast, T.value);
    xline(unique(dateshift(x, 'end', 'day')), 'w:')
    yline(duration(0, 0, 0), 'w')
    colormap(gca, cold2hot)
    clim([-200 200])
    if p == 1
        ylabel 'Forecast period'
    end
    if p == numel(value_field)
        colorbarsml 'Price (c)'
    end

    %% 2. Values (line)
    axis_stack(2, 2, p, numel(value_field), margins, [0 0.01])
    col = flipud(hot(numel(y)));
    for k = numel(y):-1:1
        h = plotsteps(gca, x([1:end end]), [A(k,:) nan], [col(k,:) 0.3], '', NaN);
    end
    set(h, 'LineWidth', 1.5, 'Color', [col(k,:) 1])
    yline(0, 'w')
    colormap(gca, col)
    if p == 1
        ylabel 'Price (c)'
    end
    if p == numel(value_field)
        h = colorbarsml('Forecast period');
        set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'h')))
    end
    ylim(ylim + diff(ylim)*[-0.05 0.05])

    continue
    %% 3. Change (heatmap)
    axis_stack(3, 4, p, numel(value_field), margins)
    [~, A, x, y] = plotheatmap(T.(time_field), T.forecast, T.change);
    colormap(gca, cold2hot),
    xline(unique(dateshift(x, 'end', 'day')), 'w:')
    yline(duration(0, 0, 0), 'w')
    clim([-200 200])
    if p == 1
        ylabel 'Forecast period'
    end
    if p == numel(value_field)
        colorbarsml 'Price change (c)'
    end

    %% 4. Change (line)
    axis_stack(4, 4, p, numel(value_field), margins)
    col = flipud(hot(numel(y)));
    for k = numel(y):-1:1
        h = plotsteps(gca, x([1:end end]), [A(k,:) nan], [col(k,:) 0.3], '', NaN);
    end
    set(h, 'LineWidth', 1.5, 'Color', [col(k,:) 1])
    xlabel(['Time (' T.(time_field).TimeZone ')'])
    colormap(gca, col)
    if p == 1
        ylabel 'Price change (c)'
    end
    if p == numel(value_field)
        h = colorbarsml('Forecast period');
        set(h, 'Ticks', (0:6:24)/24, 'TickLabels', string(duration(0:6:24, 0, 0, 'Format', 'h')))
    end
    ylim(ylim + diff(ylim)*[-0.05 0.05])
end

% Finish
linkallaxes
end