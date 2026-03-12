% Download and read Australian Energy Market Operator (AEMO) statewide
% wholesale electricity PRICE and DEMAND data.
%
% Remarks:
% - AEMO changes sampling from 30 min to 5 minutes on 2021-10-01 00:00
% - 'RRP' is the state's Regional Reference Price in $/MWh (exGST)
% - 'rrp' is same but in c/kWh (rrp=RRP/10)
% - 'time' is the start time of each interval
%
% Example:
%   aemo(staleLim=hours(0)).download('SA', {'2024-07-01' 0})
%   T = aemo().read('SA', {'2024-07-01' '2024-07-10'})
%
% Reference:
%   https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data
%   https://aemo.com.au/aemo/data/nem/priceanddemand/PRICE_AND_DEMAND_202509_sa1.csv
%   https://www.aemo.com.au/Energy-systems/Electricity/National-Electricity-Market-NEM/Data-NEM/Data-Dashboard-NEM

% Forecast data, both 5 and 30 min:
% https://www.aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/market-management-system-mms-data/pre-dispatch

classdef aemo

    properties
        dataFold char = fullfile(fileparts(mfilename('fullpath')), 'data')
    end

    methods
        function obj = aemo(varargin)
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function T = getPrice(obj, state, span)
            obj.download(state, span);
            T = obj.read(state, span);
        end

        function download(obj, state, span, staleLim)
            % Download required month(s) of data to files
            %   download(state, span, staleLim)
            if nargin<4 || isempty(staleLim), staleLim = hours(0); end

            monthList = unique(dateshift(checkdate(span(1)) : checkdate(span(end)), 'start', 'month'));
            for month = monthList
                [file, url] = obj.monthFile(state, month);

                % Skip if the file exists and is complete or not stale
                if isfile(file) && (complete(file) || ~stale(file, staleLim))
                    continue
                end

                % Download
                fprintf('  %s > %s', url, file)
                folder = fileparts(file);
                if ~isfolder(folder)
                    mkdir(folder)
                end
                websave(file, url);
                fprintf('  (%g b)\n', dir(file).bytes)
            end
        end

        function T = read(obj, state, span)
            % Read AEMO data for a given state and time span, resamples
            % historic data to a 5-minute grid.

            % Standardize time span and get months list
            span = checkdate(span, '+10:00', minutes(5));
            monthList = unique(dateshift(span(1):span(end), 'start', 'month'));

            % Load and stack files
            T = cell(numel(monthList), 1);
            for k = 1:numel(monthList)
                file = obj.monthFile(state, monthList(k));
                if isfile(file)
                    T{k} = readtable(file);
                end
            end
            T = vertcat(T{:});
            if isempty(T), T = timetable.empty; return, end

            % Find interval start time
            cutoverTime = datetime('2021-10-01', 'TimeZone', '+10:00');
            n = cellfun(@numel, T.SETTLEMENTDATE);
            time = NaT(height(T), 1, 'TimeZone', '+10:00');
            time(n==19) = datetime(T.SETTLEMENTDATE(n==19), 'InputFormat', 'yyyy/MM/dd HH:mm:ss', 'TimeZone', '+10:00');
            time(n==16) = datetime(T.SETTLEMENTDATE(n==16), 'InputFormat', 'yyyy/MM/dd HH:mm'   , 'TimeZone', '+10:00');
            time = time - minutes(30 - 25*(time >= cutoverTime));

            % Make a sorted timetable
            T = timetable(time, T.RRP/10, T.TOTALDEMAND, 'VariableNames', ["price_ckwh" "usage_mwh"]);
            T = sortrows(T, 'time'); % eg SA 2016/08/14 16:30:00 is not sorted

            % Resample to a 5 min grid
            T.temp = time;
            T = retime(T, (span(1) : minutes(5) : span(2) - minutes(5)), 'previous');
            ind = T.time - T.temp >= minutes(30) & T.time < cutoverTime;
            T.temp = [];
            T{ind, :} = nan; % NaN missing data

            % Format time
            T.time.Format = 'yyyy-MM-dd HH:mm';
        end

        function T = read_old(obj, state, span)
            % Read data
            fprintf(' Reading AEMO data...\n')
            monthList = unique(dateshift(checkdate(span(1), '+10:00') : checkdate(span(end), '+10:00'), 'start', 'month'));
            T = cell(numel(monthList), 1); % Preallocate
            for k = 1:numel(monthList)
                file = obj.monthFile(state, monthList(k));
                if isfile(file)
                    T{k} = readtable(file);
                end
            end
            T = vertcat(T{:});
            
            if ~isempty(T)
                % Convert timestamps to datetime
                T.SETTLEMENTDATE = datetime(T.SETTLEMENTDATE, 'InputFormat', 'yyyy/MM/dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+10:00');

                % Calculate interval start time
                period = minutes(30 - 25*(T.SETTLEMENTDATE >= datetime(2021, 10, 1, 'TimeZone', '+10:00')));
                T.time = T.SETTLEMENTDATE - period; % Set the interval start time

                % Filter data using time span
                T = T(T.time >= checkdate(span(1), '+10:00') & T.time < checkdate(span(end), '+10:00'), :);

                % Reformat data
                T = table(T.time, T.RRP/10, T.TOTALDEMAND, 'VariableNames', ["time" "price_ckwh" "usage_mwh"]);
            
                % Reasample to 5 min
                T = table2timetable(T);
                T = retime(T, 'regular', 'fillwithmissing', 'TimeStep', minutes(30));
                T = retime(T, 'regular', 'previous', 'TimeStep', minutes(5));
            end
        end

        function [file, url] = monthFile(obj, state, month)
            name = sprintf('PRICE_AND_DEMAND_%s_%s1.csv', char(month, 'yyyyMM'), upper(state));
            file = fullfile(obj.dataFold, upper(state), name);
            url  = ['https://aemo.com.au/aemo/data/nem/priceanddemand/' name];
        end
    end
end

function tf = complete(file)
fid = fopen(file, 'r');
fseek(fid, -100, 'eof'); % Read last 100 bytes in file
txt = fread(fid, Inf, '*char')';
fclose(fid);
tf = contains(txt, '01 00:00:00'); % Completed files end with the start of next month
end

function tf = stale(file, staleLim)
tf = datetime(dir(file).date) + staleLim < datetime('now');
end
