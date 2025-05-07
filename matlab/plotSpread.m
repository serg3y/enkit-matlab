function plotSpread(ax, x, y, x2, y2, color, name, varargin)
% Plots a region about x,y defined by x2,y2.
%  plotSpread(ax, x, y, x2, y2, color, name, varargin)

if nargin < 4 || isempty(x2), x2 = x; end
if nargin < 5 || isempty(y2), y2 = y*0; end
if nargin < 6 || isempty(color)
    color = ax.ColorOrder(mod(ax.ColorOrderIndex - 1, size(ax.ColorOrder, 1)) + 1, :);
end
if nargin < 7 || isempty(name), name = ''; end

y  = fillmissing(y,  'constant', 0);
y2 = fillmissing(y2, 'constant', 0);

x = x + seconds(0.01); % HACK to fix patch
[X,  Y ] = makeSteps(x,  y ); % Makes into teps
[X2, Y2] = makeSteps(x2, y2);
XX = [X(:); flipud(X2(:))]; % Ford and then reverse
YY = [Y(:); flipud(Y2(:))];

name = sprintf('\\color[rgb]{%g %g %g}%s', color, name);

patch(ax, XX, YY, color, 'EdgeColor', color, 'DisplayName', name, 'FaceAlpha', 0.3, 'EdgeAlpha', 0.2, varargin{:});

end