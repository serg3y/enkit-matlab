function [X, Y] = makeSteps(x, y)
% Given x,y at start of intervals, create X,Y for the intervals
dx = diff(x);
if isduration(x)
    dx = mod(dx, 1); % wrap -23:30 to 00:30
end
x2 = x + dx([1:end end]);
X = [x x2]';
Y = [y y]';
end