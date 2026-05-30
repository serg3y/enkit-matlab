function app = MeterTab(tabGroup, app, cfg)
    H = cfg.H; W = cfg.W;
    fold = fullfile(cfg.rootFold, 'meter', 'data');
    ht = uitab(tabGroup, 'Title', 'Meter');
    
    uihyperlink(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Import smart meter data.', 'URL', 'https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard');
    uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'meter', 'Readme.txt')));
    
    uilabel(ht, 'Position', [10 H-100 40 30], 'Text', 'Input:');
    h = uieditfield(ht, 'text', 'Position', [50 H-100 W-220 30], 'Value', fold);
    
    uibutton(ht, 'push', 'Position', [W-120 H-100 30 30], 'Icon', cfg.foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.selectFolder(h));
    uibutton(ht, 'push', 'Position', [W-80 H-100 70 30], 'Text', 'Import', 'ButtonPushedFcn', @(~,~)importNemData(h));

    function importNemData(h)
        T = nem().read(h.Value);
        app.appendData(T)
    end
end