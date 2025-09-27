%% Inputs
span = {'2024-08-01' '2025-07-31'};
tariff = 'RTOU_B'; %'RTOU' 'RELE2W'
state = "SA";

%% Get data
T = aemo().getPrice(state, span, 5, {'start' 'spot'});
[T.tod, T.date] = timeofday2(T.start);
T.month = month(T.date);

%% Spot + Tariff
g = groupsummary(T, 'tod', @mean, 'spot');
x = g.tod;
y_spot = g.fun1_spot;
y_tariff = tariffs(tariff, g.tod);

fig(1, 'dark', 'handy')
plotspread2(gca, x, y_spot + y_tariff, [], [1 1 0], state);
ylim([-5 75])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Price (c/kWh)'
title 'Average wholesale price (2024-08-01 to 2025-07-31)'
xlabel 'Time of day (+10h)'
legend show location NW

figsave(gcf, 'plots\sa_average_price_simple.png', [1200 800])

%% Tariff
g = groupsummary(T, 'tod', @mean, 'spot');
x = g.tod;
y_spot = g.fun1_spot;
y_tariff = tariffs(tariff, g.tod);

fig(1, 'dark', 'handy')
subplot(221)
plotspread2(gca, x, y_tariff, [], [0 1 0], 'Tariff')
ylim([-5 75])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Price (c/kWh)'
xlabel 'Time of day (+10h)'
legend show location NW

% Spot
subplot(223)
plotspread2(gca, x, y_spot, [], [1 1 0], 'Spot')
ylim([-5 75])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Price (c/kWh)'
xlabel 'Time of day (+10h)'
legend show location NW

% Tariff + Spot
subplot(222)
plotspread2(gca, x, y_tariff, y_spot + y_tariff, [1 1 0], 'Tariff');
plotspread2(gca, x, y_tariff, [], [0 1 0], 'Spot Price');
ylim([-5 75])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Price (c/kWh)'
xlabel 'Time of day (+10h)'
legend show location NW

% Spot + Tariff
subplot(224)
plotspread2(gca, x, y_spot, y_spot + y_tariff, [0 1 0], 'Tariff');
plotspread2(gca, x, y_spot, [], [1 1 0], 'Spot');
ylim([-5 75])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'Price (c/kWh)'
xlabel 'Time of day (+10h)'
legend show location NW

linkallaxes
figsave(gcf, 'plots\sa_average_price.png', [800 600])

%% Monthly
fig(3, 'dark', 'handy')

for m = 1:12
    g = groupsummary(T(month(T.date) == m,:), {'month' 'tod'}, @mean, 'spot');
    x = g.tod;
    y = g.fun1_spot + tariffs(tariff, g.tod);
    c = interp1(linspace(-5, 55, 100), jet(100), mean(y)); % interpolate colors
    t = string(datetime(2025, m, 1), 'MMM  ') + round(mean(y),1) + "c";

    plotsteps(gca, x, y, c, t);
    plotspread2(gca, x, y, [], c, t,'FaceAlpha',0.04,'HandleVisibility','off');
    ylim([-5 180])
    xlim(duration([0 24], 0, 0))
    set(gca, 'XTick', duration(0:4:24, 0, 0))
    ylabel 'Price (c/kWh)'
    xlabel 'Time of day (+10h)'
    legend show location NW
end

linkallaxes
figsave(gcf, 'plots\sa_average_price_monthly.png', [800 600])

%%
%!robocopy "D:\MATLAB\enkit\aemo" "D:\s3rg3y\Share\enkit\aemo" *.csv *.txt *.py *.png /S /DCOPY:T /S /NDL /NS /NC /NJH /NJS /NP