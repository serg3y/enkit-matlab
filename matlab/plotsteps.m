function h = plotsteps(ax, x, y, color, name, fillval, varargin)
% Plot a line with steps
%   h = plotsteps(ax, x, y, color, name, varargin)

% Defaults
if nargin < 4 || isempty(color)
    color = ax.ColorOrder(mod(ax.ColorOrderIndex - 1, size(ax.ColorOrder, 1)) + 1, :);
end
if nargin < 5 || isempty(name), name = ''; end
if nargin < 6 || isempty(fillval), fillval = 0; end

color = color2rgb(color);

y = fillmissing(y, 'constant', fillval);
[X, Y] = makeSteps(x(:), y(:));

if isduration(x)
    ind = find(diff(X(:))<0);
    [i, j] = sort([1:numel(X) ind']);
    X = X(i);
    Y = Y(i);
    X(diff(j)<0) = NaN;
    Y(diff(j)<0) = NaN;
end

name = sprintf('\\color[rgb]{%g %g %g}%s', color(1:3), name);

h = plot(ax, X(:), Y(:), 'color', color, 'DisplayName', name, varargin{:});

if ~nargout
    clear h
end

end