function GUI2
%% EnKit GUI - Energy data management and analysis interface
% Constants
cfg.guiFold = fileparts(mfilename('fullpath'));
cfg.rootFold = fileparts(cfg.guiFold);
cfg.rez = minutes(5);

% Icons:
cfg.fileIcon = fullfile(cfg.guiFold, 'icons', 'file.png');
cfg.newfIcon = fullfile(cfg.guiFold, 'icons', 'new.png');
cfg.saveIcon = fullfile(cfg.guiFold, 'icons', 'save.png');
cfg.savsIcon = fullfile(cfg.guiFold, 'icons', 'saveas.png');
cfg.foldIcon = fullfile(cfg.guiFold, 'icons', 'folder.png');
cfg.openIcon = fullfile(cfg.guiFold, 'icons', 'open.png');
cfg.helpIcon = fullfile(cfg.guiFold, 'icons', 'help.png');
cfg.rmpvIcon = fullfile(cfg.guiFold, 'icons', 'rmpv.png');
cfg.rmnvIcon = fullfile(cfg.guiFold, 'icons', 'rmnv.png');
cfg.flipIcon = fullfile(cfg.guiFold, 'icons', 'flip.png');
cfg.refrIcon = fullfile(cfg.guiFold, 'icons', 'refresh.png');
cfg.copyIcon = fullfile(cfg.guiFold, 'icons', 'copy.png');
cfg.delrIcon = fullfile(cfg.guiFold, 'icons', 'deleterow.png');

cfg.units = ["kw" "kwh" "$" "c" "c/kwh" "custom"]; cfg.units = categorical(cfg.units, cfg.units);
cfg.zones = ["+08:00" "+09:30" "+10:00" "+10:30" "+11:00" "Perth" "Adelaide" "Darwin" "Brisbane" "Sydney"];
cfg.zones = categorical(cfg.zones);

%% Figure
cfg.W = 900; cfg.H = 460;
delete(findall(0, 'Tag', 'enkit'))
warning off MATLAB:ui:containers:SizeChangedFcnDisabledWhenAutoResizeOn
gui = uifigure  ('Position', [100 400 cfg.W+20 cfg.H+20], 'Name', 'EnKit', 'Tag', 'enkit');
tab = uitabgroup('Position', [ 10  10 cfg.W    cfg.H   ], 'Parent', gui);

% Shared app state and methods
app.gui = gui;
app.updateData = @updateData;
app.appendData = @appendData;
app.loadIcon = @loadIcon;
app.selectFile = @selectFile;
app.selectFolder = @selectFolder;
app.showHelp = @showHelp;
app.conditionTable = @conditionTable;
app.getRow = @getRow;
app.getVar = @getVar;
app.struct2str = @struct2str;
app.dateFormat = @dateFormat;

%% Initialize Modular Tabs
app = DataTab(tab, app, cfg);
app = MeterTab(tab, app, cfg);
app = BatteryTab(tab, app, cfg);
app = InverterTab(tab, app, cfg);
app = AemoTab(tab, app, cfg);
app = PvOutputTab(tab, app, cfg);
app = SimTab(tab, app, cfg);
app = SimSolarTab(tab, app, cfg);
app = AmberTab(tab, app, cfg);
app = TariffsTab(tab, app, cfg);
app = InflationTab(tab, app, cfg);

%% Core Shared Functions
    function rgb = loadIcon(file)
        [rgb, ~, alpha] = imread(file);
        rgb = im2double(rgb);
        rgb(repmat(alpha == 0, [1 1 3])) = nan;
    end

    function clearData()
        gui.UserData = [];
        set(findobj(gui, 'Tag', 'start_time'), 'Value', '')
        set(findobj(gui, 'Tag', 'stop_time'), 'Value', '')
        if isfield(app, 'hData'), app.hData.Data = {}; end
        if isfield(app, 'hImport'), app.hImport.Items = {}; end
        if isfield(app, 'hExport'), app.hExport.Items = {}; end
        gui.Name = 'EnKit';
    end

    function updateData(T)
        if isempty(T)
            clearData()
            return
        end

        % Validate and assign data
        T = app.conditionTable(T);
        gui.UserData = T;

        % Forward update to modular components
        if isfield(app, 'DataTab_Update'), app.DataTab_Update(T, cfg); end
        if isfield(app, 'TariffsTab_Update'), app.TariffsTab_Update(T); end

        % Update start_time and stop_times
        set(findobj(gui, 'Tag', 'start_time'), 'Value', string(min(T.time), app.dateFormat(min(T.time))));
        set(findobj(gui, 'Tag', 'stop_time' ), 'Value', string(max(T.time) + cfg.rez, app.dateFormat(max(T.time) + cfg.rez)));

        % Update app title
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
                    T = removevars(T, duplicates);
                end
                t = app.conditionTable(t);
                T = synchronize(T, t, 'union');
                T.Properties.DimensionNames{1} = 'time';
            end
            updateData(T)
        catch ex
            fprintf(2, '%s\n', ex.message)
        end
    end

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
if istable(T)
    T = table2timetable(T, 'RowTimes', 'time');
end
T.Properties.DimensionNames{1} = 'time';
if ~isprop(T, 'C1')
    T = addprop(T, {'C1' 'C2'}, {'variable' 'variable'});
    T.Properties.CustomProperties.C1{1} = [];
    T.Properties.CustomProperties.C2{1} = [];
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

function frmt = dateFormat(t)
if timeofday(t) == 0
    frmt = 'yyyy-MM-dd';
else
    frmt = 'yyyy-MM-dd HH:mm';
end
end
