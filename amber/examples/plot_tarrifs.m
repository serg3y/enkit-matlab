tod = duration(0:0.5:23.5,0,0, 'Format', 'hh:mm');

figmode(2, 'dark', 'handy')
plotsteps(gca, tod, tariffs('amber RTOU', datetime('2025-07-02') + tod), [], 'AMBER RTOU 2025',  [], [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('amber RTOU', datetime('2024-07-02') + tod), [], 'AMBER RTOU 2024',  [], [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('amber relew', datetime('2024-07-02') + tod), [], 'AMBER RELEW 2024', [], [], 'linewidth', 2)
ylim([0 80])
xlim([min(tod) max(tod)])
ylabel 'c/kWh'
title 'Net Fees (ex. GST)'
legend show location SO
figsave(gcf, 'Fees - SA Amber.png', [1200 800])


%% Others
tod = duration(0:0.5:23.5, 0, 0, 'Format', 'hh:mm');

figmode(1, 'dark', 'handy')
plotsteps(gca, tod, tariffs('AGL SK',    datetime('2024-07-02') + tod), [], 'AGL SK 2024',     [], [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('Origin JS', datetime('2024-07-02') + tod), [], 'Origin JS 2024',  [], [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('Origin JS', datetime('2025-07-02') + tod), [], 'Origin JS 2025',  [], [], 'linewidth', 2)
ylim([0 80])
xlim([min(tod) max(tod)])
ylabel 'c/kWh'
title 'Fees (ex. GST)'
legend show location SO
figsave(gcf, 'Fees - SA Others.png', [1200 800])
