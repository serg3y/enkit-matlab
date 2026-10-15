function app = InflationTab(tabGroup, app, cfg)
H = cfg.H;
ht = uitab(tabGroup, 'Title', 'Inflation');
uilabel(ht, 'Position', [10 H-60 400 30], 'Text', 'Inflation data from FRED.', 'FontSize', 14);
uibutton(ht, 'push', 'Position', [10 H-100 100 30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadInflation());

uilabel(ht, 'Position', [120 H-100 80 30], 'Text', 'Date range:');
t1 = uieditfield(ht, 'Position', [200 H-100 100 30], 'Tag', 'start_time', 'Placeholder', 'yyyy-mm-dd');
t2 = uieditfield(ht, 'Position', [310 H-100 100 30], 'Tag', 'stop_time',  'Placeholder', 'yyyy-mm-dd');
uibutton(ht, 'push', 'Position', [420 H-100 100 30], 'Text', 'Read', 'ButtonPushedFcn', @(~,~)readInflation());

    function downloadInflation()
        url = 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=AUSCPIALLQINMEI';
        file = fullfile(cfg.rootFold, 'inflation', 'AUSCPIALLQINMEI.csv');
        if ~isfolder(fileparts(file))
            mkdir(fileparts(file));
        end
        system(sprintf('curl -sS -L -o "%s" "%s"', file, url));
    end

    function readInflation()
        file = fullfile(cfg.rootFold, 'inflation', 'AUSCPIALLQINMEI.csv');
        T = readtable(file);
        T = renamevars(T, {'observation_date' 'AUSCPIALLQINMEI'}, {'time' 'inflation'});
        T.time.TimeZone = '+1000';
        T.inflation = T.inflation ./ T.inflation(end); % Normalise
        T.Properties.VariableUnits = {'' 'coef'};
        T = table2timetable(T);

        % Update plot
        delete(findobj(ht, 'Tag', 'InflationPlot'))
        hAx = uiaxes(ht, 'Position', [10 10 cfg.W-20 H-140], 'XGrid', 'on', 'YGrid', 'on', 'NextPlot', 'add', 'Tag', 'InflationPlot');
        ylabel(hAx, 'Inflation (coef)');
        title(hAx, sprintf('Australian Consumer Price Index (Normalised to %s)', char(T.time(end), 'uuuu-MM-dd')));
        plot(hAx, T.time(end), T.inflation(end), 'ro', 'LineWidth', 2)

        % Interpolate
        T = retime(T, checkdate(t1.Value, '+1000') : cfg.rez : checkdate(t2.Value, '+1000') - seconds(1), 'linear');

        % Plot
        plot(hAx, T.time, T.inflation, '.-', 'LineWidth', 2)

        % Append
        app.appendData(app.conditionTable(T));
    end
end
