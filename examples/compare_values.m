% Show how the forecast buy/sell price changes as the forecast time
% approaches actual time.
% 
% Usage:
% 1.Run amber().downloadForecastPeriodicaly to collect several days of data
% 2.Set v_field for price to: 'sell_price' or 'buy_price'
% 3.Set x_field for x-axis to: 'start' or 'query'

% Load data
T = amber().readForecastData({'2025-04-03' '2025-04-10'}, 30, 24);
T = T(T.forecast<0, :);
[~, i] = unique(T(:, {'start' 'forecast'}), 'rows');
i = intersect(i,find( T.forecast < 0));
T = T(i, {'start'  'buy_price' 'sell_price' 'tariff_price'});

fig(1, 'dark', 'handy')
plot(T.start, T.buy_price)

T = amber().getData('prices',{'2025-04-03' '2025-04-10'}, 30);

plot(T.start, T.buy_price)

%%
file = amber().downloadForecastOnce([48 0], 30);
T = amber().readForecastData({-1 1}, 30, 24);
fig(1, 'dark', 'handy')
T.start.TimeZone = "Australia/Adelaide";
plot(T.start, T.buy_price)