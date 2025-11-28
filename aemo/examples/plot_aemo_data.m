%% Plot AEMO 'RRP' Price and 'Total Demand' Data

% Time span for data
% span = {'2021-10-01', -1}; % 2021-10-01 is when data switched to 5 min
span = {'2025-06-01', '2025-07-01'}; % Spike
span = {-365, -1}; % Last year

% States and values to plot
states = ["NSW", "QLD", "VIC", "SA", "TAS"];
states = ["NSW"];
values = ["rrp", "TOTALDEMAND"];
values = ["rrp"];

%% Plot setup
figmode(-1, 'dark', 'handy')  % Custom figure mode
gamma = 40;

for k = 1:numel(states)
    % Prepare data
    T = aemo().getPrice(states{k}, span, {'time', 'rrp', 'TOTALDEMAND'});
    % T = aemo().resample(T, 30);  % 30-minute intervals
    [T.tod, T.date] = timeofdaylocal(T.time);  % Extract time-of-day and date
    
    for j = 1:numel(values)
        % Prepare subplot layout
        axis_stack(k, numel(states), j, numel(values), [0.04, 0.04, 0.08, 0.04])
        ylabel(states{k})
        
        % Configure axes, colormap, and colorbar based on value type
        switch values{j}
            case 'rrp'
                if gamma ~= 1
                    cspan = [-2000 2000];
                    ticklabels = [-2000 -100 -50 -10 0 10 50 100 2000];
                    [cmap, ticks] = cold2hot(10000, gamma, ticklabels);
                    plotheatmap(T.date, T.tod, T.(values{j}),[], [], [], cspan, cmap)
                    clim(cspan)
                    colormap(gca, cold2hot(256))
                    c = colorbarsml('c/kWh');
                    set(c, 'Ticks', ticks,'TickLabels',  ticklabels)
                else
                    plotheatmap(T.date, T.tod, T.(values{j}))
                    clim([-200, 200])
                    colormap(gca, cold2hot)
                    colorbarsml('c/kWh')
                end
                if k == 1
                    title('RRP Price')
                end
            case 'TOTALDEMAND'
                plotheatmap(T.date, T.tod, T.(values{j}))
                clim([0, inf])
                colormap(gca, jet)
                colorbarsml('MW')
                if k == 1
                    title('Total Demand')
                end
        end
    end
end
linkallaxes()
ylim(duration([0.001, 24], 0, 0)) % Set y-axis limits for time-of-day

return
%% Save figure
figsave(1, 'plot_aemo_data.png', [1920, 1080])

%% Copy data and plots to Google Drive (Windows command)
% !robocopy "D:\MATLAB\enkit\aemo" "D:\s3rg3y\Share\enkit\aemo" *.csv *.txt *.py *.png /S /DCOPY:T /S /NDL /NS /NC /NJH /NJS /NP
