% Periodically downloads Amber price forecasts.
% - Downloads 24 hrs @ 30 min and 1 hr @ 5 min, every 5 minutes.
% - Delay download by 30-45 sec, after the 5 minute mark, to ensure
%     prices update and to be nice to server. 
% - File name is NEM time (+1000) at start of download, e.g.
%     data/forecast_sa_30min/json/20250403_013132.json

txt = fileread('amber.ini');
state  = regexp(txt, '(?<=state\s*=\s*)\S+',  'match', 'once');
siteId = regexp(txt, '(?<=siteId\s*=\s*)\S+', 'match', 'once');
token  = regexp(txt, '(?<=token\s*=\s*)\S+',  'match', 'once');
period = 5; % Delay between downloads (min)
rand_delay = seconds(15)*rand; % random delay, 0-15 sec

while true

    % Wait till next download time
    system_time = datetime('now');  % Current time (local timezone)
    offset = minutes(period - mod(minute(system_time), period) + 0.5) + rand_delay; % Delay to ensure prices update and polling is randomised
    download_time = dateshift(system_time, 'start', 'minute') + offset; %
    fprintf('\nNext download: %s\n', char(download_time)) % Progress
    pause(seconds(download_time - system_time))

    % Initiate downloads
    try
        download_amber_forecast_once(state, siteId, token, [48 48], 30); % Download ±24 hr @ 30 min
        download_amber_forecast_once(state, siteId, token, [12 12],  5); % Download ±1 hr @ 5 min
    catch ex
        fprintf(2, '%s\n', ex.message) % Print errors to screen
    end
end


function file = download_amber_forecast_once(state, siteId, token, span, rez)

% Prepare folder and filename
out_fold = fullfile(fileparts(mfilename('fullpath')), 'data', sprintf('%s_%s_%gmin', 'forecast', state, rez), 'json');
if ~isfolder(out_fold)
    mkdir(out_fold);
end
start_time = datetime('now', 'TimeZone', '+1000'); % NEM time, derived from system time
start_time = dateshift(start_time, 'start', 'minute') - minutes(mod(minute(start_time), 45)); % Round down to nearest 5 min
file = fullfile(out_fold, [char(start_time, 'yyyyMMdd_HHmm') '.json']);

% Build and run curl command
url = sprintf('https://api.amber.com.au/v1/sites/%s/prices/current?previous=%g&next=%g&resolution=%g', siteId, span, rez);
cmd = sprintf('curl -sS -X GET "%s" -H "Authorization: Bearer %s" -o "%s"', url, token, file);
fprintf(' %s\n > %s\n', url, file) % Progress
system(cmd); % Download
end
