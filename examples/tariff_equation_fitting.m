% Fit_tariff_equations
% 1.2 x ( spot + tariff + 4.55c)
% RTOU tariff: 18.79c (peak), 7.56c (off peak), 3.81c (day)
% 4.55 is hedging (1.5c) + carbon offset (0.22c) + market charges (0.47c) + certificates (2.36c)
% Each July 4.55c and tariff will change.

T = amber().getData('prices', {'2025-01-01' -2}, 30);
T.RTOU = calctariff('RTOU', T.start, T.spot_price);

figure(1), clf
plot(T.buy_price, T.buy_price - T.RTOU,'.')

R = corrcoef(T.RTOU, T.buy_price);
R(1, 2)
polyfit(T.RTOU, T.buy_price, 1)
sqrt(mean((T.RTOU - T.buy_price).^2))


%% 
T2 = aemo().getData('sa', {'2025-01-01' -2}, 30);
T2.RTOU = calctariff('RTOU', T2.time, T2.spot);
plot(T.spot_price - T2.spot)
plot(T.RTOU - T2.RTOU)

%%
T2 = aemo().getData('sa', {'2024-11-27' '2025-04-30'}, 5);
plot(diff(T2.time))

writetable(T2,'D:\s3rg3y\Share\enkit\amber\RELE_and_RELE2W_5min_.csv')



%%
% T = readtable('D:\s3rg3y\Share\enkit\amber\RELE_and_RELE2W.csv');
% time = datetime(T.Var1, T.Var2, T.Var3, T.Var4, T.Var5, 0);
% T = table(time, T.Var6, T.Var7, T.Var8, 'VariableNames', {'time' 'spot' 'buy' 'sell'});
% T.time.TimeZone = 'Australia/Adelaide';
% T.time.TimeZone = '+1000';
% T = sortrows(T, 'time');
% T.time.Format = 'yyyy-MM-dd''T''HH:mm:ssZ';
% writetable(T, 'D:\s3rg3y\Share\enkit\amber\RELE_and_RELE2W_2.csv')
%%
T2 = aemo().getData('sa', {'2024-11-27' '2025-04-30'}, 5);

T = readtable('D:\s3rg3y\Share\enkit\amber\SA_price_05min_20241127_20250430_RELE_and_RELE2W.csv');
T.time = datetime(T.time, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ssZ', 'TimeZone', '+1000');
%%
T.RELE2W = calctariff('RELE2W', T.time, T.spot);
plot(T.buy,T .buy - T.RELE2W,'.')

i = ~isnan(T.RELE2W)
polyfit(T.RELE2W(i), T.buy(i), 1)
%%
plot(T.buy - T.RELE2W,'.')
