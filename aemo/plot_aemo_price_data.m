% This is a plot of electricity price and demand data from AEMO since 2020.
% The RRP spot price is updated daily and goes back to 1998 for each state.
% For this plot RRP was converted from $/MWh (exGST) to c/kWh (incGST).
% 
%   spot = RRP / 10 * 1.1  (c/kWh)
% 
% To convert spot price to consumer price tariff information is needed.
% I used my and Rob's Amber data to back-out the following tariff equations for 2024/2025FY.
% 
%   price = spot * 1.1105195 + tariff (cents/kWh)
% 
%   RTOU:   25.56422 (peak) 13.21122 (off-peak) 9.08622 (day)
%   RELE2W: 41.29422 (peak) 15.65322 (off-peak) 8.20622 (day)
% 
% Links:
%   https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data
%   https://drive.google.com/drive/folders/1fobuTq48HuNrJfxVP7vktMzlQpmiFelO
%   https://github.com/serg3y/enkit-matlab.git


rez = 30; % Time sampling (minutes)
span = {'2020-01-01' '2025-06-01'}; % Time span
state = ["NSW" "QLD" "VIC" "SA" "TAS"];
value = ["spot" "TOTALDEMAND"];

% Plot
fig(1, 'dark', 'handy')
for k = 1:numel(state)
    T = aemo().getPrice(state{k} , span, rez, {'time' 'spot' 'TOTALDEMAND'});
    for j = 1:numel(value)
        [T.tod, T.date] = timeofday2(T.time);
        axis_stack(k, numel(state), j, numel(value))
        plotheatmap(T.date, T.tod, T.(value{j}))
        ylabel(state{k})
        switch value{j}
            case 'spot'
                clim([-200 200])
                colormap(gca, cold2hot)
                colorbarsml 'c/kWh'
                if k == 1
                    title 'Spot Price'
                end
            case 'TOTALDEMAND'
                clim([0 inf])
                colormap(gca, jet)
                colorbarsml 'MW'
                if k == 1
                    title 'Total Demand'
                end
        end
    end
end

linkallaxes
ylim(duration([0.001 24],0,0))
figsave(1, 'plot_aemo_price_data.png', [1600 1200])

%%
!robocopy "D:\MATLAB\enkit\aemo" "D:\s3rg3y\Share\enkit\aemo" *.csv *.txt *.py *.png /S /DCOPY:T /S /NDL /NS /NC /NJH /NJS /NP