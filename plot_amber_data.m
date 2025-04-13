% PLOT AMBER ENERGY PRICE DATA

% Examples
plotPrice(18, {'2025-01-01' '2025-03-20'}, "sapn_andrew", ["buy_amount" "buy_amount" "tariff_amount" "tariff_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" "" "heatmap" ""])
% plotPrice(17, {'2025-01-01' '2025-03-20'}, "sapn_serge", ["buy_amount" "buy_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" ""])
return
plotPrice(16, {'2025-01-01' '2025-03-20'}, "sapn_andrew", ["buy_amount" "buy_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" ""])
% return
plotPrice(15, {'2025-01-01' '2025-03-20'}, "amber_nmi", ["buy_price" "buy_amount" "buy_price_diff" "buy_saving" "buy_saving"], ["heatmap" "heatmap" "heatmap" "heatmap" ""])
% return
plotPrice(14, {'2025-01-01' '2025-03-20'}, ["buy_price"], ["heatmap" ])
% plotPrice(13, {'2025-01-01' '2025-03-20'}, "net_saving", "heatmap")
plotPrice(12, {'2025-01-01' '2025-03-20'}, ["buy_saving" "sell_saving"], "heatmap")
plotPrice(11, {'2025-01-01' '2025-03-01'}, ["buy_amount" "sell_amount"], "heatmap")
plotPrice(10, {'2025-01-01' '2025-03-01'}, ["buy_price" "sell_price"], "heatmap")
plotPrice(9, {'2025-01-01' '2025-03-01'}, ["buy_price_diff" "sell_price_diff"], "heatmap")
plotPrice(8, {'2025-01-01' -1}, ["buy_price" "sell_price"], "24hr")
plotPrice(7, {'2025-01-01' -1}, ["buy_price" "sell_price"], "24hr")
plotPrice(6, {'2025-01-01' -1}, ["buy_price_diff" "sell_price_diff"], "24hr")
plotPrice(5, {'2025-01-01' '2025-01-10'}, ["buy_price_diff" "sell_price_diff"])
plotPrice(4, {'2025-01-01' '2025-01-01'}, ["buy_price_diff" "sell_price_diff"])
plotPrice(3, {'2025-01-01' '2025-01-01'}, ["buy_price" "sell_price"], "agl")
plotPrice(2, {'2025-01-01' '2025-01-01'}, ["buy_price" "sell_price"], ["36" "6" "18"])
plotPrice(1, {'2025-01-01' '2025-01-01'}, "buy_price&sell_price", "5min")


function plotPrice(fig, span, source, type, mode)
if nargin < 5 || isempty(mode)
    mode = "";
end
if ~isscalar(type) && isscalar(mode)
    mode = repmat(mode, size(type));
end

switch source
    case 'sapn_andrew'
        T = nem12read('sapn\andrew');
    case 'sapn_serge'
        T = nem12read('sapn\serge');
    case 'amber_prices_30min'
        T = amber().getData('prices', span, 30);
    case 'amber_prices_5min'
        T = amber().getData('prices', span, 5);
    case 'amber_usage_30min'
        T = amber().getData('usage', span, 30);
    case 'amber_usage_5min'
        T = amber().getData('usage', span, 5);
    otherwise
        error('Unknown source: %s\n',source)
end

% Prepare figure
figure(fig), clf
set(fig, 'WindowStyle', 'docked', 'Color', 'k', 'NumberTitle', 'off', 'Name', num2str(fig))
plot_y = linspace(0.03, 0.97, numel(type) + 1); % Plot heights

% Plot one axis at a time
A = []; % Init handles list
for k = 1:numel(type)

    % Setup axis
    a = axes('Position', [0.08 plot_y(end-k) 0.84 plot_y(end-k+1) - plot_y(end-k)], ...
        'Color', 'k', 'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6], 'GridColor', [0.6 0.6 0.6]);
    hold on, grid on, box on, axis tight
    switch k
        case 1, set(a, 'XAxisLocation', 'top')
        case numel(type), set(a, 'XAxisLocation', 'bottom')
        otherwise, a.XRuler.FontSize = 0.01; % no axis
    end

    X = T.start;
    switch type(k)

        case {'buy_amount' 'sell_amount'  'tariff_amount'}
            ylabel(regexprep([source; type(k)], {'_' 'amount'}, {' ' '(kwh)'}))
            X = T.start;
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

        case {'buy_price' 'sell_price' 'tariff_price'}
            ylabel(regexprep(type(k), {'_' 'amount'}, {' ' '(kwh)'}))
            Y = T.(type(k));
            c = col(type(k));
            switch mode(k)
                case "agl"
                    plotSpread(a, X, Y, X, agl(X, type(k)), c)
                    plotLine(a, X, Y, c)
                case "5min"
                    plotSpread(a, X, Y, T2.start, T2.(type(k)), c)
                    plotLine(a, X, Y, c)
                case "24hr"
                    X = timeofday(X);
                    plotLine(a, X, Y, [c 0.2], 'linewidth', 0.5)
                    Y = arrayfun(@(x) mean(Y(X == x)), unique(X));
                    X = unique(X);
                    plotLine(a, X, Y, c)
                case "heatmap"
                    if type(k) == "sell_price"
                        cmap = rbg;
                    else
                        cmap = flipud(rbg);
                    end
                    plotHeatmap(a, X, Y, cmap)
                otherwise
                    plotSpread(a, X, Y, X, Y*0 + str2double(mode(k)), c)
                    plotLine(a, X, Y, c)
            end

        case 'buy_saving'
            ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
            T = amber().getData('prices', span, 30);
            T2 = amber().getData('usage', span, 30);
            X = T.start;
            switch mode(k)
                case ""
                    Y = agl(X, 'buy_price') .* T2.buy_amount;
                    d = dateshift(X, 'start', 'day');
                    y1 = accumarray(findgroups(d), Y, [], @sum)/100 + agl([], 'supply');
                    t = sprintf('\\color[rgb]{1 .2 .2}AGL = $%.2f\n', sum(y1) );
                    plotLine(a, unique(d), y1, [1 .2 .2], 'DisplayName', t)

                    Y = T.buy_price .* T2.buy_amount;
                    d = dateshift(X, 'start', 'day');
                    y = accumarray(findgroups(d), Y, [], @sum)/100 + amb([], 'supply');
                    t = sprintf('\\color[rgb]{.4 .4 1}Amber = $%.2f\n', sum(y) );
                    plotLine(a, unique(d), y, [0.2 .2 1], 'DisplayName', t)

                    y3 = y-y1;
                    t = sprintf('\\color[rgb]{.2 1 .2}Saving = $%.2f', sum(y3));
                    plotLine(a, unique(d), y3, [.2 1 .2], 'DisplayName', t)

                    legend show

                case "heatmap"
                    Y = (T.buy_price - agl(X, 'buy_price')) .* T2.buy_amount;
                    plotHeatmap(a, X, Y, flipud(rbg))
            end

        case 'sell_saving'
            ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
            T = amber().getData('prices', span, 30);
            T2 = amber().getData('usage', span, 30);
            X = T.start;
            % Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
            Y = (T.sell_price ) .* T2.sell_amount;
            cmap = rbg;
            plotHeatmap(a, X, Y, cmap)

        case 'net_saving'
            ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
            T = amber().getData('prices', span, 30);
            T2 = amber().getData('usage', span, 30);
            X = T.start;
            Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
            cmap = rbg;
            plotHeatmap(a, X, Y, cmap)

        case 'buy_price&sell_price'
            ylabel 'buy / sell'
            plotLine(a, X, T.buy_price, 'r')
            plotLine(a, X, T.sell_price, 'b')
            if mode(k) == "5min"
                plotSpread(a, X, T.buy_price, T2.start, T2.buy_price, 'r')
                plotSpread(a, X, T.sell_price, T2.start, T2.sell_price, 'b')
            end

        case {'buy_price_diff' 'sell_price_diff'}
            ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
            m = strrep(type(k), '_diff', '');
            Y = T.(m) - agl(X, m);
            c = col(m);
            switch mode(k)
                case '24hr'
                    X = timeofday(X);
                    plotLine(a, X, Y, [c 0.2], 'linewidth', 0.5)
                    X2 = unique(X);
                    Y2 = arrayfun(@(x) mean(Y(X == x)), X2);
                    plotLine(a, X2, Y2, c, 'linewidth', 2)
                case "heatmap"
                    if type(k) == "sell_price"
                        cmap = rbg;
                    else
                        cmap = flipud(rbg);
                    end
                    plotHeatmap(a, X, Y, cmap)
                otherwise
                    plotLine(a, X, Y, c)
            end

        case 'renewables'
            ylabel 'Renewables (%)'
            plotLine(a, X, T.renewables, [0 0.5 0])
            yline(a, 100, 'w--')
            linkaxes([a a], 'x'), xlim([min(X) max(T.stop)])
            if mode(k) == "5min"
                plotSpread(a, X, T.renewables, T2.start, T2.renewables, [0 0.5 0])
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

% Defaults
if nargin<5 || isempty(step), tod_step = minutes(mode(diff(x))); end

% Get time of day and date
tod = timeofday(x); % Time of day > Y
day = x - tod; % Date > X

% Form an array - time vs data
tod_edges = duration(0, 0:tod_step:24*60, 0, 0);
day_edges = min(day):max(day)+1;
[~, ~, tod_i] = histcounts(tod, tod_edges); % Bin based on time
[~, ~, day_i] = histcounts(day, day_edges); % Bin based on day
A = accumarray([tod_i day_i], y);

% Display heat map
h = imagesc(ax, day_edges([1 end-1])+0.5, tod_edges([1 end-1]) + tod_step/2/24/60 , A);
colormap(ax, cmap)
clim([-1 1]*min(max(A(:)), 160))
p = ax.Position;

% Display colorbar, don't move plot
hc = colorbar;
set(hc, 'color', [0.6 0.6 0.6]);
ax.Position = p;

set(hc, 'Position', hc.Position.*[1 1 0.6 1]-[0.01 0 0 0]);
xline(xlim, 'w'), yline(ylim, 'w') % Draw a box around the plot
ax.YAxis.TickLabelFormat = 'hh:mm';

% Set the custom data cursor callback function
dcm = datacursormode(gcf);
h.UserData = struct('A', A, 'tod_edges', tod_edges, 'day_edges', day_edges, 'ax', ax); % Store the data in the axis UserData
set(dcm, 'UpdateFcn', @dataTip);
end

function txt = dataTip(~, event)
% Custom data cursor function
h = event.Target; % Get axis that triggered the event
ud = h.UserData;  % Retrieve the UserData struct

if isempty(ud)
    txt = ''; return
end

% Get the datetime positions based on the cursor position
[~, ~, day_i] = histcounts(num2ruler(event.Position(1), ud.ax.XAxis), ud.day_edges);
[~, ~, tod_i] = histcounts(num2ruler(event.Position(2), ud.ax.YAxis), ud.tod_edges);

% Format the data tip text
txt = sprintf('Value: %.2f\nTime: %s\nDay: %s', ud.A(tod_i, day_i), ...
    char(ud.tod_edges(tod_i)), char(ud.day_edges(day_i)));
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