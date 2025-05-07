function x = checkdate(x, default_timezone)
% Ensure x is a date.
if isnumeric(x) && x<1000
    x = datetime + x; % day is an offset
elseif isnumeric(x)
    x = datetime(x, 'ConvertFrom', 'datenum'); % day is datenum
elseif ~isdatetime(x)
    x = datetime(x); % day is string
end
x = dateshift(x, 'start', 'day');
if nargin>1
    x.TimeZone = default_timezone;
end
end