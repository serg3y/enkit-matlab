function app = PvOutputTab(tabGroup, app, cfg)
    H = cfg.H; W = cfg.W; gui = app.gui;
    fold = fullfile(cfg.rootFold, 'pvoutput', 'data');
    ht = uitab(tabGroup, 'Title', 'PVoutput');
    
    uihyperlink(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Import or download solar production data from PVoutput.org', 'URL', 'https://pvoutput.org/map.jsp?country=1&state=SA');
    uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(''));
    
    uilabel(ht, 'Position', [10 H-100 70 30], 'Text', 'Input:');
    h = uieditfield(ht, 'text', 'Position', [50 H-100 W-220 30], 'Value', fold);
    uibutton(ht, 'push', 'Position', [W-160 H-100 30 30], 'Icon', cfg.foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.selectFolder(h));
    uibutton(ht, 'push', 'Position', [W-80 H-100 70 30], 'Text', 'Import', 'ButtonPushedFcn', @(~,~)importPVoutputData(h.Value));
    
    uilabel(ht, 'Position', [10 H-140 40 30], 'Text', 'Sys Id:');
    hSysId = uidropdown(ht, 'Position', [50 H-140 100 30], 'Editable', 'on', 'ValueChangedFcn', @(s,~)selectPvSite(s.Value));
    hPvUrl = uihyperlink(ht, 'Position', [160 H-140 50 30], 'Text', 'Map', 'URL', 'https://pvoutput.org/map.jsp?country=1&state=SA');
    
    uilabel(ht, 'Position', [290 H-140 80 30], 'Text', 'Date range:');
    t1 = uieditfield(ht, 'Position', [360 H-140 100 30], 'Value', '-400', 'Tag', 'start_time');
    t2 = uieditfield(ht, 'Position', [500 H-140 100 30], 'Value', '-5', 'Tag', 'stop_time');
    
    uibutton(ht, 'push', 'Position', [740 H-140 70 30], 'Text', 'Description', 'ButtonPushedFcn', @(~,~)downloadPvoutoutInfo(0));
    uibutton(ht, 'push', 'Position', [W-80 H-140 70 30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadPvoutoutProduction({t1.Value, t2.Value}));
    
    hPvMap = uiaxes(ht, 'Position', [30 10 460 290], 'XLim', [112 155], 'YLim', [-44.5 -10], 'Clim', [0 100], 'XGrid', 'on', 'YGrid', 'on', 'NextPlot', 'add');
    hPvInfo = uitextarea(ht, 'Position', [500 30 390 270], 'Editable', 'off', 'FontName', 'Courier New', 'FontSize', 15, 'WordWrap', 'off', 'BackgroundColor', gui.Color);
    uibutton(ht, 'push', 'Position', [W-40 H-190 30 30], 'Icon', cfg.refrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)refreshPvSiteInfo(1));

    disableDefaultInteractivity(hPvMap)
    plot(hPvMap, load('coastlines.mat').coastlon, load('coastlines.mat').coastlat, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'HitTest', 'off');
    refreshPvSiteInfo(0)
    set(datacursormode(gui), 'UpdateFcn', @(~,e)updateDataTip(e), 'SnapToDataVertex', 'on', 'Enable', 'off')

    function downloadPvoutoutInfo(staleThreshold)
        pvoutput().downloadInfo(hSysId.Value, staleThreshold)
        refreshPvSiteInfo(1)
    end

    function downloadPvoutoutProduction(span)
        pvoutput().downloadProduction(hSysId.Value, span)
        refreshPvSiteInfo(1)
    end

    function importPVoutputData(path)
        T = pvoutput().read(path);
        app.appendData(T);
    end

    function refreshPvSiteInfo(refresh)
        S = pvoutput().readPVlist(refresh);
        delete(findobj(hPvMap, 'Tag', 'PVsite'))
        for k = 1:height(S)
            scatter(hPvMap, S.lon(k), S.lat(k), 200, S.gaps(k), '.', 'Tag', 'PVsite', 'UserData', S(k,:));
        end
        colorbar(hPvMap)
        hPvMap.Colormap = interp1([0 1],[0 1 0;1 0 0],linspace(0,1,256).^0.5);
        hSysId.Items = string(S.sysId);
        hSysId.UserData = S;
        selectPvSite(hSysId.Value)
    end

    function selectPvSite(sysId)
        sysId = string(sysId);
        hSysId.Value = sysId;
        hPvUrl.URL = "https://pvoutput.org/listmap.jsp?sid=" + sysId;
        delete(findall(hPvMap, 'Tag', 'selectedPVsite'))
        S = hSysId.UserData;
        s = S(string(S.sysId)==sysId, :);
        if ~isempty(s)
            scatter(hPvMap, s.lon, s.lat, 400, s.gaps, 'p', 'Tag', 'selectedPVsite', 'LineWidth', 2, 'HitTest', 'off')
            hPvInfo.Value = app.struct2str(s);
        else
            hPvInfo.Value = '';
        end
    end

    function txt = updateDataTip(e)
        if e.Target.Tag == "PVsite"
            s = e.Target.UserData;
            selectPvSite(s.sysId)
            txt = sprintf('Lat: %.4f\nLon: %.4f', e.Position([2 1]));
        else
            txt = sprintf('X: %g\nY: %g',e.Position);
        end
    end
end