function T = tariffs(tariff, time, spot)
% tariff  = tariffs(tariff)
% fees    = tariffs(tariff, time)
% price   = tariffs(tariff, time, spot)

% https://help.amber.com.au/hc/en-us/articles/21725379941389-SAPN-Two-Way-Tariff-RELE2W
% https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/
% https://www.sapowernetworks.com.au/public/download.jsp?id=328119

if ~nargin
    x = duration(0:0.5:23.5,0,0, Format='hh:mm');
    fig(1, 'dark', 'handy')
    subplot(2,1,1)
    plotsteps(gca, x, tariffs('RTOU'  , x), [1.0 0.3 0.3], 'RTOU tariff + other fees',  [], 'linewidth', 2)
    plotsteps(gca, x, tariffs('RELE2W', x), [0.3 0.3 1.0], 'RELE2W tariff + other fees',[], 'linewidth', 2)
    ylim([0 45])
    xlim(duration([0 24], 0, 0))
    ylabel 'c/kWh'
    title 'Tariffs 2024/2025 FY'
    legend show location NW
    
    subplot(2,1,2)
    for state = ["NSW" "QLD" "VIC" "SA" "TAS"]
        T = aemo().getPrice(state, {'2024-07-01' '2025-06-30'}, 5, {'time' 'spot'});
        [T.tod, T.date] = timeofday2(T.time);
        g = groupsummary(T, 'tod', @mean, 'spot');
        plotsteps(gca, g.tod, g.fun1_spot, [], state + " Avg. Spot Price")
    end
    ylim([-5 55])
    xlim(duration([0 24], 0, 0))
    ylabel 'c/kWh'
    title 'Spot price 2024/2025 FY'
    legend show location NW
    figsave(gcf, 'tariffs_and_spot.png', [800 400])
end

% Tariff data
data = {
    "RTOU"   "2024-07-01" 'Australia/Adelaide'  [0  1  6 10 15]' [25.56422 13.21122 25.56422  9.08622 25.56422]' 1.1105195  % Residential Time of Use         $18.79 $7.56 $3.81
    "RELE2W" "2024-07-01" 'Australia/Adelaide'  [0 10 16 17 21]' [15.65322  8.20622 15.65322 41.29422 15.65322]' 1.1105195  % Residential Electrify Two Way,  $33.09 $9.78 $3.01
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
