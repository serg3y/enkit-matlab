function figmode(varargin)
% Apply preset graphics settings to MATLAB figures.
%    figmode(mode1, mode2, ...)
%    figmode(fig, mode1, ...)  where fig is a figure number or handle.
%
% Examples:
%   figmode(-1, 'dark', 'handy')

% Check inputs
fig = [];
clr = false;
if ~isempty(varargin) && (isnumeric(varargin{1}) || isgraphics(varargin{1}, 'figure'))
    if isnumeric(varargin{1})
        fig = abs(varargin{1});
        clr = varargin{1} < 0;
    else
        fig = varargin{1};
    end
    varargin = varargin(2:end);
end
if isempty(varargin)
    varargin = {'default'};
end

% Apply each mode
cellfun(@applymode, varargin)

% Focus and figure
if ~isempty(fig) && isscalar(fig)
    if clr && ishandle(fig)
        close(fig)
        figure(fig)
    end
    figure(fig)
end
end

function applymode(mode)
switch mode
    case {'Default' 'reset'}
        applymode('light')
        applymode('nohandy')

    case 'handy'
        set(groot, 'DefaultAxesCreateFcn', @(ax, ~) hold(ax, 'on'));
        set(groot, 'DefaultAxesXGrid', 'on');
        set(groot, 'DefaultAxesYGrid', 'on');
        % set(groot, 'DefaultAxesBox', 'on');
        set(groot, 'DefaultFigureWindowStyle', 'docked');
        set(groot, 'DefaultFigureNumberTitle', 'off');
        set(groot, 'DefaultFigureCreateFcn', @(h, ~) set(h, 'Name', num2str(h.Number)));
        set(groot, 'DefaultAxesFontSize', 12);
        set(groot, 'DefaultTextFontSize', 12);
        set(groot, 'DefaultColorbarCreateFcn', @(h, ~) set(get(h, 'Label'), 'FontSize', 10));

    case 'nohandy'
        set(groot, 'DefaultAxesCreateFcn', 'remove');
        set(groot, 'DefaultAxesXGrid', 'remove');
        set(groot, 'DefaultAxesYGrid', 'remove');
        set(groot, 'DefaultAxesBox', 'remove');
        set(groot, 'DefaultFigureWindowStyle', 'remove');
        set(groot, 'DefaultFigureNumberTitle', 'remove');
        set(groot, 'DefaultFigureCreateFcn', 'remove');
        set(groot, 'DefaultAxesFontSize', 'remove');
        set(groot, 'DefaultTextFontSize', 'remove');
        set(groot, 'DefaultColorbarCreateFcn', 'remove');

    case 'dark'
        white = [0.7 0.7 0.7];
        set(groot, 'DefaultFigureColor', [0 0 0]);
        set(groot, 'DefaultAxesColor', [0 0 0]);
        set(groot, 'DefaultAxesXColor', white);
        set(groot, 'DefaultAxesYColor', white);
        set(groot, 'DefaultAxesZColor', white);
        set(groot, 'DefaultTextColor', white);
        set(groot, 'DefaultAxesGridColor', white);
        set(groot, 'DefaultAxesMinorGridColor', white);
        set(groot, 'DefaultColorbarColor', white);
        set(groot, 'DefaultLegendTextColor', white);
        set(groot, 'DefaultAxesColorOrder', [
            1.0 0.4 0.4
            0.4 0.8 1.0
            1.0 1.0 0.4
            0.8 0.6 1.0
            0.4 1.0 0.6
            1.0 0.6 0.2
            0.6 0.6 0.6]);

    case 'light'
        set(groot, 'DefaultFigureColor', 'remove');
        set(groot, 'DefaultAxesColor', 'remove');
        set(groot, 'DefaultAxesXColor', 'remove');
        set(groot, 'DefaultAxesYColor', 'remove');
        set(groot, 'DefaultAxesZColor', 'remove');
        set(groot, 'DefaultTextColor', 'remove');
        set(groot, 'DefaultAxesGridColor', 'remove');
        set(groot, 'DefaultAxesMinorGridColor', 'remove');
        set(groot, 'DefaultColorbarColor', 'remove');
        set(groot, 'DefaultLegendTextColor', 'remove');
        set(groot, 'DefaultAxesColorOrder', 'remove');

end
end