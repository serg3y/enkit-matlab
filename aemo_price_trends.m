load('C:\MATLAB\enkit\gui\data\AEMO.mat', 'T')

%% Correct for inflation
T.sa_price_n  = T.sa_price ./T.inflation;
T.nsw_price_n = T.nsw_price./T.inflation;
T.qld_price_n = T.qld_price./T.inflation;
T.vic_price_n = T.vic_price./T.inflation;
T.tas_price_n = T.tas_price./T.inflation;
save('C:\MATLAB\enkit\gui\data\AEMO_normalised.mat', 'T')
 
%% Usage weighted price
t = table(datetime(1999:2026,1,1, 'TimeZone', '+1000')', 'VariableNames', {'year'});
for k = 1:height(t)
    i = T.time >= t.year(k) & T.time < t.year(k) + 1;
    T.sa_price_nw (i) = T.sa_price_n (i).*T.sa_usage (i) ./ mean(T.sa_usage (i));
    T.nsw_price_nw(i) = T.nsw_price_n(i).*T.nsw_usage(i) ./ mean(T.nsw_usage(i));
    T.qld_price_nw(i) = T.qld_price_n(i).*T.qld_usage(i) ./ mean(T.qld_usage(i));
    T.vic_price_nw(i) = T.vic_price_n(i).*T.vic_usage(i) ./ mean(T.vic_usage(i));
    T.tas_price_nw(i) = T.tas_price_n(i).*T.tas_usage(i) ./ mean(T.tas_usage(i)); 
end
save('C:\MATLAB\enkit\gui\data\AEMO_normalised_weighted.mat', 'T')

return
%%
T.year = year(T.time);
groupsummary(T, 'year', @mean, {'nsw_price_normalised_weighted'})

%%
