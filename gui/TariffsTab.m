function app = TariffsTab(tabGroup, app, cfg)
    H = cfg.H; W = cfg.W; gui = app.gui;
    ht = uitab(tabGroup, 'Title', 'Tariffs');
    
    uilabel(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Predict usage cost.', 'FontSize', 14);
    uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'meter', 'Readme.txt')));
    
    uilabel(ht, 'Position', [10 H-100 40 30], 'Text', 'Tariff:');
    hTariffs = uidropdown(ht, 'Position', [50 H-100 150 30], 'Items', {}, 'ValueChangedFcn', @(h,~)previewTariff(h.Value));
    uibutton(ht, 'push', 'Position', [200 H-100 30 30], 'Icon', cfg.refrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)refreshTariffList());
    
    uilabel(ht, 'Position', [250 H-100 40 30], 'Text', 'Import:');
    hImport = uidropdown(ht, 'Position', [290 H-100 80 30], 'Items', {}, 'Placeholder', 'no data');
    uilabel(ht, 'Position', [380 H-100 40 30], 'Text', 'Export:');
    hExport = uidropdown(ht, 'Position', [420 H-100 80 30], 'Items', {}, 'Placeholder', 'no data');
    
    uilabel(ht, 'Position', [510 H-100 80 30], 'Text', 'Date range:');
    t1 = uieditfield(ht, 'Position', [580 H-100 100 30], 'Tag', 'start_time');
    t2 = uieditfield(ht, 'Position', [690 H-100 100 30], 'Tag', 'stop_time');
    uibutton(ht, 'push', 'Position', [W-80 H-100 70 30], 'Text', 'Calculate', 'ButtonPushedFcn', @(~,~)calcTariffs());

    app.hImport = hImport;
    app.hExport = hExport;
    app.TariffsTab_Update = @updateUI;

    refreshTariffList();

    function refreshTariffList()
        hTariffs.Items = unique(tariffs().tariff, 'stable');
    end

    function updateUI(T)
        t = T.Properties.VariableNames(vartype('numeric'));
        hImport.Items = t;
        hExport.Items = t;
        if any(ismember(t, 'import_kw')), hImport.Value = 'import_kw'; end
        if any(ismember(t, 'export_kw')), hExport.Value = 'export_kw'; end
    end

    function previewTariff(tariffName)
        delete(findobj(ht, 'Tag', 'previewTariff'))
        dayList = tariffs(tariffName).date';
        n = numel(dayList);
        stepW = 1/n;
        for k = 1:n
            ax = uiaxes(ht, 'Units', 'normalized', 'Position', [stepW*(k-1)+0.01 0.01 stepW*0.95 0.75], 'XLim', [0 24], 'YLim', [-15 65], 'XGrid', 'on', 'YGrid', 'on', 'Tag', 'previewTariff');
            if k == 1, ylabel(ax, 'Price (c/kWh)', 'FontWeight', 'bold'); end
            time = dayList(k) + hours(0:0.5:23.5);
            [buy_price, sell_price, supply] = tariffs(tariffName, time);
            time_hrs = hours(timeofday(time));
            plotstepspread(ax, time_hrs, buy_price, [], 'r', sprintf('Av.Buy=%.2f c/kWh', mean(buy_price)), 'xy')
            plotstepspread(ax, time_hrs, sell_price, [], 'g', sprintf('Av.Sell=%.2f c/kWh', mean(sell_price)), 'xy')
            title(ax, string(dayList(k)))
        end
    end

    function calcTariffs()
        T = gui.UserData;
        if ~isempty(T)
            time = T.time;
            step = hours(mode(diff(time)));
            [buy_ckwh, sell_ckwh, supply_c] = tariffs(hTariffs.Value, time);
            cost_c = buy_ckwh.*T.(hImport.Value)*step - sell_ckwh.*T.(hExport.Value)*step + supply_c;
            app.appendData(timetable(time, cost_c));
        end
    end
end