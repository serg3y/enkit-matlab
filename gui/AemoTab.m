function app = AemoTab(tabGroup, app, cfg)
H = cfg.H;
W = cfg.W;
ht = uitab(tabGroup, 'Title', 'AEMO');

uihyperlink(ht,      'Position', [  10  H-60 W-40 30], 'Text', 'Statewide wholesale electricity price and usage data from AEMO.', 'URL', 'https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data', 'FontSize', 14);
uibutton(ht, 'push', 'Position', [W-40  H-60   30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'aemo', 'Readme.txt')));

uilabel(ht,          'Position', [  10 H-100   40 30], 'Text', 'State:');
hs = uidropdown(ht,  'Position', [  50 H-100   80 30], 'Value', 'SA', 'Items', ["NSW" "QLD" "VIC" "SA" "TAS"]);
uibutton(ht, 'push', 'Position', [ 140 H-100   30 30], 'Icon', cfg.foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)system(['explorer.exe /select, ' aemo().dataFold]));
uilabel(ht,          'Position', [ 200 H-100   70 30], 'Text', 'Date range:');
t1 = uieditfield(ht, 'Position', [ 270 H-100  100 30], 'Value', '-400', 'Tag', 'start_time', 'Placeholder', 'yyyy-mm-dd');
t2 = uieditfield(ht, 'Position', [ 380 H-100  100 30], 'Value', '-5', 'Tag', 'stop_time', 'Placeholder', 'yyyy-mm-dd');
uibutton(ht, 'push', 'Position', [ 510 H-100   70 30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadAemoData());
uibutton(ht, 'push', 'Position', [ 590 H-100   70 30], 'Text', 'Read', 'ButtonPushedFcn', @(~,~)importAemoData());

    function importAemoData()
        T = aemo().read(hs.Value, {t1.Value, t2.Value});
        T = renamevars(T, ["price_ckwh" "usage_gw"], lower(hs.Value) + ["_price_ckwh" "_usage_gw"]);
        T.Properties.VariableDescriptions = upper(hs.Value) + [" Price" " Usage"];
        T.Properties.VariableUnits = ["c/kWh" "GW"];
        app.appendData(T);
    end

    function downloadAemoData()
        aemo().download(hs.Value, {t1.Value, t2.Value});
    end
end
