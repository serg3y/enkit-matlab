function h = plotspread2(ax, x, y1, y2, color, name, varargin)
% Plots a region defined by x,y1,y2.
%  plotSpread(ax, x, y1, y2, color, name, varargin)

if nargin < 4 || isempty(y2), y2 = y1*0; end
if nargin < 5 || isempty(color)
    color = ax.ColorOrder(mod(ax.ColorOrderIndex - 1, size(ax.ColorOrder, 1)) + 1, :);
end
if nargin < 6 || isempty(name), name = ''; end

y1 = fillmissing(y1, 'constant', 0);
y2 = fillmissing(y2, 'constant', 0);

x = x + seconds(0.01); % HACK to fix patch
[X, Y1] = makeSteps(x, y1); % Makes into teps
[~, Y2] = makeSteps(x, y2);
XX = [ X(:); flipud( X(:))]; % Ford and then reverse
YY = [Y1(:); flipud(Y2(:))];

name = sprintf('\\color[rgb]{%g %g %g}%s', color, name);

h = patch(ax, XX, YY, color, 'EdgeColor', color, 'DisplayName', name, 'FaceAlpha', 0.3, 'EdgeAlpha', 0.2, varargin{:});

end