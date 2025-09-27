%% Compare usage - SAPN vs Amber (same)
% T1 = amber().getUsage({'2025-06-23' '2025-07-01'}); % Amber (starts 2025-06-23)
% T2 = nem12read('D:\MATLAB\enkit\sapn\data\Serge\*.csv');
% T = innerjoin(T1, T2, 'Keys', 'start');
% rms(T.buy_amount - T.buy_kwh) % same
% rms(T.sell_amount - T.sell_kwh) % same

%% Compare price - AEMO RTOU calculated vs Amber (same)
% T1 = amber().getPrices({'2024-11-30' '2025-09-20'}); % spot_price (starts 2024-11-30)
% T2 = aemo().getPrice('SA',{'2024-11-30' '2025-09-20'}); % spot
% T2.RTOU_B = tariffs('RTOU_B', T2.start, T2.spot); % predict amber buy price
% T2.RTOU_S = tariffs('RTOU_S', T2.start, T2.spot); % predict amber sell price
% T = innerjoin(T1, T2, 'Keys', 'start');
% rms(T.spot_price - T.spot) % same
% rms(T.RTOU_B - T.buy_price) % same
% rms(T.RTOU_S - T.sell_price) % same

%% Load data 
% Prices - AEMO spot > RTOU calculated
switch -3
    case -3,span = {'2024-03-28' '2025-03-29'}; % Andrew
    case -2,span = {'2024-12-01' '2025-08-31'}; % Serge
    case -1,span = {'2024-09-01' '2025-08-31'}; % Jenka
    case 1, span = {'2024-12-01' '2024-12-29'};
    case 2, span = {'2024-12-30' '2025-01-29'};
    case 3, span = {'2025-01-30' '2025-02-27'};
    case 4, span = {'2025-02-28' '2025-03-29'};
    case 5, span = {'2025-03-30' '2025-04-29'};
    case 6, span = {'2025-04-30' '2025-05-29'};
    case 7, span = {'2025-05-30' '2025-06-29'};
    case 8, span = {'2025-06-30' '2025-07-29'};
    case 9, span = {'2025-07-30' '2025-08-29'};
end
T1 = aemo().getPrice('SA', span);
T1.buy_price  = tariffs('RTOU_B', T1.start, T1.spot); % predict
T1.sell_price = tariffs('RTOU_S', T1.start, T1.spot);

% Usage - SAPN
switch 2
    case 1, folder = 'Serge';  curtailment = false;
    case 2, folder = 'Andrew'; curtailment = false; % 2023-03-30 to 2025-03-29
    case 3, folder = 'Jenka';  curtailment = true;
end
T2 = nem12read(fullfile('D:\MATLAB\enkit\sapn\data', folder, '*.csv'));
try 
    T2.buy_kwh = T2.buy_kwh + T2.buy2_kwh;
    T2.buy2_kwh = [];
end
T2.start = dateshift(T2.start, 'start', 'second');

% Join
T = innerjoin(T1, T2, 'Keys', 'start');
assert(isscalar(unique(diff(T.start))), 'Time precission errors')
[T.tod, T.date] = timeofday2(T.start);
[i, g] = findgroups(T.date);

% Cost
T.buy_cost = T.buy_kwh .* T.buy_price;
T.sell_cost = T.sell_kwh .* T.sell_price;
if curtailment
    T.sell_cost(T.sell_price<0) = 0; % Curtailment
    T.sell_kwh(T.sell_price<0) = 0;
end
T.cost = T.buy_cost - T.sell_cost; % Net cost

% Predict Amber bill
D = groupsummary(T, 'date', @(x)sum(x), {'buy_kwh' 'buy_cost' 'sell_kwh' 'sell_cost'});
D = renamevars(D, {'fun1_buy_kwh' 'fun1_buy_cost' 'fun1_sell_kwh' 'fun1_sell_cost'}, {'buy_kwh' 'buy_cost' 'sell_kwh' 'sell_cost'});
assert(all(D.GroupCount==288))

D.Usage = D.buy_kwh;
D.Cost = D.buy_cost/100;
D.BuyRate = D.Cost./D.Usage;
D.Supply(:) = 0.9897; 
D.AmberFee(:) = 0.6574;
D.BuyGST = (D.Cost + D.Supply + D.AmberFee) * 0.1;
D.ChargesTotal = D.Cost + D.Supply + D.AmberFee + D.BuyGST;
D.Export = D.sell_kwh;
D.Credits = D.sell_cost/100;
D.SellRate = D.Credits./D.Export;
D.SellGST = min(D.Credits * 0.1, 0);
D.CreditsTotal = D.Credits + D.SellGST;
D.DailyTotal = D.ChargesTotal - D.CreditsTotal;
D = removevars(D, {'buy_kwh' 'buy_cost' 'sell_kwh' 'sell_cost'});

Usage = sum(D.Usage);
Cost = sum(D.Cost);
BuyRate = Cost/Usage;
Supply = sum(D.Supply); 
AmberFee = sum(D.AmberFee);
BuyGST = sum(D.BuyGST);
ChargesTotal = sum(D.ChargesTotal);
Export = sum(D.Export);
Credits = sum(D.Credits);
SellRate = Credits/Export;
SellGST = min(Credits * 0.1, 0);
CreditsTotal = sum(D.CreditsTotal) + SellGST;
BillTotal = sum(D.DailyTotal);

%
clc
fprintf('User: %s\n', folder)
fprintf('Curtailing: %s\n', string(curtailment))
fprintf('Period: %s - %s  (%g days)\n', T.start([1 end]), round(days(diff(T.start([1 end])))))
if 1
    fprintf('%-16s%9.2f\n','Usage (kWh)' ,     Usage)
    fprintf('%-16s%9.2f\n','Cost ($)',         Cost)
    fprintf('%-16s%9.2f\n','AvgRate (c/kWh)',  BuyRate)
    fprintf('%-16s%9.2f\n','SupplyFee ($)',    Supply)
    fprintf('%-16s%9.2f\n','AmberFee ($)',     AmberFee)
    fprintf('%-16s%9.2f\n','GST ($)',          BuyGST)
    fprintf('%-16s%9.2f\n','ChargesTotal ($)', ChargesTotal)
    fprintf('%-16s%9.2f\n','Export (kWh)',     Export)
    fprintf('%-16s%9.2f\n','Credits (kWh)',    Credits)
    fprintf('%-16s%9.2f\n','AvgRate (c/kWh)',  SellRate)
    fprintf('%-16s%9.2f\n','Bill Total ($)',   BillTotal)
else
    fprintf('%.4f\n', Usage)
    fprintf('%.4f\n', BuyRate)
    fprintf('%.4f\n', Cost)
    fprintf('%.4f\n', Supply)
    fprintf('%.4f\n', 0)
    fprintf('%.4f\n', AmberFee)
    fprintf('%.4f\n', BuyGST)
    fprintf('%.4f\n', ChargesTotal)
    fprintf('%.4f\n', Export)
    fprintf('%.4f\n', SellRate)
    fprintf('%.4f\n', Credits)
    fprintf('%.4f\n', 0)
    fprintf('%.4f\n', SellGST)
    fprintf('%.4f\n', Credits)
    fprintf('%.4f\n', BillTotal)
end

%% Plot
fig(1, 'dark', 'handy')
myplot(T, 1, 2, 'Buy',  'buy_cost',  'buy_kwh',  'buy_cost',  cold2hot, [1.0 0.3 0.3], [0.3 1.0 0.3])
myplot(T, 2, 2, 'Sell', 'sell_cost', 'sell_kwh', 'sell_cost', hot2cold, [0.3 1.0 0.3], [1.0 0.3 0.3])
linkallaxes
figsave(1, ['predicted_amber_charges_' folder '.png'], [1600 1000])

%%
function myplot(T, N, M, name, price, amount, cost, c1, c2, c3)

axis_stack(1, 6, N, M)
plotheatmap(T.date, T.tod, T.(price))
colormap(gca, c1), clim([-200 200]), colorbarsml 'Price (c/kWh)'
title(name)

axis_stack(2, 6, N, M)
plotheatmap(T.date, T.tod, T.(amount))
colormap(gca, c1), clim([-3 3]), colorbarsml 'Amount (kWh)'

axis_stack(3, 6, N, M)
[i, G] = findgroups(T.date);
y = accumarray(i, T.(amount)); plotsteps (gca, G, y, c2,  sprintf('Amount %.1f kWh/day', mean(y)))
y = accumarray(i, T.(amount)); plotSpread(gca, G, y, [], [], c2, '' ,'HandleVisibility', 'off')
yline(gca, mean(y), ':y', 'HandleVisibility', 'off')
ylabel 'Amount (kWh/day)', legend show location north
set(gca, 'YAxisLocation', 'right')

axis_stack(4, 6, N, M)
plotheatmap(T.date, T.tod, T.(cost))
colormap(gca, c1), clim([-100 100]), colorbarsml 'Cost (c)'

axis_stack(5, 6, N, M)
[i, G] = findgroups(T.date);
p = T.(cost)>=0;
n = T.(cost)< 0;
y = accumarray(i, T.(cost).*p); plotSpread(gca, G, y, [], [], c2, sprintf('Cost (+ve) %.1f c/day', mean(y)))
y = accumarray(i, T.(cost).*n); plotSpread(gca, G, y, [], [], c3, sprintf('Cost (-ve) %.1f c/day', mean(y)))
y = accumarray(i, T.(cost)   ); plotsteps (gca, G, y, [1 1 0.3],  sprintf('Cost (net) %.1f c/day', mean(y)))
yline(gca, mean(y), ':y', 'HandleVisibility', 'off')
ylabel 'Cost (c/day)', legend show location north
set(gca, 'YAxisLocation', 'right')

axis_stack(6, 6, N, M)
y = accumarray(i, T.(cost).*p)./accumarray(i, T.(amount).*p); plotSpread(gca, G, y, [], [], c2, sprintf('Price (+ve) %.1f c/kwh', sum(T.(cost).*p)/sum(T.(amount).*p)))
y = accumarray(i, T.(cost).*n)./accumarray(i, T.(amount).*n); plotSpread(gca, G, y, [], [], c3, sprintf('Price (-ve) %.1f c/kwh', sum(T.(cost).*n)/sum(T.(amount).*n)))
y = accumarray(i, T.(cost)   )./accumarray(i, T.(amount)   ); plotsteps (gca, G, y, [1 1 0.3],  sprintf('Price (net) %.1f c/kwh', sum(T.(cost)   )/sum(T.(amount)   )))
yline(gca, 0, 'w', 'HandleVisibility', 'off')
ylabel 'Price (c/kWh)', legend show location north
set(gca, 'YAxisLocation', 'right')

end