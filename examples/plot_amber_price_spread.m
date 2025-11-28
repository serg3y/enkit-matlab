% PLOT AMBER PRICE SPREAD

% 1.2 x ( spot + tariff + 4.55c)
% RTOU tariff: 18.79c (peak), 7.56c (off peak), 3.81c (day)
% 4.55 is hedging (1.5c) + carbon offset (0.22c) + market charges (0.47c) + certificates (2.36c)
% Each July 4.55c and tariff will change.

% T = amber().getPrices(span, rez);
% T.start.TimeZone = timezone;
% 
% figure(3),clf
% T.RTOU2 = (T.spot_price + tariffs(T.start, 'RTOU2'))*1.1105195 + 4.760668;
% plot(T.buy_price, T.buy_price-T.RTOU2,'.')
% R = corrcoef(T.RTOU2, T.buy_price);
% R(1, 2)
% polyfit(T.RTOU2, T.buy_price, 1)
% sqrt(mean((T.RTOU2- T.buy_price).^2))
% 
% figure(4), clf
% T.RTOU = (T.spot_price + tariffs(T.start, 'RTOU'))*1.2 + 5.551;
% plot(T.buy_price, T.buy_price-T.RTOU,'.')
% R = corrcoef(T.RTOU, T.buy_price);
% R(1, 2)
% polyfit(T.RTOU, T.buy_price, 1)
% sqrt(mean((T.RTOU - T.buy_price).^2))
% 
% return

%%

rez = 30;
span = {'2025-01-01' '2025-02-01'};
value = 'buy_price'; figmode(1, 'dark', 'handy')
% value = 'RTOU2'; figmode(2, 'dark', 'handy')
timezone = 'Australia/Adelaide';

%% Load data
T = amber().getPrices(span, rez);
T.start.TimeZone = timezone;

T.RTOU2 = (T.spot_price + tariffs(T.start, 'RTOU2'))*1.1105195 + 4.760668;

T.value = T.(value);

[T.time, T.date] = timeofdaylocal(T.start);

% Prep figure
colormap(gcf, flipud(rbg))

%% Plot prices
subplot(4,2,1), title 'spot_price'
plotheatmap(T.time, T.date, T.spot_price)
clim([-100 100])

subplot(4,2,2), title(value)
plotheatmap(T.time, T.date, T.value)
clim([-100 100])
colorbarsml 'Price (cent)'

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,2,3)
y0 = accumarray(time_ind, T.spot_price, [], @nanmean); %#ok<*NANMEAN>
plotSpread(gca, time_bin, y0, [], [], 'y', 'DisplayName', sprintf('Spot= %.1f c/kWh', mean(y0)))
ylim([-5 80]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

subplot(4,2,4)
y = accumarray(time_ind, T.value, [], @nanmean);
plotSpread(gca, time_bin, y, time_bin, y0, 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)-mean(y0)))
plotSpread(gca, time_bin, y0, time_bin, min(0, y0), 'y', 'DisplayName', sprintf('Spot= %.1f c/kWh', mean(y0)))
ylim([-5 80]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

%% Plot spread
T.fees = T.value - T.spot_price;

subplot(4,4,10:11), title 'fees'
plotheatmap(T.time, T.date, T.fees)
clim([-100 100])
colorbarsml 'Price (c/kWh)'

%% Plot average spread
[time_ind, time_bin] = findgroups(T.time);

subplot(4,4,14:15)
% subplot(1,1,1)
y = accumarray(time_ind, T.fees, [], @nanmean);
plotSpread(gca, time_bin, y, [], [], 'r', 'DisplayName', sprintf('Fees= %.1f c/kWh', mean(y)))
ylim([-5 40]), xlim(duration([0 24], 0, 0))
ylabel 'Price (c/kWh)'
legend show location north

% ylim([22.9 23.1])

%% Link axes
ax = findobj(gcf, 'type', 'axes');
linkaxes(ax, 'x');

return
linkaxes(ax(cellfun(@isdatetime, {ax.YTick})), 'y')

return
% Save figure
file = 'plots\amber_price_spread.png';
figsave(1, file, [1500 1200])
figsave(1, file, [1500 1200])
I = imread(file);
imwrite(I(60:end-100,110:end-80,:),file);
