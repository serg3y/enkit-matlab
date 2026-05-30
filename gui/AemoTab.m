function app = AemoTab(tabGroup, app, cfg)
H = cfg.H;
W = cfg.W;
fold = fullfile(cfg.rootFold, 'aemo', 'data');
ht = uitab(tabGroup, 'Title', 'AEMO');

uihyperlink(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Download and import AEMO wholesale price data', 'URL', 'https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data');
uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'aemo', 'Readme.txt')));

uilabel(ht, 'Position', [10 H-100 70 30], 'Text', 'Input:');
h = uieditfield(ht, 'text', 'Position', [50 H-100 W-220 30], 'Value', fold);
uibutton(ht, 'push', 'Position', [W-160 H-100 30 30], 'Icon', cfg.foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.selectFolder(h));

uilabel(ht, 'Position', [10 H-140 40 30], 'Text', 'State:');
hState = uidropdown(ht, 'Position', [50 H-140 100 30], 'Value', 'SA', 'Items', ["NSW" "QLD" "VIC" "SA" "TAS"]);
uilabel(ht, 'Position', [290 H-140 80 30], 'Text', 'Date range:');
t1 = uieditfield(ht, 'Position', [360 H-140 100 30], 'Value', '-400', 'Tag', 'start_time');
t2 = uieditfield(ht, 'Position', [500 H-140 100 30], 'Value', '-5', 'Tag', 'stop_time');

uibutton(ht, 'push', 'Position', [W-80 H-100 70 30], 'Text', 'Read', 'ButtonPushedFcn', @(~,~)importAemoData());
uibutton(ht, 'push', 'Position', [W-80 H-140 70 30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadAemoData());

    function importAemoData()
        T = aemo().read(hState.Value, {t1.Value, t2.Value});
        app.appendData(T);
    end

    function downloadAemoData()
        aemo().download(hState.Value, {t1.Value, t2.Value});
    end
end
