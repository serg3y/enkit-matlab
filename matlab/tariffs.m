function T = tariffs(tariff, time, spot)
% Returns SAPN tariff and fees (tnf) or applies tnf to the spot price.
%   profile = tariffs(tariff)              - tariff + fees profile
%   tnf     = tariffs(tariff, time)        - tariff + fees at given time
%   price   = tariffs(tariff, time, spot)  - final consumer price
%
% Remarks:
% - Tariff and fees (T&F) were derived by analysing Amber price history
%   eg, RTOU tnf = 25.56422(peak), 13.21122(offpeak), 9.08622(day) (c/kWh)
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
% Links:
%   https://www.sapowernetworks.com.au/public/download.jsp?id=328119
%   https://help.amber.com.au/hc/en-us/articles/21725379941389-SAPN-Two-Way-Tariff-RELE2W
%   https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/

if ~nargin
    x = duration(0:0.5:23.5,0,0, 'Format', 'hh:mm');
    fig(1, 'dark', 'handy')
    plotsteps(gca, x, tariffs('RTOU'  , x), [1.0 0.3 0.3], 'RTOU tariff + other fees',  [], 'linewidth', 2)
    plotsteps(gca, x, tariffs('RELE2W', x), [0.3 0.3 1.0], 'RELE2W tariff + other fees',[], 'linewidth', 2)
    ylim([0 45])
    xlim(duration([0 24], 0, 0))
    ylabel 'c/kWh'
    title 'SA Electricity Tariffs and Fees FY2024/25'
    legend show location NW
    return
end

% Tariff data
data = {
    "RTOU"   "2024-07-01" 'Australia/Adelaide'  [0  1  6 10 15]' [25.56422 13.21122 25.56422  9.08622 25.56422]' 1.1105195  % Residential Time of Use        SAPN report: ([18.79 7.56 3.81] + 4.4502) * 1.1
    "RELE2W" "2024-07-01" 'Australia/Adelaide'  [0 10 16 17 21]' [15.65322  8.20622 15.65322 41.29422 15.65322]' 1.1105195  % Residential Electrify Two Way, SAPN report: ([33.09 9.78 3.01] + 4.4502) * 1.1
    "AGL"    "2024-07-01" 'Australia/Adelaide'  [0  1  6 10 15]' [47.41    34.94    47.41    31.78    47.41   ]' 0       }; %

% Make a table
T = cell2table(data, 'VariableNames', {'tariff' 'date' 'timezone' 'tod' 'offset' 'scale'});

% Select one
T = T(T.tariff == upper(tariff), :);

% Scale spot price
if nargin >= 3
    spot = spot .* T.scale;
else
    spot = 0;
end

% Apply offset
if nargin >= 2
    if isdatetime(time)
        tod = timeofday2(time, T.timezone{1});
    else
        tod = time;
    end
    ind = discretize(tod, duration([T.tod{:}; 24], 0, 0));
    T = T.offset{:}(ind) + spot;
end
end
