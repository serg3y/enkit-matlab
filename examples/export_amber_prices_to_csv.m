% Export Amber Energy price history to CSV
% price = spot + tariff  (cents/kWh inc. GST)
% RTOU_tariff = 25.56422 (peak), 13.21122 (off-peak), 9.08622 (day)

% Load historic csv price data
f1 = 'amber\sa_prices_30min_csv\2001129180-RTOU-E1-fromGrid-timeOfUse.csv';
f2 = 'amber\sa_prices_30min_csv\2001129180-RTOU-E2-fromGrid-controlledLoadTimeOfUse';
f3 = 'amber\sa_prices_30min_csv\2001129180-NOTAPPLIC-B1-toGrid-feedIn.csv';
T1 = read_amber_csv({f1 f2 f3}, {'RTOU' 'RTOUCL' 'FIT'}, '+10:00');
T1 = renamevars(T1, 'start', 'time');

% Load api price data
T2 = amber().getPrices({'2024-04-04' -2}, 30);
T2 = renamevars(T2, {'start' 'spot_price' 'renewables' 'buy_price' 'tariff_price' 'sell_price'}, {'time' 'spot' 'renewables' 'RTOU' 'RTOUCL' 'FIT'});
T2.duration = [];
T2.renewables = [];

% Join
T = outerjoin(T1(T1.time < T2.time(1), :), T2, 'Keys', {'time' 'RTOU' 'RTOUCL' 'FIT'}, 'MergeKeys', true);
T = movevars(T, 'spot', 'after', 'time');
T.time.Format = 'yyyy-MM-dd''T''HH:mm:ssZ';

% plot(T.RTOU - T.RTOUCL)
writetable(T, 'D:\MATLAB\enkit\amber\SA_price_30min_20240422_20250430_RTOU.csv')

T.time.TimeZone = 'Australia/Adelaide'
plot(T.time,T.RTOU-(T.spot+ tariffs(T.time,'rtou3')))