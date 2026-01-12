% See also:
%   https://support.solarquotes.com.au/hc/en-us/articles/360001312176-How-Do-I-Access-my-Smart-Meter-Data
%   https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard
%   https://www.energyaustralia.com.au/resources/PDFs/User%20Guide_v3.pdf

classdef nem

    methods
        function [T, header] = read(~, files, span, names, rez, timezone)
            % Read and condition NEM12 data file(s) into a table.
            %   T = nem12read(files)             - File(s) to read (filename|wildcard)
            %   T = nem12read(files, span)            - Rename column names (cellstr)
            %   T = nem12read(files, span, names)         - Rename column names (cellstr)
            %   T = nem12read(files, span, names, rez)         - Resample time period (min)
            %   T = nem12read(files, span, names, rez, timezone)   - Change time zone (str)
            %   [T, header] = nem12read(__)                  - Get header struct

            % Defaults
            if nargin < 2 || isempty(files),    files = cd; end
            if nargin < 3 || isempty(span),     span = []; end
            if nargin < 4 || isempty(names),    names = "auto"; end % Field names
            if nargin < 5 || isempty(rez),      rez = []; end
            if nargin < 6 || isempty(timezone), timezone = '+10'; end % NEM TimeZone is always +10h
            calcTotla = true;
            calcRates = true;

            % List files
            if isfolder(files)
                files = fullfile(files, '*.csv');
            end
            d = dir(files); % Supports single file or wildcard
            files = fullfile({d.folder}, {d.name});

            % Read all files
            parts = cell(1, numel(files));
            for i = 1:numel(files)
                [parts{i}, header] = nem12read(files{i});
            end
            T = vertcat(parts{:});

            if isempty(T)
                return
            end

            % Remove duplicates (for overlapping files)
            [~, ind] = unique(T.time);
            T = T(ind, :);

            % Sort columns (exports last)
            isExport = startsWith(T.Properties.VariableNames, 'B');
            T = T(:, [find(~isExport) find(isExport)]);

            % Make exports negative
            ind = startsWith(T.Properties.VariableNames, 'B');
            if any(ind)
                T(:, ind) = -1 .* T(:, ind);
            end

            % Resample (optional)
            if ~isempty(rez)
                % Floor time to the nearest rez period
                T.time = dateshift(T.time, 'start', 'minute') - minutes(mod(minute(T.time), rez));

                % Sum across each period by time
                T = groupsummary(T, 'time', @sum, T.Properties.VariableNames(2:end));

                % Clean up helper variables
                T = renamevars(T, T.Properties.VariableNames, strrep(T.Properties.VariableNames, 'fun1_', ''));
                T = removevars(T, 'GroupCount');
            end

            % Rename columns (optional)
            if all(isequal(names, "auto"))
                varNames = T.Properties.VariableNames;
                E = find(startsWith(varNames, 'E'));
                B = find(startsWith(varNames, 'B'));
                if ~isempty(E), varNames{E(1)} = 'import_kwh'; end % first E*  > import
                if  numel(E)>1, varNames{E(2)} = 'cl_kwh';     end % second E* > controlled load
                if ~isempty(B), varNames{B(1)} = 'export_kwh'; end % first B*  > export
                T.Properties.VariableNames = varNames;
            end

            % TimeZone
            T.time.TimeZone = '+10';
            if ~isempty(timezone)
                T.time.TimeZone = timezone; % Change time zone (optional)
            end

            % Filter on time
            if ~isempty(span)
                T = T(T.time >= checkdate(span(1), T.time.TimeZone) & T.time < checkdate(span(2), T.time.TimeZone), :);
            end

            % Total "grid" usage
            if calcTotla
                T.grid_kwh = T.import_kwh;
                if hascolumn(T, 'export_kwh')
                    T.grid_kwh = T.grid_kwh + T.export_kwh;
                end
                if hascolumn(T, 'cl_kwh')
                    T.grid_kwh = T.grid_kwh + T.cl_kwh;
                end
            end

            % Convert kwh to kw
            if calcRates
                ind = endsWith(T.Properties.VariableNames, '_kwh');
                T(:, ind) = T(:, ind) ./ hours(mode(diff(T.time)));
                T.Properties.VariableNames = strrep(T.Properties.VariableNames, '_kwh', '_kw');
            end
        end
    end
end

function [T, header] = nem12read(file)
% Read a single NEM12 file into a table.
% Assumes only one meter and consistent headers.

% Read file contents
txt = fileread(file);
if ~ (startsWith(txt, '200,') || startsWith(txt, '100,'))
    warning('Unknown file format: %s\n', file)
    T = [];
    header = [];
    return
end

% Remove "400" and "100" lines
txt = regexprep(txt, '^100,.*?\n', ''); % Discard first line if it starts with 100, eg "100,NEM12,202512021535,TCAUSTM,CUSTAG"
txt = regexprep(txt, '(?<=\n)400,.*?\n', ''); % Discard 400 lines, eg "400,5,5,A,89,"
txt = regexprep(txt, '\r', ''); % Discard windows carriage return

% Parse the header
parts = split(regexp(txt, '200[^\n]*', 'match', 'once'), ',');
header = struct( ...
    'SN', parts{2}, ... % Meter serial number (unique identifier for the physical meter)
    'NMI', parts{7}, ... % National Metering Identifier (identifies the connection point)
    'Channels', parts{3}, ... % List of meter channels (e.g. E1B1E2, E1B1)
    'Units', parts{8}, ... % Units of measure (e.g. KWH)
    'Interval', str2double(parts{9})); % Interval length in minutes (e.g. 05, 15, 30)

% Extract "200" blocks
blocks = regexp([10 txt], '(?<=\n200,).*?(?=\n200|\n900|$)', 'match');
frmt = '(?<nmi>\d+),(?<list>\w+),(?<ch2>\w+),(?<channel>\w+),.*,(?<meter>\w+),(?<unit>\w+),(?<rez>\d+),\n(?<data>.*)';
blocks = regexp(blocks, frmt, 'names');

% Parse block data (loop instead of cellfun)
parts = cell(1, numel(blocks));
for i = 1:numel(blocks)
    parts{i} = parseblockdata(blocks{i});
end
T = vertcat(parts{:});

% Make a table by pivoting channels into columns
T = unstack(T, 'kwh', 'channel');

% Fill missing values
ind = ismissing(T(:, 2:end));
if any(ind(:))
    T{:, 2:end} = fillmissing(T{:, 2:end}, 'constant', 0);
    fprintf(2, ' Warning: Filled %g missing values.\n', sum(ind(:)))
end

end

function T = parseblockdata(block)
% Convert data block into a table

rezMin = str2double(block.rez);
tod = minutes(0 : rezMin : 24*60 - 0.00001);

% Parse "300" records
frmt = ['300 %{yyyyMMdd}D' repmat('%f', 1, numel(tod)) '%s%*s%*s%{yyyyMMddHHmmss}D'];
data = textscan(block.data, frmt, 'Delimiter', ',', 'CollectOutput', true);

% Build table
kwh = reshape(data{2}', [], 1);
time = reshape((data{1} + tod)', [], 1);
time.Format = 'yyyy-MM-dd HH:mm';
channel = repmat(string(block.channel), numel(kwh), 1);
T = table(time, kwh, channel);
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
