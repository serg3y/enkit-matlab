%% Compare usage - SAPN vs Amber (same)
% T1 = amber().getUsage({'2025-06-23' '2025-07-01'}); % Amber (starts 2025-06-23)
% T2 = nem().read('D:\MATLAB\enkit\meter\data\Serge\*.csv');
% T = innerjoin(T1, T2, 'Keys', 'time');
% rms(T.buy_amount - T.import_kwh) % same
% rms(T.sell_amount - T.export_kwh) % same

%% Compare price - AEMO RTOU calculated vs Amber
% T1 = amber().getPrices({'2025-01-01' '2025-01-31'}); % spot_price (starts 2024-11-30)
% T2 = aemo().read('SA', {'2025-01-01' '2025-02-01'}); % AEMO rrp
% [T2.RTOU_B, T2.RTOU_S] = tariffs('SAPN RTOU', T2.time, T2.SA_price_ckwh); % predict amber buy price
% T = innerjoin(T1, T2, 'Keys', 'time');
% polyfit(T.spot_price, T.SA_price_ckwh,2)
% plot(T.spot_price, T.SA_price_ckwh,'.')
% rms(T.spot_price - T.SA_price_ckwh)
% rms(T.RTOU_B - T.buy_price)
% rms(T.RTOU_S - T.sell_price)

%% Load data

% example = 'Jenka 3'; data_folder = 'D:\MATLAB\enkit\meter\data\Jenka'; curtailment = true; tariff = 'Origin JS';  
% example = 'Jenka 3'; data_folder = 'D:\MATLAB\enkit\meter\data\Jenka'; curtailment = true; tariff = 'amber rtou'; 

% example = 'Jason SS'; labels = ["Usage" "Cost"]; curtailment = false; tariff = 'JA'; span = ["2025-08-31" "2025-11-16"]; data_folder = 'D:\MATLAB\enkit\meter\data\Jason';

example = 'Serge'; labels = ["Usage" "Cost"]; curtailment = false; tariff = 'Amber RTOU'; span = ["2024-12-01" "2025-11-29"]; data_folder = 'D:\MATLAB\enkit\meter\data\Serge';
% example = 'Serge'; labels = ["Buy Price"];    curtailment = false; tariff = 'Amber RTOU'; span = ["2024-12-01" "2025-11-29"]; data_folder = 'D:\MATLAB\enkit\meter\data\Serge';
% example = 'Serge'; labels = ["Export"]; curtailment = false; tariff = 'Amber RTOU'; span = ["2024-12-01" "2025-11-29"]; data_folder = 'D:\MATLAB\enkit\meter\data\Serge';

switch example
    case -3, span = {'2024-03-28' '2025-03-29'}; % Andrew
    case -2, span = {'2024-12-01' '2025-08-31'}; % Serge
    case -1, span = {'2024-09-01' '2025-08-31'}; % Jenka

        % Jenka's bills                                             actual (origin) | sim (origin) | sim (Amber)
    case 'Jenka 1', span = {'2024-09-21' '2024-12-21'}; %       26.24 + 75 = 101.24 | 126.96       | 261
    case 'Jenka 2', span = {'2024-12-21' '2025-03-21'}; %      164.87 + 75 = 239.87 | 264.91       | 424
    case 'Jenka 3', span = {'2025-03-21' '2025-06-21'}; % 92d  259.82 + 75 = 334.82 | 350.63-32.75 | 423
    case 'Jenka 4', span = {'2025-06-21' '2025-09-21'}; %      548.60 + 75 = 623.60 | 624.35       | 667.52

        % Serge's bills
    % case 'Serge 1', span = {'2024-12-01' '2024-12-29'};
    % case 'Serge 2', span = {'2024-12-30' '2025-01-29'};
    % case 'Serge 3', span = {'2025-01-30' '2025-02-27'};
    % case 'Serge 4', span = {'2025-02-28' '2025-03-29'};
    % case 'Serge 5', span = {'2025-03-30' '2025-04-29'};
    % case 'Serge 6', span = {'2025-04-30' '2025-05-29'};
    % case 'Serge 7', span = {'2025-05-30' '2025-06-29'};
    % case 'Serge 8', span = {'2025-06-30' '2025-07-29'};
    % case 'Serge 9', span = {'2025-07-30' '2025-08-29'};

    case 'Jason SS', span = ["2025-08-31" "2025-11-16"];
end

%% Load electricity usage
T = nem().read(data_folder, span);
[T.tod, T.date] = timeofdaylocal(T.time);
if hascolumn(T, 'cl_kw')
    T.import_kw = T.import_kw + T.cl_kw; % Lump controlled loads with regular usage (HACK)
    T.cl_kw = [];
end

% Append electricity prices
[T.buy_price, T.sell_price, T.supply] = tariffs(tariff, T.time, 'sa');
T.price_diff = T.buy_price-T.sell_price;

%% Calculate Cost
step_hrs = hours(mode(diff(T.time)));
T.buy_cost = T.import_kw*step_hrs .* T.buy_price;
T.sell_cost = T.export_kw*step_hrs .* T.sell_price;

% Apply curtailment
if curtailment
    T.sell_cost(T.sell_price<0) = 0;
    T.export_kwh(T.sell_price<0) = 0;
end

% Net cost
T.cost = T.buy_cost + T.sell_cost;

%% Calculate rates (kW)
% interval = hours(mode(diff(T.time))); % sampling interval (hrs)
% T.import_kw = T.import_kwh/interval; % kW
% T.export_kw = T.export_kwh/interval;
% T.total_kw = T.import_kw - T.export_kw;
% controlled_load = hascolumn(T, 'cl_kwh') && sum(T.cl_kwh)>0;
% if controlled_load
%     T.cl_kwh = fillmissing(T.cl_kwh, 'constant', 0);
%     T.cl_kw = T.cl_kwh*60/header.Interval;
%     T.total_kw = T.total_kw + T.cl_kw;
% end

%% Plot
figmode(-1, 'dark')
n = numel(labels);
for k = 1:numel(labels)

    % Plot settings
    switch labels(k)
        case "Usage",      prop = "grid_kw";    units = 'kW'; col = [1 0 0; 0 1 0];
        case "Export",     prop = "export_kw";  units =["kW" "kWh"]; col = [       0 1 0];
        case "Buy Price",  prop = "buy_price";  units = 'c/kWh';     col = [1 0 0; 0 1 0];
        case "Sell Price", prop = "sell_price"; units = 'c/kWh';     col = [0 1 0; 1 0 0];
        case "Price Diff", prop = "price_diff"; units = 'c/kWh';     col = [1 0 0; 0 1 0];
        case "Cost",       prop = "cost";       units = 'c';         col = [1 0 0; 0 1 0];
        otherwise, error('undefined')
    end

    % Axes position
    pos = [0 1-1/n*k 1 1/n]; % L B W H

    % Plot
    ax = heatmapTimeVsDatePlus(T, 'time', prop, col, labels(k), units, pos);
end

linkallaxes
xlim(ax(1), datetime([min(T.time) max(T.time)], 'TimeZone', ax(1).XLim.TimeZone))

file = fullfile(data_folder, "Predict Cost - " + example + " - " + strjoin(labels) + ".png")
% figsave(1, file, [1920 1080])
return


%% Predict Amber bill
T.import_kwh = T.import_kw*step_hrs;
T.export_kwh = T.export_kw*step_hrs;
D = groupsummary(T, 'date', @(x)sum(x), {'import_kwh' 'buy_cost' 'export_kwh' 'sell_cost' 'supply'});
D = renamevars(D, {'fun1_import_kwh' 'fun1_buy_cost' 'fun1_export_kwh' 'fun1_sell_cost' 'fun1_supply'}, {'import_kwh' 'buy_cost' 'export_kwh' 'sell_cost' 'Supply'});
assert(all(D.GroupCount==288))

% Origin
if 1
    D.Usage = D.import_kwh;
    D.Cost = D.buy_cost/100;
    D.Supply = D.Supply/100;
    D.BuyRate = D.Cost./D.Usage;
    D.BuyGST = (D.Cost + D.Supply) * 0.1;
    D.ChargesTotal = D.Cost + D.Supply + D.BuyGST;
    D.Export = D.export_kwh;
    D.Credits = D.sell_cost/100;
    D.SellRate = D.Credits./D.Export;
    D.SellGST = min(D.Credits * 0.1, 0);
    D.CreditsTotal = D.Credits + D.SellGST;
    D.DailyTotal = D.ChargesTotal - D.CreditsTotal;
    D = removevars(D, {'import_kwh' 'buy_cost' 'export_kwh' 'sell_cost'});

    clc
    num_days = ceil(days(range(T.time)));
    fprintf('User: %s\n', data_folder)
    fprintf('Curtailment: %s\n', string(curtailment))
    fprintf('%s  %s  %g\n',  checkdate(span), num_days)
    fprintf('%-16s%9.2f\n', 'Usage (kWh)' , sum(D.Usage))
    fprintf('%-16s%9.2f\n', 'Export (kWh)', sum(D.Export))
    fprintf('%-16s%9.2f\n', 'Cost ($)',     sum(D.Cost))
    fprintf('%-16s%9.2f\n', 'Supply ($)',   sum(D.Supply))
    fprintf('%-16s%9.2f\n', 'Credits ($)',  sum(D.Credits))
    fprintf('%-16s%9.2f\n', 'Total ($)',    sum(D.DailyTotal))
end

if 0

    D.Usage = D.import_kwh;
    D.Cost = D.buy_cost/100;
    D.Supply = D.Supply/100;
    D.BuyRate = D.Cost./D.Usage;
    D.BuyGST = (D.Cost + D.Supply) * 0.1;
    D.ChargesTotal = D.Cost + D.Supply + D.BuyGST;
    D.Export = D.export_kwh;
    D.Credits = D.sell_cost/100;
    D.SellRate = D.Credits./D.Export;
    D.SellGST = min(D.Credits * 0.1, 0);
    D.CreditsTotal = D.Credits + D.SellGST;
    D.DailyTotal = D.ChargesTotal - D.CreditsTotal;
    D = removevars(D, {'import_kwh' 'buy_cost' 'export_kwh' 'sell_cost'});

    num_days = ceil(days(range(T.time)));
    Usage = sum(D.Usage);
    Charges = sum(D.Cost);
    BuyRate = Charges/Usage;
    Supply = sum(D.Supply);
    BuyGST = sum(D.BuyGST);
    ChargesTotal = sum(D.ChargesTotal);
    Export = sum(D.Export);
    Credits = sum(D.Credits);
    SellRate = Credits/Export;
    SellGST = min(Credits * 0.1, 0);
    CreditsTotal = sum(D.CreditsTotal) + SellGST;
    BillTotal = sum(D.DailyTotal);

    clc
    fprintf('User: %s\n', data_folder)
    fprintf('Curtailment: %s\n', string(curtailment))
    fprintf('Period: %s - %s  (%g days)\n', T.time(1), dateshift(T.time(end), 'end', 'day'), num_days)
    fprintf('%-16s%9.2f\n','Usage (kWh)' ,     Usage)
    fprintf('%-16s%9.2f\n','Cost ($)',         Charges)
    fprintf('%-16s%9.2f\n','AvgRate (c/kWh)',  BuyRate)
    fprintf('%-16s%9.2f\n','Supply ($)',       Supply)
    fprintf('%-16s%9.2f\n','GST ($)',          BuyGST)
    fprintf('%-16s%9.2f\n','ChargesTotal ($)', ChargesTotal)
    fprintf('%-16s%9.2f\n','Export (kWh)',     Export)
    fprintf('%-16s%9.2f\n','Credits ($)',      Credits)
    fprintf('%-16s%9.2f\n','AvgRate (c/kWh)',  SellRate)
    fprintf('%-16s%9.2f\n','Bill Total ($)',   BillTotal)
end

return
%% Plot
figmode(-1, 'dark', 'handy')
myplot(T, 1, 2, 'Buy',  'buy_cost',  'import_kwh',  'buy_cost',  cold2hot, [1.0 0.3 0.3], [0.3 1.0 0.3])
myplot(T, 2, 2, 'Sell', 'sell_cost', 'export_kwh', 'sell_cost', hot2cold, [0.3 1.0 0.3], [1.0 0.3 0.3])
linkallaxes
figsave(1, ['simulate_amber_bill_' data_folder '.png'], [1600 1000])

%%
function myplot(T, N, M, name, price, amount, cost, c1, c2, c3)

axis_stack(1, 6, N, M)
plotheatmap(T.date, T.tod, T.(price))
colormap(gca, c1), clim([-3 3]), colorbarsml 'Price (c/kWh)'
title(name)

axis_stack(2, 6, N, M)
plotheatmap(T.date, T.tod, T.(amount))
colormap(gca, c1), clim([-1 1]), colorbarsml 'Amount (kWh)'

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