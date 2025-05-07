% Periodically downloads Amber price forecasts.
% - Downloads 24 hrs @ 30 min and 1 hr @ 5 min, every 5 minutes.
% - Delay download by 30-45 sec, after the 5 minute mark, to ensure
%     prices update and to be nice to server. 
% - File name is NEM time (+1000) at start of download, eg
%     forecast\sa_30min\json\20250403_013132.json

txt = fileread('amber.ini');
state  = regexp(txt, '(?<=state\s*=\s*)\S+',  'match', 'once')
siteId = regexp(txt, '(?<=siteId\s*=\s*)\S+', 'match', 'once')
token  = regexp(txt, '(?<=token\s*=\s*)\S+',  'match', 'once')
period = 5; % Delay between downloads (min)
rand_delay = seconds(15)*rand; % random delay, 0-15 sec

while true
    system_time = datetime('now');
    offset = minutes(period - mod(minute(system_time), period) + 0.5) + rand_delay; % Delay to ensure prices update and polling is randomised
    download_time = dateshift(system_time, 'start', 'minute') + offset; %
    disp(['Next download: ' char(download_time)]) % Progress
    pause(seconds(download_time - system_time))
    try
        download_amber_forecast_once(state, siteId, token, [48 48], 30); % Download ±24 hr @ 30 min
        download_amber_forecast_once(state, siteId, token, [12 12],  5); % Download ±1 hr @ 5 min
    catch ex
        fprintf(2, '%s\n', ex.message) % Print errors to screen
    end
end

function file = download_amber_forecast_once(state, siteId, token, span, rez)
% Download current Amber price forecast.

fold = fullfile('forecast', sprintf('%s_%s_%gmin', 'forecast', state, rez), 'json');
if ~isfolder(fold)
    mkdir(fold);
end

% Download
start_time = datetime('now', 'TimeZone', '+1000'); % System time
file = fullfile(fold, [char(start_time, 'yyyyMMdd_HHmmss') '.json']);
url = sprintf('https://api.amber.com.au/v1/sites/%s/prices/current?previous=%g&next=%g&resolution=%g', siteId, span, rez);
cmd = sprintf(' curl -sS -X GET "%s" -H "Authorization: Bearer %s" -o "%s"', url, token, file); % curl command
disp(cmd) % Progress
system(cmd); % Download
end
