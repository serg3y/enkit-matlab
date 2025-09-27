function out = tariffs(tariff, time, spot)
% Calculates SAPN and Amber fees or adds fees to provided spot price.
%   feestable = tariffs()                    - plot summary
%   feestable = tariffs(tariff)              - plot summary
%   fees      = tariffs(tariff, time)        - fees at given time
%   price     = tariffs(tariff, time, spot)  - final consumer price
%
% Remarks:
% - Tariff and fees were derived by analysing Amber price history
%   eg, RTOU fees = 25.56422(peak), 13.21122(offpeak), 9.08622(day) (c/kWh)
% - They can also be calculated (mostly) using SAPN's "Tariff Price List":
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119
%   RTOU tariff only = [18.79 7.56 3.81] (c/kWh exGST)
%     = ([18.79 7.56 3.81] + X) * 1.1
%   Where X is derived to be 4.4502c, composed of: hedging (1.5c) + Carbon
%     offset (0.22c), market charges (0.47c), certificates (2.36c)  [Rob]
%
% Sammary:
%   spot = (RRP / 10) * 1.1
%   price = spot * 1.1105195 + (tariff + 4.4502) * 1.1
%
% Example:
%   t = datetime(2025, 7, 2) + (0:0.5:24)/24
%   buy_price = tariffs('RTOU_B', t) % c/kWh (inc GST)
%
% Links:
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119 (2024-25)
%   https://help.amber.com.au/hc/en-us/articles/21725379941389-SAPN-Two-Way-Tariff-RELE2W
%   https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/
%
% See also: tariff_equation_fitting

% All fee options as a table
data = {
    % https://www.sapowernetworks.com.au/public/download.jsp?id=328119 - Table1 pg4  - 2024 NUoS RTOU: [18.79 7.56 3.81] 
    % https://www.sapowernetworks.com.au/public/download.jsp?id=333252 - Table9 pg37 - 2025 NUoS RTOU: [18.95 9.47 4.74] 
    % https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/loss_factors_and_regional_boundaries/2025-26-marginal-loss-factors/distribution-loss-factors-for-the-2025-26.pdf - Table24 pg26 - SA 2024,2025 DLF: 1.1161, 1.0811 
    "2024-07-01"  "sapn_rtou_buy"    "Australia/Adelaide"  [0  1  6 10 15]'  [18.79    7.56     18.79     3.81    18.79   ]'  1.1161  % 57.53 c/day supply
    "2024-07-01"  "sapn_rtou_sell"   "Australia/Adelaide"   0                  0                                              1/1.1161
    "2025-07-01"  "sapn_rtou_buy"    "Australia/Adelaide"  [0     6 10 16]'  [           9.47   18.95     4.74    18.95   ]'  1.0811
    "2025-07-01"  "sapn_rtou_sell"   "Australia/Adelaide"  [0       10 16]'  [ 0                         -1        0      ]'  1/1.0811

    "2024-07-01"  "amber_rtou_buy"   "Australia/Adelaide"  [0  1  6 10 15]'  [25.56422 13.21122 25.56422  9.08622 25.56422]'  1.2215706  % amber_fees = sapn_fees * 1.1 + 4.8952
    "2024-07-01"  "amber_rtou_sell"  "Australia/Adelaide"   0                  0                                              1.1105195  %
    "2024-07-01"  "amber_relew_buy"  "Australia/Adelaide"  [0 10 16 17 21]'  [15.65322  8.20622 15.65322 41.29422 15.65322]'  1.1105195  % Residential Electrify Two Way, SAPN report: ([33.09 9.78 3.01] + 4.4502) * 1.1
    "2025-07-01"  "amber_rtou_buy"   "Australia/Adelaide"  [0     6 10 16]'  [         14.68214 25.11014  9.47914 25.11014]'  1.1876641  % SAPN report: [18.95 9.47 4.74] * 1.1 + 4.2651 = [25.1101 14.6821 9.4791]
    "2025-07-01"  "amber_rtou_sell"  "Australia/Adelaide"  [0       10 16]'  [ 0                         -1        0      ]'  1.0796946  % Residential Time of Use Sell 2025

    "2024-07-01"  "RTOU_B"           "Australia/Adelaide"  [0  1  6 10 15]'  [25.56422 13.21122 25.56422  9.08622 25.56422]'  1.1105195  % SAPN report: [18.79 7.56 3.81] * 1.1 + 4.8952 = [25.5642 13.2112 9.0862]
    "2024-07-01"  "RTOU_S"           "Australia/Adelaide"  [0            ]'  [ 0                                          ]'  1.0095632  %
    "2024-07-01"  "RELE2W"           "Australia/Adelaide"  [0 10 16 17 21]'  [15.65322  8.20622 15.65322 41.29422 15.65322]'  1.1105195  % Residential Electrify Two Way, SAPN report: ([33.09 9.78 3.01] + 4.4502) * 1.1
    "2025-07-01"  "RTOU_B"           "Australia/Adelaide"  [0     6 10 16]'  [         14.68214 25.11014  9.47914 25.11014]'  1.0796946  % SAPN report: [18.95 9.47 4.74] * 1.1 + 4.2651 = [25.1101 14.6821 9.4791]
    "2025-07-01"  "RTOU_S"           "Australia/Adelaide"  [0 10 16      ]'  [ 0        -1       0                        ]'  0.9815405  % Residential Time of Use Sell 2025
    "2025-07-01"  "RESELE"           "Australia/Adelaide"  [0 10 16 17 21]'  [nan      nan      nan       nan     nan     ]'  nan        % Residential Electrify Two Way

    "2024-07-01"  "AGL"              "Australia/Adelaide"  [0  1  6 10 15]'  [47.41    34.94    47.41    31.78    47.41   ]'  0        };%

T = cell2table(data, 'VariableNames', {'date' 'tariff' 'timezone' 'tod' 'fees' 'scale'}); % Form a table
T.date = datetime(T.date, 'TimeZone', '+10'); % Format start date

% Select one or more fee options
if nargin >= 1
    T = T(strcmpi(T.tariff, tariff), :);
end
if nargin < 2
    out = T; % Return fee table
    return
end

% Find fee at specific time
if nargin >= 2
    % Select a tariff for each time point
    time = datetime(time, 'TimeZone', '+10'); % Ensure time points use required timezone
    ti = discretize(time, [T.date; T.date(end) + years(1000)]);
    
    % Step through tariffs
    out = nan(size(ti)); % Initialise output
    for k = 1:max(ti)
        tod = timeofday2(time(k == ti), 'Australia/Adelaide');
        ii = discretize(tod, duration([T.tod{k}; 24], 0, 0));
        out(k == ti) = T.fees{k}(ii); % look up fees
    end
end

% Add spot price, if provided by user
if nargin >= 3
    out(ti>0) = out(ti>0) + spot(ti>0) .* T.scale(ti(ti>0));
end

end
