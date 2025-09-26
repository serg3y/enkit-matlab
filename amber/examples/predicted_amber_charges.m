
% Load api price data
T1 = amber().getPrices({'2024-09-01' '2025-09-01'}, 30);
T1 = amber().getPrices({'2024-09-01' '2025-09-01'},  5);
T1.start.TimeZone = 'Australia/Adelaide';

% Load SAPN usage data
archive = 'D:\MATLAB\enkit\sapn';
fold = 'serge';
T1 = nem12read(fullfile(archive, fold, '*.csv'), [], 30, '+10');

% Load Amber price data
f1 = 'amber\sa_prices_30min_csv\2001129180-RTOU-E1-fromGrid-timeOfUse.csv';
f2 = 'amber\sa_prices_30min_csv\2001129180-RTOU-E2-fromGrid-controlledLoadTimeOfUse';
f3 = 'amber\sa_prices_30min_csv\2001129180-NOTAPPLIC-B1-toGrid-feedIn.csv';
T2 = read_amber_csv({f1 f2 f3}, {'RTOU' 'RTOUCL' 'FIT'}, '+10:00', 'Australia/Adelaide');

T2 = read_amber_csv({'amber\sa_prices_30min_csv\2001129180-RTOU-E1-fromGrid-timeOfUse.csv'}, {'RTOU'}, '+10:00', 'Australia/Adelaide');

% Join
T = innerjoin(T1, T2, 'Keys', 'start');
[T.time, T.date] = timeofday(T.start);
[i, g] = findgroups(T.date);

% Cost
T.buy_cost = T.buy_amount .* T.RTOU;
T.tariff_cost = T.tariff_amount .* T.RTOUCL;
T.sell_cost = T.sell_amount .* T.FIT;
T.cost = T.buy_cost + T.tariff_cost - T.sell_cost;

%% Plot
F ={'Buy'            'RTOU'   'buy_amount'    'buy_cost'    cold2hot [1.0 0.3 0.3] [0.3 1.0 0.3]
    'Controled load' 'RTOUCL' 'tariff_amount' 'tariff_cost' cold2hot [1.0 0.3 0.3] [0.3 1.0 0.3]
    'Sell'           'FIT'    'sell_amount'   'sell_cost'   hot2cold [0.3 1.0 0.3] [1.0 0.3 0.3]};

if sum(T.tariff_amount)==0
    F(2, :) = [];
end

fig(1, 'dark', 'handy')
for k = 1:size(F,1)
    plot(T, k, size(F,1), F{k,:})
end
linkallaxes
figsave(1, ['plots\simcost_' fold '.png'], [1600 1000])

%%
function plot(T, N, M, name, price, amount, cost, c1, c2, c3)

axis_stack(1, 6, N, M)
plotheatmap(T, 'date', 'time', price)
colormap(gca, c1), clim([-200 200]), colorbarsml 'Price (c/kWh)'
title(name)

axis_stack(2, 6, N, M)
plotheatmap(T, 'date', 'time', amount)
colormap(gca, c1), clim([-3 3]), colorbarsml 'Amount (kWh)'

axis_stack(3, 6, N, M)
[i, g] = findgroups(T.date);
y = accumarray(i, T.(amount)); plotsteps (gca, g, y, c2,  sprintf('avg amount %.1f kWh/day', mean(y)))
y = accumarray(i, T.(amount)); plotSpread(gca, g, y, [], [], c2, '' ,'HandleVisibility', 'off')
yline(gca, mean(y), ':y', 'HandleVisibility', 'off')
ylabel 'Amount (kWh/day)', legend show location north
set(gca, 'YAxisLocation', 'right')

axis_stack(4, 6, N, M)
plotheatmap(T, 'date', 'time', cost)
colormap(gca, c1), clim([-100 100]), colorbarsml 'Cost (c)'

axis_stack(5, 6, N, M)
[i, g] = findgroups(T.date);
p = T.(cost)>=0;
n = T.(cost)< 0;
y = accumarray(i, T.(cost).*p); plotSpread(gca, g, y, [], [], c2, sprintf('+ve cost %.1f c/day', mean(y)))
y = accumarray(i, T.(cost).*n); plotSpread(gca, g, y, [], [], c3, sprintf('-ve cost %.1f c/day', mean(y)))
y = accumarray(i, T.(cost)   ); plotsteps (gca, g, y, [1 1 0.3],  sprintf('avg cost %.1f c/day', mean(y)))
yline(gca, mean(y), ':y', 'HandleVisibility', 'off')
ylabel 'Cost (c/day)', legend show location north
set(gca, 'YAxisLocation', 'right')

axis_stack(6, 6, N, M)
y = accumarray(i, T.(cost).*p)./accumarray(i, T.(amount).*p); plotSpread(gca, g, y, [], [], c2, sprintf('+ve price %.1f c/kwh', sum(T.(cost).*p)/sum(T.(amount).*p)))
y = accumarray(i, T.(cost).*n)./accumarray(i, T.(amount).*n); plotSpread(gca, g, y, [], [], c3, sprintf('-ve price %.1f c/kwh', sum(T.(cost).*n)/sum(T.(amount).*n)))
y = accumarray(i, T.(cost)   )./accumarray(i, T.(amount)   ); plotsteps (gca, g, y, [1 1 0.3],  sprintf('avg price %.1f c/kwh', sum(T.(cost)   )/sum(T.(amount)   )))
yline(gca, 0, 'w', 'HandleVisibility', 'off')
ylabel 'Price (c/kWh)', legend show location north
set(gca, 'YAxisLocation', 'right')

end