function plotsteps(ax, x, y, color, name, varargin)
% Plot a line wit steps

[X, Y] = makeSteps(x, y);

if isduration(x)
    ind = find(diff(X(:))<0);
    [i, j] = sort([1:numel(X) ind']);
    X = X(i);
    Y = Y(i);
    X(diff(j)<0) = NaN;
    Y(diff(j)<0) = NaN;
end

name = sprintf('\\color[rgb]{%g %g %g}%s', color, name);

plot(ax, X(:), Y(:), 'Color', color, 'DisplayName', name, varargin{:})

end