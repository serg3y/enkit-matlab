function [buy, sell, supply] = tariffs(tariff, time, rrp)
% Gets provider fees, optionaly can add spot price (inc GST).
%   [buy, sell, supply] = tariffs(tariff, time)    - fees at given time
%   [buy, sell, supply] = tariffs(tariff, time, rrp)  - final consumer price
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
% Links:
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119 (2024-25)
%   https://help.amber.com.au/hc/en-us/articles/21725379941389-SAPN-Two-Way-Tariff-RELE2W
%   https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/
%
% See also: tariff_equation_fitting

%#ok<*NBRAK2>

% Price data
data = {
    % https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/loss_factors_and_regional_boundaries/2025-26-marginal-loss-factors/distribution-loss-factors-for-the-2025-26.pdf - Table24 pg26 - SA 2024,2025 DLF: 1.1161, 1.0811
    "2024-07-01" "sapn rtou"   nan     [ 1  6 10 15] [7.56     18.79     3.81    18.79   ] 1.1161    [0      ] [0     ] inf 1/1.1161 % https://www.sapowernetworks.com.au/public/download.jsp?id=328119 - Table1 pg4  - 2024 NUoS RTOU: [18.79 7.56 3.81]
    "2025-07-01" "sapn rtou"   nan     [ 0  6 10 16] [9.47     18.95     4.74    18.95   ] 1.0811    [0 10 16] [0 -1 0] inf 1/1.0811 % https://www.sapowernetworks.com.au/public/download.jsp?id=333252 - Table9 pg37 - 2025 NUoS RTOU: [18.95 9.47 4.74]
    "2024-07-01" "amber rtou"  181.247 [ 1  6 10 15] [13.21122 25.56422  9.08622 25.56422] 1.221571  [0      ] [0     ] inf 1.110520 % supply = (65.77 + 99.00) * 1.1 = 181.2470
    "2025-07-01" "amber rtou"  190.685 [ 0  6 10 16] [14.68214 25.11014  9.47914 25.11014] 1.187664  [0 10 16] [0 -1 0] inf 1.079695 % supply = (74.16 + 99.19) * 1.1 = 190.6850
    "2024-07-01" "origin JS"   107.459 [ 1  6 10 15] [32.626   55.814   27.247   55.814  ] 0         [0      ] [10    ] inf  0        
    "2025-07-01" "origin JS"   116.050 [ 0  6 10 16] [35.233   59.653   29.425   59.653  ] 0         [0      ] [10    ] inf  0        
    "2024-07-01" "JA"          111.518 [ 0         ] [45.034                             ] 0         [0      ] [4.737 ] inf  0 % 8c first 10kWh, then 2c, avg export is 21.6 kWh
    "2000-01-01" "JS"          116.050 [ 0  6 10 16] [35.233   59.653   29.425   59.653  ] 0         [0      ] [10    ] inf  0        
    "2024-07-01" "fake AB"     107.459 [ 1  6 10 15] [32.626   55.814   27.247   55.814  ] 0         [0      ] [4     ] inf 0        
    "2024-07-01" "amber relew" nan     [10 16 17 21] [8.20622  15.65322 41.29422 15.65322] 1.1105195 [0      ] [nan   ] inf nan      
    "2024-07-01" "AGL SK"      nan     [ 1  6 10 15] [34.94    47.41    31.78    47.41   ] 0         [0      ] [nan   ] inf nan      
    };

if ~nargin
    buy = data;
    return
end

% Check inputs
time = datetime(time, 'TimeZone', 'Australia/Adelaide'); % Ensure input time has same timezone (HACK)
step = days(mode(diff(time)));

% Make a table
T = cell2table(data, 'VariableNames', {'date' 'tariff' 'supply' 'buy_tod' 'buy_fees' 'buy_scale' 'sell_tod' 'sell_fees' 'export_limit' 'sell_scale'});
T.date = datetime(T.date, 'TimeZone', '+10');

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
    buy = nan(n, 1);
    sell = nan(n, 1);
    supply = nan(n, 1);

    % Step through tariffs
    for k = tariff_ind_list
        idx = (tariff_ind == k);
        tod = timeofdaylocal(time(idx));

        % Buy fees
        ii = discretize(tod, hours([T.buy_tod{k} 24]));
        ii(isnan(ii)) = numel(T.buy_tod{k});
        buy(idx) = T.buy_fees{k}(ii);

        % Sell fees
        ii = discretize(tod, hours([T.sell_tod{k} 24]));
        ii(isnan(ii)) = numel(T.sell_tod{k});
        sell(idx) = T.sell_fees{k}(ii);

        % Supply charges
        supply(idx) = T.supply(k) * step;
    end
end

% Add spot price, if provided
if nargin >= 3
    if ~isempty(rrp) && (ischar(rrp) || isstring(rrp))
        T2 = aemo().getPrice(rrp, [min(time) max(time) + seconds(1)]);
        time = dateshift(time, 'star', 'second');
        [~, ind] = ismember(time, T2.time);
        rrp = nan(n, 1);
        valid = ind > 0;
        rrp(valid) = T2.rrp(ind(valid));
    end
    buy(tariff_ind>0)  = buy(tariff_ind>0)  + rrp(tariff_ind>0) .* T.buy_scale(tariff_ind(tariff_ind>0));
    sell(tariff_ind>0) = sell(tariff_ind>0) + rrp(tariff_ind>0) .* T.sell_scale(tariff_ind(tariff_ind>0));
end
