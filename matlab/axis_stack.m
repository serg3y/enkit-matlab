function axis_stack(row, numrows, col, numcols)

% Defaults
if nargin<1 || isempty(row), row = 1; end
if nargin<2 || isempty(numrows), numrows = 1; end
if nargin<3 || isempty(col), col = 1; end
if nargin<4 || isempty(numcols), numcols = 1; end

% Create axis
height = 0.9/numrows;
width = (0.91-(numcols-1)/10)/numcols;
ax = axes('Position', [(1/numcols)*(col-1)+0.04  0.96-height*row  width  height]);
box on, axis tight
if row < numrows
    ax.XRuler.FontSize = 0.01; % Hide X axis
end
set(ax, 'TickLength', [0.004 0])
end