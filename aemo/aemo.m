% Example: 
% T = aemo(download=1/24).getPrice('SA', {'2024-07-01' '2025-06-01'}, 30)
%
% Source:
% https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data
% eg https://aemo.com.au/aemo/data/nem/priceanddemand/PRICE_AND_DEMAND_202501_SA1.csv

classdef aemo

    properties
        datafold = fileparts(mfilename('fullpath'))
        download = 12/24 % Both a flag to say if downloads are allowed and a threshold to say when a an incomplete file is deemed to be 'stale' (day fraction)
    end

    methods
        function obj = aemo(varargin)
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function T = getPrice(obj, region, span, rez, fields)
            % Get AEMO price (and demand) data.

            % AEMO data comes in one month blocks, list required months
            span = [checkdate(span{1}, '+1000') checkdate(span{2}, '+1000')];
            month1 = dateshift(span(1), 'start', 'month');
            month2 = dateshift(span(2), 'start', 'month');
            months = month1 : calmonths(1) : month2;

            % Read
            T = arrayfun(@(x)obj.getPrice1(region, x), months, 'UniformOutput', false);
            T = vertcat(T{:});

            % Insert 'time' and 'spot' columns
            ind = T.SETTLEMENTDATE >= datetime('2021-10-01', 'TimeZone', '+1000');
            time = T.SETTLEMENTDATE - minutes(ind*5 + ~ind*30); % Start time of each period
            spot = (T.RRP/10) * 1.1; % Convert $/MWh exGST > c/kWh incGST
            T = addvars(T, time, spot, 'Before', 1);

            % Filter on time
            T = T(T.time >= span(1) & T.time < span(2) + 1, :);
            T = sortrows(T, 'time'); % Ensure time is sorted

            % Resample
            if nargin>3 && ~isempty(rez)
                if nargin < 5
                    fields = T.Properties.VariableNames;
                end

                % Downsample 'time' to nearest rez-minute mark
                T.time = T.time - minutes(mod(minute(T.time), rez));

                % Compute means for numeric variables
                t1 = groupsummary(T, 'time', @mean, intersect({'spot' 'TOTALDEMAND' 'RRP'}, fields));
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

                % Reorder
                T = movevars(T, fields);

            elseif nargin>4

                % Select a subset of fields and reorder
                T = T(:, fields);
            end

        end

        function T = getPrice1(obj, region, month)
            % Get one month of AEMO price (and demand) data.

            assert(ismember(region, ["NSW" "QLD" "VIC" "SA" "TAS"]), 'Invalid region, use: "NSW" "QLD" "VIC" "SA" "TAS"')
            
            T = []; % Init
            file = sprintf('PRICE_AND_DEMAND_%s_%s1.csv', string(month, 'yyyyMM'), region);
            path = fullfile(obj.datafold, region, file);

            % Abort if month is in future
            if month > datetime('now', 'TimeZone', '+1000')
                return
            end

            % Download if file is missing or stale
            if obj.download && (~isfile(path) || ~isComplete(path) && isOld(path, obj.download))
                if ~isfolder(region)
                    mkdir(region)
                end
                url = ['https://aemo.com.au/aemo/data/nem/priceanddemand/' file];
                cmd = sprintf('curl -sS "%s" > "%s"', url, path);
                disp(cmd) % Progress
                system(cmd); % Download
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
fseek(fid, -100, 'eof'); % Go to 100 bytes before end of file
txt = fread(fid, 100, '*char')';
tf = contains(txt, '01 00:00:00');
fclose(fid);
end

function tf = isOld(file, thresh)
fileDate = datetime(dir(file).date);
tf = fileDate + thresh < datetime('now');
end