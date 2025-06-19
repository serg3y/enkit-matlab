function T = nem12read(files, names, rez, timezone, timezone2)
% Read SA Power Networks NEM12 data file(s) into a table.
%   T = nem12read(files)
%
% Remarks:
% - NEM12 is a very old CSV format used by SA Power Networks to provide
%   electricity usage data, via their customer portal:
%   https://customer.portal.sapowernetworks.com.au/meterdata
%
% Example:
%   cd D:\MATLAB\enkit\sapn\serge   
%   T = nem12read('*.csv')
%   writetable(T, 'fixed.txt')
%
% See also:
%   https://www.energyaustralia.com.au/resources/PDFs/User%20Guide_v3.pdf

% Send issues and sample data files to: s3rg3y at hotmail dot com

% Defaults
if nargin<2 || isempty(names)
    names = ["sell_amount" "buy_amount" "controlled_amount"]; % Name each field
end
if nargin<3, rez = []; end
if nargin<4, timezone = []; end
if nargin<5, timezone2 = []; end

% Find raw CSV files
if isfolder(files)
    files = fullfile(files, '**', '*.csv'); % Recursive search of a folder
end
list = dir(files); % Single file or wildcard
list = fullfile({list.folder}, {list.name});

% Read files
T = cellfun(@(x)nem12read_i(x, names), list, 'UniformOutput', false);
T = vertcat(T{:});
T.start.Format = 'yyyy-MM-dd HH:mm';

% Sort on time, remove overlaps
if ~isempty(T)
    [~, ind] = unique(T.start);
    T = T(ind, :);
end

% Resample
if ~isempty(rez)
    % Floor to nearest rez-minute mark
    T.start = dateshift(T.start, 'start', 'minute') - minutes(mod(minute(T.start), rez));

    % Group
    T = groupsummary(T, 'start', @sum, names);

    % Clean up
    T = renamevars(T, T.Properties.VariableNames, strrep(T.Properties.VariableNames, 'fun1_', ''));
    T = removevars(T, 'GroupCount');
end

% Assign time zone
if ~isempty(timezone)
    T.start.TimeZone = timezone;
end
if ~isempty(timezone2)
    T.start.TimeZone = timezone2;
end

end


function [T, blocks] = nem12read_i(file, names)
% Read a single NEM12 file

% Read file contents
txt = fileread(file);
if ~startsWith(txt, '200,')
    T = [];
    warning('Unknown file format: %s\n', file)
    return % Ensure file has correct format
end
txt = regexprep(txt, '(?<=\n)400.*?\n', ''); % Remove '400' lines

% Extract blocks
blocks = regexp([10 txt], '(?<=\n200,).*?(?=\n200|\n900|$)', 'match');
frmt = '(?<nmi>\d+),(?<list>\w+),(?<ch2>\w+),(?<channel>\w+),.*,(?<meter>\d+),(?<unit>\w+),(?<rez>\d+),\n(?<data>.*)';
blocks = regexp(blocks, frmt, 'names');

% Parse data for each block
T = cellfun(@parseblockdata, blocks, 'UniformOutput', false);
T = vertcat(T{:});

% Convert each 'channel' into column
T = unstack(T, 'kwh', 'channel');

% Assign column names
T.Properties.VariableNames = ["start" names];
end


function T = parseblockdata(block)
% Convert data in a single block (single channel) into a table

tod = 0 : str2double(block.rez)/24/60 : 1 - 0.0001;
frmt = ['300 %{yyyyMMdd}D' repmat('%f', 1, numel(tod)) '%s%*s%*s%{yyyyMMddHHmmss}D'];
data = textscan(block.data, frmt, 'Delimiter', ',', 'CollectOutput', true);

% Make a table
kwh = reshape(data{2}', [], 1);
start = reshape((data{1} + tod)', [], 1);
channel = repmat(string(block.channel), numel(kwh), 1);
T = table(start, kwh, channel);
end
