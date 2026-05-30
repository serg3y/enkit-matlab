function app = DataTab(tabGroup, app, cfg)
H = cfg.H; W = cfg.W; gui = app.gui;
ht = uitab(tabGroup, 'Title', 'Data');

uilabel(ht, 'Position', [10 H-60 W-40 30], 'Text', 'Manage, save, load and plot data.', 'FontSize', 14);
uibutton(ht, 'push', 'Position', [W-40 H-60 30 30], 'Icon', cfg.helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)app.showHelp(fullfile(cfg.rootFold, 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel(ht, 'Position', [10 H-100 40 30], 'Text', 'Input:');

hRoot = uieditfield(ht,'text','Position', [50 H-100 W-220 30], 'Value', fullfile(cfg.guiFold, 'data'), 'Placeholder', 'Select file');

uibutton(ht, 'push', 'Position', [W-160 H-100 30 30], 'Icon', cfg.newfIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)newData(hRoot), 'Tooltip', 'Start new');
uibutton(ht, 'push', 'Position', [W-120 H-100 30 30], 'Icon', cfg.saveIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)saveData(hRoot, 0), 'Tooltip', 'Save data');
uibutton(ht, 'push', 'Position', [W-80 H-100 30 30], 'Icon', cfg.savsIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)saveData(hRoot, 1), 'Tooltip', 'Save as...');
uibutton(ht, 'push', 'Position', [W-40 H-100 30 30], 'Icon', cfg.openIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)loadData(hRoot), 'Tooltip', 'Load data');

hData = uitable(ht, 'Position', [10 10 W-180 H-120], 'CellEditCallback',@(h,e)editData(h,e), 'CellSelectionCallback', @(h,e)pickColor(h,e), 'SelectionChangedFcn', @(h,~)highlightRows(h), 'FontWeight', 'bold', 'RowStriping', 'off', 'RowName', '', 'ColumnEditable', true);
app.hData = hData;

% Row Operation Buttons
uibutton(ht, 'Position', [W-160 H-140 30 30], 'Text', '⇑', 'ButtonPushedFcn', @(~,~)moveRows(hData, -1));
uibutton(ht, 'Position', [W-120 H-140 30 30], 'Text', '⇓', 'ButtonPushedFcn', @(~,~)moveRows(hData, +1));
uibutton(ht, 'Position', [W-80 H-140 30 30], 'Icon', cfg.copyIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)copyRows(hData));
uibutton(ht, 'Position', [W-40 H-140 30 30], 'Icon', cfg.delrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)deleteRows(hData));

uibutton(ht, 'Position', [W-160 H-180 30 30], 'Icon', cfg.rmnvIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)clipNegative(hData), 'Tooltip', 'Remove negative values');
uibutton(ht, 'Position', [W-120 H-180 30 30], 'Icon', cfg.rmpvIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)clipPositive(hData), 'Tooltip', 'Remove positive values');
uibutton(ht, 'Position', [W- 80 H-180 30 30], 'Icon', cfg.flipIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)flipSign(hData), 'Tooltip', 'Flip sign');

% Time Trim
hStart = uieditfield(ht, 'Position', [W-160 H-260 100 30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
uibutton(ht, 'Position', [W-40 H-260 30 30], 'Text', '↦', 'ButtonPushedFcn', @(~,~)trimTime(hStart.Value,1));
hStop = uieditfield(ht, 'Position', [W-130 H-300 100 30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uibutton(ht, 'Position', [W-160 H-300 30 30], 'Text', '↤', 'ButtonPushedFcn', @(~,~)trimTime(hStop.Value,0));

uibutton(ht, 'Position', [W-80 H-340 70 30], 'Text', 'Export', 'ButtonPushedFcn', @(~,~)export(hRoot));
uibutton(ht, 'Position', [W-80 10 70 30], 'Text', 'Heatmap+', 'ButtonPushedFcn', @(~,~)plotRows(hData));

app.DataTab_Update = @updateUI;

    function updateUI(T, cfg)
        % Construct info table for display
        for k = width(T):-1:1
            t = T{:,k};
            switch T.Properties.VariableTypes(k)
                case 'double'
                    info(k,:) = {mean(t,1,'omitmissing') sum(t,1,'omitmissing') range(t) sum(~isfinite(t))/height(T)*100 min(t) max(t)};
                case {'datetime' 'duration'}
                    info(k,:) = {"" "" round(days(range(t)+cfg.rez),1)+"d" sum(~isfinite(t))/height(T)*100 strrep(string(min(t)), ' 00:00', '') strrep(string(max(t)+cfg.rez), ' 00:00', '')};
            end
        end
        info = [T.Properties.VariableNames' T.Properties.VariableDescriptions' T.Properties.VariableUnits' cellstr(T.Properties.VariableTypes)' info cell(width(T), 2)];
        info = cell2table(info, 'VariableNames', {'Property' 'Label' 'Units' 'Type' 'Mean' 'Sum' 'Range' 'Fill %' 'Min' 'Max' 'C1' 'C2'});

        [i,j] = ismember(string(info.Units), string(cfg.units)); info.Units(i) = num2cell(cfg.units(j(i)));
        [i,j] = ismember(string(info.Units), string(cfg.zones)); info.Units(i) = num2cell(cfg.zones(j(i)));

        hData.ColumnWidth = {'auto' 'auto' 70 70 60 60 60 60 60 60 30 30};
        hData.Data = info;

        % Styles
        i1 = find(hData.Data.Properties.VariableNames == "C1");
        i2 = find(hData.Data.Properties.VariableNames == "C2");
        for k = 1:width(T)
            addStyle(hData, uistyle('BackgroundColor', T.Properties.CustomProperties.C1{k}), 'cell', [k i1]);
            addStyle(hData, uistyle('BackgroundColor', T.Properties.CustomProperties.C2{k}), 'cell', [k i2]);
        end
    end

% Internal Logic Functions
    function newData(h)
        h.Value = fullfile(cfg.guiFold, 'data');
        app.updateData([]);
    end

    function saveData(h, saveas)
        if isempty(gui.UserData), return, end
        if saveas || isempty(h.Value)
            [file, path] = uiputfile('*.mat', 'Save as', h.Value); figure(gui)
            if isequal(file, 0), return, end
            h.Value = fullfile(path, file);
        end
        T = gui.UserData; save(h.Value, 'T'); figure(gui)
    end

    function loadData(h)
        [file, path] = uigetfile('*.mat', 'Open', h.Value); figure(gui)
        if isequal(file, 0), return, end
        h.Value = fullfile(path, file); T = load(h.Value, 'T').T; app.updateData(T)
    end

    function editData(h,e)
        old = char(e.PreviousData);
        new = char(e.EditData);
        if isequal(new, old), return, end

        T = gui.UserData;
        row = e.Indices(1);
        col = e.Indices(2);
        var = app.getVar(h);
        name = h.ColumnName{col};

        if name == "Property"
            if old == "time", return, end % time is read only
            try
                T = renamevars(T, e.PreviousData, e.NewData);
            catch ex
                fprintf(2, ' %s\n', ex.message)
            end
        elseif name == "Label"
            T.Properties.VariableDescriptions{row} = new;
        elseif name == "Units" && var == "time"
            T.time.TimeZone = char(new);
            ind = strcmpi(string(cfg.zones), new);
            if any(ind)
                h.Data.Units{row} = []; % Required for category reassignment
                h.Data.Units{row} = cfg.zones(ind);
                T.Properties.VariableUnits{row} = char(cfg.zones(ind));
            end
        elseif name == "Units"
            switch old + ">" + new
                case 'kw>kwh', T.(var) = T.(var) .* cfg.rez; T = renamevars(T, var, regexprep(var, '_kw$', '_kwh'));
                case 'kwh>kw', T.(var) = T.(var) ./ cfg.rez; T = renamevars(T, var, regexprep(var, '_kwh$', '_kw'));
                case '$>c',    T.(var) = T.(var) .* 100; T = renamevars(T, var, regexprep(var, '_\$$', '_c'));
                case 'c>$',    T.(var) = T.(var) ./ 100; T = renamevars(T, var, regexprep(var, '_c$', '_\$'));
            end
            if new == "custom"
                h.Data.Units{row} = [];
                T.Properties.VariableUnits{row} = '';
            else
                ind = strcmpi(string(cfg.units), new);
                if any(ind)
                    h.Data.Units{row} = []; % Required for category reassignment
                    h.Data.Units{row} = cfg.units(ind);
                    T.Properties.VariableUnits{row} = char(cfg.units(ind));
                end
            end
        end
        app.updateData(T);
    end

    function highlightRows(h, row)
        if nargin<2, row = app.getRow(h); end
        [R, C] = ndgrid(row, 1:size(h.Data,2)); h.Selection = [R(:), C(:)];
    end

    function pickColor(h,e)
        if numel(e.Indices)~=2, return, end
        row = e.Indices(:, 1); col = e.Indices(:, 2); name = h.ColumnName{col};
        if ismember(name, ["C1" "C2"])
            T = gui.UserData; oldColor = T.Properties.CustomProperties.(name){row};
            newColor = uisetcolor(oldColor); figure(gui);
            if isscalar(newColor), return, end
            T.Properties.CustomProperties.(name){row} = newColor; app.updateData(T)
        end
    end

    function moveRows(h, offset)
        row = app.getRow(h);
        if isempty(row), return; end
        n = height(h.Data);
        T = gui.UserData;
        k = numel(row);
        if offset < 0 % up
            selLim = 1:k;
            movRow = row(row > selLim);
            newSel = max(row + offset, selLim);
        else % down
            selLim = (1:k) + n - k;
            movRow = row(row < selLim);
            newSel = min(row + offset, selLim);
        end
        if isempty(movRow), return, end
        newInd = movRow + offset;
        newOrder([newInd setdiff(1:n, newInd)]) = [movRow setdiff(1:n, movRow)];
        highlightRows(h, newSel), drawnow
        app.updateData(T(:, newOrder))
    end

    function copyRows(h)
        row = app.getRow(h); if isempty(row), return, end
        T = gui.UserData; t = T(:, row);
        t.Properties.VariableNames = t.Properties.VariableNames + "_copy";
        app.appendData(t);
    end

    function deleteRows(h)
        var = app.getVar(h, 1); if isempty(var), return, end
        T = gui.UserData; T(:, var) = []; app.updateData(T)
    end

    function clipNegative(h)
        var = app.getVar(h, 1); if isempty(var), return, end
        T = gui.UserData; T(:, var) = varfun(@(x)max(x, 0), T(:, var)); app.updateData(T)
    end

    function clipPositive(h)
        var = app.getVar(h, 1); if isempty(var), return, end
        T = gui.UserData; T(:, var) = varfun(@(x)min(x, 0), T(:, var)); app.updateData(T)
    end

    function flipSign(h)
        var = app.getVar(h, 1); if isempty(var), return, end
        T = gui.UserData; T(:, var) = varfun(@(x)x.*-1, T(:, var)); app.updateData(T)
    end

    function trimTime(str, flag)
        T = gui.UserData; t = datetime(str, 'TimeZone', T.time.TimeZone);
        if flag, T = T(T.time >= t, :); else, T = T(T.time < t, :); end
        app.updateData(T)
    end

    function export(h)
        T = gui.UserData; T(:, vartype('numeric')) = varfun(@(x)round(x, 6), T(:, vartype('numeric')));
        file = [strrep(h.Value, '.mat', '') '.csv']; writetimetable(T, file); fprintf(' > %s\n', file)
    end

    function plotRows(h)
        rows = app.getRow(h); if isempty(rows), return, end
        T = gui.UserData; n = numel(rows);
        fig = figmode(figure, 'dark', 'MenuBar', 'none', 'ToolBar', 'none', 'Name', 'Plot', 'Tag', 'enkit');

        set(fig, ...
            WindowStyle = 'normal', ...
            DefaultAxesXGrid = 'on', ...
            DefaultAxesYGrid = 'on', ...
            DefaultAxesGridAlpha = 0.1, ...
            DefaultAxesGridColor = [0.5 0.5 0.5], ...
            DefaultLineMarkerSize = 10, ...
            DefaultAxesXColor = [0.5 0.5 0.5], ...
            DefaultAxesYColor = [0.5 0.5 0.5], ...
            DefaultAxesXLimitMethod = 'tight', ...
            DefaultAxesYLimitMethod = 'tight', ...
            DefaultUicontrolFontWeight = 'bold');

        % Toolbar
        H = uitoolbar(fig);
        uipushtool(H, 'Tooltip', 'Save Plot', 'CData', app.loadIcon(cfg.saveIcon), 'ClickedCallback', @(~,~)saveFig(fig));
        uitoolfactory(H, 'Exploration.ZoomIn');
        uitoolfactory(H, 'Exploration.ZoomOut');
        uitoolfactory(H, 'Exploration.Pan');
        uitoolfactory(H, 'Exploration.DataCursor');

        function saveFig(f)
            [file, path] = uiputfile({'*.png';'*.jpg'}, 'Save as');
            if ~isequal(file,0), exportgraphics(f, fullfile(path,file)); end
        end

        for k = 1:n
            var = string(T.Properties.VariableNames{rows(k)});
            col = [T.Properties.CustomProperties.C2{rows(k)}; T.Properties.CustomProperties.C1{rows(k)}];
            pos = [0 1-1/n*k 1 1/n];
            heatmapTimeVsDatePlus(T, var, col, T.Properties.VariableDescriptions{rows(k)}, T.Properties.VariableUnits{rows(k)}, pos);
        end
        linkallaxes
    end
end
