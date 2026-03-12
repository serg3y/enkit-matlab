function t = checkdate(t, tz, roundto)
% Ensure t is datetime, if needed apply timezone and rounding.
%   t = checkdate(t)
%   t = checkdate(t, tz)
%   t = checkdate(t, tz, roundto)
%
% Remarks:
% - To remove timezone set tz = ''
% - To preserve timezone set tz = []
% - To round t down to nearest day set rounto = 'day' (default:minutes(5))

if nargin<2, tz = []; end
if nargin<3, roundto = minutes(5); end

if iscell(t)
    t = cellfun(@(x)checkdate(x, tz, roundto), t);
    return
end

if ischar(t) && isfinite(str2double(t))
    t = str2double(t); % convert '-10' -> -10
end

if ischar(t) || isstring(t)
    t = datetime(t); % text -> datetime
elseif isnumeric(t)
    if t < 1000
        t = datetime('now') + days(t); % offset -> datetime
    else
        t = datetime(t, 'ConvertFrom', 'datenum'); % datenum -> datetime
    end
end

if ~isnumeric(tz)
    t.TimeZone = tz;
end

if ~isempty(roundto)
    if isduration(roundto)
        n = minutes(roundto);
        t.Minute = floor(t.Minute / n) * n;
        t.Second = 0;
    else
        t = dateshift(t, 'start', roundto);
    end
end
end
