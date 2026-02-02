function [buy_price, sell_price, supply] = tariffs(tariff, time)
% Retruns electricity buy and sell prices for various providers at a
% given date and time (inc GST). Includes wholesale providers.
%   [buy_price, sell_price, supply] = tariffs(tariff, time)
%
% Remarks:
% - Tariff and fees were derived by analysing Amber price history
%   eg, RTOU fees = 25.56422(peak), 13.21122(offpeak), 9.08622(day) (c/kWh)
% - They can also be calculated (mostly) using SAPN's "Tariff Price List":
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119
%   RTOU tariff only = [18.79 7.56 3.81] (c/kWh exGST)
%     = ([18.79 7.56 3.81] + X) * 1.1
%   Where X was derived to be 4.4502c, composed of: hedging (1.5c) + Carbon
%     offset (0.22c), market charges (0.47c), certificates (2.36c)  [Rob]
%
% Example Equation:
%   rrp = (RRP / 10) * 1.1
%   spot = rrp * 1.1105195 + (tariff + 4.4502) * 1.1
%
% Example:
%   time = datetime('2025-07-02') + hours(0:0.5:23.5)
%   [buy_price, sell_price, supply] = tariffs('origin js', time)
%   plotsteps(gca, time, buy_price)
%
% Example:
%   tariffs('plot all')
%
% Links:
%   https://wattever.com.au/compare-best-electricity-rates/#sapower
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119 (2024-25)
%   https://help.amber.com.au/hc/en-us/articles/21725379941389-SAPN-Two-Way-Tariff-RELE2W
%   https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/
%
% See also: tariff_equation_fitting

%#ok<*NBRAK2>

if nargin==1 && ischar(tariff) && tariff == "plot all"
    time = datetime('2025-012-02') + hours(0:0.5:23.5);
    tariffList = unique(tariffs().tariff, 'stable')';
    clf, hold on
    for k = numel(tariffList):-1:1
        a(k) = subplot(ceil(numel(tariffList)/3),3,k); ylim([-15 65]), title(tariffList(k) + " 2025")
        hold on, grid on
        [buy_price, sell_price, supply] = tariffs(tariffList(k), time);
        plotstepspread(gca, time, buy_price, [], 'r')
        plotstepspread(gca, time, sell_price, [], 'g')
    end
    linkaxes(a,'xy')
    return
end

% Price data
fields = {'date' 'tariff'          'supply'  'buy_tod'     'buy_fees'                   'sell_tod' 'sell_fees' 'export_limit' 'rrp_buy' 'rrp_sell' 'rrp_source'};
data = {
    % https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/loss_factors_and_regional_boundaries/2025-26-marginal-loss-factors/distribution-loss-factors-for-the-2025-26.pdf - Table24 pg26 - SA 2024,2025 DLF: 1.1161, 1.0811
    "2024-07-01" "SAPN RTOU"        nan     [ 1  6 10 15] [7.56     18.79     3.81    18.79   ] [0      ] [0      ] inf 1.1161    1/1.1161 '' % https://www.sapowernetworks.com.au/public/download.jsp?id=328119 - Table1 pg4  - 2024 NUoS RTOU: [18.79 7.56 3.81]
    "2025-07-01" "SAPN RTOU"        nan     [ 0  6 10 16] [9.47     18.95     4.74    18.95   ] [0 10 16] [0  1  0] inf 1.0811    1/1.0811 '' % https://www.sapowernetworks.com.au/public/download.jsp?id=333252 - Table9 pg37 - 2025 NUoS RTOU: [18.95 9.47 4.74]
    "2024-07-01" "Amber RTOU"       181.247 [ 1  6 10 15] [13.21122 25.56422  9.08622 25.56422] [0      ] [0      ] inf 1.221571  1.110520 '' % supply = (65.77 + 99.00) * 1.1 = 181.2470
    "2025-07-01" "Amber RTOU"       190.685 [ 0  6 10 16] [14.68214 25.11014  9.47914 25.11014] [0 10 16] [0  1  0] inf 1.187664  1.079695 '' % supply = (74.16 + 99.19) * 1.1 = 190.6850

    "2024-07-01" "Amber RTOU+sa"    199.372 [ 1  6 10 15] [14.53234 28.12064  9.99484 28.12064] [0      ] [0      ] inf 1.3437281 1.221572 'sa' % inc GST
    "2025-07-01" "Amber RTOU+sa"    191.29  [ 0  6 10 16] [16.15035 27.62115 10.42705 27.62115] [0 10 16] [0 1.1 0] inf 1.3064304 1.187665 'sa' 
    "2024-07-01" "Amber RTOU+amber" 181.24  [0          ] [0                                  ] [0      ] [0      ] inf 1.1       1.1      'amber' % inc GST
    "2025-07-01" "Amber RTOU+amber" 191.29  [0          ] [0                                  ] [0      ] [0      ] inf 1.1       1.1      'amber'
    
    "2024-07-01" "Amber RELEW"      nan     [10 16 17 21] [ 8.20622 15.65322 41.29422 15.65322] [0      ] [nan    ] inf 1.1105195 nan      ''    
    "2024-07-01" "test JA"          111.518 [ 0         ] [45.034                             ] [0      ] [ -4.737] inf 0         0        ''    % 8c first 10kWh, then 2c, avg export is 21.6 kWh
    "2024-07-01" "tast AB"          107.459 [ 1  6 10 15] [32.626   55.814   27.247   55.814  ] [0      ] [ -4    ] inf 0         0        ''           
    "2000-01-01" "Origin JS"        116.050 [ 0  6 10 16] [35.233   59.653   29.425   59.653  ] [0      ] [-10    ] inf 0         0        ''    % hack
    "2024-07-01" "Origin JS"        107.459 [ 1  6 10 15] [32.626   55.814   27.247   55.814  ] [0      ] [-10    ] inf 0         0        ''           
    "2025-07-01" "Origin JS"        116.050 [ 0  6 10 16] [35.233   59.653   29.425   59.653  ] [0      ] [-10    ] inf 0         0        ''           
    "2024-07-01" "AGL SK"           113.916 [ 1  6 10 15] [38.4340  52.1510  34.9580  52.1510 ] [0      ] [ -4    ] inf 0         0        ''    % incGST, 2024 only
    "2024-01-01" "AGL RM"           115.060 [ 1  6 10 15] [40.9310  55.7150  37.0590  55.7150 ] [0      ] [-12    ] inf 0         0        ''    % incGST, hacked start time
    "2025-06-23" "AGL RM"           109.197 [ 1  6 10 15] [34.1440  49.016   29.4690  49.016  ] [0      ] [-10    ] inf 0         0        ''    % incGST
    "2024-01-01" "EA LL"            106.913 [0          ] [51.8487                            ] [0      ] [  0    ] inf 0         0        ''    % incGST
    
    "2024-01-01" "GlowBird"         106.913 [0          ] [34                                 ] [0      ] [  0    ] inf 0         0        ''    % incGST
    "2024-01-01" "FOUR4FREE"        144.045 [ 1  6 10 14] [33.077    54.417    0       54.417 ] [0      ] [  0    ] inf 0         0        ''    % incGST
    
    "2024-01-01" "Momentum HomeRun" 170.06  [ 1  6 10 15] [31.35     40.04    27.17    40.04  ] [0      ] [  2.5  ] inf 0         0        ''    % incGST

    %"2025-06-23" "GlowBird Boos"    121.000 [0          ] [34.65                              ] [0      ] [0      ] inf 0         0        ''    % incGST

    % "2024-01-01" "GloBird"          106.913 [0          ] [51.8487                            ] [0      ] [  0    ] inf 0         0        ''    % incGST
    };

% fields = {'date' 'tariff'          'supply' 'buy_fees'                     'sell_fees' 'export_limit' 'rrp_buy' 'rrp_sell' 'rrp_source'};
% data2 = {
%     "2024-07-01" "SAPN RTOU"        nan     [18.79     7.56      3.81   ]  [  0     ] inf 1.1161    1/1.1161 ''       % https://www.sapowernetworks.com.au/public/download.jsp?id=328119 - Table1 pg4  - 2024 NUoS RTOU: [18.79 7.56 3.81]
%     "2025-07-01" "SAPN RTOU"        nan     [18.95     9.47      4.74   ]  [  0 1   ] inf 1.0811    1/1.0811 ''       % https://www.sapowernetworks.com.au/public/download.jsp?id=333252 - Table9 pg37 - 2025 NUoS RTOU: [18.95 9.47 4.74]
%     "2024-07-01" "Amber RTOU"       181.247 [25.56422  13.21122  9.08622]  [  0     ] inf 1.221571  1.110520 ''       % supply = (65.77 + 99.00) * 1.1 = 181.2470
%     "2025-07-01" "Amber RTOU"       190.685 [25.11014  14.68214  9.47914]  [  0 1   ] inf 1.187664  1.079695 ''       % supply = (74.16 + 99.19) * 1.1 = 190.6850
%     "2024-07-01" "Amber RTOU+sa"    199.372 [28.12064  14.53234  9.99484]  [  0     ] inf 1.3437281 1.221572 'sa'     % inc GST
%     "2025-07-01" "Amber RTOU+sa"    191.29  [27.62115  16.15035 10.42705]  [  0 1.1 ] inf 1.3064304 1.187665 'sa' 
%     "2024-07-01" "Amber RTOU+amber" 181.24  [ 0                         ]  [  0     ] inf 1.1       1.1      'amber'  % inc GST
%     "2025-07-01" "Amber RTOU+amber" 191.29  [ 0                         ]  [  0     ] inf 1.1       1.1      'amber'
%     "2024-07-01" "Origin JS"        107.459 [55.814    32.626   27.247  ]  [-10     ] inf 0         0        ''           
%     "2025-07-01" "Origin JS"        116.050 [59.653    35.233   29.425  ]  [-10     ] inf 0         0        ''           
%     "2024-07-01" "AGL SK"           113.916 [52.1510   38.4340  34.9580 ]  [ -4     ] inf 0         0        ''       % incGST, 2024 only
%     "2025-07-01" "AGL RM"           109.197 [49.016    34.1440  29.4690 ]  [-10     ] inf 0         0        ''       % incGST
%     "2024-01-01" "EA LL"            106.913 [51.8487                    ]  [  0     ] inf 0         0        ''       % incGST
%     "2024-01-01" "GloBird"          106.913 [51.8487                    ]  [  0     ] inf 0         0        ''       % incGST
%     };


% Make a table
T = cell2table(data, 'VariableNames', fields);
T.date = datetime(T.date, 'TimeZone', '+10');

% Exit if needed
if ~nargin
    buy_price = T;
    return
elseif nargin==1
    buy_price = T(T.tariff==tariff, :);
    return
end

% Check inputs
time = datetime(time, 'TimeZone', 'Australia/Adelaide'); % Ensure input time has same timezone (HACK)
step = days(mode(diff(time)));

% Convert numeric array to cell 
for f = ["buy_tod" "buy_fees" "sell_tod" "sell_fees"]
    if isnumeric(T.(f))
        T.(f) = num2cell(T.(f), 2);
    end
end

% Select tariff
T = T(strcmpi(T.tariff, tariff), :);
if isempty(T)
    error('Invalid tariff selection: %s', tariff)
end

% Find fee at specific time
if nargin >= 2
    % Map each time point to a tariff
    tariff_ind = discretize(time, [T.date; T.date(end) + years(100)]);
    tariff_ind_list = reshape(unique(rmmissing(tariff_ind)), 1, []); % used tariffs as row vector

    % Initialise output
    n = numel(time);
    buy_price = nan(n, 1);
    sell_price = nan(n, 1);
    supply = nan(n, 1);

    % Step through tariffs
    for k = tariff_ind_list
        idx = (tariff_ind == k);
        tod = timeofdaylocal(time(idx));

        % Buy fees
        ii = discretize(tod, hours([T.buy_tod{k} 24]));
        ii(isnan(ii)) = numel(T.buy_tod{k});
        buy_price(idx) = T.buy_fees{k}(ii);

        % Sell fees
        ii = discretize(tod, hours([T.sell_tod{k} 24]));
        ii(isnan(ii)) = numel(T.sell_tod{k});
        sell_price(idx) = T.sell_fees{k}(ii);

        % Supply charges
        supply(idx) = T.supply(k) * step;
    end
end

% Wholesale tariffs
switch lower(T.rrp_source{1})
    case {'nsw' 'qld' 'sa' 'tas' 'vic'} % AMEO
        T2 = aemo().getPrice(T.rrp_source{1}, [min(time) max(time) + seconds(1)]);
        [~, ind] = ismember(time, T2.time);
        rrp = nan(n, 1);
        valid = ind > 0;
        rrp(valid) = T2{ind(valid),2};
        buy_price(tariff_ind>0) = buy_price(tariff_ind>0) + rrp(tariff_ind>0) .* T.rrp_buy(tariff_ind(tariff_ind>0));
        sell_price(tariff_ind>0) = sell_price(tariff_ind>0) - rrp(tariff_ind>0) .* T.rrp_sell(tariff_ind(tariff_ind>0));
    case 'amber'
        T2 = amber().getPrices([min(time) max(time)]);
        buy_price = nan(n, 1);
        sell_price = nan(n, 1);
        if isempty(T2), return, end
        [~, ind] = ismember(time, T2.time);
        valid = ind > 0;
        buy_price(valid) = T2.buy_price(ind(valid));
        sell_price(valid) = -T2.sell_price(ind(valid));
end
