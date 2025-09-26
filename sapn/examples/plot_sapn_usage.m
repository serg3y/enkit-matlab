% Plot SA Power Network electricity usage data.
% 
% Usage:
% 1.Manually download one or more data files from SA Power network.
% 2.Set fold to be the path to the data folder.

archive = 'D:\MATLAB\enkit\sapn\data';
folder = 'Andrew'; plots = 6;
% folder = 'Serge';  plots = 4;
% folder = 'Jenka';  plots = 4;

% Load data
T = nem12read(fullfile(archive, folder, '*.csv'));
[T.time, T.date] = timeofday2(T.start);

%% Plot
G = groupsummary(T, 'time', @mean, {'buy_kwh' 'sell_kwh'});
x = G.time;
y1 = G.fun1_buy_kwh;
y2 = G.fun1_sell_kwh;

fig(1, 'dark', 'handy')
subplot(2,1,1)
plotspread2(gca, x, y1, [], [1.0 0.3 0.3], sprintf('Buy (avg. = %.1f kWh/day)', sum(y1)));
title(folder)
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Buy (kWh)'
legend show location NW

subplot(2,1,2)
plotspread2(gca, x, y2, [], [0.3 1.0 0.3], sprintf('Sell (avg. = %.1f kWh/day)', sum(y2)));
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Sell (kWh)'
xlabel 'Time (+10h)'
legend show location NW

linkallaxes
figsave(1, fullfile(archive, folder, [folder '_tod_usage.png']), [1000 1000])

%% Plot
fig(2, 'dark', 'handy')
axis_stack(1, plots)
plotheatmap(T.date, T.time, T.buy_kwh, [], [], @(x)x*1000)
colormap(gca, flipud(rbg));
clim(max(T.buy_kwh(:))*[-1 1])
colorbarsml
title(folder)

axis_stack(2, plots)
[i, G] = findgroups(T.date);
y = accumarray(i, T.buy_kwh);
plotspread2(gca, G, y, [], [1.0 0.3 0.3], sprintf('Buy (avg. = %.1f kWh/day)', mean(y)))
ylabel 'Buy (kWh)'
legend show location north

axis_stack(3, plots)
plotheatmap(T.date, T.time, T.sell_kwh, [], [], @(x)x*1000)
colormap(gca, rbg);
clim(max(T.sell_kwh(:))*[-1 1])
colorbarsml

axis_stack(4, plots)
[i, G] = findgroups(T.date);
y = accumarray(i, T.sell_kwh);
plotspread2(gca, G, y, [], [0.3 1.0 0.3], sprintf('Sell (avg. = %.1f kWh/day)', mean(y)))
ylabel 'Sell (kWh)'
legend show location north

if plots>4
    axis_stack(5, 6)
    plotheatmap(T.date, T.time, T.buy2_kwh, [], [], @(x)x*1000)
    colormap(gca, flipud(rbg));
    clim(max(T.buy2_kwh(:))*[-1 1]+[-0.1 0.1])
    colorbarsml

    axis_stack(6, 6)
    [i, G] = findgroups(T.date);
    y = accumarray(i, T.buy2_kwh);
    plotspread2(gca, G, y, [], [1.0 0.3 1.0], sprintf('avg. = %.1f kWh/day', mean(y)))
    ylabel 'Buy (kWh)'
    legend show location north
end

linkallaxes
figsave(2, fullfile(archive, folder, [folder '_usage.png']), [1000 1000])
