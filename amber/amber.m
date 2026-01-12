% Amber API cannot handle partial days. This wrapper does same.

% Examples:
% amber().getSites
% amber().getPrices({'2024-11-01' 0}, 5);
% amber().getUsage( {'2024-12-23' -1}, 30);
% amber().downloadForecastPeriodicaly

% Remarks:
% "usage" is not available for current data and possibly last day
% "prices" includes forecasts when time span includes future periods

% aims:
% 1. show saving relative to AGL
% 2. show historic power usage and cost
% 3. show current usage and cost

% Links
% SA Power dashboard: https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard 

classdef amber

    properties
        datafold = fullfile(fileparts(mfilename('fullpath')), 'data')
        token
        siteId
        state
        nmi
    end

    methods

        function obj = amber(varargin)
            % Class constructor

            % Apply ini settings
            ini = fullfile(fileparts(mfilename('fullpath')), 'amber.ini');
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
            T = getData(obj, 'usage', span, 5);
        end
        
        function T = getPrices(obj, span)
            T = getData(obj, 'prices', span, 5);
        end

        function T = getData(obj, type, span, rez)
            % Read or download prices or usage data
            if nargin < 4, rez = []; end  % Use default 5 min resolution

            % Collect results in a cell
            tables = {};

            for day = checkdate(span(1)) : checkdate(span(end))
                % Ignore time zones
                day.TimeZone = ''; 

                % Choose identifier depending on type
                switch type
                    case 'usage',  t = sprintf('%s_%s_%s', type, obj.state, obj.nmi);
                    case 'prices', t = sprintf('%s_%s',    type, obj.state);
                    otherwise, error('Unknown type: %s', type);
                end

                % Build file path (no extension)
                file = fullfile(obj.datafold, t, char(day, 'yyyyMMdd'));
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % % Check cached file
                % json_file = dir([file '.json']);
                % isStale = @(f, d) datetime(f.date) < d + 1 + hours(1) && datetime(f.date) + minutes(30) < datetime;
                % if ~isempty(json_file) && isStale(json_file, day)
                %     delete(fullfile(json_file.folder, json_file.name));
                %     json_file = [];
                % end

                % Check cached file
                json_file = dir(file + ".json");
                if ~isempty(json_file)
                    t = datetime(json_file.date);
                    if t < day + days(1) + hours(1) && t + minutes(30) < datetime('now') % check if stale
                        delete(fullfile(json_file.folder, json_file.name));
                        json_file = [];
                    end
                end

                % Load or download JSON
                if isempty(json_file)
                    url_span = sprintf('startDate=%s&endDate=%s', ...
                        char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd'));
                    if isempty(rez)
                        url_rez = '';
                    else
                        url_rez = sprintf('&resolution=%g', rez);
                    end
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span url_rez];
                    [err, json_file] = obj.geturl(url);

                    if err
                        fprintf(2, 'Error: %s\n', json_file);
                        continue
                    end

                    filewrite([file '.json'], json_file);
                else
                    json_file = fileread([file '.json']);
                end

                % Skip if no data
                if numel(json_file) <= 2
                    fprintf('  %s - no data\n', day);
                    continue
                end

                % Convert json to table and store
                tables{end+1} = obj.readDataFile(type, [file '.json']); %#ok<AGROW>
            end

            % Combine all tables
            if isempty(tables)
                T = table(); % return empty if nothing collected
            else
                T = vertcat(tables{:});
            end
        end




        function T = getData_old(obj, type, span, rez)
            % Read or download prices or usage data

            if nargin < 4, rez = []; end % Use default 5 min resolution

            % Step through days
            T = []; % Large table to hold all data
            for day = checkdate(span(1)) : checkdate(span(end))

                % Set output file path (no extension)
                switch type
                    case 'usage',  file = fullfile(obj.datafold, sprintf('%s_%s', type, obj.nmi  ), char(day, 'yyyyMMdd'));
                    case 'prices', file = fullfile(obj.datafold, sprintf('%s_%s', type, obj.state), char(day, 'yyyyMMdd'));
                end
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % Check if cached files exist
                json_file = dir([file '.json']);

                % Check if cached file is stale
                if ~isempty(json_file) && ...                            % if JSON file exists, but ...
                        datetime(json_file.date) < day + 1 + 1/24 && ... % file was saved near day's end, and ...
                        datetime(json_file.date) + 0.5/24 < datetime     % file is more then 30 min old, then
                    delete(fullfile(json_file.folder, json_file.name))   % delete the file, as it may be stale
                    json_file = [];
                end
                
                % Load cached json
                if ~isempty(json_file)
                    json = fileread([file '.json']);

                else
                    % Download
                    url_span = sprintf('startDate=%s&endDate=%s', char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd')); % Time span component
                    if ~isempty(rez)
                        url_rez = sprintf('&resolution=%g', rez);
                    else
                        url_rez = '';
                    end
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span url_rez]; % REST URL query
                    [err, json] = obj.geturl(url); % Download

                    % Skip on error
                    if err
                        fprintf(2, 'Error: %s\n', json)
                        continue
                    end

                    % Write json to file, even if its empty
                    filewrite([file '.json'], json)
                end

                % Skip if no data
                if numel(json) <= 2
                    fprintf('  %s - no data\n', day)
                    continue
                end

                % Convert json to a table
                t = obj.readDataFile(type, [file '.json']);

                T = [T; t]; %#ok<AGROW>
            end
        end

        function T = readDataFile(~, type, file)
            % Read prices or usage JSON data file and output a table
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

            % Replace endTime with duration
            T.duration = minutes(T.endTime-T.startTime);
            T.endTime = [];

            % Convert from UTC to nemTime TimeZone
            timezone = T.nemTime{1}(end-5:end);
            T.startTime.TimeZone = timezone;

            switch type

                case 'prices'
                    % Remove predictions
                    T = T(T.type == "ActualInterval", :);

                    % Remove junk columns
                    T = T(:, {'startTime' 'duration' 'perKwh' 'spotPerKwh' 'renewables' 'channelType'});
                    
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
                    T = movevars(T, {'buy_price' 'buy2_price' 'sell_price' 'spot_price' 'renewables'}, 'After', 'duration');

                case 'usage'
                    % Remove predictions
                    T = T(T.type == "Usage", :);

                    % Remove junk columns
                    T = T(:, {'startTime' 'duration' 'kwh' 'perKwh' 'channelType'});

                    % Use positive values for feed-in
                    T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

                    % Convert channelType from rows to columns
                    T = unstack(T, {'kwh' 'perKwh'}, 'channelType');

                    % Improve column names
                    T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'(.*)_(.*)' 'general' 'feedIn' 'controlledLoad' '_perKwh' 'kwh' 'Time'}, {'$2_$1' 'buy' 'sell' 'buy2' '_price' 'amount' ''});

                    % Re-order columns
                    T = movevars(T, {'buy_amount' 'buy_price' 'sell_amount' 'sell_price' 'buy2_amount' 'buy2_price'}, 'After', 'duration');
            end
        end

        function downloadForecastPeriodicaly(obj)
            % Periodically downloads price forecasts, every 5 min.
            %   amber().downloadForecastPeriodicaly
            % - Downloads 24 hrs @ 30 min data and 1 hrs @ 5 min.
            % - Downloads are delayed by 30 sec after the 5 minute mark,
            %   because prices tend to update near the start of the mark.
            % - Downloads are further delayed by a random offset, in the
            %   range of 0-15 sec, to be nice to the server.
            period = 5; % Delay between downloads (min)
            rand_offset = rand*0.25; % 15 sec
            while true
                now_local = datetime('now');
                offset = minutes(period - mod(minute(now_local), period) + 0.5 + rand_offset);
                next_local = dateshift(now_local, 'time', 'minute') + offset; % Wait 1-2 min past the mark, to ensure prices are updated and polling is randomised
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
            % Read forecast data from files

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
                    t = cellfun(@obj.readForecastFile, files, 'UniformOutput', false);
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

        function T = readForecastFile(~, file)
            % Convert JSON to a table
            
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

function tf = isComplete(file)
fid = fopen(file, 'r');
fseek(fid, -100, 'eof'); % Read last 100 bytes in file
txt = fread(fid, Inf, '*char')';
tf = contains(txt, 'T23:55:00'); % File should end at start of next month
fclose(fid);
end

function tf = isOld(file, thresh)
fileDate = datetime(dir(file).date);
tf = fileDate + thresh < datetime('now');
end
