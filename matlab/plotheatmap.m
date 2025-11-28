function [h, A, xVec, yVec] = plotheatmap(X, Y, V, accumfun, fillval, alphafun, range, cmap)
% Plot heatmap and activate data cursor.
%   plotheatmap(X, Y, V)
%   plotheatmap(X, Y, V, accumfun, fillval, alphafun)
%   [h, A, xVec, yVec] = plotheatmap(__)
%
% Remarks
% - Fills missing data, but assumes step size is fixed.
% - Assumes x,y are provided at the start of each interval.

% Defaults
if nargin<5 || isempty(accumfun)
    accumfun = @sum;
end
if nargin<6 || isempty(fillval)
    fillval = NaN;
end
if nargin<7 || isempty(alphafun)
    if any(isnumeric(V))
        alphafun = @(x)double(~isnan(x));
    else
        alphafun = [];
    end
end
immode = nargin>=8 && (~isempty(range) || ~isempty(cmap));
if immode
    if isempty(range)
        range = [min(V(:)), max(V(:))];
    end
    if isempty(cmap)
        cmap = colormap;
    end
end

% Infer step size
xStep = mode(diff(unique(X)));
yStep = mode(diff(unique(Y)));

% Create full range
xVec = min(X) : xStep : max(X);
yVec = min(Y) : yStep : max(Y);

% Map X and Y onto indices
xi = round((X - min(X)) / xStep) + 1;
yi = round((Y - min(Y)) / yStep) + 1;

% Accumulate
A = accumarray([yi xi], V, [numel(yVec) numel(xVec)], accumfun, fillval);

% Display
if immode
    img = val2img(A, range, cmap); % Convert to array to an RGB image
    h = imagesc([min(X) max(X)] + xStep/2, [min(Y) max(Y)] + yStep/2, img, 'UserData', A);
else
    h = imagesc([min(X) max(X)] + xStep/2, [min(Y) max(Y)] + yStep/2, A);
end

% Tweak appearance
axis tight
if isduration(Y)
    ax = gca;
    ax.YAxis.TickLabelFormat = 'hh:mm'; % Imporve tick format
end

% Make NaNs transperant
if ~isempty(alphafun) && ~immode
    alpha(h, alphafun(A));
end

% Draw a box
xline(xlim, 'color', get(groot, 'DefaultAxesXColor'))
yline(ylim, 'color', get(groot, 'DefaultAxesXColor'))

% Data cursor
set(datacursormode(gcf), 'UpdateFcn', @dataTip);

% Outputs
if ~nargout
    clear h
end
end

function txt = dataTip(~, event)
% Custom data cursor for 2D image-like data

if ~isempty(event.Target.UserData)
    A = event.Target.UserData;
else
    A = event.Target.CData;
end
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

txt = sprintf('%.4f\nx: %s\ny: %s', A(yIdx, xIdx), string(xCenters(xIdx)), string(yCenters(yIdx)));
end
