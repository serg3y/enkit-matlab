function [X, Y] = makeSteps(x, y)
% Given vectors x and y of equal length, that represent step values
% at the *start* of each interval, returns 2-by-N arrays X,Y where
% each column represents the start and end of an interval.
%   [X, Y] = makeSteps(x, y)
%
% Remarks:
% - If x is a duration array, intervals wrap at 24 hours.

arguments
    x {mustBeVector}
    y {mustBeVector}
end

% Ensure row vectors
x = x(:)';
y = y(:)';

% Get step
dx = diff(x);
dx = [dx dx(end)];

% Wrap duration [00:00 24:00)
if isa(x, 'duration')
    dx = mod(dx, hours(24));
end

X = [x; x+dx];
Y = [y; y];
end