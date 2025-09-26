% Fit an equation that converts spot price to final Amber buy price.
% N.B. Fees update each July.


%% 1. Load Amber data
span = {'2025-07-10' '2025-07-20'};
T = amber().getPrices(span);
T.start.TimeZone = "Australia/Adelaide"; % Fees periods are in local time
[T.tod, T.date] = timeofday2(T.start);
clf, grid on
scatter3(T.spot_price, T.buy_price, T.tod, [], T.buy_price-T.spot_price, '.') % Amber mapping
xlabel 'Spot price'
ylabel 'Buy price'
view(0, 90)


%% 2. Fit buy price
[ind, ~, ~, str] = ransacLines(T.spot_price, T.buy_price, 3, 0.1, 50);
clf
subplot(211), grid on, gscatter(T.spot_price, T.buy_price, ind), legend(str)
subplot(212), grid on, gscatter(T.tod, ind, ind), xlabel Time


%% 3. Fit sell price
[ind, ~, ~, str] = ransacLines(T.spot_price, T.sell_price, 3, 0.1, 50);
clf
subplot(211), grid on, gscatter(T.spot_price, T.buy_price, ind), legend(str)
subplot(212), grid on, gscatter(T.tod, ind, ind), xlabel Time


%% 4. Manually update tariffs.m


%% 5. Check buy price (same)
T.model = tariffs('RTOU_B', T.start, T.spot_price);
figure(1), clf
rms(T.model - T.buy_price) % cents
plot(T.start, T.buy_price - T.model,'.')


%% 6. Check sell price (same)
T.model = tariffs('RTOU_S', T.start, T.spot_price);
figure(1), clf
rms(T.model - T.sell_price) % cents
plot(T.start, T.sell_price - T.model,'.')


%% 7. Check buy price using AEMO spot price (same)
T2 = aemo().getPrice('sa', span); 
TT = innerjoin(T, T2, "Keys", "start"); % Join
TT.model = tariffs('RTOU_B', TT.start, TT.spot);
figure(1), clf
rms(TT.model - TT.buy_price) % cents
plot(TT.start, TT.buy_price - TT.model, '-')


%% 8. Check buy price using AEMO spot price (same)
T2 = aemo().getPrice('sa', span); 
TT = innerjoin(T, T2, "Keys", "start"); % Join
TT.model = tariffs('RTOU_S', TT.start, TT.spot);
figure(1), clf
rms(TT.model - TT.sell_price) % cents
plot(TT.start, TT.sell_price - TT.model, '-')