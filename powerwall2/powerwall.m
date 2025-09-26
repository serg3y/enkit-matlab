% Examples:
% T = powerwall().getData({'2019-04-06' '2019-04-08'});
% T = powerwall().getData({'2019-01-01' 0});

classdef powerwall

    properties
        data_fold = fullfile(fileparts(mfilename('fullpath')), 'data') % Data foler
        download = 1 % allow missing files to be downloaded
        refresh_token
        access_token
        site_id % device id
        site_info
        time_zone = 'Australia/Adelaide'
    end

    methods

        function obj = powerwall(varargin)
            % Class constructor

            % Apply ini settings
            ini = fullfile(fileparts(mfilename('fullpath')), 'powerwall.ini');
            if isfile(ini)
                txt = fileread(ini);
                for prop = string(properties(obj)')
                    value = regexp(txt, "(?<=^\s*" + prop + "\s*=\s*)[^ \r\n]*", 'match', 'once', 'lineanchors'); % Find the value
                    if ~isempty(value)
                        obj.(prop) = strtrim(value);
                    end
                end
            end

            % Apply user settings
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k + 1};
            end

            obj = obj.authenticate;
        end

        function obj = authenticate(obj, site_ind)
            if nargin<2 || isempty(site_ind), site_ind = 1; end

            % Get access_token
            data = webwrite("https://auth.tesla.com/oauth2/v3/token", struct('grant_type', 'refresh_token', 'client_id', 'ownerapi', 'refresh_token', obj.refresh_token, 'scope', 'openid email offline_access'));
            obj.access_token = data.access_token;

            % Get site_id
            data = webread("https://owner-api.teslamotors.com/api/1/products", weboptions(HeaderFields = {'Authorization' ['Bearer ' obj.access_token]}));
            info = data.response(site_ind);
            obj.site_id = num2str(info.energy_site_id);

            % Write info to file (optional)
            if ~isfolder(obj.data_fold)
                mkdir(obj.data_fold);
            end
            writelines(jsonencode(info, 'PrettyPrint', true), fullfile(obj.data_fold, obj.site_id + "_info.json"))
        end

        function T = getData(obj, span)
            % Read or download prices or usage data

            % Step through days
            T = []; % Large table to hold all data
            for day = checkdate(span{1}) : checkdate(span{end})

                % Set output file path (no extension)
                file = fullfile(obj.data_fold, sprintf('%s', obj.site_id), [char(day, 'yyyyMMdd') '.csv']);

                % Delete incomplete files
                if obj.download && isfile(file) && isStale(file, 1.1)
                    delete(file)
                end

                % Download
                if obj.download && ~isfile(file)
                    if ~isfolder(fileparts(file))
                        mkdir(fileparts(file))
                    end

                    end_date = datetime(day, 'TimeZone', obj.time_zone, 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ") + days(1) - seconds(1); % Set end_date to be 1sec before end of the day, must include correct timezone for the region including daylight savings, eg '2023-01-01T23:59:00+10:30' or '2023-01-02T09:29:00Z' (for Australia/Adelaide in summer)
                    url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + obj.site_id + "/calendar_history?kind=power&end_date=" + strrep(char(end_date), '+', '%2B');
                    disp(url + ' > ' + file) % Show progress
                    data = webread(url, weboptions(HeaderFields = {'Authorization' ['Bearer ' obj.access_token]})).response; % Download one days data
                    if ~isempty(data)
                        assert(isequal(data.installation_time_zone, end_date.TimeZone), "Set TimeZone to '%s'", data.installation_time_zone) % Check that time zones match (optional)
                        data = struct2table(data.time_series); % Convert data to a table
                        data(:, 2:end) = round(data(:, 2:end), 3); % Round values to 3 decimal places (optional)
                        writetable(data, file) % Write to csv
                        pause(1) % Avoid "Too Many Requests"
                    end

                end

                % Read file
                if isfile(file)
                    t = readtable(file);
                    if ~ismember(size(t,1), [288 276 300]) && size(t,1)>0
                        fprintf('%s n=%g [%s %s]\n', file, size(t,1), t.timestamp{[1 end]})
                    end
                    disp(size(t, 1))
                    T = [T; t]; %#ok<AGROW>
                end
            end

            T.timestamp = datetime(strrep(T.timestamp, 'T', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ssZ', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+09:30');

        end

        function downloadForecastPeriodicaly(obj)
            % Periodically downloads price forecasts, every 5 min.
            %   amber().downloadForecastPeriodicaly
            % - Downloads 24 hrs @ 30 min data and 1 hr @ 5 min.
            % - Downloads are delayed by 30 sec after the 5 minute mark,
            %   because prices tend to update near the start of the mark.
            % - Downloads are further delayed by a random offset, in the
            %   range of 0-15 sec, to be nice to the server.
            period = 5; % Delay between downloads (min)
            rand_offset = rand*0.25; % 15 sec
            while true
                now_local = datetime('now');
                offset = minutes(period - mod(minute(now_local), period) + 0.5 + rand_offset);
                next_local = dateshift(now_local, 'start', 'minute') + offset; % Wait 1-2 min past the mark, to ensure prices are updated and polling is randomised
                fprintf(' Next download: %s\n', next_local) % Progress
                pause(seconds(next_local - now_local))
                try
                    obj.downloadForecastOnce([48 48], 30); % Download 24 hr @ 30 min
                    obj.downloadForecastOnce([12 12],  5); % Download 1 hr @ 5 min (optional)
                end
            end
        end

        function file = downloadForecastOnce(obj, span, rez)
            % Download current price forecast, once.
            %   amber().downloadForecastOnce(span, rez)
            % - File name is nem time at start of download.
            % - Prints local time to screen.
            fold = fullfile(obj.data_fold, 'forecast', sprintf('%s_%gmin', obj.state, rez), 'raw');
            if ~isfolder(fold)
                mkdir(fold);
            end
            start_time = datetime('now', 'TimeZone', 'local'); % Download start time (local)
            [err, json] = obj.geturl(sprintf('https://api.amber.com.au/v1/sites/%s/prices/current?previous=%g&next=%g&resolution=%g', obj.siteId, span, rez)); % Download
            d = jsondecode(json);
            start_time.TimeZone = d{1}.nemTime(end-5:end); % Switch to nem time zone
            file = fullfile(fold, [char(start_time, 'yyyyMMdd_HHmmss') '.json']);
            filewrite(file, json)
            if err
                fprintf(2, 'Error: %s\n', json) % Print errors to screen
            end
        end

        function [err, msg] = geturl(obj, url)
            % Delay to avoid friquent downloads
            persistent time_of_last_download
            delay_between_downloads = 5; % (sec)
            if isempty(time_of_last_download)
                time_of_last_download = NaT;
            end
            pause(seconds(time_of_last_download + seconds(delay_between_downloads) - datetime)) 
            time_of_last_download = datetime;

            % Download
            cmd = sprintf('curl -sS -X GET "%s" -H "Authorization: Bearer %s"', url, obj.token); % curl download command
            fprintf(1, ' %s\n', cmd); % Display comman on screen
            [err, msg] = system(cmd); % Run command

            % Check for errors
            if ~err && numel(msg) > 2
                if msg(1) ~= '{' && numel(msg)<200
                    err = 1;
                elseif numel(msg)<1000
                    data = jsondecode(msg);
                    if isfield(data, 'message')
                        err = 1;
                        msg = data.message;
                    end
                end
            end
        end
    end
end

function day = checkdate(day, default_timezone)
% Ensure day is a date.
if isnumeric(day) && day<1000
    day = datetime + day; % day is an offset
elseif isnumeric(day)
    day = datetime(day, 'ConvertFrom', 'datenum'); % day is datenum
elseif ~isdatetime(day)
    day = datetime(day); % day is string
end
day = dateshift(day, 'start', 'day');
if nargin>1
    day.TimeZone = default_timezone;
end
end

function tf = isIncomplete(file)
fid = fopen(file, 'r');
fseek(fid, -100, 'eof'); % Read last 100 bytes in file
tf = ~contains(fread(fid, Inf, '*char')', 'T23:55:00'); % Check file end
fclose(fid);
end

function tf = isStale(file, thresh)
[~, name] = fileparts(file);
dt = datetime(name, 'InputFormat', 'yyyyMMdd');
tf = dt + thresh > datetime(dir(file).date);
end