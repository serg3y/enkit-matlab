function [h, A, xCats, yCats] = plotheatmap(T, xvar, yvar, vvar, defaultvalue)
% Plot heatmap and activate data cursor
% - Presumes all intervals are same size
% - Presumes x,y are provided at the start of an interval

if nargin<5 || isempty(defaultvalue)
    defaultvalue = NaN;
end

X = T.(xvar);
Y = T.(yvar);
V = T.(vvar);

[xCats, ~, xi] = unique(X);
[yCats, ~, yi] = unique(Y);

dx = mode(diff(xCats));
dy = mode(diff(yCats));

A = accumarray([yi xi], V, [numel(yCats) numel(xCats)], @(x)median(x, 'omitnan'), defaultvalue); % Accumulate

hold on, axis tight xy
h = imagesc([min(X) max(X)] + dx/2, [min(Y) max(Y)] + dy/2, A);

alpha(h, ~isnan(A)*1);

set(datacursormode(gcf), 'UpdateFcn', @dataTip);
end

function txt = dataTip(~, event)
% Custom data cursor for 2D image-like data

A = event.Target.CData;
xdata = event.Target.XData;
ydata = event.Target.YData;

[ny, nx] = size(A);
xCenters = linspace(xdata(1), xdata(2), nx);
yCenters = linspace(ydata(1), ydata(2), ny);

dx = mode(diff(xCenters));
dy = mode(diff(yCenters));
xEdges = [xCenters - dx/2, xCenters(end) + dx/2];
yEdges = [yCenters - dy/2, yCenters(end) + dy/2];

xPos = num2ruler(event.Position(1), event.Target.Parent.XAxis);
yPos = num2ruler(event.Position(2), event.Target.Parent.YAxis);
xIdx = discretize(xPos, xEdges);
yIdx = discretize(yPos, yEdges);

txt = sprintf('v: %.2f\nx: %s\ny: %s', A(yIdx, xIdx), string(xCenters(xIdx)), string(yCenters(yIdx)));
end
