% Plot SA Power Network electricity usage data.
%
% Usage:
% 1.Manaully download one or more data files from SA Power network.
% 2.Set fold to be the path to the data folder.

fold = 'serge';

% Load data
T = nem12read(fullfile('sapn', fold), [], 30, '+10');

t = amber().getData('prices', {'2024-12-01' '2025-03-20'}, 30);
T = innerjoin(T, t, 'Keys', 'start');
[T.time, T.date] = timeofday(T.start);
T.time.Format = 'hh:mm';
T.buy_value = T.buy_price .* T.buy_amount;
T.sell_value = T.sell_price .* T.sell_amount;
T.tariff_value = T.tariff_price .* T.tariff_amount;

%% Plot
fig(1, 'dark', 'handy')
list = ["buy" "tariff" "sell"];
for k = 1:3
    
    switch list{k}
        case {'buy' 'tariff'}
            c1 = [1.0 0.3 0.3]; c2 = [0.2 0.8 0.2]; cm = flipud(rbg);
        case 'sell'
            c1 = [0.2 0.8 0.2]; c2 = [1.0 0.3 0.3]; cm = rbg;
    end

    axis_stack(1,5,k,3)
    plotheatmap(T.date, T.time, T.([list{k} '_price']))
    colormap(gca, cm);
    clim([-200 200])
    colorbarsml
    ylabel 'Price (cents)'
    title(upper(list{k}))
    
    axis_stack(2,5,k,3)
    plotheatmap(T.date, T.time, T.([list{k} '_amount']))
    colormap(gca, cm);
    clim([-5 5])
    colorbarsml
    ylabel 'Amount (kwh)'

    axis_stack(3,5,k,3)
    [i, g] = findgroups(T.date);
    y = accumarray(i, T.([list{k} '_amount']));
    plotsteps(gca, g, y, c1, sprintf('%.1f kwh/day', mean(y)))
    legend show
    set(gca, 'ylim', get(gca, 'ylim').*[0 1.1])
    ylabel 'Amount (kwh)'

    axis_stack(4,5,k,3)
    plotheatmap(T.date, T.time, T.([list{k} '_value']))
    colormap(gca, cm);
    clim([-300 300])
    colorbarsml
    ylabel 'Value (cents)'

    axis_stack(5,5,k,3)
    [i, g] = findgroups(T.date);
    y = accumarray(i, T.([list{k} '_value']));
    plotsteps(gca, g, y, c1, sprintf('%.2f c/day', mean(y)))
    y = accumarray(i, min(T.([list{k} '_value']),0));
    plotsteps(gca, g, y, c2, sprintf('%.2f c/day', mean(min(y,0))))
    legend show
    ylabel 'Value ($)'

end

ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');
linkaxes(ax(cellfun(@isduration, {ax.YTick})), 'y')

figsave(1, 'plots\amber_cost_prediction.png', [1000 1000])
