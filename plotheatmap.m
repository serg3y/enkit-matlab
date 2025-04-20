function [h, A, xCats, yCats] = plotheatmap(T, xvar, yvar, vvar, accumfun, fillval, alphafun)
% Plot heatmap and activate data cursor
% - Presumes all intervals are same size
% - Presumes x,y are provided at the start of an interval

if nargin<5 || isempty(accumfun)
    accumfun = @sum;
end
if nargin<6 || isempty(fillval)
    fillval = NaN;
end
if nargin<7 || isempty(alphafun)
    if any(isnumeric(T.(vvar)))
        alphafun = @(x)double(~isnan(x));
    else
        alphafun = [];
    end
end

X = T.(xvar);
Y = T.(yvar);
V = T.(vvar);

% Accumulate
[xCats, ~, xi] = unique(X);
[yCats, ~, yi] = unique(Y);
A = accumarray([yi xi], V, [numel(yCats) numel(xCats)], accumfun, fillval);

% Plot
axis tight
if isduration(yCats)
    axis xy
else
    axis ij
end
dx = mode(diff(xCats));
dy = mode(diff(yCats));
h = imagesc([min(X) max(X)] + dx/2, [min(Y) max(Y)] + dy/2, A);

% Make NaNs transperant
if ~isempty(alphafun)
    alpha(h, alphafun(A));
end

% Draw a box
xline(xlim, 'color', get(groot, 'DefaultAxesXColor'))
yline(ylim, 'color', get(groot, 'DefaultAxesXColor'))

% Imporve tick format
if isduration(yCats)
    ax = gca;
    ax.YAxis.TickLabelFormat = 'hh:mm';
end

% Data cursor
set(datacursormode(gcf), 'UpdateFcn', @dataTip);

% Outputs
if ~nargout
    clear h
end
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
