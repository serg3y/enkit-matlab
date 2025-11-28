function [tod, date, dst] = timeofdaylocal(dt, timezone)
% Returns time of day usign local time, accounting for day light savings.
%   [tod, date, dst] = timeofdaylocal(dt)
%   [tod, date, dst] = timeofdaylocal(dt, timezone)
% 
% Remarks:
% - Normal timeofday() returns elpased time since start of day.
% - If timezone is specifeid then t is converted to that timezone first.
%
% Example:
%   dt = datetime('2025-04-06 01:00', 'TimeZone', 'Australia/Adelaide') + hours(0:0.5:3)';
%   tod_elapsed = timeofday(dt);
%   [tod_local, date_local, dst] = timeofdaylocal(dt);
%   table(dt, tod_elapsed, tod_local, dst)

% Apply or convert timezone, if provided
if nargin > 1 && ~isempty(timezone)
    dt.TimeZone = timezone;
else
    timezone = dt.TimeZone;
end

% test for daylight savings time
dst = isdst(dt);

% Remove timezone, so that timeofday returns local time
dt.TimeZone = '';

% Get time of day and date
[tod, date] = timeofday(dt);

% Re-apply timezone
date.TimeZone = timezone;

% Adjsut format also
tod.Format = 'hh:mm';
end
