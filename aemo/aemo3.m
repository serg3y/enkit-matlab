% Class to download and read Australian Energy Market Operator (AEMO) data.
%
% Remarks:
% - RRP is the state's Regional Reference Price in $/MWh (exGST)
% - rrp is the RRP in c/kWh (RRP/10)
% - time is the start time of each interval
% - Sampling period changed from 30 min to 5 minutes on 2021-10-01 00:00
% - Use tariffs.m to convert rrp to a 'node specific' "spot prices".
%
% Example: 
%   T = aemo().readData('SA', {'2024-07-01' 0})
%   https://aemo.com.au/aemo/data/nem/priceanddemand/PRICE_AND_DEMAND_202509_sa1.csv
%
% Reference:
%   https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data

classdef aemo

    properties
        datafold = fullfile(fileparts(mfilename('fullpath')), 'data')
        download = 12/24 % Both a flag to say if downloads are allowed and a threshold to say when an incomplete file is deemed to be 'stale' (day fraction)
    end

    methods
        function obj = aemo(varargin)
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function T = readData(obj, region, span, fields)
            % Get AEMO price (and demand) data.

            % Defaults
            if nargin<4 || isempty(cellstr(fields))
                fields = {'time' 'rrp'};
            elseif strcmp(fields, 'all')
                fields = [];
            end

            % AEMO data comes in monthly files, find required files
            span = checkdate(span, '+10:00');
            months = dateshift(span(1), 'start', 'month') : calmonths(1) : dateshift(span(2), 'start', 'month');

            % Read
            region = upper(region);
            T = arrayfun(@(x)obj.downloadData(region, x), months, 'UniformOutput', false);
            T = vertcat(T{:});

            % Insert 'time' and 'spot_price' columns
            cutover = datetime(2021, 10, 1, 'TimeZone', '+10:00');
            period = 30 - 25*(T.SETTLEMENTDATE >= cutover); % 30 before cutover, 5 after
            time = T.SETTLEMENTDATE - minutes(period); % Start time of each period
            rrp = T.RRP/10; % Convert $/MWh to c/kWh
            T = addvars(T, time, rrp, 'Before', 1);

            % Filter and sort time
            T = T(T.time >= span(1) & T.time < span(2), :);
            T = sortrows(T, 'time'); % Ensure time is sorted

            % Select fields if requested
            if ~isempty(fields)
                T = T(:, cellstr(fields));
            end
        end

        function T = resample(~, T, rez)
            fields = T.Properties.VariableNames;

            % Downsample 'time' to nearest rez-minute mark
            T.time = T.time - minutes(mod(minute(T.time), rez));

            % Compute means for numeric variables
            t1 = groupsummary(T, 'time', @mean, intersect({'rrp' 'TOTALDEMAND' 'RRP'}, fields));
            t1 = renamevars(t1, t1.Properties.VariableNames, strrep(t1.Properties.VariableNames, 'fun1_', ''));
            t1 = removevars(t1, 'GroupCount');

            % Get last values for categorical variables
            if ~isempty(intersect({'SETTLEMENTDATE' 'REGION' 'PERIODTYPE'}, fields))
                [~, ind] = unique(T.time, 'last');
                t2 = T(ind, intersect({'time' 'SETTLEMENTDATE' 'REGION' 'PERIODTYPE'}, fields));
                T = outerjoin(t1, t2, 'Keys', 'time', 'MergeKeys', true);
            else
                T = t1;
            end
        end

        function T = downloadData(obj, region, month)
            % Get one month of AEMO price (and demand) data.

            assert(ismember(region, ["NSW" "QLD" "VIC" "SA" "TAS"]), 'Invalid region, use: "NSW" "QLD" "VIC" "SA" "TAS"')
            region = lower(region);
            
            T = []; % Init
            file = sprintf('PRICE_AND_DEMAND_%s_%s1.csv', string(month, 'yyyyMM'), region);
            path = fullfile(obj.datafold, region, file);

            % Abort if month is in future
            if month > datetime('now', 'TimeZone', '+1000')
                return
            end

            % Download if file is missing or stale
            if obj.download && (~isfile(path) || ~isComplete(path) && isOld(path, obj.download))
                if ~isfolder(fileparts(path))
                    mkdir(fileparts(path))
                end
                url = ['https://aemo.com.au/aemo/data/nem/priceanddemand/' file];
                cmd = sprintf('curl -L -sS "%s" > "%s"', url, path);
                disp(cmd) % Progress
                err = system(cmd); % Download

                % Check file
                if err || ~isfile(path)
                    error('something went wront')
                else
                    txt = fileread(path);
                    if startsWith(txt, '<')
                        delete(path)
                        error('%s', txt)
                    end
                end
            end
            
            % Read file
            if isfile(path)
                opts = detectImportOptions(path);
                opts = setvaropts(opts, {'REGION' 'PERIODTYPE'}, 'Type', 'string');
                T = readtable(path, opts);
                T.SETTLEMENTDATE = datetime(T.SETTLEMENTDATE, 'InputFormat', 'yyyy/MM/dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', '+1000');
            end
        end
    end
end

function tf = isComplete(file)
fid = fopen(file, 'r');
fseek(fid, -100, 'eof'); % Read last 100 bytes in file
txt = fread(fid, Inf, '*char')';
tf = contains(txt, '01 00:00:00'); % File should end at start of next month
fclose(fid);
end

function tf = isOld(file, thresh)
fileDate = datetime(dir(file).date);
tf = fileDate + thresh < datetime('now');
end