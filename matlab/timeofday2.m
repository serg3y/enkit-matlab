function [tod, date] = timeofday2(tt, timezone)
% Returns clock time, and date, accounting for day light savings.
%   [tod, date] = timeofday2(tt)
%   [tod, date] = timeofday2(tt, timezone)
% 
% - This version returns the daylight savings adjusted clock time, not
%   elpased time since start of day, like the normal timeofday().

% Apply time zone if given
if nargin > 1 && ~isempty(timezone)
    tt.TimeZone = timezone;
end

% Remove time zone so that timeofday returns the timezone adjusted time
tt.TimeZone = '';

% Get time of day and date
[tod, date] = timeofday(tt);

% Adjsut format also
tod.Format = 'hh:mm';
end
