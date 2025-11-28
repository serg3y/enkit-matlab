function ax = axis_stack(row, numrows, col, numcols, margins, spacing, heading)
% axis_stack(row,numrows,col,numcols,margins,spacing,heading)
% Supports multi-tile spanning via vector row/col inputs.

% Defaults
if nargin<1 || isempty(row),     row = 1; end
if nargin<2 || isempty(numrows), numrows = 1; end
if nargin<3 || isempty(col),     col = 1; end
if nargin<4 || isempty(numcols), numcols = 1; end
if nargin<5 || isempty(margins), margins = [0.06 0.04 0.06 0.04]; end   % L T R B
if nargin<6 || isempty(spacing), spacing = [0 0]; end                   % X Y
if nargin<7 || isempty(heading), heading = ''; end

row = row(:)'; col = col(:)';  % force row vector form

% Normalize margins/spacings
if isscalar(margins), margins = repmat(margins,1,4); end
if numel(margins)==2, margins = [margins margins]; end  % [LR TB] → [L T R B]
if isscalar(spacing), spacing = [spacing spacing]; end

% Span size determination
rows_spanned = max(row) - min(row) + 1;
cols_spanned = max(col) - min(col) + 1;

% Individual tile sizes
tile_h = (1 - margins(2) - margins(4) - (numrows-1)*spacing(2)) / numrows;
tile_w = (1 - margins(1) - margins(3) - (numcols-1)*spacing(1)) / numcols;

% Final axis dims
height = rows_spanned*tile_h + (rows_spanned-1)*spacing(2);
width  = cols_spanned*tile_w + (cols_spanned-1)*spacing(1);

left   = margins(1) + (min(col)-1)*(tile_w+spacing(1));
bottom = 1 - margins(2) - max(row)*tile_h - (max(row)-1)*spacing(2);

% Build axis
ax = axes('Position', [left bottom width height]);
box on, axis tight
set(ax,'TickLength',[0.004 0])

% Hide X axis unless lowest block
if max(row) < numrows
    ax.XRuler.FontSize = 0.01;
end

% Title positioning
if ~isempty(heading)
    title(heading,'Position',[0.5 0.85 0],'Units','normalized')
end

if ~nargout
    clear ax
end
end
