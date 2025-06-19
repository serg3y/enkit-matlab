% Plot SA Power Network electricity usage data.
%
% Usage:
% 1.Manually download data file(s) from SA Power network, see \sapn\README
% 2.Set fold to be the path to the data folder.

fold = 'serge';
rez = 30;

% Load data
T = nem12read(fullfile('sapn', fold), [], rez, '+10');

t = amber().getData('prices', {'2024-12-01' '2025-06-18'}, rez);
T = innerjoin(T, t, 'Keys', 'start');
[T.time, T.date] = timeofday2(T.start);
T.time.Format = 'hh:mm';
T.buy_cost = (T.buy_price .* T.buy_amount)/100;
T.sell_cost = (T.sell_price .* T.sell_amount)/100;

%% Plot
fig(1, 'dark', 'handy')
list = ["buy" "sell"];

for k = 1:numel(list)
    
    switch list{k}
        case {'buy' 'tariff'}
            c1 = [1.0 0.3 0.3]; c2 = [0.2 0.8 0.2]; cm = flipud(rbg);
        case 'sell'
            c1 = [0.2 0.8 0.2]; c2 = [1.0 0.3 0.3]; cm = rbg;
    end

    % Daily Weighted Average Price
    axis_stack(1,6,k,2,[],[0 0.01])
    [i, g] = findgroups(T.date);
    y1 = accumarray(i, T.([list{k} '_cost']));
    y2 = accumarray(i, T.([list{k} '_amount']));
    y = y1./y2*100; % Average daily price
    plotsteps(gca, g, y, c1, sprintf('avg = %.2f c/kwh', sum(y1)/sum(y2)*100))
    plotspread2(gca, g, y, [], c1, [], 'HandleVisibility', 'off')
    y1 = accumarray(i, min(T.([list{k} '_cost']), 0));
    y2 = accumarray(i, T.([list{k} '_amount']));
    y = y1./y2*100; % Average daily price
    plotsteps(gca, g, y, c2, sprintf('avg = %.2f c/kwh', sum(y1)/sum(y2)*100))
    legend show location best
    ylabel({'Price' 'c/kwh'})
    title(upper(list{k}))

    axis_stack(2,6,k,2,[],[0 0.01])
    plotheatmap(T.date, T.time, T.([list{k} '_price']))
    colormap(gca, cm);
    clim([-200 200])
    colorbarsml c/kWh

    axis_stack(3,6,k,2,[],[0 0.01])
    [i, g] = findgroups(T.date);
    y = accumarray(i, T.([list{k} '_amount']));
    plotsteps(gca, g, y, c1, sprintf('avg = %.1f kwh/day', mean(y)))
    plotspread2(gca, g, y, [], c1, [], 'HandleVisibility', 'off')
    legend show location best
    set(gca, 'ylim', get(gca, 'ylim').*[0 1.1])
    ylabel({'Usage' 'kWh/day'})

    axis_stack(4,6,k,2,[],[0 0.01])
    plotheatmap(T.date, T.time, T.([list{k} '_amount']))
    colormap(gca, cm);
    clim([-5 5])
    colorbarsml("kWh/" + rez + "min")

    axis_stack(5,6,k,2,[],[0 0.01])
    [i, g] = findgroups(T.date);
    y = accumarray(i, T.([list{k} '_cost']));
    plotsteps(gca, g, y, c1, sprintf('avg = %.2f $/day', mean(y)))
    plotspread2(gca, g, y, [], c1, [], 'HandleVisibility', 'off')
    y = accumarray(i, min(T.([list{k} '_cost']), 0));
    plotsteps(gca, g, y, c2, sprintf('avg = %.2f $/day', mean(min(y, 0))))
    legend show location best
    ylabel({'Value' '$/day'})

    axis_stack(6,6,k,2,[],[0 0.01])
    plotheatmap(T.date, T.time, T.([list{k} '_cost']))
    colormap(gca, cm);
    clim([-3 3])
    colorbarsml("$/" + rez + "min")

end

ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');
linkaxes(ax(cellfun(@isduration, {ax.YTick})), 'y')

figsave(1, 'plots\amber_cost.png', [1600 900])
