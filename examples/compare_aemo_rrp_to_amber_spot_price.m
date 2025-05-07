T1 = readtable('D:\MATLAB\enkit\aemo\SA\PRICE_AND_DEMAND_202501_SA1.csv');
T1.time = datetime(T1.SETTLEMENTDATE, 'InputFormat','uuuu/MM/dd HH:mm:ss', 'Format','yyyy-MM-dd HH:mm');
T1.time.TimeZone = '+1000';
T1.time = T1.time - minutes(5);
T1.RRP = (T1.RRP/10)*1.1;

T2 = amber().getData('prices', {'2025-01-01' '2025-01-30'}, 5);
T2.time = T2.start;

T = innerjoin(T1, T2, 'keys', 'time')

clf, hold on
plot(T.RRP, T.spot_price-T.RRP, '.')
% plot(T2.start, T2.spot_price./(T1.RRP/10))