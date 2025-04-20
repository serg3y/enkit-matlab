function plotSpread(ax, x, y, x2, y2, color, varargin)
% Plots a region about x,y defined by x2,y2.

if nargin<4 || isempty(x2), x2 = x; end
if nargin<5 || isempty(y2), y2 = y*0; end

x = x + seconds(0.01); % HACK to fix patch
[X, Y] = makeSteps(x, y); % Makes into teps
[X2, Y2] = makeSteps(x2, y2);
XX = [X(:); flipud(X2(:))]; % Ford and then reverse
YY = [Y(:); flipud(Y2(:))];
patch(ax, XX, YY, color, 'FaceAlpha', 0.3, 'EdgeColor', color, 'EdgeAlpha', 0.2, varargin{:});

end