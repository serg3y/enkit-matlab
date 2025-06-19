function axis_stack(row, numrows, col, numcols, margins, spacing)

% Defaults
if nargin<1 || isempty(row), row = 1; end
if nargin<2 || isempty(numrows), numrows = 1; end
if nargin<3 || isempty(col), col = 1; end
if nargin<4 || isempty(numcols), numcols = 1; end
if nargin<5 || isempty(margins), margins = [0.04 0.04]; end %LTRB
if nargin<6 || isempty(spacing), spacing = [0 0]; end %XY

% Create axis
height = (1-margins(2)-margins(4))/numrows;
width = (1-margins(1)-margins(3)-(numcols-1)/10)/numcols;
ax = axes('Position', [(1/numcols)*(col-1)+margins(1)  1-margins(2)-height*row  width-spacing(1) height-spacing(2)]);
box on, axis tight
if row < numrows
    ax.XRuler.FontSize = 0.01; % Hide X axis
end
set(ax, 'TickLength', [0.004 0])
end