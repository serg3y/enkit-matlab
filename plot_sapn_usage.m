% Plot SA Power Network electricity usage data.
% 
% Usage:
% 1.Manaully download one or more data files from SA Power network.
% 2.Set fold to be the path to the data folder.

fold = 'serge'; % eg serge andrew

% Load data
T = nem12read(fullfile('sapn', fold));
T.time = timeofday(T.start);
T.date = dateshift(T.start, 'start', 'day');

% Plot
figmode(-1, 'dark', 'handy')

axis_stack(1, 6)
plotheatmap(T, 'date', 'time', 'buy_amount', [], [], @(x)x*1000)
colormap(gca, flipud(rbg));
clim(max(T.buy_amount(:))*[-1 1])
colorbar_small
title(['sapn ' fold])

axis_stack(2, 6)
[i, g] = findgroups(T.date);
y = accumarray(i, T.buy_amount);
plotsteps(gca, g, y, [1.0 0.3 0.3], sprintf('%.1f kwh/day', mean(y)))
ylabel 'buy (kwh)'
legend show location north

axis_stack(3, 6)
plotheatmap(T, 'date', 'time', 'tariff_amount', [], [], @(x)x*1000)
colormap(gca, flipud(rbg));
clim(max(T.tariff_amount(:))*[-1 1]+[-0.1 0.1])
colorbar_small

axis_stack(4, 6)
[i, g] = findgroups(T.date);
y = accumarray(i, T.tariff_amount);
plotsteps(gca, g, y, [1.0 0.3 1.0], sprintf('%.1f kwh/day', mean(y)))
ylabel 'buy (kwh)'
legend show location north

axis_stack(5, 6)
plotheatmap(T, 'date', 'time', 'sell_amount', [], [], @(x)x*1000)
colormap(gca, rbg);
clim(max(T.sell_amount(:))*[-1 1])
colorbar_small

axis_stack(6, 6)
[i, g] = findgroups(T.date);
y = accumarray(i, T.sell_amount);
plotsteps(gca, g, y, [0.3 1.0 0.3], sprintf('%.1f kwh/day', mean(y)))
ylabel 'buy (kwh)'
legend show location north

ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');
linkaxes(ax(cellfun(@isduration, {ax.YTick})), 'y')

figsave(1, ['plots\sapn_usage_' fold '.png'], [1000 1000])

function axis_stack(k, n)
% Create axis
height = 0.9/n;
ax = axes('Position', [0.08  0.96 - height * k  0.84  height]);
box on, axis tight
if k < n
    ax.XRuler.FontSize = 0.01; % Hide X axis
end
end