function plotLine(ax, x, y, color, varargin)
% Plot a line
[X, Y] = makeSteps(x, y);
if isduration(x)
    ind = find(diff(X(:))<0);
    [i, j] = sort([1:numel(X) ind']);
    X = X(i);
    Y = Y(i);
    X(diff(j)<0) = NaN;
    Y(diff(j)<0) = NaN;
end
plot(ax, X(:), Y(:), 'color', color, 'LineWidth', 1, varargin{:})
end