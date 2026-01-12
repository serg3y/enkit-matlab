% Class to download and read Powerwall2 data from the Tesla Owner API.
% 
% Remarks:
% - To donwload data requires you to get a Tesla API "refresh token". These
%   tokens can expire and may need to be refreshed at some point.
% - A "refresh token" is used to generate an "access toke" by
%   'Authenticating' with the Tesla API and last for 8 hrs.
% - Downloaded files are reused automatically, incomplete files are
%   re-downloaded, data is returned as a table with units kW & kWh.
% - Data is provided using daily files, and dealing with timestamps 
%   (utc vs local time) is annoying...
%
% Known API limitations:
% - The Tesla Owner API provides only one day of data per request. To
%   retrieve a full 24-hour period, the query 'end_date' must be just
%   before local midnight, and must account for daylight saving. Also the
%   timezone format is strict; for example, for Adelaide in summer use:
%     end_date=2025-01-01T23:59:59%2B10:30
% - The API does not provide the site timezone upfront. Therefore, clients 
%   must know or cache the site's 'installation_time_zone' to reliably
%   request full local-day periods, and must account for daylight savings.
%
% Configuration:
% 1. Get a refreshToken from a third-party site, eg
%    https://www.myteslamate.com/tesla-token
% 2. Use "battery/powerwall.ini" to provide settings, eg:
%    refreshToken = ABC123***
%    timeZone = Australia/Adelaide
%
% Examples:
%   pw = powerwall2(timeZone = 'Australia/Adelaide')
%   powerwall2().download({'2025-01-01' -1});  % Download a date range
%   T = powerwall2().read({'2025-01-01' -1});  % Read a date range

% TODO
% - This class uses legacy authentication, which is officialy depricated.

classdef powerwall2 < handle

    properties
        dataFold = enkitPath('battery', 'data')
        iniFile = enkitPath('battery', 'powerwall2.ini')
        refreshToken char
        accessToken char
        siteInfo
        siteIds
        timeZone char
    end

    methods
        function obj = powerwall2(varargin)
            % Parse ini settings
            if isfile(obj.iniFile)
                txt = fileread(obj.iniFile);
                for p = string(properties(obj)')
                    v = regexp(txt, "(?<=^\s*" + p + "\s*=\s*)[^\r\n]*", "match", "once", "lineanchors");
                    if ~isempty(v)
                        obj.(p) = strtrim(v);
                    end
                end
            else
                fprintf(' Missing settings file: %s\n', obj.iniFile)
            end
            if ischar(obj.siteIds)
                obj.siteIds = str2num(obj.siteIds); %#ok<ST2NM> str2num is required to handle vectors, eg '[12345 12345]'
            end
            
            % Parse user inputs
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k + 1};
            end
        end

        function authenticate(obj) 
            % Get an access token and site info from Tesla API
            if isempty(obj.refreshToken)
                error('A refreashToken is required to authenticate with Tesla API')
            end

            % Get access token
            url = 'https://auth.tesla.com/oauth2/v3/token';
            fprintf(' Authenticating: %s >', url)
            t = webwrite(url, struct('grant_type', 'refresh_token', 'client_id', 'ownerapi', 'refresh_token', obj.refreshToken));
            obj.accessToken = t.access_token;
            fprintf(' SUCCESS\n')

            % Get site info
            url = 'https://owner-api.teslamotors.com/api/1/products';
            fprintf(' Getting site info: %s\n', url)
            t = webread(url, weboptions(HeaderFields = {'Authorization', ['Bearer ' obj.accessToken]}));
            obj.siteInfo = t.response;

            % Save site info to file(s)
            if ~isfolder(obj.dataFold)
                mkdir(obj.dataFold);
            end
            for k = 1:numel(obj.siteInfo)
                file = fullfile(obj.dataFold, obj.siteInfo(k).energy_site_id + "_siteInfo.json");
                writelines(jsonencode(obj.siteInfo(k), 'PrettyPrint', true), file);
                obj.siteIds(1, k) = obj.siteInfo(k).energy_site_id; % List all site ids
                fprintf(' > %s\n', file)
            end

            % Detect timezone
            if isempty(obj.timeZone)
                siteId = obj.siteIds(1);
                fprintf(' Getting site (%d) timezone:', siteId)
                end_date_str = char(datetime('now', 'TimeZone', 'UTC', 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ") - hours(24) - seconds(1));
                url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + siteId + "/calendar_history?kind=power&end_date=" + end_date_str;
                t = webread(url, weboptions(HeaderFields = {'Authorization', ['Bearer ' obj.accessToken]})).response;
                fprintf(' %s\n', t.installation_time_zone)
                obj.timeZone = t.installation_time_zone;
            end
        end

        function download(obj, span, siteId)
            % Download and cache daily data files
            dayVec = resolveSpan(span, obj.timeZone);
            if nargin<3 || isempty(siteId)
                if isempty(obj.siteIds)
                    obj.authenticate();
                end
                siteId = string(obj.siteIds(1)); % Default to the first device
            end

            for day = dayVec
                file = fullfile(obj.dataFold, siteId, string(day, 'yyyyMMdd') + ".csv");
                if isfile(file) && day + hours(30) > datetime(dir(file).date, 'TimeZone', day.TimeZone)
                    delete(file) % File might be incomplete
                end
                if isfile(file)
                    continue
                end
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file))
                end
                if isempty(obj.accessToken)
                    obj.authenticate();
                end

                % Download one day
                end_date = dateshift(day, 'start', 'day', 'next') - seconds(1); % Can handle daylight savings
                end_date = datetime(end_date, 'TimeZone', obj.timeZone, 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ");
                end_date_str = strrep(char(end_date), '+', '%2B'); % API cant handle plus signs
                url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + siteId + "/calendar_history?kind=power&end_date=" + end_date_str;


                % power             Instantaneous power (kW) time series
                % energy            Energy over interval (kWh per sample)
                % self_consumption	Portion of solar used on-site
                % grid_import       Energy imported from the grid
                % grid_export       Energy exported to the grid
                % solar             Solar production
                % battery           Battery charge/discharge
                % home              Home load / consumption
                % url = 'https://owner-api.teslamotors.com/api/1/energy_sites/2282236/calendar_history?kind=energy&           end_date=2026-01-08T23:59:59%2B10:30'
                % url = 'https://owner-api.teslamotors.com/api/1/energy_sites/2282236/calendar_history?kind=energy&period=day&end_date=2026-01-06T23:59:59%2B10:30'


                fprintf(' %s >', url)
                t = webread(url, weboptions(HeaderFields = {'Authorization', ['Bearer ' obj.accessToken]})).response;
                if isempty(t)
                    fprintf(' no data\n')
                    continue
                end
                if ~isequal(t.installation_time_zone, end_date.TimeZone)
                    fprintf(2, ' WARNING: The user provided timezone (%s) zone is not same as Tesla API timezone (%s)', t.installation_time_zone, end_date.TimeZone)
                end

                % Save to file
                t = struct2table(t.time_series);
                t(:, 2:end) = round(t(:, 2:end), 3);
                fprintf(' %s (n=%g)\n', file, height(t))
                writetable(t, file)
                pause(1) % Be nice to server
            end
        end

        function T = read(obj, span, siteId, timezone)
            % Read cached data files for a date span and return a table
            if nargin < 3 || isempty(siteId)
                if isempty(obj.siteIds)
                    obj.authenticate();
                end
                siteId = string(obj.siteIds(1)); % Default to the first device
            end
            if nargin < 4 || isempty(timezone)
                timezone = obj.timeZone; % use system timezone by default
            end
            days = resolveSpan(span, obj.timeZone);
            C = cell(numel(days), 1);

            % Read
            for k = 1:numel(days)
                file = fullfile(obj.dataFold, siteId, char(days(k), 'yyyyMMdd') + ".csv");
                if ~isfile(file), continue, end

                t = readtable(file);
                if ~ismember(height(t), [288 276 300]) && height(t) > 0
                    fprintf(' Unexpected number of rows: file = %s,  rows = %3g/288,  start = %s,  stop = %s\n', file, height(t), t.timestamp{[1 end]});
                end
                C{k} = t;
            end

            % Join
            C(cellfun(@isempty, C)) = [];
            if isempty(C)
                T = [];
                return
            end
            T = vertcat(C{:});

            % Convert timestamps, include units, derive amounts
            T.timestamp = datetime(strrep(T.timestamp, 'T', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ssZ', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', timezone);
            T{:, vartype('numeric')} = T{:, vartype('numeric')} / 1000;
            T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'timestamp' '_power'}, {'time' '_kw'});

            % Compute kwh
            T = sortrows(T, 'time');
            ind = endsWith(T.Properties.VariableNames, '_kw');
            E = T(:, ind) .* hours(mode(diff(T.time)));
            E.Properties.VariableNames = strrep(E.Properties.VariableNames, '_kw', '_kwh');
            T = [T E];
        end
    end
end

function days = resolveSpan(span, timeZone)
% Resolve user span input into a vector of whole-day datetimes
if nargin < 2 || isempty(span)
    days = [];
    return
end
if ~iscell(span)
    span = {span span};
end
d0 = parseDay(span{1}, timeZone);
if isscalar(span) || isempty(span{2})
    d1 = d0;
elseif isnumeric(span{2}) && span{2} < 0
    d1 = datetime('today', 'TimeZone', timeZone) + span{2};
else
    d1 = parseDay(span{2}, timeZone);
end
days = dateshift(d0, 'start', 'day') : dateshift(d1, 'start', 'day');
end

function d = parseDay(x, timeZone)
% Convert various date inputs to a start-of-day datetime
if isnumeric(x) && x < 1000
    d = datetime('today') + x;
elseif isnumeric(x)
    d = datetime(x, 'ConvertFrom', 'datenum');
elseif isdatetime(x)
    d = x;
else
    d = datetime(x);
end
d = dateshift(d, 'start', 'day');
if nargin > 1
    d.TimeZone = timeZone;
end
end
