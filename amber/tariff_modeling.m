% Fit equations that convert AEMO spot price to Amber buy and sell prices.
%
% Remarks:
% - Amber fees include SAPN fees and both update on 1st July.
% - Amber adds 10% to the AEMO RRP, which is an amber fee, and not GST!

%% 1. Load AEMO RRP and Amber data (spot_price buy_price sell_price)
span = {'2025-07-10' '2025-07-20'};
T1 = aemo().getPrice('sa', span, 'spot'); 
T2 = amber().getPrices(span);
T = innerjoin(T1, T2, "Keys", "start"); % Join


%% 2. Fit
clf, fig(1, 'dark', 'handy')

% buy
[i1, ~, ~, s1] = ransacLines(T.spot_price/1.1, T.buy_price, 3, 0.1, 50);
subplot(221), grid on, gscatter(T.spot_price, T.buy_price, i1), legend(s1), title 'Buy'
subplot(223), grid on, gscatter(T.tod, i1, i1), xlabel Time

% sell
[i2, ~, ~, s2] = ransacLines(T.spot_price/1.1, T.sell_price, 3, 0.1, 50);
subplot(222), grid on, gscatter(T.spot_price, T.sell_price, i2), legend(s2), title 'Sell'
subplot(224), grid on, gscatter(T.tod, i2, i2), xlabel Time


%% 1. Load Amber data (spot_price buy_price buy2_price sell_price)
span = {'2025-07-10' '2025-07-20'};

T = amber().getPrices(span);
T.start.TimeZone = "Australia/Adelaide"; % Fee periods are defined in local time
T.tod = timeofday2(T.start);

%% 2. Fit
clf, fig(1, 'dark', 'handy')

% buy
[i1, ~, ~, s1] = ransacLines(T.spot_price/1.1, T.buy_price, 3, 0.1, 50);
subplot(221), grid on, gscatter(T.spot_price, T.buy_price, i1), legend(s1), title 'Buy'
subplot(223), grid on, gscatter(T.tod, i1, i1), xlabel Time

% sell
[i2, ~, ~, s2] = ransacLines(T.spot_price/1.1, T.sell_price, 3, 0.1, 50);
subplot(222), grid on, gscatter(T.spot_price, T.sell_price, i2), legend(s2), title 'Sell'
subplot(224), grid on, gscatter(T.tod, i2, i2), xlabel Time

%% 3. Manually update tariffs.m

% eg "RTOU_B" "2025-07-01" 'Australia/Adelaide'  [0 6 10 16]' [int2 int1 int3 int1]' slope

%% 4. Check model
rms(tariffs('RTOU_B', T.start, T.spot_price) - T.buy_price)  % buy error (cents)
rms(tariffs('RTOU_S', T.start, T.spot_price) - T.sell_price) % sell error (cents)

%% 5. Check using AEMO spot price
T2 = aemo().getPrice('sa', span); 
TT = innerjoin(T, T2, "Keys", "start"); % Join
rms(tariffs('RTOU_B', TT.start, TT.RRP/10*1.1) - TT.buy_price)  % buy error (cents)
rms(tariffs('RTOU_S', TT.start, TT.RRP/10*1.1) - TT.sell_price) % sell error (cents)
