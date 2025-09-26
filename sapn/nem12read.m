function T = nem12read(files, names, rez, timezone)
% Read SA Power Networks NEM12 data file(s) into a table.
%   T = nem12read(files)             - File(s) to read (filename|wildcard)
%   T = nem12read(files, names)          - Rename column names (cellstr)
%   T = nem12read(files, names, rez)         - Resample time period (min)
%   T = nem12read(files, names, rez, timezone)   - Change time zone (str)
%
% Remarks:
% - NEM12 is an old CSV format used by SA Power Networks to provide
%   electricity usage data, via their customer portal:
%   https://customer.portal.sapowernetworks.com.au/meterdata
%
% Example:
%   T = nem12read('D:\MATLAB\enkit\sapn\data\serge\*.csv')
%
% See also:
%   https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard
%   https://www.energyaustralia.com.au/resources/PDFs/User%20Guide_v3.pdf

% Defaults
if nargin < 2 || isempty(names)
    names = ["sell_kwh" "buy_kwh" "buy2_kwh"]; % Field names
end
if nargin < 3, rez = []; end
if nargin < 4, timezone = '+10'; end % NEM timezone is always +10h
if nargin < 5, timezone = []; end

% Find files
files = dir(files); % Supports single file or wildcard
files = fullfile({files.folder}, {files.name});

% Read all files
parts = cell(1, numel(files));
for i = 1:numel(files)
    parts{i} = nem12read_i(files{i});
end
T = vertcat(parts{:});

if isempty(T)
    return
end

% Remove duplicates (for overlapping files)
[~, ind] = unique(T.start);
T = T(ind, :);

% Resample (optional)
if ~isempty(rez)
    % Floor time to the nearest rez period
    T.start = dateshift(T.start, 'start', 'minute') - minutes(mod(minute(T.start), rez));

    % Sum across each period by time
    T = groupsummary(T, 'start', @sum, T.Properties.VariableNames(2:end));

    % Clean up helper variables
    T = renamevars(T, T.Properties.VariableNames, strrep(T.Properties.VariableNames, 'fun1_', ''));
    T = removevars(T, 'GroupCount');
end

% Rename columns (optional)
if ~isempty(names)
    T.Properties.VariableNames(2:end) = names(1:numel(T.Properties.VariableNames)-1);
end

% Timezone
T.start.TimeZone = '+10';
if ~isempty(timezone)
    T.start.TimeZone = timezone; % Change time zone (optional)
end

% Condition (avoid precission errors using innerjoin)
T.start = dateshift(T.start, 'start', 'second');

end


function T = nem12read_i(file)
% Read a single NEM12 file into a table

% Read file contents
txt = fileread(file);
if ~startsWith(txt, '200,')
    warning('Unknown file format: %s\n', file)
    T = [];
    return
end

% Remove "400" records
txt = regexprep(txt, '(?<=\n)400.*?\n', '');

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

% Pivot channels into columns
T = unstack(T, 'kwh', 'channel');
end

function T = parseblockdata(block)
% Convert a single "200" block (single channel) into a table

rezMin = str2double(block.rez);
tod = 0 : rezMin/24/60 : 1 - 0.0001;

% Scan "300" records
frmt = ['300 %{yyyyMMdd}D' repmat('%f', 1, numel(tod)) '%s%*s%*s%{yyyyMMddHHmmss}D'];
data = textscan(block.data, frmt, 'Delimiter', ',', 'CollectOutput', true);

% Build table
kwh = reshape(data{2}', [], 1);
start = reshape((data{1} + tod)', [], 1);
start.Format = 'yyyy-MM-dd HH:mm';
channel = repmat(string(block.channel), numel(kwh), 1);

T = table(start, kwh, channel);
end