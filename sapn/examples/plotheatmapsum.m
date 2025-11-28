function [ax,panel] = plotheatmapsum(T, time, val, col, lbl, units, pos, f1, f2)
% Display time series data as heat map + sum plots inside a container panel.
% pos now defines the container location instead of the axes themselves.
%
% Output:
%   ax    = axes handles [heatmap, daily sum, tod sum]
%   panel = container panel handle (move this to move plots)

if nargin<4 || isempty(col), col = [1 0 0]; end
if nargin<5 || isempty(lbl), lbl = ''; end
if nargin<6 || isempty(units), units = ["" ""]; end
if nargin<7 || isempty(pos), pos = [0 0 1 1]; end
if nargin<8 || isempty(f1), f1 = @(x)sum(x, 1, 'omitmissing'); end
if nargin<9 || isempty(f2), f2 = @(x)sum(x, 1, 'omitmissing'); end

% Create container to hold the whole visualization
parentFig = ancestor(gcf,'figure');     % safe if used inside sub-GUIs
panel = uicontainer(parentFig,'Units','normalized','Position',pos,'BackgroundColor', get(parentFig,'Color'));

% Ensure visual consistency
units = string(units);
if isscalar(units)
    units = [units units];
end

% Compute TOD + Date
[T.tod, T.date] = timeofday(T.(time));

% Layout inside panel (relative)
mainPos  = [0.10 0.14 0.70 0.60];  % main heatmap - L B W H
cbarPos  = [0.03 0.14 0.02 0.60];  % color bar
topPos   = [0.10 0.74 0.70 0.15];  % daily summary
sidePos  = [0.80 0.14 0.15 0.60];  % tod summary

% Heatmap
ax(1) = axes('Parent',panel,'Position',mainPos);
plotheatmap(T.date, T.tod, T.(val))
colormap(ax(1),gradient(col));
if size(col,1)==1
    clim(ax(1),[0 max(T.(val))])
else
    clim(ax(1),max(abs(T.(val))).*[-1 1])
end
h = colorbar(ax(1),'Location','manual','Position',cbarPos);
h.Label.String = units(1);

% Daily summary (top)
G = groupsummary(T,'date',f1,val);
y = G{:,3};
ax(2) = axes('Parent',panel,'Position',topPos,'XColor','none');
if any(y<0)
    plotstepspread(ax(2),G.date,max(y,0),[],col(1,:),sprintf('avg=%.2f',mean(max(y,0))))
    plotstepspread(ax(2),G.date,min(y,0),[],col(2,:),sprintf('avg=%.2f',mean(min(y,0))))
else
    plotstepspread(ax(2),G.date,y,[],col(1,:),sprintf('avg=%.2f',mean(y)))
end
ylabel(ax(2),units(2)), legend(ax(2),'show','Location','best'), title(ax(2),lbl)

% TOD summary (side)
G = groupsummary(T,'tod',f2,val);
y = G{:,3};
ax(3) = axes('Parent',panel,'Position',sidePos,'YColor','none');
if any(y<0)
    plotstepspread(ax(3),G.tod,max(y,0),[],col(1,:),sprintf('avg=%.3f',mean(max(y,0))),'yx')
    plotstepspread(ax(3),G.tod,min(y,0),[],col(2,:),sprintf('avg=%.3f',mean(min(y,0))),'yx')
else
    plotstepspread(ax(3),G.tod,y,[],col(1,:),sprintf('avg=%.3f',mean(y)),'yx')
end
ylim(ax(3),duration([0 24],0,0))
xlabel(ax(3),units(1)), legend(ax(3),'show','Location','best')

end

function cmap = gradient(col, n)
if nargin<2 || isempty(n), n = 265; end

if size(col,1) == 1
    c = [0 0 0; max(col-0.7, 0); col; 1 1 1];
    cmap = interp1([0 0.1 0.5 1], c, linspace(0,1,n));
else
    cmap = [flipud(gradient(col(2,:), n/2)); gradient(col(1,:), n/2)];
end
end
