tod = duration(0:0.5:23.5,0,0, 'Format', 'hh:mm');
fig(1, 'dark', 'handy')
plotsteps(gca, tod, tariffs('RTOU_B', datetime(2025, 7, 2) + tod), [], 'AMBER RTOU 2025',  [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('RTOU_B', datetime(2024, 7, 2) + tod), [], 'AMBER RTOU 2024',  [], 'linewidth', 2)
plotsteps(gca, tod, tariffs('RELE2W', datetime(2024, 7, 2) + tod), [], 'AMBER RELEW 2024', [], 'linewidth', 2)
% plotsteps(gca, tod, tariffs('AGL'   , datetime(2024, 7, 2) + tod), [], 'AGL 2024',         [], 'linewidth', 2)
ylim([0 60])
xlim([min(tod) max(tod)])
ylabel 'c/kWh'
title 'Net Fees (ex. GST)'
legend show location SO
figsave(gcf, 'Net Fees Amber SA.png', [1200 800])


%
%   aemo_rrp_
%   spot = (RRP / 10) * 1.1
%   price = spot * 1.1105195 + (tariff + 4.4502) * 1.1