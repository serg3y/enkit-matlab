% PLOT AMBER PRICE SPREAD

% Load data
T = amber().getData('prices', {'2024-01-01' datetime-2}, 30);
[T.time, T.date] = timeofday(T.start);
T.time.Format = 'hh:mm';

% Prep figure
figmode(-1, 'dark', 'handy')
colormap(gcf, flipud(rbg))

%% Plot prices
subplot(4,4,1), title 'Spot Price'
plotheatmap(T, 'time', 'date', 'spot_price')
clim([-100 100])

subplot(4,4,2), title 'Buy Price'
plotheatmap(T, 'time', 'date', 'buy_price')
clim([-100 100])

subplot(4,4,3), title 'Controlled Load Price'
plotheatmap(T, 'time', 'date', 'tariff_price')
clim([-100 100])

subplot(4,4,4), title 'Sell Price'
plotheatmap(T, 'time', 'date', 'sell_price')
clim([-100 100])
set(colorbar_small().Label, 'String', 'Price (cent)')

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,4,5)
y0 = accumarray(time_ind, T.spot_price, [], @nanmean); %#ok<*NANMEAN>
plotSpread(gca, time_bin, y0, [], [], 'y', 'DisplayName', sprintf('%.1fc', mean(y0)))
ylim([-5 60]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'
legend show location north

subplot(4,4,6)
y = accumarray(time_ind, T.buy_price, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('%.1fc', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'HandleVisibility', 'off')
ylim([-5 60]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'
legend show location north

subplot(4,4,7)
y = accumarray(time_ind, T.tariff_price, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('%.1fc', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'HandleVisibility', 'off')
ylim([-5 60]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'
legend show location north

subplot(4,4,8)
y = accumarray(time_ind, T.sell_price, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('%.1fc', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'HandleVisibility', 'off')
ylim([-5 60]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'
legend show location north


%% Plot spread
T.buy_price_diff = T.buy_price - T.spot_price;
T.tariff_price_diff = T.tariff_price - T.spot_price;
T.sell_price_diff = T.sell_price - T.spot_price;

subplot(4,4,10), title 'Buy Fee'
plotheatmap(T, 'time', 'date', 'buy_price_diff')
clim([-100 100])

subplot(4,4,11), title 'Controlled Load Fee'
plotheatmap(T, 'time', 'date', 'tariff_price_diff')
clim([-100 100])

subplot(4,4,12), title 'Sell Fee'
plotheatmap(T, 'time', 'date', 'sell_price_diff')
clim([-100 100])
set(colorbar_small().Label, 'String', 'Price (cent)')

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,4,14)
y = accumarray(time_ind, T.buy_price_diff, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r')
ylim([-5 30]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'

subplot(4,4,15)
y = accumarray(time_ind, T.tariff_price_diff, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r')
ylim([-5 30]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'

subplot(4,4,16)
y = accumarray(time_ind, T.sell_price_diff, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r')
ylim([-5 30]), xlim(duration([0 24], 0, 0))
ylabel 'Price (cents)'

%% Link axes
ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');
linkaxes(ax(cellfun(@isdatetime, {ax.YTick})), 'y')

% Save figure
figsave(1, 'plots\amber_price_spread.png', [1900 1200])
figsave(1, 'plots\amber_price_spread.png', [1900 1200])
