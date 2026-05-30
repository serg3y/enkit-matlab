function app = InflationTab(tabGroup, app, cfg)
H = cfg.H;
ht = uitab(tabGroup, 'Title', 'Inflation');
uilabel(ht, 'Position', [10 H-60 400 30], 'Text', 'Inflation data from FRED.', 'FontSize', 14);
uibutton(ht, 'push', 'Position', [10 H-100 100 30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadInflation());
uibutton(ht, 'push', 'Position', [120 H-100 100 30], 'Text', 'Read', 'ButtonPushedFcn', @(~,~)readInflation());

% Add Date range input boxes that behave same as other tabs and limit how much data is read in. This will be used to calculate inflation over a specific period.
uilabel(ht, 'Position', [10 H-140 80 30], 'Text', 'Date range:');
t1 = uieditfield(ht, 'Position', [90 H-140 100 30], 'Value', '2020-01-01', 'Tag', 'start_date');
t2 = uieditfield(ht, 'Position', [200 H-140 100 30], 'Value', '2023-01-01', 'Tag', 'stop_date');

    function downloadInflation()
        url = 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=AUSCPIALLQINMEI';
        file = fullfile(cfg.rootFold, 'inflation', 'AUSCPIALLQINMEI.csv');
        if ~isfolder(fileparts(file))
            mkdir(fileparts(file));
        end
        system(sprintf('curl -L -o "%s" "%s"', file, url));
    end

    function T = readInflation()
        file = fullfile(cfg.rootFold, 'inflation', 'AUSCPIALLQINMEI.csv');
        if isfile(file)
            T = readtable(file);
            T = renamevars(T, {'observation_date' 'AUSCPIALLQINMEI'}, {'time' 'inflation'});
            T.inflation = T.inflation./T.inflation(end);
            T.time.TimeZone = 'UCT';

            % Filter by date range

            app.appendData(T);
        end
    end
end
