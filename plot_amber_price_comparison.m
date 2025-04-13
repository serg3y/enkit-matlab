% PLOT AMBER ENERGY PRICE DATA

% Examples
plotmode dark handy
figure(1), clf
plotPrice("sapn_andrew", ["buy_amount" "buy_amount" "tariff_amount" "tariff_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" "" "heatmap" ""])

function plotPrice(source, type, mode)
if nargin < 5 || isempty(mode)
    mode = "";
end
if ~isscalar(type) && isscalar(mode)
    mode = repmat(mode, size(type));
end

switch source
    case 'sapn_andrew'
        T = nem12read('sapn\andrew');
    otherwise
        error('Unknown source: %s\n',source)
end

% Prepare figure
plot_y = linspace(0.03, 0.97, numel(type) + 1); % Plot heights

A = [];
for k = 1:numel(type)
    a = axes('Position', [0.08 plot_y(end-k) 0.84 plot_y(end-k+1) - plot_y(end-k)]);
    box on, axis tight
    switch k
        case 1, set(a, 'XAxisLocation', 'top')
        case numel(type), set(a, 'XAxisLocation', 'bottom')
        otherwise, a.XRuler.FontSize = 0.01;
    end

    X = T.start;
    switch type(k)
        case {'buy_amount' 'sell_amount'  'tariff_amount'}
            ylabel(regexprep([source; type(k)], {'_' 'amount'}, {' ' '(kwh)'}))
            Y = T.(type(k));
            [c, cmap, cstr] = col(type(k));
            switch mode(k)
                case "heatmap"
                    plotHeatmap(a, X, Y, cmap)
                case ""
                    d = dateshift(X, 'start', 'day');
                    y = accumarray(findgroups(d), Y, [], @sum);
                    t = sprintf([cstr '%.2fkwh\n'], sum(y));
                    plotLine(a, unique(d), y, c, 'DisplayName', t)
                    legend show
            end
    end

    if mode(k) ~= "heatmap"
        yline(a, 0, 'w--', 'HandleVisibility', 'off')
        ylim(a, ylim(a) + [-5 5])
    end
    A = [A a]; %#ok<AGROW>
end

ind = arrayfun(@(x)isdatetime(x.XLim), A);
if any(ind)
    linkaxes(A(ind), 'x')
end
ind = arrayfun(@(x)isduration(x.YLim)&isduration(x.YLim), A);
if any(ind)
    linkaxes(A(ind), 'xy')
end
if k == numel(type)
    file = sprintf('plots/%g.png', gcf().Number);
    figsave(gcf, file, [1920 1080])
end

end

function plotHeatmap(ax, x, y, cmap, tod_step)
if nargin<5 || isempty(tod_step), tod_step = minutes(mode(diff(x))); end

tod = timeofday(x);
day = x - tod;

tod_edges = duration(0, 0:tod_step:24*60, 0, 0);
day_edges = min(day):max(day)+1;
[~, ~, tod_i] = histcounts(tod, tod_edges);
[~, ~, day_i] = histcounts(day, day_edges);
A = accumarray([tod_i day_i], y);

h = imagesc(ax, day_edges([1 end-1])+0.5, tod_edges([1 end-1]) + tod_step/2/24/60 , A);
colormap(ax, cmap)
clim([-1 1]*min(max(A(:)), 160))
p = ax.Position;

hc = colorbar;
set(hc, 'color', [0.6 0.6 0.6]);
ax.Position = p;
set(hc, 'Position', hc.Position.*[1 1 0.6 1]-[0.01 0 0 0]);
xline(xlim, 'w'), yline(ylim, 'w')
ax.YAxis.TickLabelFormat = 'hh:mm';

dcm = datacursormode(gcf);
h.UserData = struct('A', A, 'tod_edges', tod_edges, 'day_edges', day_edges, 'ax', ax);
set(dcm, 'UpdateFcn', @dataTip);
end

function txt = dataTip(~, event)
h = event.Target;
ud = h.UserData;
if isempty(ud)
    txt = ''; return
end

[~, ~, day_i] = histcounts(num2ruler(event.Position(1), ud.ax.XAxis), ud.day_edges);
[~, ~, tod_i] = histcounts(num2ruler(event.Position(2), ud.ax.YAxis), ud.tod_edges);

if any(day_i==0) || any(tod_i==0)
    txt = 'Out of bounds';
else
    val = ud.A(tod_i, day_i);
    txt = {
        datestr(ud.day_edges(day_i), 'yyyy-mm-dd')
        sprintf('Time: %s', char(ud.tod_edges(tod_i)))
        sprintf('Value: %.2f', val)
    };
end
end

function [c, cmap, cstr] = col(str)
str = char(str);
switch str(1:3)
    case 'buy', c = [1.0 0.3 0.3]; cmap = flipud(rbg);
    case 'sel', c = [0.3 1.0 0.3]; cmap = rbg;
    case 'tar', c = [1.0 0.3 1.0]; cmap = flipud(rbg);
end
cstr = sprintf('\\\\color[rgb]{%g %g %g}', c);
end
