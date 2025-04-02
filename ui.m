function amberui

% Examples
examples = {
    'Option 1' 'buy' [0 50 0 50] 'sell' [50 100 0 50] 'buy-saving' [0 50 50 100] 'sell-saving' [50 100 50 100]
    'Option 2' 'buy' [0 50 0 50] 'sell' [50 100 0 50] 'buy-saving' [0 50 50 100] 'sell-saving' [50 100 50 100]};

% Show UI
delete(findobj('Type', 'figure', 'Name', 'AmberUI')); % Close old windows
f = figure('Name', 'AmberUI', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8], 'Color', 'k'); % Figgure

p1 = uipanel('Parent', f, 'Title', 'Panel', 'Position', [0 0.97 1 0.3], 'BorderType', 'none', 'BackgroundColor', 'k');
hdrop  = uicontrol('Parent', f, 'Style', 'pop',  'Units', 'normalized', 'Position', [0.01 0 0.19 1], 'String', examples(:, 1)); % Drop-down
hstart = uicontrol('Parent', p1, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.21 0 0.09 1], 'String', string(datetime, 'yyyy-MM-dd')); % Start Time
hstop  = uicontrol('Parent', p1, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.31 0 0.09 1], 'String', string(datetime, 'yyyy-MM-dd')); % Stop Time

p2 = uipanel('Parent', f, 'Title', '', 'Position', [0 0 1 0.96], 'BorderType','none');
hrun   = uicontrol('Style', 'push', 'Units', 'normalized', 'Position', [0.4 0.97 0.1 0.03], 'String', 'Run', 'Callback', @(~,~) run(hdrop, hstart, hstop)); % Run Button
end

function run(hdrop, hstart, hstop)
startTime = hdrop.String
startTime = hstart.String
stopTime = hstop.String
end
