% Plot AEMO spot price and demand data since 2020.

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
figsave(1, 'plot_aemo_data.png', [1600 1200])

% Copy data and plots to google drive
% !robocopy "D:\MATLAB\enkit\aemo" "D:\s3rg3y\Share\enkit\aemo" *.csv *.txt *.py *.png /S /DCOPY:T /S /NDL /NS /NC /NJH /NJS /NP