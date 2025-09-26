% Amber API cannot handly partial days. This wrapper does same.

% Examples:
% amber().getSites
% amber().getPrices({'2024-11-01' 0}, 5);
% amber().getUsage( {'2024-12-23' -1}, 30);
% amber().downloadForecastPeriodicaly

% Remarks:
% "usage" is not available for current data and possibly last day
% "prices" includes forecasts when time span includes future periods

% aims:
% 1. show saving relative to agl
% 2. show historic power usage and cost
% 3. show current usage and cost

% Links
% SA Power dashbaord: https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard 

classdef amber

    properties
        datafold = fullfile(fileparts(mfilename('fullpath')), 'data')
        token
        siteId
        state
        nmi
    end

    methods

        function obj = amber(varargin)
            % Class constructor

            % Apply ini settings
            ini = fullfile(fileparts(mfilename('fullpath')), 'amber.ini');
            if isfile(ini)
                txt = fileread(ini);
                for prop = string(properties(obj)')
                    value = regexp(txt, "(?<=^\s*" + prop + "\s*=\s*)[^ \r\n]*", 'match', 'once', 'lineanchors'); % Find the value
                    if ~isempty(value)
                        obj.(prop) = strtrim(value);
                    end
                end
            end

            % Apply user settings
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k + 1};
            end

            % Download siteId, if needed
            if isempty(obj.siteId)
                site = obj.getSites;
                disp(site)
                disp(site.channels)
                obj.siteId = site.id;
                fprintf(2, 'To skip this step assign "siteId" property in "amber.ini" file to the "id" value above.\n')
                pause(1)
            end
        end

        % function plotPrice(obj, fig, span, source, type, mode)
        %     if nargin < 5 || isempty(mode)
        %         mode = "";
        %     end
        %     if ~isscalar(type) && isscalar(mode)
        %         mode = repmat(mode, size(type));
        %     end
        % 
        %     switch source
        %         case 'sapn_andrew'
        %             T = nem12read('sapn\andrew');
        %         case 'sapn_serge'
        %             T = nem12read('sapn\serge');
        %         case 'amber_prices_30min'
        %             T = obj.getData('prices', span, 30);
        %         case 'amber_prices_5min'
        %             T = obj.getData('prices', span, 5);
        %         case 'amber_usage_30min'
        %             T = obj.getData('usage', span, 30);
        %         case 'amber_usage_5min'
        %             T = obj.getData('usage', span, 5);
        %         otherwise
        %             error('Unknown source: %s\n',source)
        %     end
        % 
        %     % Prepare figure
        %     figure(fig), clf
        %     set(fig, 'WindowStyle', 'docked', 'Color', 'k', 'NumberTitle', 'off', 'Name', num2str(fig))
        %     plot_y = linspace(0.03, 0.97, numel(type) + 1); % Plot heights
        % 
        %     % Plot one axis at a time
        %     A = []; % Init handles list
        %     for k = 1:numel(type)
        % 
        %         % Setup axis
        %         a = axes('Position', [0.08 plot_y(end-k) 0.84 plot_y(end-k+1) - plot_y(end-k)], ...
        %             'Color', 'k', 'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6], 'GridColor', [0.6 0.6 0.6]);
        %         hold on, grid on, box on, axis tight
        %         switch k
        %             case 1, set(a, 'XAxisLocation', 'top')
        %             case numel(type), set(a, 'XAxisLocation', 'bottom')
        %             otherwise, a.XRuler.FontSize = 0.01; % no axis
        %         end
        % 
        %         X = T.start;
        %         switch type(k)
        % 
        %             case {'buy_amount' 'sell_amount'  'buy2_amount'}
        %                 ylabel(regexprep([source; type(k)], {'_' 'amount'}, {' ' '(kwh)'}))
        %                 X = T.start;
        %                 Y = T.(type(k));
        %                 [c, cmap, cstr] = col(type(k));
        %                 switch mode(k)
        %                     case "heatmap"
        %                         plotHeatmap(a, X, Y, cmap)
        %                     case ""
        %                         d = dateshift(X, 'start', 'day');
        %                         y = accumarray(findgroups(d), Y, [], @sum);
        %                         t = sprintf([cstr '%.2fkwh\n'], sum(y));
        %                         plotsteps(a, unique(d), y, c, t)
        %                         legend show
        %                 end
        % 
        %             case {'buy_price' 'sell_price' 'buy2_price'}
        %                 ylabel(regexprep(type(k), {'_' 'amount'}, {' ' '(kwh)'}))
        %                 Y = T.(type(k));
        %                 c = col(type(k));
        %                 switch mode(k)
        %                     case "agl"
        %                         plotSpread(a, X, Y, X, agl(X, type(k)), c)
        %                         plotsteps(a, X, Y, c)
        %                     case "5min"
        %                         plotSpread(a, X, Y, T2.start, T2.(type(k)), c)
        %                         plotsteps(a, X, Y, c)
        %                     case "24hr"
        %                         X = timeofday(X);
        %                         plotsteps(a, X, Y, [c 0.2], '', 'linewidth', 0.5)
        %                         Y = arrayfun(@(x) mean(Y(X == x)), unique(X));
        %                         X = unique(X);
        %                         plotsteps(a, X, Y, c)
        %                     case "heatmap"
        %                         if type(k) == "sell_price"
        %                             cmap = rbg;
        %                         else
        %                             cmap = flipud(rbg);
        %                         end
        %                         plotHeatmap(a, X, Y, cmap)
        %                     otherwise
        %                         plotSpread(a, X, Y, X, Y*0 + str2double(mode(k)), c)
        %                         plotsteps(a, X, Y, c)
        %                 end
        % 
        %             case 'buy_saving'
        %                 ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
        %                 T = obj.getData('prices', span, 30);
        %                 T2 = obj.getData('usage', span, 30);
        %                 X = T.start;
        %                 switch mode(k)
        %                     case ""
        %                         Y = agl(X, 'buy_price') .* T2.buy_amount;
        %                         d = dateshift(X, 'start', 'day');
        %                         y1 = accumarray(findgroups(d), Y, [], @sum)/100 + agl([], 'supply');
        %                         t = sprintf('\\color[rgb]{1 .2 .2}AGL = $%.2f\n', sum(y1) );
        %                         plotsteps(a, unique(d), y1, [1 .2 .2], t)
        % 
        %                         Y = T.buy_price .* T2.buy_amount;
        %                         d = dateshift(X, 'start', 'day');
        %                         y = accumarray(findgroups(d), Y, [], @sum)/100 + amb([], 'supply');
        %                         t = sprintf('\\color[rgb]{.4 .4 1}Amber = $%.2f\n', sum(y) );
        %                         plotsteps(a, unique(d), y, [0.2 .2 1], t)
        % 
        %                         y3 = y-y1;
        %                         t = sprintf('\\color[rgb]{.2 1 .2}Saving = $%.2f', sum(y3));
        %                         plotsteps(a, unique(d), y3, [.2 1 .2], t)
        % 
        %                         legend show
        % 
        %                     case "heatmap"
        %                         Y = (T.buy_price - agl(X, 'buy_price')) .* T2.buy_amount;
        %                         plotHeatmap(a, X, Y, flipud(rbg))
        %                 end
        % 
        %             case 'sell_saving'
        %                 ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
        %                 T = obj.getData('prices', span, 30);
        %                 T2 = obj.getData('usage', span, 30);
        %                 X = T.start;
        %                 % Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
        %                 Y = (T.sell_price ) .* T2.sell_amount;
        %                 cmap = rbg;
        %                 plotHeatmap(a, X, Y, cmap)
        % 
        %             case 'net_saving'
        %                 ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
        %                 T = obj.getData('prices', span, 30);
        %                 T2 = obj.getData('usage', span, 30);
        %                 X = T.start;
        %                 Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
        %                 cmap = rbg;
        %                 plotHeatmap(a, X, Y, cmap)
        % 
        %             case 'buy_price&sell_price'
        %                 ylabel 'buy / sell'
        %                 plotsteps(a, X, T.buy_price, 'r')
        %                 plotsteps(a, X, T.sell_price, 'b')
        %                 if mode(k) == "5min"
        %                     plotSpread(a, X, T.buy_price, T2.start, T2.buy_price, 'r')
        %                     plotSpread(a, X, T.sell_price, T2.start, T2.sell_price, 'b')
        %                 end
        % 
        %             case {'buy_price_diff' 'sell_price_diff'}
        %                 ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
        %                 m = strrep(type(k), '_diff', '');
        %                 Y = T.(m) - agl(X, m);
        %                 c = col(m);
        %                 switch mode(k)
        %                     case '24hr'
        %                         X = timeofday(X);
        %                         plotsteps(a, X, Y, [c 0.2], '', 'LineWidth', 0.5)
        %                         X2 = unique(X);
        %                         Y2 = arrayfun(@(x) mean(Y(X == x)), X2);
        %                         plotsteps(a, X2, Y2, c, '', 'LineWidth', 2)
        %                     case "heatmap"
        %                         if type(k) == "sell_price"
        %                             cmap = rbg;
        %                         else
        %                             cmap = flipud(rbg);
        %                         end
        %                         plotHeatmap(a, X, Y, cmap)
        %                     otherwise
        %                         plotsteps(a, X, Y, c)
        %                 end
        % 
        %             case 'renewables'
        %                 ylabel 'Renewables (%)'
        %                 plotsteps(a, X, T.renewables, [0 0.5 0])
        %                 yline(a, 100, 'w--')
        %                 linkaxes([a a], 'x'), xlim([min(X) max(T.stop)])
        %                 if mode(k) == "5min"
        %                     plotSpread(a, X, T.renewables, T2.start, T2.renewables, [0 0.5 0])
        %                 end
        %         end
        %         if mode(k) ~= "heatmap"
        %             yline(a, 0, 'w--', 'HandleVisibility', 'off')
        %             ylim(a, ylim(a) + [-5 5])
        %         end
        %         A = [A a]; %#ok<AGROW>
        %     end
        % 
        %     ind = arrayfun(@(x)isdatetime(x.XLim), A);
        %     if any(ind)
        %         linkaxes(A(ind), 'x')
        %     end
        %     ind = arrayfun(@(x)isduration(x.YLim)&isduration(x.YLim), A);
        %     if any(ind)
        %         linkaxes(A(ind), 'xy')
        %     end
        %     if k == numel(type)
        %         file = sprintf('plots/%g.png', gcf().Number);
        %         figsave(gcf, file, [1920 1080])
        %     end
        % 
        % end

        function data = getSites(obj)
            % Download site informaiton
            [err, json] = obj.geturl('https://api.amber.com.au/v1/sites');
            assert(~err, '%s', json) % Abort if error

            % Parse data
            data = jsondecode(json);
            if isfield(data, 'channels') % Convert channels field to a table of strings
                t = varfun(@string, struct2table(data.channels));
                t.Properties.VariableNames = fieldnames(data.channels);
                data.channels = t;
            end
        end

        function T = getUsage(obj, span)
            T = getData(obj, 'usage', span);
        end
        function T = getPrices(obj, span, varargin)
            T = getData(obj, 'prices', span, varargin{:});
        end
        function T = getData(obj, type, span, rez)
            % Read or download prices or usage data
            if nargin < 4, rez = []; end  % Use default 5 min resolution

            % Collect results in a cell (faster than growing a table)
            tables = {};

            for day = checkdate(span{1}) : checkdate(span{end})

                % Choose identifier depending on type
                switch type
                    case 'usage'
                        id = obj.nmi;
                    case 'prices'
                        id = obj.state;
                    otherwise
                        error('Unknown type: %s', type);
                end

                % Build file path (no extension)
                file = fullfile(obj.datafold, sprintf('%s_%s', type, id), char(day, 'yyyyMMdd'));
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % Cached file check
                json_file = dir([file '.json']);
                isStale = @(f, d) datetime(f.date) < d + 1 + hours(1) && datetime(f.date) + minutes(30) < datetime;

                if ~isempty(json_file) && isStale(json_file, day)
                    delete(fullfile(json_file.folder, json_file.name));
                    json_file = [];
                end

                % Load or download JSON
                if isempty(json_file)
                    url_span = sprintf('startDate=%s&endDate=%s', ...
                        char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd'));
                    if isempty(rez)
                        url_rez = '';
                    else
                        url_rez = sprintf('&resolution=%g', rez);
                    end
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span url_rez];
                    [err, json] = obj.geturl(url);

                    if err
                        fprintf(2, 'Error: %s\n', json);
                        continue
                    end

                    filewrite([file '.json'], json);
                else
                    json = fileread([file '.json']);
                end

                % Skip if no data
                if numel(json) <= 2
                    fprintf('  %s - no data\n', day);
                    continue
                end

                % Convert json to table and store
                tables{end+1} = obj.readDataFile(type, [file '.json']);
            end

            % Combine all tables
            if isempty(tables)
                T = table(); % return empty if nothing collected
            else
                T = vertcat(tables{:});
            end
        end




        function T = getData_old(obj, type, span, rez)
            % Read or download prices or usage data

            if nargin < 4, rez = []; end % Use default 5 min resolution

            % Step through days
            T = []; % Large table to hold all data
            for day = checkdate(span{1}) : checkdate(span{end})

                % Set output file path (no extension)
                switch type
                    case 'usage',  file = fullfile(obj.datafold, sprintf('%s_%s', type, obj.nmi  ), char(day, 'yyyyMMdd'));
                    case 'prices', file = fullfile(obj.datafold, sprintf('%s_%s', type, obj.state), char(day, 'yyyyMMdd'));
                end
                if ~isfolder(fileparts(file))
                    mkdir(fileparts(file));
                end

                % Check if cached files exist
                json_file = dir([file '.json']);

                % Check if cached file is stale
                if ~isempty(json_file) && ...                            % if JSON file exists, but ...
                        datetime(json_file.date) < day + 1 + 1/24 && ... % file was saved near day's end, and ...
                        datetime(json_file.date) + 0.5/24 < datetime     % file is more then 30 min old, then
                    delete(fullfile(json_file.folder, json_file.name))   % delete the file, as it may be stale
                    json_file = [];
                end
                
                % Load cached json
                if ~isempty(json_file)
                    json = fileread([file '.json']);

                else
                    % Download
                    url_span = sprintf('startDate=%s&endDate=%s', char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd')); % Time span component
                    if ~isempty(rez)
                        url_rez = sprintf('&resolution=%g', rez);
                    else
                        url_rez = '';
                    end
                    url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span url_rez]; % REST URL query
                    [err, json] = obj.geturl(url); % Download

                    % Skip on error
                    if err
                        fprintf(2, 'Error: %s\n', json)
                        continue
                    end

                    % Write json to file, even if its empty
                    filewrite([file '.json'], json)
                end

                % Skip if no data
                if numel(json) <= 2
                    fprintf('  %s - no data\n', day)
                    continue
                end

                % Convert json to a table
                t = obj.readDataFile(type, [file '.json']);

                T = [T; t]; %#ok<AGROW>
            end
        end

        function T = readDataFile(~, type, file)
            % Read prices or usage JSON data file and output a table
            data = jsondecode(fileread(file));

            % Convert to array of structs
            if iscell(data)
                for k = 1:numel(data)
                    if isfield(data{k}, 'tariffInformation')
                        data{k} = rmfield(data{k}, 'tariffInformation'); % privides forecast price, in "prices" and in "usage" endpoints
                    end
                    if isfield(data{k}, 'advancedPrice')
                        data{k} = rmfield(data{k}, 'advancedPrice'); % privides forecast price, in "prices" endpoints
                    end
                    if isfield(data{k}, 'estimate')
                        data{k} = rmfield(data{k}, 'estimate'); % indicates if record is an estimate in in "prices" endpoints
                    end
                end
                data = [data{:}];
            end

            % Make a table
            T = struct2table(data);

            % Parse time
            T.startTime = datetime(T.startTime, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'Format','yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
            T.endTime = datetime(T.endTime, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'Format','yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
            T.startTime = dateshift(T.startTime, 'start', 'minute'); % Round start time to neares minute

            % Replace endTime with duration
            T.duration = minutes(T.endTime-T.startTime);
            T.endTime = [];

            % Convert from UTC to nemTime TimeZone
            timezone = T.nemTime{1}(end-5:end);
            T.startTime.TimeZone = timezone;

            switch type

                case 'prices'
                    % Remove predictions
                    T = T(T.type == "ActualInterval", :);

                    % Remove junk columns
                    T = T(:, {'startTime' 'duration' 'perKwh' 'spotPerKwh' 'renewables' 'channelType'});
                    
                    % Use positive values for feedin
                    T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

                    % Convert channelType from rows to columns
                    T = unstack(T, {'perKwh' 'spotPerKwh'}, 'channelType');
                    
                    % There is no difference between buy & sell spot prices
                    T(:, {'spotPerKwh_controlledLoad'}) = [];
                    try
                        T(:, {'spotPerKwh_feedIn'}) = []; %HACK for edge case with missing columns on 2024-11-29
                    catch
                        T.sell_price = zeros(size(T,1), 1); %HACK
                    end

                    % Improve column names
                    T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'startTime' 'perKwh_general' 'perKwh_controlledLoad' 'perKwh_feedIn' 'spotPerKwh_general'}, {'start' 'buy_price' 'buy2_price' 'sell_price' 'spot_price'});

                    % Re-order columns
                    T = movevars(T, {'buy_price' 'buy2_price' 'sell_price' 'spot_price' 'renewables'}, 'After', 'duration');

                case 'usage'
                    % Remove predictions
                    T = T(T.type == "Usage", :);

                    % Remove junk columns
                    T = T(:, {'startTime' 'duration' 'kwh' 'perKwh' 'channelType'});

                    % Use positive values for feedin
                    T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

                    % Convert channelType from rows to columns
                    T = unstack(T, {'kwh' 'perKwh'}, 'channelType');

                    % Improve column names
                    T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'(.*)_(.*)' 'general' 'feedIn' 'controlledLoad' '_perKwh' 'kwh' 'Time'}, {'$2_$1' 'buy' 'sell' 'buy2' '_price' 'amount' ''});

                    % Re-order columns
                    T = movevars(T, {'buy_amount' 'buy_price' 'sell_amount' 'sell_price' 'buy2_amount' 'buy2_price'}, 'After', 'duration');
            end
        end

        function downloadForecastPeriodicaly(obj)
            % Periodically downloads price forecasts, every 5 min.
            %   amber().downloadForecastPeriodicaly
            % - Downloads 24 hrs @ 30 min data and 1 hr @ 5 min.
            % - Downloads are delayed by 30 sec after the 5 minute mark,
            %   because prices tend to update near the start of the mark.
            % - Downloads are further delayed by a random offset, in the
            %   range of 0-15 sec, to be nice to the server.
            period = 5; % Delay between downloads (min)
            rand_offset = rand*0.25; % 15 sec
            while true
                now_local = datetime('now');
                offset = minutes(period - mod(minute(now_local), period) + 0.5 + rand_offset);
                next_local = dateshift(now_local, 'start', 'minute') + offset; % Wait 1-2 min past the mark, to ensure prices are updated and polling is randomised
                fprintf(' Next download: %s\n', next_local) % Progress
                pause(seconds(next_local - now_local))
                try
                    obj.downloadForecastOnce([48 48], 30); % Download 24 hr @ 30 min
                    obj.downloadForecastOnce([12 12],  5); % Download 1 hr @ 5 min (optional)
                end
            end
        end

        function file = downloadForecastOnce(obj, span, rez)
            % Download current price forecast, once.
            %   amber().downloadForecastOnce(span, rez)
            % - File name is nem time at start of download.
            % - Prints local time to screen.
            fold = fullfile(obj.datafold, 'forecast', sprintf('%s_%gmin', obj.state, rez), 'raw');
            if ~isfolder(fold)
                mkdir(fold);
            end
            start_time = datetime('now', 'TimeZone', 'local'); % Download start time (local)
            [err, json] = obj.geturl(sprintf('https://api.amber.com.au/v1/sites/%s/prices/current?previous=%g&next=%g&resolution=%g', obj.siteId, span, rez)); % Download
            d = jsondecode(json);
            start_time.TimeZone = d{1}.nemTime(end-5:end); % Switch to nem time zone
            file = fullfile(fold, [char(start_time, 'yyyyMMdd_HHmmss') '.json']);
            filewrite(file, json)
            if err
                fprintf(2, 'Error: %s\n', json) % Print errors to screen
            end
        end

        function T = readForecastData(obj, span, rez, forecast_limit)
            % Read forecast data from files

            if nargin<4 || isempty(forecast_limit)
                forecast_limit = [];
            end

            % List all data files
            filt = fullfile(obj.datafold, 'data', sprintf('forecast_%s_%gmin', obj.state, rez), 'json', '*.json');
            all_files = dir(filt);
            assert(~isempty(all_files), 'No data files matching "%s"', filt)
            
            % Extract time from filename
            all_times = datetime(extractBetween({all_files.name}, 1, 13), 'InputFormat', 'yyyyMMdd_HHmm');

            T = [];
            for day = checkdate(span{1}) : checkdate(span{2})

                parquet = fullfile(obj.datafold, 'data', sprintf('forecast_%s_%gmin', obj.state, rez), [char(day, 'yyyyMMdd') '.parquet']);

                if isfile(parquet)
                    t = datetime(dir(parquet).date);
                    if t + days(2) > span{2} && t + minutes(4) < datetime
                        fprintf(' Deleteing %s\n', parquet)
                        delete(parquet)
                    end
                end

                if isfile(parquet)
                    t = parquetread(parquet);
                else
                    % Read files on time (approx)
                    files = all_files(all_times >= day - 1 & all_times <= day + 1.1);
                    files = fullfile({files.folder}, {files.name});
                    t = cellfun(@obj.readForecastFile, files, 'UniformOutput', false);
                    t = vertcat(t{:});

                    if ~isempty(t)
                        % Remove duplicates
                        t.forecast = max(t.forecast, duration(0, -rez, 0)); % Treat all historic data equaly
                        t = unique(t, 'rows');

                        % Filter data on time
                        day.TimeZone = t.start.TimeZone;
                        t = t(t.start >= day & t.start < day + 1, :);
                        parquetwrite(parquet, t); % Save cache
                    end
                end
                T = [T; t];
            end

            if isempty(T)
                return
            end
            
            T.forecast.Format = 'hh:mm';
            
            % Filter on time span
            time_zone = T.start.TimeZone;
            T = T(T.start >= checkdate(span{1}, time_zone) & T.start < checkdate(span{2}, time_zone), :);

            % Filter on forecast duration
            if ~isempty(forecast_limit)
                T = T(T.forecast < duration(forecast_limit, 0, 0), :);
            end

            T = sortrows(T, {'start' 'query' 'forecast'}); % Sort on time fields
        end

        function T = readForecastFile(~, file)
            % Convert JSON to a table
            
            % Read file
            data = fileread(file);

            % Check
            if isequal(data, '{"message": "Internal server error"}')
                movefile(file, [file '.error'])
                T = [];
                return
            end

            % Decode
            data = jsondecode(data);

            fields = {'type' 'startTime' 'perKwh' 'renewables' 'spotPerKwh' 'channelType' 'low' 'med' 'high'}; % Required fields
            C = repmat({nan}, numel(data), numel(fields)); % Initialize cell array
            for i = 1:numel(data)
                [tf, ind] = ismember(fields, fieldnames(data{i})); % Find required fields
                t = struct2cell(data{i});
                C(i, tf) = t(ind(tf)); % Copy required fields
                if isfield(data{i}, 'advancedPrice')
                    C(i, end-2:end) = struct2cell(data{i}.advancedPrice); % forecast data
                else
                    C(i, end-2:end) = repmat({data{i}.perKwh}, 1, 3);
                end
            end
            T = cell2table(C, 'VariableNames', fields);

            % Format startTime
            T.startTime = datetime(extractBetween(T.startTime, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
            T.startTime.TimeZone = data{1}.nemTime(end-5:end); % Use NEM timezone

            % Compute forecast period
            t = data{find(cellfun(@(x)x.type == "CurrentInterval", data), 1)}.startTime;
            current_time = datetime(extractBetween(t, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'TimeZone', 'UTC');
            T = addvars(T, T.startTime - current_time, 'After', 'startTime', 'NewVariableNames', 'forecast');
            T.forecast.Format = 'hh:mm';

            % Compute query time
            [~, f] = fileparts(file);
            t = datetime(f, 'InputFormat', 'yyyyMMdd_HHmm');
            offset = minutes(mod(minute(t) -  mod(minute(t), 5), 30)); % Round down to nearest 5 minutes
            T = addvars(T, T.startTime + offset, 'After', 'startTime', 'NewVariableNames', 'query');

            % Pivot data
            T = unstack(T, {'perKwh' 'low' 'med' 'high'}, 'channelType');

            % Rename
            vars = T.Properties.VariableNames;
            T = renamevars(T, vars, regexprep(vars, {'(.*)_(.*)' 'startTime' 'spotPerKwh' '_perKwh'}, {'$2_$1' 'start' 'spot_price' '_price'}));

            % Reorder
            vars = T.Properties.VariableNames;
            vars = sort(vars(contains(vars,'_')));
            T = movevars(T, vars, 'After', 'renewables');
        end

        function [err, msg] = geturl(obj, url)
            % Delay to avoid "Error: Too many requests"
            persistent time_of_last_download
            delay_between_downloads = 10; % (sec)
            if isempty(time_of_last_download)
                time_of_last_download = NaT;
            end
            pause(seconds(time_of_last_download + seconds(delay_between_downloads) - datetime)) 
            time_of_last_download = datetime;

            % Download
            cmd = sprintf('curl -sS -X GET "%s" -H "Authorization: Bearer %s"', url, obj.token); % curl download command
            fprintf(1, ' %s\n', cmd); % Display comman on screen
            [err, msg] = system(cmd); % Run command

            % Check for errors
            if ~err && numel(msg) > 2
                if msg(1) ~= '{' && numel(msg)<200
                    err = 1;
                elseif numel(msg)<1000
                    data = jsondecode(msg);
                    if isfield(data, 'message')
                        err = 1;
                        msg = data.message;
                    end
                end
            end
        end
    end
end

function day = checkdate(day, default_timezone)
% Ensure day is a date.
if isnumeric(day) && day<1000
    day = datetime + day; % day is an offset
elseif isnumeric(day)
    day = datetime(day, 'ConvertFrom', 'datenum'); % day is datenum
elseif ~isdatetime(day)
    day = datetime(day); % day is string
end
day = dateshift(day, 'start', 'day');
if nargin>1
    day.TimeZone = default_timezone;
end
end

function tf = isComplete(file)
fid = fopen(file, 'r');
fseek(fid, -100, 'eof'); % Read last 100 bytes in file
txt = fread(fid, Inf, '*char')';
tf = contains(txt, 'T23:55:00'); % File should end at start of next month
fclose(fid);
end

function tf = isOld(file, thresh)
fileDate = datetime(dir(file).date);
tf = fileDate + thresh < datetime('now');
end
