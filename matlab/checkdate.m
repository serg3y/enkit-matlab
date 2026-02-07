function t = checkdate(t, tz, roundto)
% Ensure t is datetime, if needed apply timezone and rounding.
%   t = checkdate(t)
%   t = checkdate(t, tz)
%   t = checkdate(t, tz, roundto)

% Defaults
if nargin<2, tz = ''; end
if nargin<3, roundto = ''; end

% Batch mode
if iscell(t)
    t = cellfun(@(x)checkdate(x, tz, roundto), t);
    return
end

if ischar(t) && isfinite(str2double(t))
    t = str2double(t); % convert '-10' > [-10]
end

if ischar(t) || isstring(t)
    t = datetime(t); % text -> datetime
elseif isnumeric(t)
    t(t<1000) = now + t(t<1000); %#ok<TNOW1> % offsets -> datenum
    t = datetime(t, 'ConvertFrom', 'datenum'); % datenum -> datetime
end

if ~isempty(tz)
    t.TimeZone = tz;
end

if ~isempty(roundto)
    t = dateshift(t, 'start', roundto);
end
end
