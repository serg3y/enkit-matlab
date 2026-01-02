function h = plotstepspread(ax, x, y1, y2, color, name, mode, varargin)
% Plots a region defined by x,y1,y2.
%  plotdpread2(ax, x, y1, y2, color, name, mode, varargin)

% Defaults
if nargin < 4 || isempty(y2), y2 = y1*0; end
if nargin < 5 || isempty(color)
    color = ax.ColorOrder(mod(ax.ColorOrderIndex - 1, size(ax.ColorOrder, 1)) + 1, :);
end
if nargin < 6 || isempty(name), name = ''; end
if nargin < 7 || isempty(mode), mode = 'xy'; end

% Checks
color = color2rgb(color);
y1 = fillmissing(y1, 'constant', 0);
y2 = fillmissing(y2, 'constant', 0);

% HACK to fix patch glitches
if isduration(x)
    x = x + seconds(0.01);
end

% Makes into teps
[X, Y1] = makeSteps(x, y1);
[~, Y2] = makeSteps(x, y2);

% Make an area
XX = [ X(:); flipud( X(:))];
YY = [Y1(:); flipud(Y2(:))];

% Coloured legend
name = sprintf('\\color[rgb]{%g %g %g}%s', color, name);

% Create patch
if strcmpi(mode,'xy')
    h = patch(ax, XX, YY, color, 'EdgeColor', color, 'DisplayName', name, 'FaceAlpha', 0.3, 'EdgeAlpha', 0.2, varargin{:});
else
    h = patch(ax, YY, XX, color, 'EdgeColor', color, 'DisplayName', name, 'FaceAlpha', 0.3, 'EdgeAlpha', 0.2, varargin{:});
end

if ~nargout
    clear h
end

end
