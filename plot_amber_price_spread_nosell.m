% PLOT AMBER PRICE SPREAD

% Load data
T = amber().getData('prices', {'2024-01-01' datetime-2}, 30);
[T.time, T.date] = timeofday(T.start);
T.time.Format = 'hh:mm';

% Prep figure
figmode(-1, 'dark', 'handy')
colormap(gcf, flipud(rbg))

%% Plot prices
subplot(4,3,1), title 'Spot Price'
plotheatmap(T, 'time', 'date', 'spot_price')
clim([-100 100])

subplot(4,3,2), title 'General Price'
plotheatmap(T, 'time', 'date', 'buy_price')
clim([-100 100])

subplot(4,3,3), title 'Controlled Load Price'
plotheatmap(T, 'time', 'date', 'tariff_price')
clim([-100 100])
set(colorbar_small().Label, 'String', 'Price (cent)')

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,3,4)
y0 = accumarray(time_ind, T.spot_price, [], @nanmean); %#ok<*NANMEAN>
plotSpread(gca, time_bin, y0, [], [], 'y', 'DisplayName', sprintf('Spot= %.1f c/kWh', mean(y0)))
ylim([-5 80]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

subplot(4,3,5)
y = accumarray(time_ind, T.buy_price, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'DisplayName', sprintf('Spot= %.1f c/kWh', mean(y0)))
ylim([-5 80]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

subplot(4,3,6)
y = accumarray(time_ind, T.tariff_price, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'DisplayName', sprintf('Spot= %.1f c/kWh', mean(y0)))
ylim([-5 80]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

%% Plot spread
T.buy_price_diff = T.buy_price - T.spot_price;
T.tariff_price_diff = T.tariff_price - T.spot_price;
T.sell_price_diff = T.sell_price - T.spot_price;

subplot(4,3,8), title 'General Fees'
plotheatmap(T, 'time', 'date', 'buy_price_diff')
clim([-100 100])

subplot(4,3,9), title 'Controlled Load Fees'
plotheatmap(T, 'time', 'date', 'tariff_price_diff')
clim([-100 100])
set(colorbar_small().Label, 'String', 'Price (c/kWh)')

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,3,11)
y = accumarray(time_ind, T.buy_price_diff, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)))
ylim([-5 40]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

subplot(4,3,12)
y = accumarray(time_ind, T.tariff_price_diff, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)))
ylim([-5 40]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

%% Link axes
ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');
linkaxes(ax(cellfun(@isdatetime, {ax.YTick})), 'y')

% Save figure
file = 'plots\amber_price_spread.png';
figsave(1, file, [1500 1200])
figsave(1, file, [1500 1200])
I = imread(file);
imwrite(I(60:end-100,110:end-80,:),file);
