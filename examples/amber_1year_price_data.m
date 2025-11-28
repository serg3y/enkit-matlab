% Compare csv prices with the date provided by API

% Load api price data
T1 = amber().getPrices({'2025-04-04' '2025-04-10'}, 30);
T1.start.TimeZone = 'Australia/Adelaide';

% Load csv price data
f1 = 'amber\data\prices_sa_30min\2001129180-RTOU-E1-fromGrid-timeOfUse.csv';
f2 = 'amber\data\prices_sa_30min\2001129180-RTOU-E2-fromGrid-controlledLoadTimeOfUse';
f3 = 'amber\data\prices_sa_30min\2001129180-NOTAPPLIC-B1-toGrid-feedIn.csv';
T2 = read_amber_csv({f1 f2 f3}, {'RTOU' 'RTOUCL' 'FIT'}, '+10:00', 'Australia/Adelaide');

% Join
T = innerjoin(T1, T2, 'Keys', 'start', 'LeftVariables', {'start' 'buy_price' 'tariff_price' 'sell_price'}, 'RightVariables', {'RTOU' 'RTOUCL' 'FIT'});
[T.time, T.date] = timeofdaylocal(T.start);

% Diff
T.dRTOU = T.buy_price - T.RTOU;
T.dRTOUCL = T.tariff_price - T.RTOUCL;
T.dFIT = T.sell_price - T.FIT;

%%
figmode(1, 'dark', 'handy')
plot(T.buy_price, T.RTOU - T.buy_price, '.')
plot(T.RTOUCL, T.RTOUCL - T.tariff_price, '.')
plot(T.FIT, T.FIT - T.sell_price, '.')

%% Plot prices
figmode(2, 'dark', 'handy')
colormap(gcf, flipud(rbg))
subplot(3,3,1), plotheatmap(T.time, T.date, T.buy_price),    clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,4), plotheatmap(T.time, T.date, T.RTOU),         clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,7), plotheatmap(T.time, T.date, T.dRTOU),        clim([-1 1]),     colorbarsml 'Price diff (cent)'
subplot(3,3,2), plotheatmap(T.time, T.date, T.tariff_price), clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,5), plotheatmap(T.time, T.date, T.RTOUCL),       clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,8), plotheatmap(T.time, T.date, T.dRTOUCL),      clim([-1 1]),     colorbarsml 'Price diff (cent)'
subplot(3,3,3), plotheatmap(T.time, T.date, T.sell_price),   clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,6), plotheatmap(T.time, T.date, T.FIT),          clim([-100 100]), colorbarsml 'Price (cent)'
subplot(3,3,9), plotheatmap(T.time, T.date, T.dFIT),         clim([-1 1]),     colorbarsml 'Price diff (cent)'
linkaxes_all