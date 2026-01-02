function h = plotsteps(ax, x, y, color, name, fillval, mode, varargin)
% Plot a line using steps generated using makeSteps.
%   h = plotsteps(ax, x, y, color, name, fillval, mode, plotArgs...)

% Defaults
arguments
    ax, x, y, color = [], name char = '', fillval = [], mode char = 'xy'
end
arguments (Repeating)
    varargin
end

% Checks
if isempty(color)
    idx = mod(ax.ColorOrderIndex - 1, size(ax.ColorOrder, 1)) + 1;
    color = ax.ColorOrder(idx, :);
end
if isempty(fillval)
    fillval = 0;
end
color = color2rgb(color);

% Fill missing
y = fillmissing(y, 'constant', fillval);

% Make steps
[X, Y] = makeSteps(x(:), y(:));

% Fix wrap-around for duration axis
if isa(x, 'duration')
    ind = find(diff(X(:))<0);
    [i, j] = sort([1:numel(X) ind']);
    X = X(i);
    Y = Y(i);
    X(diff(j)<0) = NaN;
    Y(diff(j)<0) = NaN;
end

% Colored DisplayName (matlab legend rgb color)
name = sprintf('\\color[rgb]{%g %g %g}%s', color(1:3), name);

% Plot
if strcmpi(mode, 'xy')
    h = plot(ax, X(:), Y(:), 'color', color, 'DisplayName', name, varargin{:});
elseif strcmpi(mode, 'yx')
    h = plot(ax, Y(:), X(:), 'color', color, 'DisplayName', name, varargin{:});
else
    error('Unkown mode %s', mode)
end

if ~nargout
    clear h
end

end