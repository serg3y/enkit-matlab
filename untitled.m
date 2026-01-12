%%
T = powerwall2().read({'2019-01-01' 0});

%%

total_los_kwhperday = -sum(T.battery_kwh) / days(range(T.time))


%%
ind = T.battery_kwh>0;
w(ind)=1.08;
w(~ind)=0.89;

T.SOC = 5 + cumsum(T.battery_kwh.*w');

%%
clf,
ax(1) = subplot(211); plot(T.time, T.SOC)
ax(2) = subplot(212); plot(T.time, T.battery_kwh)

linkaxes(ax,'x')

function cost = costFun(v, c1, c2)
cost = predictSoc(v, c1, c2) - 6;
end

function soc = predictSoc(v, c1, c2)
ind = v>0;
w(ind) = 1 + c1;
w(~ind) = 1 - c2;
soc = 6 + cumsum(v.*w' + c2);
end