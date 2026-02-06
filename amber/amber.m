% Amber API cannot handle partial days. This wrapper does same.

% Examples:
% amber().getSites
% amber().download({'2026-01-01' 0})

% T = amber().getPrices({'2024-11-01' '2024-12-01'})
% T = amber().getUsage({'2025-06-01' '2026-06-01'})
% amber().downloadForecastPeriodicaly

% Remarks:
% "usage" is not available for current data and possibly last day
% "prices" includes forecasts when time span includes future periods

% Links
% SA Power dashboard: https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard

classdef amber

    properties
        datafold = fullfile(fileparts(mfilename('fullpath')), 'data')
        token
        siteId
        state
        nmi
        startDate
    end

    methods

        function obj = amber(varargin)
            % Class constructor

            % Select ini file
            if nargin==1
                ini = varargin{1};
                varargin{1} = [];
            else
                ini = fullfile(fileparts(mfilename('fullpath')), 'amber.ini');
            end

            % Read ini file
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
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k + 1};
            end

            % Download siteId, if needed
            if isempty(obj.siteId)
                site = obj.getSites;
                disp(site)
                disp(site.channels)
                obj.siteId = site.id;
                fprintf(2, 'To skip this step assign "siteId" property in "amber.ini" file to the "id" value above.\n')
                pause(1)
            end
        end

        function data = getSites(obj)
            % Download site information
            [err, json] = obj.geturl('https://api.amber.com.au/v1/sites');
            assert(~err, '%s', json) % Abort if error

            % Parse data
            data = jsondecode(json);
            if isfield(data, 'channels') % Convert channels field to a table of strings
                t = varfun(@string, struct2table(data.channels));
                t.Properties.VariableNames = fieldnames(data.channels);
                data.channels = t;
            end
        end

        function T = getUsage(obj, span)
            T = downloadData(obj, 'usage', span, 5);
        end

        function T = getPrices(obj, span)
            T = downloadData(obj, 'prices', span, 5);
        end

        function T = downloadData(obj, type, span)
            % Download prices or usage data

            % Initialise
            T = {};
            for day = checkdate(span(1)) : checkdate(span(end))
                % Ignore time zones
                day.TimeZone = '';

                % Skip if day is before startDate
                if ~isempty(obj.startDate) && day < datetime(obj.startDate)
                    continue
                end

                % Choose identifier depending on type
                switch type
                    case 'usage', t = sprintf('%s_%s_%s', type, obj.state, obj.nmi);
                    case 'prices', t = sprintf('%s_%s', type, obj.state);
                end

                % File path
                file = fullfile(obj.datafold, t, [char(day, 'yyyyMMdd') '.json']);
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % Delete file if its stale
                if isfile(file)
                    info = dir(file);
                    t = datetime(info.date);
                    if t < day + days(1) + hours(1) && t + minutes(30) < datetime('now') % check if stale
                        delete(file);
                    end
                end

                % Download file if required
                if ~isfile(file)
                    url_span = sprintf('startDate=%s&endDate=%s', char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd'));
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span];
                    [err, data] = obj.geturl(url);

                    if err
                        fprintf(2, 'Warning: %s\n', data);
                        continue
                    end

                    filewrite(file, data);
                end

                % Skip if no data
                if numel(file) <= 2
                    fprintf('  %s - no data\n', day);
                    continue
                end

                % Convert json to table and store
                T{end+1} = readDataFile(file, type); %#ok<AGROW>
            end

            % Combine all tables
            if isempty(T)
                T = table(); % return empty if nothing collected
            else
                T = vertcat(T{:});
            end
        end

        function download(obj, span, type)
            % Download prices or usage data
            if nargin < 3 || isempty(type), type = 'prices'; end

            % Initialise
            dayvec = checkdate(span(1), '') : checkdate(span(end), '');

            % Step through days
            for k = 1:numel(dayvec)                
                % Skip if day is before startDate
                if ~isempty(obj.startDate) && dayvec(k) < datetime(obj.startDate)
                    continue
                end

                % File path
                switch type
                    case 'usage', t = sprintf('%s_%s_%s', type, obj.state, obj.nmi);
                    case 'prices', t = sprintf('%s_%s', type, obj.state);
                end
                file = fullfile(obj.datafold, t, [char(dayvec(k), 'yyyyMMdd') '.json']);
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % Delete file if its stale
                if isfile(file)
                    info = dir(file);
                    t = datetime(info.date);
                    if t < dayvec(k) + days(1) + hours(1) && t + minutes(30) < datetime('now')
                        delete(file);
                    end
                end

                % Download file, if required
                if ~isfile(file)
                    url_span = sprintf('startDate=%s&endDate=%s', char(dayvec(k), 'yyyy-MM-dd'), char(dayvec(k), 'yyyy-MM-dd'));
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span];
                    [err, data] = obj.geturl(url);

                    if err
                        fprintf(2, 'Warning: %s\n', data); 
                        continue
                    end

                    % Save data to file
                    filewrite(file, data);
                end
            end
        end

        function T = read(obj, span, type)
            % Read prices or usage data
            if nargin < 3 || isempty(type), type = 'prices'; end

            % Initialise
            dayvec = checkdate(span(1), '') : checkdate(span(end), '');
            T = cell(size(dayvec));

            % Step through files
            for k = 1 : numel(dayvec)

                % File path
                switch type
                    case 'usage', t = sprintf('%s_%s_%s', type, obj.state, obj.nmi);
                    case 'prices', t = sprintf('%s_%s', type, obj.state);
                end
                file = fullfile(obj.datafold, t, [char(dayvec(k), 'yyyyMMdd') '.json']);

                % Read data
                if isfile(file)
                    T{k} = readDataFile(file, type);
                end
            end

            % Make one table
            T = vertcat(T{:});
        end

        function downloadForecastPeriodicaly(obj)
            % Periodically downloads price forecasts, every 5 min.
            % - Downloads 24 hrs @ 30 min data and 1 hrs @ 5 min.
            % - Downloads are delayed by 30 sec after the 5 minute mark to
            %   allow for prices to be published.
            % - Downloads are further delayed by a random offset, in the
            %   range of 0-15 sec, to be nice to the server.
            period = 5; % Time between downloads (min)
            rand_offset = rand*0.25; % random delay of 0-15 (sec)
            while true
                now_local = datetime('now');
                offset = minutes(period - mod(minute(now_local), period) + 0.5 + rand_offset);
                next_local = dateshift(now_local, 'time', 'minute') + offset; % next download time (local time)
                fprintf(' Next download: %s\n', next_local) % Progress
                pause(seconds(next_local - now_local))
                try
                    obj.downloadForecastOnce([48 48], 30); % Download 24 hr @ 30 min
                    obj.downloadForecastOnce([12 12],  5); % Download 1 hr @ 5 min (optional)
                catch ex
                    fprintf(2, 'ERROR: %s\n', ex.message)
                end
            end
        end

        function file = downloadForecastOnce(obj, span, rez)
            % Download current price forecast, once.
            %   amber().downloadForecastOnce(span, rez)
            % - File name is nem time at start of download.
            % - Prints local time to screen.
            fold = fullfile(obj.datafold, 'forecast', sprintf('%s_%gmin', obj.state, rez), 'raw');
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

        function T = readForecastData(obj, span, rez, forecast_limit)
            % Read multiple forecast files based on time span

            if nargin<4 || isempty(forecast_limit)
                forecast_limit = [];
            end

            % List all data files
            filt = fullfile(obj.datafold, sprintf('forecast_%s_%gmin', obj.state, rez), 'json', '*.json');
            all_files = dir(filt);
            assert(~isempty(all_files), 'No data files matching "%s"', filt)

            % Extract time from filename
            all_times = datetime(extractBetween({all_files.name}, 1, 13), 'InputFormat', 'yyyyMMdd_HHmm');

            T = [];
            for day = checkdate(span{1}) : checkdate(span{2})

                parquet = fullfile(obj.datafold, sprintf('forecast_%s_%gmin', obj.state, rez), [char(day, 'yyyyMMdd') '.parquet']);

                if isfile(parquet)
                    t = datetime(dir(parquet).date);
                    if t + days(2) > span{2} && t + minutes(4) < datetime
                        fprintf(' Deleteing %s\n', parquet)
                        delete(parquet)
                    end
                end

                if isfile(parquet)
                    t = parquetread(parquet);
                else
                    % Read files on time (approx)
                    files = all_files(all_times >= day - 1 & all_times <= day + 1.1);
                    files = fullfile({files.folder}, {files.name});
                    t = cellfun(@readForecastFile, files, 'UniformOutput', false);
                    t = vertcat(t{:});

                    if ~isempty(t)
                        % Remove duplicates
                        t.forecast = max(t.forecast, duration(0, -rez, 0)); % Treat all historic data equally
                        t = unique(t, 'rows');

                        % Filter data on time
                        day.TimeZone = t.time.TimeZone;
                        t = t(t.time >= day & t.time < day + 1, :);
                        parquetwrite(parquet, t); % Save cache
                    end
                end
                T = [T; t];
            end

            if isempty(T)
                return
            end

            T.forecast.Format = 'hh:mm';

            % Filter on time span
            time_zone = T.time.TimeZone;
            T = T(T.time >= checkdate(span{1}, time_zone) & T.time < checkdate(span{2}, time_zone), :);

            % Filter on forecast duration
            if ~isempty(forecast_limit)
                T = T(T.forecast < duration(forecast_limit, 0, 0), :);
            end

            T = sortrows(T, {'time' 'query' 'forecast'}); % Sort on time fields
        end

        function [err, msg] = geturl(obj, url)
            % Delay to avoid "Error: Too many requests"
            persistent time_of_last_download
            delay_between_downloads = 10; % (sec)
            if isempty(time_of_last_download)
                time_of_last_download = NaT;
            end
            pause(seconds(time_of_last_download + seconds(delay_between_downloads) - datetime))
            time_of_last_download = datetime;

            % Download
            cmd = sprintf('curl -sS -X GET "%s" -H "Authorization: Bearer %s"', url, obj.token); % curl download command
            fprintf(1, ' %s\n', cmd); % Display command
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

function T = readDataFile(file, type)
% Read a prices or usage JSON data file and output a table.

% Defaults
if nargin<2 || isempty(type), type = 'prices'; end

% Read file
data = jsondecode(fileread(file));

% Convert to array of structs
if iscell(data)
    for k = 1:numel(data)
        if isfield(data{k}, 'tariffInformation')
            data{k} = rmfield(data{k}, 'tariffInformation'); % provides forecast price, in "prices" and in "usage" endpoints
        end
        if isfield(data{k}, 'advancedPrice')
            data{k} = rmfield(data{k}, 'advancedPrice'); % provides forecast price, in "prices" endpoints
        end
        if isfield(data{k}, 'estimate')
            data{k} = rmfield(data{k}, 'estimate'); % indicates if record is an estimate in in "prices" endpoints
        end
    end
    data = [data{:}];
end

% Make a table
T = struct2table(data);

% Parse time
T.startTime = datetime(T.startTime, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'Format','yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
T.endTime = datetime(T.endTime, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'Format','yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
T.startTime = dateshift(T.startTime, 'start', 'minute'); % Round time to nearest minute

% Remove endTime
T.endTime = [];

% Convert from UTC to nemTime (+10h)
timezone = T.nemTime{1}(end-5:end);
T.startTime.TimeZone = timezone;

switch type

    case 'prices'
        % Remove predictions
        T = T(T.type == "ActualInterval", :);

        % Remove junk columns
        T = T(:, {'startTime' 'perKwh' 'spotPerKwh' 'renewables' 'channelType'});

        % Use positive values for feed-in
        T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

        % Convert channelType from rows to columns
        T = unstack(T, {'perKwh' 'spotPerKwh'}, 'channelType');

        % There is no difference between buy & sell spot prices
        T(:, {'spotPerKwh_controlledLoad'}) = [];
        try
            T(:, {'spotPerKwh_feedIn'}) = []; %HACK for edge case with missing columns on 2024-11-29
        catch
            T.sell_price = zeros(size(T,1), 1); %HACK
        end

        % Improve column names
        T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'startTime' 'perKwh_general' 'perKwh_controlledLoad' 'perKwh_feedIn' 'spotPerKwh_general'}, {'time' 'buy_price' 'buy2_price' 'sell_price' 'spot_price'});

        % Re-order columns
        % T = movevars(T, {'buy_price' 'buy2_price' 'sell_price' 'spot_price' 'renewables'}, 'After', 'duration');

    case 'usage'
        % Remove predictions
        T = T(T.type == "Usage", :);

        % Remove junk columns
        T = T(:, {'startTime' 'kwh' 'perKwh' 'channelType'});

        % Use positive values for feed-in
        T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

        % Convert channelType from rows to columns
        T = unstack(T, {'kwh' 'perKwh'}, 'channelType');

        % Improve column names
        T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'(.*)_(.*)' 'general' 'feedIn' 'controlledLoad' '_perKwh' 'kwh' 'Time'}, {'$2_$1' 'buy' 'sell' 'buy2' '_price' 'amount' ''});

        % Re-order columns
        % T = movevars(T, {'buy_amount' 'buy_price' 'sell_amount' 'sell_price' 'buy2_amount' 'buy2_price'}, 'After', 'duration');
end
end

function T = readForecastFile(file)
% Read forecast JSON file and convert it to a table.

% Read file
data = fileread(file);

% Check
if isequal(data, '{"message": "Internal server error"}')
    movefile(file, [file '.error'])
    T = [];
    return
end

% Decode
data = jsondecode(data);

fields = {'type' 'startTime' 'perKwh' 'renewables' 'spotPerKwh' 'channelType' 'low' 'med' 'high'}; % Required fields
C = repmat({nan}, numel(data), numel(fields)); % Initialize cell array
for i = 1:numel(data)
    [tf, ind] = ismember(fields, fieldnames(data{i})); % Find required fields
    t = struct2cell(data{i});
    C(i, tf) = t(ind(tf)); % Copy required fields
    if isfield(data{i}, 'advancedPrice')
        C(i, end-2:end) = struct2cell(data{i}.advancedPrice); % forecast data
    else
        C(i, end-2:end) = repmat({data{i}.perKwh}, 1, 3);
    end
end
T = cell2table(C, 'VariableNames', fields);

% Format startTime
T.startTime = datetime(extractBetween(T.startTime, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
T.startTime.TimeZone = data{1}.nemTime(end-5:end); % Use NEM time-zone

% Compute forecast period
t = data{find(cellfun(@(x)x.type == "CurrentInterval", data), 1)}.startTime;
current_time = datetime(extractBetween(t, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'TimeZone', 'UTC');
T = addvars(T, T.startTime - current_time, 'After', 'startTime', 'NewVariableNames', 'forecast');
T.forecast.Format = 'hh:mm';

% Compute query time
[~, f] = fileparts(file);
t = datetime(f, 'InputFormat', 'yyyyMMdd_HHmm');
offset = minutes(mod(minute(t) -  mod(minute(t), 5), 30)); % Round down to nearest 5 minutes
T = addvars(T, T.startTime + offset, 'After', 'startTime', 'NewVariableNames', 'query');

% Pivot data
T = unstack(T, {'perKwh' 'low' 'med' 'high'}, 'channelType');

% Rename
vars = T.Properties.VariableNames;
T = renamevars(T, vars, regexprep(vars, {'(.*)_(.*)' 'startTime' 'spotPerKwh' '_perKwh'}, {'$2_$1' 'time' 'spot_price' '_price'}));

% Reorder
vars = T.Properties.VariableNames;
vars = sort(vars(contains(vars,'_')));
T = movevars(T, vars, 'After', 'renewables');
end

function day = checkdate(day, default_timezone)
% Ensure day is a date, discard time.
if isnumeric(day) && day<1000
    day = datetime + day; % day is an offset
elseif isnumeric(day)
    day = datetime(day, 'ConvertFrom', 'datenum'); % day is datenum
elseif ~isdatetime(day)
    day = datetime(day); % day is string
end
day = dateshift(day, 'start', 'day');

% Cange or assign a time zone
if nargin>1
    day.TimeZone = default_timezone;
end
end
