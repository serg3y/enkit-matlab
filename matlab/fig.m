function fig(h, varargin)
% Prepare new figure for a certain style of plot.
%   fig(h, style1, style2,...)  where fig is a figure number or handle.
%
% Example:
%   fig(1, 'dark', 'handy')
%   plot(rand(10))
%

% Defaults
if nargin<1 || isempty(h), h = gcf; end
if nargin<2, varargin = {'default'}; end

% Create figure
h = clf(figure(h));

% Apply styles
cellfun(@(x)applymode(h, x), varargin)
end

function applymode(h, mode)
switch lower(mode)
    case 'handy'
        set(h, 'WindowStyle', 'docked');
        set(h, 'NumberTitle', 'off');
        set(h, 'Name', num2str(h.Number));
        set(h, 'DefaultAxesCreateFcn', @(ax, ~) hold(ax, 'on'));
        set(h, 'DefaultAxesXGrid', 'on');
        set(h, 'DefaultAxesYGrid', 'on');
        set(h, 'DefaultAxesBox', 'on');
        set(h, 'DefaultAxesFontSize', 12);
        set(h, 'DefaultAxesTickLabelInterpreter', 'none');
        set(h, 'DefaultTextInterpreter', 'none');
        set(h, 'DefaultColorbarTickLabelInterpreter', 'none');

    case 'dark'
        set(h, 'Color', [0.1 0.1 0.1]);

        white = [0.7 0.7 0.7];
        set(h, 'DefaultAxesColor', [0 0 0]);
        set(h, 'DefaultAxesXColor', white);
        set(h, 'DefaultAxesYColor', white);
        set(h, 'DefaultAxesZColor', white);
        set(h, 'DefaultAxesGridColor', white);
        set(h, 'DefaultAxesMinorGridColor', white*0.8);
        set(h, 'DefaultAxesColorOrder', [
            1.0 0.4 0.4
            0.4 0.8 1.0
            1.0 1.0 0.4
            0.8 0.6 1.0
            0.4 1.0 0.6
            1.0 0.6 0.2
            0.6 0.6 0.6]);
        set(h, 'DefaultTextColor', white);
        set(h, 'DefaultColorbarColor', white);
        set(h, 'DefaultLegendTextColor', white);

    case 'default'
        set(h, 'NumberTitle', 'on');
        set(h, 'Color', get(groot, 'DefaultFigureColor'));
        set(h, 'Name', '');

        reset(h, 'DefaultAxesCreateFcn');
        reset(h, 'DefaultAxesXGrid');
        reset(h, 'DefaultAxesYGrid');
        reset(h, 'DefaultAxesBox');
        reset(h, 'DefaultAxesFontSize');
        reset(h, 'DefaultAxesTickLabelInterpreter');
        reset(h, 'DefaultTextInterpreter');
        reset(h, 'DefaultColorbarTickLabelInterpreter');

        reset(h, 'DefaultAxesColor');
        reset(h, 'DefaultAxesXColor');
        reset(h, 'DefaultAxesYColor');
        reset(h, 'DefaultAxesZColor');
        reset(h, 'DefaultAxesGridColor');
        reset(h, 'DefaultAxesMinorGridColor');
        reset(h, 'DefaultAxesColorOrder')
        reset(h, 'DefaultTextColor');
        reset(h, 'DefaultColorbarColor');
        reset(h, 'DefaultLegendTextColor');

end
end

function reset(h, prop)
set(h, prop, get(groot, prop))
end