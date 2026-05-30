function app = BatteryTab(tabGroup, app, cfg)
    H = cfg.H; W = cfg.W;
    fold = fullfile(cfg.rootFold, 'battery', 'data');
    ht = uitab(tabGroup, 'Title', 'Battery');
    
    uilabel(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Import battery data.', 'FontSize', 14);
    uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'meter', 'Readme.txt')));
    
    uilabel(ht, 'Position', [10 H-100 40 30], 'Text', 'Input:');
    h = uieditfield(ht, 'text', 'Position', [50 H-100 W-220 30], 'Value', fold);
    
    uibutton(ht, 'push', 'Position', [W-120 H-100 30 30], 'Icon', cfg.foldIcon, 'ButtonPushedFcn', @(~,~)app.selectFolder(h));
    uibutton(ht, 'push', 'Position', [W-80 H-100 70 30], 'Text', 'Import', 'ButtonPushedFcn', @(~,~)importBatteryData());
    
    uilabel(ht, 'Position', [10 H-140 40 30], 'Text', 'Type:');
    uidropdown(ht, 'Position', [50 H-140 200 30], 'Items', {'Tesla Powerwall2'});
    uilabel(ht, 'Position', [280 H-140 80 30], 'Text', 'Date range:');
    t1 = uieditfield(ht, 'Position', [350 H-140 100 30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
    t2 = uieditfield(ht, 'Position', [490 H-140 100 30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
    uicheckbox(ht, 'Position', [W-150 H-140 120 30], 'Value', 0, 'Text', 'Intersection only');

    function importBatteryData()
        try
            T = powerwall2().read({t1.Value, t2.Value});
            app.appendData(T)
        catch ex
            fprintf(2, 'Error: %s\n', ex.message);
        end
    end
end