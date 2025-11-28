function h = colorbarsml(label, varargin)
% Create a small colorbar, and dont move axis.
% h = colorbarsml(label, varargin)

% Turn on colorbar
drawnow % without this colorbar width is hard to control
colorbar off
ax_pos = get(gca, 'Position'); % Save axis position
h = colorbar(varargin{:});
set(gca, 'Position', ax_pos); % Restore axis position

% Make colorbar smaller
pos = h.Position;
pos(1) = ax_pos(1)+ ax_pos(3) + 0.001; % Move left
pos(2) = pos(2) + pos(4) * 0.05; % Move up
pos(3) = pos(3) * 0.6; % Reduce width
pos(4) = pos(4) * 0.9; % Reduce height
h.Position = pos;

if nargin && ~isempty(label)
    set(h.Label, 'String', label, 'FontSize', get(gcf, 'DefaultAxesFontSize'))
end

if ~nargout
    clear h
end
end