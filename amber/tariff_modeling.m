% Fit equations that convert AEMO price to Amber buy and sell prices.
%
% Remarks:
% - Amber fees include SAPN fees and both update on 1st July.
% - Amber adds 10% to the AEMO RRP, which is an amber fee, and not GST!

%% 1. Load AEMOs rrp and Ambers spot_price buy_price sell_price

% Period
span = {'2025-05-10' '2025-05-20'}; % 2024
span = {'2025-07-10' '2025-07-20'}; % 2025

% Load
T1 = aemo().getPrice('sa', span, 'rrp'); 
T2 = amber().getPrices(span);
T = innerjoin(T1, T2); % Join

% Teriff periods use local time, not NEM time
T.tod = timeofday2(T.time, 'Australia/Adelaide');

%% 2. Fit
[T.i1, ~, ~, buy] = ransacLines(T.rrp, T.buy_price, 3, 0.1, 50);
[T.i2, ~, ~, sell] = ransacLines(T.rrp, T.sell_price, 3, 0.1, 50);

clf, fig(1, 'dark', 'handy')
subplot(221), grid on, gscatter(T.rrp, T.buy_price, T.i1), legend(buy), title 'Buy'
subplot(222), grid on, gscatter(T.rrp, T.sell_price, T.i2), legend(sell), title 'Sell'
subplot(223), grid on, gscatter(T.tod, T.i1, T.i1), xlabel Time
subplot(224), grid on, gscatter(T.tod, T.i2, T.i2), xlabel Time

% Results
clc
buy
sell

% Time of day when fees change
t = sortrows(T, 'tod');
buy_tod = [0 hours(t.tod(find(diff(t.i1)) + 1))']

t = sortrows(T, 'tod');
sell_tod = [0 hours(t.tod(find(diff(t.i2)) + 1))']

%% 3. Manually update tariffs.m
%
% Example:
% span =
%     {'2025-07-10' '2025-07-20'}
% buy =
%     {'y=1.1876641x+25.11015' }
%     {'y=1.1876639x+14.682144'}
%     {'y=1.187664x+9.4791348' }
% sell =
%     {'y=1.0796946x+6.5787892e-06'}
%     {'y=1.0796945x-1.0000052'    }
% buy_tod =
%      0     6    10    16
% sell_tod =
%      0    10    16
%
% Becomes:
%   "2025-07-01"  "amber_rtou_buy"   "Australia/Adelaide"  [0     6 10 16]'  [         14.68214 25.11014  9.47914 25.11014]'  1.1876641
%   "2025-07-01"  "amber_rtou_sell"  "Australia/Adelaide"  [0       10 16]'  [ 0                         -1        0      ]'  1.0796946

%% 4. Check model (rms should be close to zero)
rms(tariffs('amber_rtou_buy',  T.time, T.rrp) - T.buy_price)  % buy error (cents)
rms(tariffs('amber_rtou_sell', T.time, T.rrp) - T.sell_price) % sell error (cents)
