function T = read_amber_csv(files, values, timezone, timezone2)

T = read_one_file(files{1}, values{1}, timezone);

for k = 2:numel(files)
    t = read_one_file(files{k}, values{k}, timezone);
    T = outerjoin(T, t, 'Keys', 'start', 'MergeKeys', true);
end

if nargin>=4 && ~isempty(timezone2)
    T.start.TimeZone = timezone2;
end
end

function T = read_one_file(file, value, timezone)
T = readtable(file, 'VariableNamingRule', 'preserve');
T = renamevars(T, {'NEM Time' 'Price (ex GST)'}, {'start' value});
T.start = datetime(T.start, 'TimeZone', timezone, 'Format', 'yyyy-MM-dd HH:mm') - minutes(30);
end