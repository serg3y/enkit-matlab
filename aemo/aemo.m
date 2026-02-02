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
            if nargin<4 || isempty(staleLim), staleLim = hours(12); end

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
                s = upper(state);
                T = table(T.time, T.RRP/10, T.TOTALDEMAND, 'VariableNames', ["time" s+"_price_ckwh" s+"_usage_mwh"]);
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
