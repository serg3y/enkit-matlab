
x_range = [min(T.start) max(T.start)] + minutes(x_step/2);
y_range = duration([-0.25 24.25], 0, 0, 'Format', 'hh:mm');
v = t{:, 2:end}'; % values forecast by date, 50 by 288

% Plot
clf, hold on, axis tight
h = imagesc(x_range, y_range, v);

y_edges = duration(t.Properties.VariableNames(2:end), 'Format', 'hh:mm');
x_edges = t.query;
data = struct('A', v, 'y_edges', y_edges, 'x_edges', x_edges, 'ax', gca);
set(h, 'UserData', data); % Store the data in the axis UserData

set(datacursormode(gcf), 'UpdateFcn', @dataTip);

function txt = dataTip(~, event)
% Custom data cursor function
ud = event.Target.UserData;  % Retrieve the UserData struct

% Get the datetime positions based on the cursor position
[~, ~, xi] = histcounts(num2ruler(event.Position(1), ud.ax.XAxis), ud.x_edges);
[~, ~, yi] = histcounts(num2ruler(event.Position(2), ud.ax.YAxis), ud.y_edges);

% Format the data tip text
txt = sprintf('Value: %.2f\nTime: %s\nDay: %s', ud.A(yi, xi), ud.y_edges(yi), ud.x_edges(xi));
end