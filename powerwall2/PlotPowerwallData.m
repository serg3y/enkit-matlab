files = dir('C:\Powerwall\2282236\*.csv');
files = fullfile({files.folder}, {files.name});

for k = 1 : numel(files)
    t = readtable(files{k});
    t.timestamp = datetime(strrep(t.timestamp, 'T', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ssZ', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+09:30');
    if ~ismember(size(t,1), [288 276 300]) && size(t,1) > 0
        fprintf('%s n=%g [%s %s]\n', files{k}, size(t,1), t.timestamp([1 end]))
    end
    % t.home_usage = t.solar_power + t.battery_power + t.grid_power;
    % plot(t.home_usage), drawnow
end


% curl --request GET --header 'Authorization: Bearer <insert token here> 'https://owner-api.teslamotors.com/api/1/energy_sites/<site id here>/calendar_history?kind=power&end_date=2020-12-17T07%3A59%3A59.999Z'
% https://teslamotorsclub.com/tmc/threads/getting-daily-production-from-tesla-gateway-api.190973/