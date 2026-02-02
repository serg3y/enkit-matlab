function GUI
%% Paths
guiFold = fileparts(mfilename('fullpath'));
rootFold = fileparts(guiFold);

% Icons:
% D:\MATLAB\enkit\gui
% C:\Program Files\MATLAB\R2024b\toolbox\matlab\icons
% https://www.iconarchive.com/search?q=up+arrow
% https://www.alt-codes.net/arrow_alt_codes.php
fileIcon = fullfile(guiFold, 'icons', 'file.png');
newfIcon = fullfile(guiFold, 'icons', 'new.png');
saveIcon = fullfile(guiFold, 'icons', 'save.png');
savsIcon = fullfile(guiFold, 'icons', 'saveas.png');
foldIcon = fullfile(guiFold, 'icons', 'folder.png');
openIcon = fullfile(guiFold, 'icons', 'open.png');
helpIcon = fullfile(guiFold, 'icons', 'help.png');
rmpvIcon = fullfile(guiFold, 'icons', 'rmpv.png');
rmnvIcon = fullfile(guiFold, 'icons', 'rmnv.png');
flipIcon = fullfile(guiFold, 'icons', 'flip.png');
refrIcon = fullfile(guiFold, 'icons', 'refresh.png');
copyIcon = fullfile(guiFold, 'icons', 'copy.png');
delrIcon = fullfile(guiFold, 'icons', 'deleterow.png');
    function rgb = loadIcon(file)
        [rgb, ~, alpha] = imread(file);
        rgb = im2double(rgb);
        rgb(repmat(alpha == 0, [1 1 3])) = nan;
    end

units = ["kw" "kwh" "$" "c" "c/kwh" "custom"]; units = categorical(units, units);
zones = ["+08:00" "+09:30" "+10:00" "+10:30" "+11:00" "Perth" "Adelaide" "Darwin" "Brisbane" "Sydney"];
zones = categorical(zones);

%% Figure
W = 900; H = 460;
delete(findall(0, 'Tag', 'enkit'))
warning off MATLAB:ui:containers:SizeChangedFcnDisabledWhenAutoResizeOn
gui = uifigure  ('Position', [100 400 W+20 H+20], 'Name', 'EnKit', 'Tag', 'enkit');
tab = uitabgroup('Position', [ 10  10 W    H   ], 'Parent', gui); % Tab group

%% Data
ht = uitab(tab, 'Title', 'Data');
uilabel          (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Manage, save, load and plot data.', 'FontSize', 14);
uibutton         (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel          (ht,         'Position', [   10 H-100    40    30], 'Text', 'Input:');
hRoot = uieditfield(ht,'text','Position', [   50 H-100 W-220    30], 'Value', fullfile(guiFold, 'data'), 'Placeholder', 'Select file');
uibutton         (ht, 'push', 'Position', [W-160 H-100    30    30], 'Icon', newfIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)newData(hRoot),          'Tooltip', 'Start new');
uibutton         (ht, 'push', 'Position', [W-120 H-100    30    30], 'Icon', saveIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)saveData(hRoot, 0),      'Tooltip', 'Save data');
uibutton         (ht, 'push', 'Position', [W- 80 H-100    30    30], 'Icon', savsIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)saveData(hRoot, 1),      'Tooltip', 'Save as...');
uibutton         (ht, 'push', 'Position', [W- 40 H-100    30    30], 'Icon', openIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)loadData(hRoot),         'Tooltip', 'Load data');
hData = uitable  (ht,         'Position', [   10    10 W-180 H-120],                               'CellEditCallback',@(h,e)editData(h,e), 'CellSelectionCallback', @(h,e)pickColor(h,e), 'SelectionChangedFcn', @(h,~)highlightRows(h), 'FontWeight', 'bold', 'RowStriping', 'off', 'RowName', '', 'ColumnEditable', true);
uibutton         (ht,         'Position', [W-160 H-140    30    30], 'Text', '⇑', 'FontSize', 18,  'ButtonPushedFcn', @(~,~)moveRows(hData, -1),     'Tooltip', 'Move row up');
uibutton         (ht,         'Position', [W-120 H-140    30    30], 'Text', '⇓', 'FontSize', 18,  'ButtonPushedFcn', @(~,~)moveRows(hData, +1),     'Tooltip', 'Move row down');
uibutton         (ht,         'Position', [W- 80 H-140    30    30], 'Icon', copyIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)copyRows(hData),         'Tooltip', 'Duplocate row');
uibutton         (ht,         'Position', [W- 40 H-140    30    30], 'Icon', delrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)deleteRows(hData),       'Tooltip', 'Delete row');
uibutton         (ht,         'Position', [W-160 H-180    30    30], 'Icon', rmnvIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)clipNegative(hData),     'Tooltip', 'Remove negative values');
uibutton         (ht,         'Position', [W-120 H-180    30    30], 'Icon', rmpvIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)clipPositive(hData),     'Tooltip', 'Remove positive values');
uibutton         (ht,         'Position', [W- 80 H-180    30    30], 'Icon', flipIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)flipSign(hData),         'Tooltip', 'Flip sign');
hStart = uieditfield(ht,      'Position', [W-160 H-260   120    30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
uibutton         (ht,         'Position', [W- 40 H-260    30    30], 'Text', '↦', 'FontSize', 16, 'ButtonPushedFcn', @(~,~)trimTime(hStart.Value,1), 'Tooltip', 'Keep only points after this time');
hStop = uieditfield(ht,       'Position', [W-130 H-300   120    30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uibutton         (ht,         'Position', [W-160 H-300    30    30], 'Text', '↤', 'FontSize', 18, 'ButtonPushedFcn', @(~,~)trimTime(hStop.Value,0), 'Tooltip', 'Keep only points beofre this time');
uibutton         (ht,         'Position', [W- 80 H-340    70    30], 'Text', 'Export',             'ButtonPushedFcn', @(~,~)export(hRoot),           'Tooltip', 'Plot data');
uibutton         (ht,         'Position', [W- 80    10    70    30], 'Text', 'Plot',               'ButtonPushedFcn', @(~,~)plotRows(hData),         'Tooltip', 'Plot data');
    function newData(h)
        h.Value = fullfile(guiFold, 'data');
        updateData([])
    end
    function saveData(h, saveas)
        if isempty(gui.UserData), return, end
        if saveas || isempty(h.Value)
            [file, path] = uiputfile('*.mat', 'Save as', h.Value); figure(gui)
            if isequal(file, 0), return, end
            h.Value = fullfile(path, file);
        end
        if ~isempty(h.Value)
            T = gui.UserData;
            save(h.Value, 'T');
        end
        figure(gui)
    end
    function loadData(h)
        [file, path] = uigetfile('*.mat', 'Open', h.Value); figure(gui)
        if isequal(file, 0), return, end
        h.Value = fullfile(path, file);
        T = load(h.Value, 'T').T;
        updateData(T)
    end
    function editData(h,e)
        old = char(e.PreviousData);
        new = char(e.EditData);
        if isequal(new, old), return, end
        row = e.Indices(1);
        col = e.Indices(2);
        var = getVar(h);
        name = h.ColumnName{col};
        T = gui.UserData;
        if name == "Property"
            if old == "time", return, end % time is read only
            try
                T = renamevars(T, e.PreviousData, e.NewData);
            catch ex
                fprintf( 2, ' %s\n', ex.message)
            end
        elseif name == "Label"
            T.Properties.VariableDescriptions{row} = new;
        elseif name == "Units" && var=="time"
            if startsWith(new, '+')
                T.time.TimeZone = new;
            else
                T.time.TimeZone = ['Australia/' new];
            end
            ind = strcmpi(string(zones), new);
            if any(ind)
                h.Data.Units{row} = []; % Required for category reassignment
                h.Data.Units{row} = zones(ind);
                T.Properties.VariableUnits{row} = char(zones(ind));
            end
        elseif name == "Units"
            rez = hours(mode(diff(T.time)));
            switch old + ">" + new
                case 'kw>kwh', T.(var) = T.(var) .* rez; T = renamevars(T, var, regexprep(var, '_kw$', '_kwh'));
                case 'kwh>kw', T.(var) = T.(var) ./ rez; T = renamevars(T, var, regexprep(var, '_kwh$', '_kw'));
                case '$>c',    T.(var) = T.(var) .* 100; T = renamevars(T, var, regexprep(var, '_\$$', '_c'));
                case 'c>$',    T.(var) = T.(var) ./ 100; T = renamevars(T, var, regexprep(var, '_c$', '_\$'));
            end
            if new == "custom"
                h.Data.Units{row} = [];
                T.Properties.VariableUnits{row} = '';
            else
                ind = strcmpi(string(units), new);
                if any(ind)
                    h.Data.Units{row} = []; % Required for category reassignment
                    h.Data.Units{row} = units(ind);
                    T.Properties.VariableUnits{row} = char(units(ind));
                end
            end
        end
        updateData(T)
    end
    function highlightRows(h, row)
        if nargin<2 % Allow programatic selection
            row = getRow(h);
        end
        [R, C] = ndgrid(row, 1:size(h.Data,2));
        h.Selection = [R(:), C(:)];
    end
    function pickColor(h,e)
        if numel(e.Indices)~=2, return, end
        row = e.Indices(:, 1);
        col = e.Indices(:, 2);
        name = h.ColumnName{col};
        if ismember(name, ["C1" "C2"])
            T = gui.UserData;
            oldColor = T.Properties.CustomProperties.(name){row};
            newColor = uisetcolor(oldColor); figure(gui)
            if isscalar(newColor), return, end
            T.Properties.CustomProperties.(name){row} = newColor;
            updateData(T)
        end
    end
    function moveRows(h, offset)
        row = getRow(h);
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
        T = T(:, newOrder);
        updateData(T)
    end
    function copyRows(h)
        row = getRow(h);
        if isempty(row), return, end
        T = gui.UserData;
        t = T(:, row);
        t = renamevars(t, t.Properties.VariableNames, t.Properties.VariableNames + "_copy");
        updateData([T t])
    end
    function deleteRows(h)
        var = getVar(h, 1);
        if isempty(var), return, end
        T = gui.UserData;
        T(:, var) = [];
        updateData(T)
    end
    function clipNegative(h)
        var = getVar(h, 1);
        if isempty(var), return, end
        T = gui.UserData;
        T(:, var) = varfun(@(x)max(x, 0), T(:, var));
        updateData(T)
    end
    function clipPositive(h)
        var = getVar(h, 1);
        if isempty(var), return, end
        T = gui.UserData;
        T(:, var) = varfun(@(x)min(x, 0), T(:, var));
        updateData(T)
    end
    function flipSign(h)
        var = getVar(h, 1);
        if isempty(var), return, end
        T = gui.UserData;
        T(:, var) = varfun(@(x)x.*-1, T(:, var));
        updateData(T)
    end
    function trimTime(str, flag)
        T = gui.UserData;
        t = datetime(str ,'TimeZone', T.time.TimeZone);
        if flag
            T = T(T.time >= t, :);
        else
            T = T(T.time < t, :);
        end
        updateData(T)
    end
    function plotRows(h)
        rows = getRow(h);
        if isempty(rows), return, end
        fig = figmode(figure, 'dark', 'MenuBar',' none', 'ToolBar', 'none', 'Name', 'Plot', 'Tag', 'enkit');

        set(fig, ...
            WindowStyle = 'normal',...
            DefaultAxesXGrid = 'on', ...
            DefaultAxesYGrid = 'on', ...
            DefaultAxesGridAlpha = 0.1, ...
            DefaultAxesGridColor = [0.5 0.5 0.5],...
            DefaultLineMarkerSize = 10,...
            DefaultAxesXColor = [0.5 0.5 0.5], ...
            DefaultAxesYColor = [0.5 0.5 0.5], ...
            DefaultAxesXLimitMethod = 'tight', ...
            DefaultAxesYLimitMethod = 'tight', ...
            DefaultUicontrolFontWeight = 'bold');
        %addToolbarExplorationButtons(gcf); %adds toolbar icons when ToolBar='figure'

        % Toolbar
        H = uitoolbar(fig);
        uipushtool(H, 'Tooltip', 'Toggle Colorbar', 'CData', loadIcon(saveIcon), 'ClickedCallback',@(~,~)saveFig(fig));
        uitoolfactory(H, 'Exploration.ZoomIn');
        uitoolfactory(H, 'Exploration.ZoomOut');
        uitoolfactory(H, 'Exploration.Pan');
        uitoolfactory(H, 'Exploration.DataCursor');
        function saveFig(fig)
            defaultPath = enkitPath('GUI', 'plots');
            if ~isfolder(defaultPath)
                mkdir(defaultPath)
            end
            [file, path] = uiputfile({'*.png'; '*.jpg'}, 'Save as', defaultPath);
            if isequal(file, 0), return, end
            figsave(fig, fullfile(path, file), [1600 900])
        end

        T = gui.UserData;
        n = numel(rows);
        for k = 1:n
            var = string(T.Properties.VariableNames{rows(k)});
            col = [T.Properties.CustomProperties.C2{rows(k)}; T.Properties.CustomProperties.C1{rows(k)}];
            lbl = T.Properties.VariableDescriptions{rows(k)};
            unit = T.Properties.VariableUnits{rows(k)};
            pos = [0 1-1/n*k 1 1/n]; % Axes position: [L B W H]
            heatmapTimeVsDatePlus(T, 'time', var, col, lbl, unit, pos);
        end
        linkallaxes
    end
    function updateData(T)
        if isempty(T)
            gui.UserData = [];
            set(findobj(gui, 'Tag', 'start_time'), 'Value', '')
            set(findobj(gui, 'Tag', 'stop_time'), 'Value', '')
            hData.Data = {};
            hImport.Items = {};
            hExport.Items = {};
            gui.Name = 'EnKit';
            return
        end

        % Validate and assign data
        T = conditionTable(T);
        gui.UserData = T;

        % Construct info
        rez = mode(diff(T.time));
        for k = width(T):-1:1
            t = T{:,k};
            switch T.Properties.VariableTypes(k)
                case {'double' 'single' 'int'}
                    %info(k,:) = {mean(t,1,'omitmissing') range(t) sum(~isfinite(t))/height(T)*100 min(t) max(t)};
                    info(k,:) = {mean(t,1,'omitmissing') sum(t,1,'omitmissing') range(t) sum(~isfinite(t))/height(T)*100 min(t) max(t)};
                    'HACK!'
                case {'datetime' 'duration'}
                    info(k,:) = {"" "" round(days(range(t)+rez),1)+"d" sum(~isfinite(t))/height(T)*100 strrep(string(min(t)), ' 00:00', '') strrep(string(max(t)+rez), ' 00:00', '')};
            end
        end
        info = [T.Properties.VariableNames' T.Properties.VariableDescriptions' T.Properties.VariableUnits' cellstr(T.Properties.VariableTypes)' info cell(width(T), 2)];
        info = cell2table(info, 'VariableNames', {'Property' 'Label' 'Units' 'Type' 'Mean' 'Sum' 'Range' 'Fill%' 'Min' 'Max' 'C1' 'C2'});
        [i,j] = ismember(string(info.Units), string(units)); info.Units(i) = num2cell(units(j(i))); % Make a drop downs for units
        [i,j] = ismember(string(info.Units), string(zones)); info.Units(i) = num2cell(zones(j(i))); % Make a drop downs for timezone
        hData.ColumnWidth = {'auto' 'auto' 70 70 60 60 60 45 80 80 30 30};
        hData.Data = info;

        % Custom colours
        i1 = find(hData.Data.Properties.VariableNames == "C1");
        i2 = find(hData.Data.Properties.VariableNames == "C2");
        for k = 1:width(T)
            addStyle(hData, uistyle('BackgroundColor', T.Properties.CustomProperties.C1{k}), 'cell', [k i1]);
            addStyle(hData, uistyle('BackgroundColor', T.Properties.CustomProperties.C2{k}), 'cell', [k i2]);
        end
        addStyle(hData, uistyle('FontColor', [0.4 0.4 0.4]), 'column', 4:i1-1)

        % Update Tariffs tab
        t = T.Properties.VariableNames(vartype('numeric'));
        hImport.Items = t;
        hExport.Items = t;
        if any(ismember(t, 'import_kw'))
            hImport.Value = 'import_kw';
        end
        if any(ismember(t, 'export_kw'))
            hExport.Value = 'export_kw';
        end

        % Update start and stop times
        set(findobj(gui, 'Tag', 'start_time'), 'Value', string(min(T.time), 'yyyy-MM-dd HH:mm'))
        set(findobj(gui, 'Tag', 'stop_time'), 'Value', string(max(T.time) + rez, 'yyyy-MM-dd HH:mm'))

        % Update app title
        % gui.Name = sprintf('%g days, %g properties, %gm rez, %s to %s - EnKit', round(days(range(T.time))), width(T), minutes(rez), char(T.time(1),'yyyy-MM-dd'), char(dateshift(T.time(end),'end','day'), 'yyyy-MM-dd'));
        gui.Name = sprintf('%g days x %g properties - EnKit', round(days(range(T.time))), width(T) - 1);
        drawnow
    end
    function appendData(t)
        try
            T = gui.UserData;
            if isempty(T)
                T = t;
            else
                duplicates = setdiff(intersect(T.Properties.VariableNames, t.Properties.VariableNames), 'time');
                if ~isempty(duplicates)
                    fprintf(' Discarded previous data: %s\n', strjoin(duplicates, ', '))
                    T = removevars(T, duplicates);  % Remove duplicates columns
                end
                t = conditionTable(t);
                T = outerjoin(T, t, 'Keys', 'time', 'MergeKeys', true);  % Join
            end
            updateData(T)
        catch ex
            fprintf(2, '%s\n', ex.message)
        end
    end
    function export(h)
        T = gui.UserData;
        T(:, vartype('numeric')) = varfun(@(x)round(x, 6), T(:, vartype('numeric')));
        file = [strrep(h.Value, '.mat', '') '.csv'];
        writetable(T, file)
        fprintf(' > %s\n', file)
    end

%% Meter
fold = fullfile(rootFold, 'meter', 'data');
ht = uitab(tab, 'Title', 'Meter');
uihyperlink      (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Import smart meter data. See help (?) for download instructions.', 'URL', 'https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard');
uibutton         (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'meter', 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel          (ht,         'Position', [   10 H-100    40    30], 'Text', 'Input:');
h = uieditfield  (ht, 'text', 'Position', [   50 H-100 W-220    30], 'Value', fold, 'Placeholder', 'Select file or folder');
uibutton         (ht, 'push', 'Position', [W-160 H-100    30    30], 'Icon', fileIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFile(h, '*.csv'), 'Tooltip', 'Select a file...');
uibutton         (ht, 'push', 'Position', [W-120 H-100    30    30], 'Icon', foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFolder(h), 'Tooltip', 'Select a folder...');
uibutton         (ht, 'push', 'Position', [W- 80 H-100    70    30], 'Text', 'Import',             'ButtonPushedFcn', @(~,~)importNemData(h), 'Tooltip', 'Read data');
    function importNemData(h)
        T = nem().read(h.Value);
        appendData(T)
    end

%% Battery
fold = fullfile(rootFold, 'battery', 'data');
ht = uitab(tab, 'Title', 'Battery');
uilabel         (ht,          'Position', [   10 H- 60 W- 40    30], 'Text', 'Import battery data.', 'FontSize', 14);
uibutton        (ht, 'push',  'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'meter', 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel         (ht,          'Position', [   10 H-100    40    30], 'Text', 'Input:');
h = uieditfield (ht, 'text',  'Position', [   50 H-100 W-220    30], 'Value', fold, 'Placeholder', 'Select file or folder');
% uibutton        (ht, 'push',  'Position', [W-160 H-100    30    30], 'Icon', fileIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFile(h, '*.csv'), 'Tooltip', 'Select a file...');
uibutton        (ht, 'push',  'Position', [W-120 H-100    30    30], 'Icon', foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFolder(h), 'Tooltip', 'Select a folder...');
uibutton        (ht, 'push',  'Position', [W- 80 H-100    70    30], 'Text', 'Import',             'ButtonPushedFcn', @(~,~)importBatteryData(h), 'Tooltip', 'Read data');
uilabel         (ht,          'Position', [   10 H-140    40    30], 'Text', 'Type:');
uidropdown      (ht,          'Position', [   50 H-140   200    30], 'Items', {'Tesla Powerwall2'});
uilabel         (ht,          'Position', [  280 H-140    80    30], 'Text', 'Date range:');
t1 = uieditfield(ht,          'Position', [  350 H-140   120    30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
t2 = uieditfield(ht,          'Position', [  490 H-140   120    30], 'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uicheckbox      (ht,          'Position', [W-150 H-140   120    30], 'Value', 0, 'Text', 'Intersection only');
    function importBatteryData(h)
        try
            T = powerwall2().read(h.Value, {t1.Value t2.Value});
            appendData(T)
        catch ex
            fprintf(2, 'Error: %s\n', ex.message);
            fprintf(2, '%s\n', getReport(ex, 'extended', 'hyperlinks', 'off'));
        end
    end

%% Inverter
ht = uitab(tab, 'Title', 'Inverter');

%% AEMO
fold = fullfile(rootFold, 'aemo', 'data');
ht = uitab(tab, 'Title', 'AEMO');
uihyperlink      (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Download and import AEMO wholesale price data', 'URL', 'https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data');
uibutton         (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'aemo', 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel          (ht,         'Position', [   10 H-100    70    30], 'Text', 'Input:', 'Tooltip', 'Enter a custom system ID and click Download');
h = uieditfield  (ht, 'text', 'Position', [   50 H-100 W-220    30], 'Value', fold, 'Placeholder', 'Select file or folder');
uibutton         (ht, 'push', 'Position', [W-160 H-100    30    30], 'Icon', foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFolder(h), 'Tooltip', 'Select a folder...');
uilabel          (ht,         'Position', [   10 H-140    40    30], 'Text', 'State:');
h = uidropdown   (ht,         'Position', [   50 H-140   100    30], 'Value', 'SA', 'Items', ["NSW" "QLD" "VIC" "SA" "TAS"]);
uilabel          (ht,         'Position', [  290 H-140    80    30], 'Text', 'Date range:');
t1 = uieditfield (ht,         'Position', [  360 H-140   120    30], 'Value', '-400', 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
t2 = uieditfield (ht,         'Position', [  500 H-140   120    30], 'Value', '-5',   'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uibutton         (ht, 'push', 'Position', [W- 80 H-100    70    30], 'Text', 'Import',   'ButtonPushedFcn', @(~,~)importAemoData(h.Value, {t1.Value, t2.Value}), 'Tooltip', 'Read data');
uibutton         (ht, 'push', 'Position', [W- 80 H-140    70    30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadAemoData(h.Value, {t1.Value, t2.Value}), 'Tooltip', 'Download production data');
    function importAemoData(state, span)
        T = aemo().read(state, span);
        appendData(T);
    end
    function downloadAemoData(state, span)
        aemo().download(state, span, hours(12))
    end

%% PVoutput
fold = fullfile(rootFold, 'pvoutput', 'data');
ht = uitab(tab, 'Title', 'PVoutput');
uihyperlink     (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Import or download solar production data from PVoutput.org', 'URL', 'https://pvoutput.org/map.jsp?country=1&state=SA');
uibutton        (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(''), 'Tooltip', 'Open readme.txt');
uilabel         (ht,         'Position', [   10 H-100    70    30], 'Text', 'Input:', 'Tooltip', 'Enter a custom system ID and click Download');
h = uieditfield (ht, 'text', 'Position', [   50 H-100 W-220    30], 'Value', fold, 'Placeholder', 'Select file or folder');
uibutton        (ht, 'push', 'Position', [W-160 H-100    30    30], 'Icon', foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFolder(h), 'Tooltip', 'Select a folder...');
uibutton        (ht, 'push', 'Position', [W- 80 H-100    70    30], 'Text', 'Import', 'ButtonPushedFcn', @(s,~)importPVoutoutData(s, h.Value), 'Tooltip', 'Read data');
uilabel         (ht,         'Position', [   10 H-140    40    30], 'Text', 'Sys Id:');
hSysId = uidropdown(ht,      'Position', [   50 H-140   100    30], 'Editable', 'on', 'ValueChangedFcn', @(s,~)selectPvSite(s.Value));
hPvUrl = uihyperlink(ht,     'Position', [  160 H-140    50    30], 'Text', 'Map', 'URL', 'https://pvoutput.org/map.jsp?country=1&state=SA');  % Web links
uilabel         (ht,         'Position', [  290 H-140    80    30], 'Text', 'Date range:');
t1 = uieditfield(ht,         'Position', [  360 H-140   120    30], 'Value', '-400', 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
t2 = uieditfield(ht,         'Position', [  500 H-140   120    30], 'Value', '-5',   'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uibutton        (ht, 'push', 'Position', [  740 H-140    70    30], 'Text', 'Description', 'ButtonPushedFcn', @(~,~)downloadPvoutoutInfo(0), 'Tooltip', 'Download description only');
uibutton        (ht, 'push', 'Position', [W- 80 H-140    70    30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadPvoutoutProduction({t1.Value, t2.Value}), 'Tooltip', 'Download production data');
hPvMap = uiaxes (ht,         'Position', [   30    10   460   290], 'XLim', [112 155], 'YLim', [-44.5 -10], 'Clim', [0 100], 'XGrid', 'on', 'YGrid', 'on', 'NextPlot', 'add');
hPvInfo = uitextarea(ht,     'Position', [  500    30   390   270], 'Editable', 'off', 'FontName', 'Courier New', 'FontSize', 15, 'WordWrap', 'off', 'BackgroundColor', gui.Color);
uibutton        (ht, 'push', 'Position', [W- 40 H-190    30    30], 'Icon', refrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)refreshPvSiteInfo(1), 'Tooltip', 'Check downloaded data');

disableDefaultInteractivity(hPvMap)
plot(hPvMap, load('coastlines.mat').coastlon, load('coastlines.mat').coastlat, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'HitTest', 'off'); % Plot coastline
refreshPvSiteInfo(0) % 0 = dont refresh (faster)
set(datacursormode(gui), 'UpdateFcn', @(~,e)updateDataTip(e), 'SnapToDataVertex', 'on', 'Enable', 'off')

    function downloadPvoutoutInfo(staleThreshold)
        pvoutput().downloadInfo(hSysId.Value, staleThreshold)
        refreshPvSiteInfo(1)
    end
    function downloadPvoutoutProduction(span)
        pvoutput().downloadProduction(hSysId.Value, span)
        refreshPvSiteInfo(1)
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
        hSysId.UserData = S; % Store data in hSysId
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
            hPvInfo.Value = struct2str(s);
        else
            hPvInfo.Value = '';
        end
    end
    function txt = updateDataTip(e) % Hacky
        if e.Target.Tag == "PVsite"
            s = e.Target.UserData;
            selectPvSite(s.sysId)
            txt = sprintf('Lat: %.4f\nLon: %.4f', e.Position([2 1]));
        else
            txt = sprintf('X: %g\nY: %g',e.Position);
        end
    end


%% Sim Battery
ht = uitab(tab, 'Title', 'Sim Battery');

%% Sim Solar
ht = uitab(tab, 'Title', 'Sim Solar');

%% Tariffs
ht = uitab(tab, 'Title', 'Tariffs');
uilabel         (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Predict usage cost.', 'FontSize', 14);
uibutton        (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'meter', 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel         (ht,         'Position', [   10 H-100    40    30], 'Text', 'Tariff:');
hTariffs = uidropdown  (ht,  'Position', [   50 H-100   150    30], 'Items', {}, 'ValueChangedFcn', @(h,~)previewTariff(h,ht));
uibutton        (ht, 'push', 'Position', [  200 H-100    30    30], 'Icon', refrIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)refreshTariffList(), 'Tooltip', 'Refresh list of Tariffs');
uilabel         (ht,         'Position', [  250 H-100    40    30], 'Text', 'Import:');
hImport = uidropdown(ht,     'Position', [  290 H-100   140    30], 'Items', {}, 'Placeholder', 'no data');
uilabel         (ht,         'Position', [  450 H-100    40    30], 'Text', 'Export:');
hExport = uidropdown(ht,     'Position', [  490 H-100   140    30], 'Items', {}, 'Placeholder', 'no data');
uibutton        (ht, 'push', 'Position', [W- 80 H-100    70    30], 'Text', 'Caclulate', 'ButtonPushedFcn', @(~,~)calcTariffs(), 'Tooltip', 'Read data');
refreshTariffList()
    function refreshTariffList()
        hTariffs.Items = unique(tariffs().tariff, 'stable');
    end
    function previewTariff(h, ht)
        delete(findobj(ht, 'Tag', 'previewTariff'))
        dayList = tariffs(h.Value).date';
        n = numel(dayList);
        W = 1/n;
        for k = 1:numel(dayList)
            ax = uiaxes(ht, 'Units', 'normalized', 'Position', [W*(k-1)+0.01 0.01 W*0.95 0.75], 'XLim', [0 24], 'YLim', [-15 65], 'XGrid', 'on', 'YGrid', 'on', 'Tag', 'previewTariff');
            xlabel(ax, 'Time of day (hours)')
            if k == 1 
                ylabel(ax, 'Price (c/kWh)', 'FontWeight', 'bold')
            end
            xticks(ax, 0:3:24)
            time = dayList(k) + hours(0:0.5:23.5);
            [buy_price, sell_price, supply] = tariffs(h.Value, time);
            time_hrs = hours(timeofday(time));
            plotstepspread(ax, time_hrs, buy_price, [], 'r', sprintf('Av.Buy=%.2f c/kWh', mean(buy_price)), 'xy')
            plotstepspread(ax, time_hrs, sell_price, [], 'g', sprintf('Av.Sell=%.2f c/kWh', mean(sell_price)), 'xy')
            plotstepspread(ax, time_hrs, supply*nan, [], [0.9 0.4 0], sprintf('Supply=%.2f c/day', sum(supply)), 'xy')
            legend (ax, 'show', 'location', 'S', 'FontSize', 10, 'FontWeight', 'bold')
            title(ax, string(dayList(k)))
        end
    end
    function calcTariffs()
        T = gui.UserData;
        if ~isempty(T)
            time = T.time;
            step = hours(mode(diff(time)));

            [buy_ckwh, sell_ckwh, supply_c] = tariffs(hTariffs.Value, T.time);

            buy_cost_c = buy_ckwh.*T.(hImport.Value)*step;
            sell_cost_c = -sell_ckwh.*T.(hExport.Value)*step;
            supply_cost_c = supply_c;
            cost_c = buy_ckwh.*T.(hImport.Value)*step - sell_ckwh.*T.(hExport.Value)*step + supply_c;
            appendData(table(time, buy_ckwh, sell_ckwh, supply_c, buy_cost_c, sell_cost_c, supply_cost_c, cost_c));
        end
    end

%% Amber
fold = fullfile(rootFold, 'amber', 'data');
ht = uitab(tab, 'Title', 'Amber');
uihyperlink      (ht,         'Position', [   10 H- 60 W- 40    30], 'Text', 'Download and import Amber price and usage data', 'URL', 'https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard');
uibutton         (ht, 'push', 'Position', [W- 40 H- 60    30    30], 'Icon', helpIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)showHelp(fullfile(rootFold, 'aemo', 'Readme.txt')), 'Tooltip', 'Open readme.txt');
uilabel          (ht,         'Position', [   10 H-100    70    30], 'Text', 'Input:', 'Tooltip', 'Enter a custom system ID and click Download');
h = uieditfield  (ht, 'text', 'Position', [   50 H-100 W-220    30], 'Value', fold, 'Placeholder', 'Select file or folder');
uibutton         (ht, 'push', 'Position', [W-160 H-100    30    30], 'Icon', foldIcon, 'Text', '', 'ButtonPushedFcn', @(~,~)selectFolder(h), 'Tooltip', 'Select a folder...');
uilabel          (ht,         'Position', [   10 H-140    40    30], 'Text', 'State:');
h = uidropdown   (ht,         'Position', [   50 H-140   100    30], 'Value', 'SA', 'Items', ["NSW" "QLD" "VIC" "SA" "TAS"]);
uilabel          (ht,         'Position', [  290 H-140    80    30], 'Text', 'Date range:');
t1 = uieditfield (ht,         'Position', [  360 H-140   120    30], 'Value', '-400', 'Placeholder', 'yyyy-mm-dd', 'Tag', 'start_time');
t2 = uieditfield (ht,         'Position', [  500 H-140   120    30], 'Value', '-5',   'Placeholder', 'yyyy-mm-dd', 'Tag', 'stop_time');
uibutton         (ht, 'push', 'Position', [W- 80 H-100    70    30], 'Text', 'Import',   'ButtonPushedFcn', @(~,~)importAmberData(h.Value, {t1.Value, t2.Value}), 'Tooltip', 'Read data');
uibutton         (ht, 'push', 'Position', [W- 80 H-140    70    30], 'Text', 'Download', 'ButtonPushedFcn', @(~,~)downloadAmberData(h.Value, {t1.Value, t2.Value}), 'Tooltip', 'Download production data');
    function importAmberData(state, span)
        T = aemo().read(state, span);
        appendData(T);
    end
    function downloadAmberData(state, span)
        amber().getPrices({'2024-11-01' 0}, 5);
    end

%% Helper Functions
    function selectFile(h, type)
        [file, path] = uigetfile(type, 'Select file', h.Value); figure(gui)
        if ~isequal(file, 0)
            h.Value = fullfile(path, file);
        end
    end
    function selectFolder(h)
        folder = uigetdir(h.Value, 'Select folder'); figure(gui)
        if ~isequal(folder, 0)
            h.Value = folder;
        end
    end

end
%% Helper Functions 2
function showHelp(helpFile)
txt = fileread(helpFile);  % Read file
txt = replace(txt, {'&' '<' '>'}, {'&amp;' '&lt;' '&gt;'});  % Escape HTML for safe display
urls = regexp(txt, '(https?://[^\s]+)', 'match');  % Find URLs
txt = regexprep(txt, '(https?://[^\s]+)', '<u>$1</u>');  % Underline links
html = ['<html><head><base target="_blank"></head><pre style="white-space:pre-wrap; font-family:Consolas;">' txt '</pre></html>'];  % Make HTML
close(findall(0, 'Name', helpFile))  % Close old figures
fig = uifigure('Name', helpFile, 'Tag', 'enkit', 'Position', [200 200 800 600]);  % Create uifigure
uihtml(fig, 'HTMLSource', html, 'Position', [10 40 780 550]);
for k = 1:length(urls)
    uihyperlink(fig, 'Text', urls{k}, 'Position', [(k-1)*170+10 5 150 30], 'URL', urls{k});  % Web links
end
end

function T = conditionTable(T)
if ~isprop(T, 'C1')
    T = addprop(T, {'C1' 'C2'}, {'variable' 'variable'});
    T.Properties.CustomProperties.C1{1} = [];
    T.Properties.CustomProperties.C2{1} = [];
end
if ~isprop(T, 'rez')
    T = addprop(T, 'rez', 'table');
    T.Properties.CustomProperties.rez = mode(diff(T.time));
end
for k = 1:width(T)
    if isempty(T.Properties.CustomProperties.C1{k})
        T.Properties.CustomProperties.C1{k} = [0 1 0];
    end
    if isempty(T.Properties.CustomProperties.C2{k})
        T.Properties.CustomProperties.C2{k} = [1 0 0];
    end
end
if isempty(T.Properties.VariableUnits)
    T.Properties.VariableUnits(:) = regexp(T.Properties.VariableNames, '(?<=\w*_)[^_]*$', 'match', 'once');
end
if isempty(T.Properties.VariableDescriptions)
    t = strrep(regexprep(T.Properties.VariableNames, "_" + T.Properties.VariableUnits + "$", "", 'ignorecase'), "_", " "); % Remove units & replace "_" with space
    T.Properties.VariableDescriptions(:) = regexprep(t, '(?<= |^).', '${upper($0)}'); % Title case
    T.Properties.VariableDescriptions = regexprep(T.Properties.VariableDescriptions, ["sa_" "" ""], ["" "" ""]); % Title case
end
i = T.Properties.VariableTypes=="datetime";
T.Properties.VariableUnits(i) = regexprep(varfun(@(x) x.TimeZone, T(:, i), 'OutputFormat', 'cell'), '.*/', '');
end

function row = getRow(h)
if isempty(h.Selection)
    row = [];
else
    row = unique(h.Selection(:, 1))';
end
end

function var = getVar(h, numericOnly)
if isempty(h.Selection)
    var = {};
else
    var = string(h.Data.Property(unique(h.Selection(:, 1))));
    if nargin>1 && numericOnly
        var = setdiff(var, 'time'); % hack
    end
end
end

function str = struct2str(S)
t = [S.Properties.VariableNames; string(table2cell(S))];
str = sprintf('%-11s %s\n', t{:});
end