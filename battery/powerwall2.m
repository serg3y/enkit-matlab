% Examples:
% T = powerwall2().read()
% T = powerwall2().getData({'2019-04-06' '2019-04-08'});
% T = powerwall2().getData({'2019-01-01' -1});
% T = powerwall2().read([],{'2019-04-06' '2019-04-08'});

classdef powerwall2

    properties
        dataFold = fullfile(fileparts(mfilename('fullpath')), 'data') % Data foler
        downloadFlag = 1 % allow missing files to be downloaded
        refreshToken
        accessToken
        siteId
        siteInfo
        timeZone = 'Australia/Adelaide'
    end

    methods

        function obj = powerwall2(varargin)
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
        end

        function obj = authenticate(obj, site_ind)
            if nargin<2 || isempty(site_ind), site_ind = 1; end

            % Get access_token
            data = webwrite("https://auth.tesla.com/oauth2/v3/token", struct('grant_type', 'refresh_token', 'client_id', 'ownerapi', 'refresh_token', obj.refreshToken, 'scope', 'openid email offline_access'));
            obj.accessToken = data.access_token;

            % Get site_id
            data = webread("https://owner-api.teslamotors.com/api/1/products", weboptions(HeaderFields = {'Authorization' ['Bearer ' obj.accessToken]}));
            info = data.response(site_ind);
            obj.siteId = num2str(info.energy_site_id);

            % Write info to file (optional)
            if ~isfolder(obj.dataFold)
                mkdir(obj.dataFold);
            end
            writelines(jsonencode(info, 'PrettyPrint', true), fullfile(obj.dataFold, obj.siteId + "_info.json"))
        end

        function download(obj, day)
            % Download one day's data and write to CSV

            if isempty(obj.accessToken) || isempty(obj.siteId)
                obj = obj.authenticate;
            end

            file = fullfile(obj.dataFold, sprintf('%s', obj.siteId), [char(day, 'yyyyMMdd') '.csv']);

            % Delete incomplete files
            if isfile(file) && isStale(file, 1.1)
                delete(file)
            end

            % Skip if file already exists
            if isfile(file)
                return
            end

            % Ensure folder exists
            if ~isfolder(fileparts(file))
                mkdir(fileparts(file))
            end

            % Build end_date (1 second before end of day, with correct TZ)
            end_date = datetime(day, 'TimeZone', obj.timeZone, 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ") + days(1) - seconds(1);
            url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + obj.siteId + "/calendar_history?kind=power&end_date=" + strrep(char(end_date), '+', '%2B');
            disp(url + " > " + file)

            data = webread(url, weboptions('HeaderFields', {'Authorization', ['Bearer ' obj.accessToken]})).response;

            if isempty(data)
                return
            end

            % Optional TZ sanity check
            assert(isequal(data.installation_time_zone, end_date.TimeZone), "Set TimeZone to '%s'", data.installation_time_zone)

            % Convert + save
            t = struct2table(data.time_series);
            t(:,2:end) = round(t(:,2:end), 3);
            writetable(t, file)

            pause(1) % Avoid "Too Many Requests"
        end

        function T = read(obj, files, span, timezone)
            % Read data from files
            %  T = read(obj, files, span)

            if nargin < 2 || isempty(files), files = fullfile(obj.dataFold, sprintf('%s', obj.siteId)); end
            if nargin < 3 || isempty(span), span = []; end
            if nargin < 4 || isempty(timezone), timezone = '+10'; end % NEM timezone is always +10h
            
            % List files
            if isfolder(files)
                files = fullfile(files, '*.csv');
            end
            d = dir(files); % Supports single file or wildcard
            files = fullfile({d.folder}, {d.name});

            % Filter on time span
            if ~isempty(span) && ~isempty(files)
                [~, names] = fileparts(files);
                day = datetime(names, 'InputFormat', 'yyyyMMdd');
                files = files(~(day < checkdate(span{1}) | day > checkdate(span{end})));
            end

            % Check files
            if isempty(files)
                T = [];
                return
            end

            % Read files
            fprintf('Importing %g files...\n', numel(files))
            T = cell(1, numel(files));
            for k = 1:numel(files)
                T{k} = readtable(files{k});

                % Check data
                if ~ismember(height(T{k}), [288 276 300]) && height(T{k}) > 0
                    fprintf(' Unexpected number of rows: file=%s  rows=%-3g  start=%s  stop=%s\n', files{k}, height(T{k}), T{k}.timestamp{[1 end]})
                end
            end
            T = vertcat(T{:});

            % Parse time stamps
            if ~isempty(T)
                T.timestamp = datetime(strrep(T.timestamp, 'T', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ssZ', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+09:30');
            end
            if ~isempty(timezone)
                T.timestamp.TimeZone = timezone; % Change time zone (optional)
            end

            % Convert w to kw
            T{:, vartype('numeric')} = T{:, vartype('numeric')}/1000;

            % Rename columns
            T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'timestamp' '_power'}, {'time' '_kw'});

            % Append amounts (kwh)
            ind = endsWith(T.Properties.VariableNames, '_kw');
            rates = T(:, ind) .* hours(mode(diff(T.time)));
            rates.Properties.VariableNames = strrep(rates.Properties.VariableNames, '_kw', '_kwh');
            T = [T rates];
        end


        function T = getData(obj, span)
            % Read or download prices or usage data

            % Step through days
            T = []; % Large table to hold all data
            for day = checkdate(span{1}) : checkdate(span{end})

                % Set output file path (no extension)
                file = fullfile(obj.dataFold, sprintf('%s', obj.siteId), [char(day, 'yyyyMMdd') '.csv']);

                % Delete incomplete files
                if obj.downloadFlag && isfile(file) && isStale(file, 1.1)
                    delete(file)
                end

                % Download
                if obj.downloadFlag && ~isfile(file)
                    if ~isfolder(fileparts(file))
                        mkdir(fileparts(file))
                    end

                    end_date = datetime(day, 'TimeZone', obj.timeZone, 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ") + days(1) - seconds(1); % Set end_date to be 1sec before end of the day, must include correct timezone for the region including daylight savings, eg '2023-01-01T23:59:00+10:30' or '2023-01-02T09:29:00Z' (for Australia/Adelaide in summer)
                    url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + obj.siteId + "/calendar_history?kind=power&end_date=" + strrep(char(end_date), '+', '%2B');
                    disp(url + ' > ' + file) % Show progress
                    data = webread(url, weboptions('HeaderFields', {'Authorization' ['Bearer ' obj.accessToken]})).response; % Download one days data
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
                    T = [T; t]; %#ok<AGROW>
                end
            end

            T.timestamp = datetime(strrep(T.timestamp, 'T', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ssZ', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+09:30');

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

function tf = isStale(file, thresh)
[~, name] = fileparts(file);
dt = datetime(name, 'InputFormat', 'yyyyMMdd');
tf = dt + thresh > datetime(dir(file).date);
end