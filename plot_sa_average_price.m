T = aemo().getPrice("SA", {'2024-07-01' '2025-05-01'}, 5, {'time' 'spot'});
[T.tod, T.date] = timeofday2(T.time);
g = groupsummary(T, 'tod', @mean, 'spot');
x = g.tod;
y1 = g.fun1_spot;
y2 = tariffs('RTOU', g.tod);
y3 = tariffs('RELE2W', g.tod);

fig(3, 'dark', 'handy')
subplot(2,1,1)
plotspread2(gca, x, y2, [], [1 1 0], 'RTOU tariff + other fees')
plotspread2(gca, x, y3, [], [0 1 1], 'RELE2W tariff + other fees')
ylim([-5 85])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'c/kWh'
xlabel 'NEM Time (+10:00)'
title 'SA Tariffs and Other Fees (2024-07-01 to 2025-05-01)'
legend show location NW

subplot(2,1,2)
plotspread2(gca, x, y1, [],    [1 0.7 1], 'AEMO avg. spot price');
plotspread2(gca, x, y1, y1+y2, [1 1 0], ' + RTOU tariff + other fees');
plotspread2(gca, x, y1, y1+y3, [0 1 1], ' + RELE2W tariff + other fees');
ylim([-5 85])
xlim(duration([0 24], 0, 0))
set(gca, 'XTick', duration(0:4:24, 0, 0))
ylabel 'c/kWh'
xlabel 'NEM Time (+10:00)'
title 'SA Avg. Electricity Price (2024-07-01 to 2025-05-01)'
legend show location NW

linkallaxes
figsave(gcf, 'plot_sa_average_price.png', [800 600])

%%
!robocopy "D:\MATLAB\enkit\aemo" "D:\s3rg3y\Share\enkit\aemo" *.csv *.txt *.py *.png /S /DCOPY:T /S /NDL /NS /NC /NJH /NJS /NP