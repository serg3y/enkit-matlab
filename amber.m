% Amber API cannot handly partial days. This wrapper does same.

% Remarks:
% "usage" is not available for current data and possibly last day
% "prices" includes forecasts when time span includes future periods

% aims:
% 1. show saving relative to agl
% 2. show historic power usage and cost
% 3. show current usage and cost

% SA Power Network Dashbaord
% https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard

classdef amber

    properties
        token
        siteId
        state
        nmi
        activeFrom
        datafold = fullfile(fileparts(mfilename('fullpath')), 'amber')
    end

    methods

        function obj = amber(varargin)

            % ini settings
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

            % User settings
            for k = 1:2:nargin
                obj.(varargin{k}) = varargin{k + 1};
            end

            % Download siteId, if needed
            if isempty(obj.siteId)
                site = obj.getSites;
                disp(site)
                disp(site.channels)
                obj.siteId = site.id;
                fprintf(2, 'To skip this step in the future assign the "siteId" property in your "amber.ini" settings file to be the "id" value above.\n')
                pause(1)
            end


            % obj.downloadForecastPeriodicaly(5)
            % obj.getSites;
            % obj.getData('prices', {'2024-11-01' 0}, 5);
            % obj.getData('usage', {'2024-12-23' -1}, 30);
            
            return

            % return
            % Examples
            obj.plotPrice(18, {'2025-01-01' '2025-03-20'}, "sapn_andrew", ["buy_amount" "buy_amount" "tariff_amount" "tariff_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" "" "heatmap" ""])
            obj.plotPrice(17, {'2025-01-01' '2025-03-20'}, "sapn_serge", ["buy_amount" "buy_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" ""])
            return
            obj.plotPrice(16, {'2025-01-01' '2025-03-20'}, "sapn_andrew", ["buy_amount" "buy_amount" "sell_amount" "sell_amount"], ["heatmap" "" "heatmap" ""])
            % return
            obj.plotPrice(15, {'2025-01-01' '2025-03-20'}, "amber_nmi", ["buy_price" "buy_amount" "buy_price_diff" "buy_saving" "buy_saving"], ["heatmap" "heatmap" "heatmap" "heatmap" ""])
            % return
            obj.plotPrice(14, {'2025-01-01' '2025-03-20'}, ["buy_price"], ["heatmap" ])            
            % obj.plotPrice(13, {'2025-01-01' '2025-03-20'}, "net_saving", "heatmap")
            obj.plotPrice(12, {'2025-01-01' '2025-03-20'}, ["buy_saving" "sell_saving"], "heatmap")
            obj.plotPrice(11, {'2025-01-01' '2025-03-01'}, ["buy_amount" "sell_amount"], "heatmap")
            obj.plotPrice(10, {'2025-01-01' '2025-03-01'}, ["buy_price" "sell_price"], "heatmap")
            obj.plotPrice(9, {'2025-01-01' '2025-03-01'}, ["buy_price_diff" "sell_price_diff"], "heatmap")
            obj.plotPrice(8, {'2025-01-01' -1}, ["buy_price" "sell_price"], "24hr")
            obj.plotPrice(7, {'2025-01-01' -1}, ["buy_price" "sell_price"], "24hr")
            obj.plotPrice(6, {'2025-01-01' -1}, ["buy_price_diff" "sell_price_diff"], "24hr")
            obj.plotPrice(5, {'2025-01-01' '2025-01-10'}, ["buy_price_diff" "sell_price_diff"])
            obj.plotPrice(4, {'2025-01-01' '2025-01-01'}, ["buy_price_diff" "sell_price_diff"])
            obj.plotPrice(3, {'2025-01-01' '2025-01-01'}, ["buy_price" "sell_price"], "agl")
            obj.plotPrice(2, {'2025-01-01' '2025-01-01'}, ["buy_price" "sell_price"], ["36" "6" "18"])
            obj.plotPrice(1, {'2025-01-01' '2025-01-01'}, "buy_price&sell_price", "5min")
        end

        function plotPrice(obj, fig, span, source, type, mode)
            if nargin < 5 || isempty(mode)
                mode = "";
            end
            if ~isscalar(type) && isscalar(mode)
                mode = repmat(mode, size(type));
            end
            
            switch source
                case 'sapn_andrew'
                    T = nem12read('sapn\andrew');
                case 'sapn_serge'
                    T = nem12read('sapn\serge');
                case 'amber_prices_30min'
                    T = obj.getData('prices', span, 30);
                case 'amber_prices_5min'
                    T = obj.getData('prices', span, 5);
                case 'amber_usage_30min'
                    T = obj.getData('usage', span, 30);
                case 'amber_usage_5min'
                    T = obj.getData('usage', span, 5);
                otherwise
                    error('Unknown source: %s\n',source)
            end

            % Prepare figure
            figure(fig), clf
            set(fig, 'WindowStyle', 'docked', 'Color', 'k', 'NumberTitle', 'off', 'Name', num2str(fig))
            plot_y = linspace(0.03, 0.97, numel(type) + 1); % Plot heights

            % Plot one axis at a time
            A = []; % Init handles list
            for k = 1:numel(type)
                
                % Setup axis
                a = axes('Position', [0.08 plot_y(end-k) 0.84 plot_y(end-k+1) - plot_y(end-k)], ...
                    'Color', 'k', 'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6], 'GridColor', [0.6 0.6 0.6]);
                hold on, grid on, box on, axis tight
                switch k
                    case 1, set(a, 'XAxisLocation', 'top')
                    case numel(type), set(a, 'XAxisLocation', 'bottom')
                    otherwise, a.XRuler.FontSize = 0.01; % no axis
                end
                
                X = T.start;
                switch type(k)

                    case {'buy_amount' 'sell_amount'  'tariff_amount'}
                        ylabel(regexprep([source; type(k)], {'_' 'amount'}, {' ' '(kwh)'}))
                        X = T.start;
                        Y = T.(type(k));
                        [c, cmap, cstr] = col(type(k));
                        switch mode(k)
                            case "heatmap"
                                plotHeatmap(a, X, Y, cmap)
                            case ""
                                d = dateshift(X, 'start', 'day');
                                y = accumarray(findgroups(d), Y, [], @sum);
                                t = sprintf([cstr '%.2fkwh\n'], sum(y));
                                plotLine(a, unique(d), y, c, 'DisplayName', t)
                                legend show
                        end

                    case {'buy_price' 'sell_price' 'tariff_price'}
                        ylabel(regexprep(type(k), {'_' 'amount'}, {' ' '(kwh)'}))
                        Y = T.(type(k));
                        c = col(type(k));
                        switch mode(k)
                            case "agl"
                                plotSpread(a, X, Y, X, agl(X, type(k)), c)
                                plotLine(a, X, Y, c)
                            case "5min"
                                plotSpread(a, X, Y, T2.start, T2.(type(k)), c)
                                plotLine(a, X, Y, c)
                            case "24hr"
                                X = timeofday(X);
                                plotLine(a, X, Y, [c 0.2], 'linewidth', 0.5)
                                Y = arrayfun(@(x) mean(Y(X == x)), unique(X));
                                X = unique(X);
                                plotLine(a, X, Y, c)
                            case "heatmap"
                                if type(k) == "sell_price"
                                    cmap = rbg;
                                else
                                    cmap = flipud(rbg);
                                end
                                plotHeatmap(a, X, Y, cmap)
                            otherwise
                                plotSpread(a, X, Y, X, Y*0 + str2double(mode(k)), c)
                                plotLine(a, X, Y, c)
                        end

                    case 'buy_saving'
                        ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
                        T = obj.getData('prices', span, 30);
                        T2 = obj.getData('usage', span, 30);
                        X = T.start;
                        switch mode(k)
                            case ""
                                Y = agl(X, 'buy_price') .* T2.buy_amount;
                                d = dateshift(X, 'start', 'day');
                                y1 = accumarray(findgroups(d), Y, [], @sum)/100 + agl([], 'supply');
                                t = sprintf('\\color[rgb]{1 .2 .2}AGL = $%.2f\n', sum(y1) );
                                plotLine(a, unique(d), y1, [1 .2 .2], 'DisplayName', t)

                                Y = T.buy_price .* T2.buy_amount;
                                d = dateshift(X, 'start', 'day');
                                y = accumarray(findgroups(d), Y, [], @sum)/100 + amb([], 'supply');
                                t = sprintf('\\color[rgb]{.4 .4 1}Amber = $%.2f\n', sum(y) );
                                plotLine(a, unique(d), y, [0.2 .2 1], 'DisplayName', t)

                                y3 = y-y1;
                                t = sprintf('\\color[rgb]{.2 1 .2}Saving = $%.2f', sum(y3));
                                plotLine(a, unique(d), y3, [.2 1 .2], 'DisplayName', t)

                                legend show

                            case "heatmap"
                                Y = (T.buy_price - agl(X, 'buy_price')) .* T2.buy_amount;
                                plotHeatmap(a, X, Y, flipud(rbg))
                        end
                        
                    case 'sell_saving'
                        ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
                        T = obj.getData('prices', span, 30);
                        T2 = obj.getData('usage', span, 30);
                        X = T.start;
                        % Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
                        Y = (T.sell_price ) .* T2.sell_amount;
                        cmap = rbg;
                        plotHeatmap(a, X, Y, cmap)

                    case 'net_saving'
                        ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
                        T = obj.getData('prices', span, 30);
                        T2 = obj.getData('usage', span, 30);
                        X = T.start;
                        Y = (T.sell_price - agl(X,'sell')) .* T2.sell_amount;
                        cmap = rbg;
                        plotHeatmap(a, X, Y, cmap)

                    case 'buy_price&sell_price'
                        ylabel 'buy / sell'
                        plotLine(a, X, T.buy_price, 'r')
                        plotLine(a, X, T.sell_price, 'b')
                        if mode(k) == "5min"
                            plotSpread(a, X, T.buy_price, T2.start, T2.buy_price, 'r')
                            plotSpread(a, X, T.sell_price, T2.start, T2.sell_price, 'b')
                        end

                    case {'buy_price_diff' 'sell_price_diff'}
                        ylabel(regexprep(type(k), {'_' 'amount'}, {' ' 'kwh'}))
                        m = strrep(type(k), '_diff', '');
                        Y = T.(m) - agl(X, m);
                        c = col(m);
                        switch mode(k)
                            case '24hr'
                                X = timeofday(X);
                                plotLine(a, X, Y, [c 0.2], 'linewidth', 0.5)
                                X2 = unique(X);
                                Y2 = arrayfun(@(x) mean(Y(X == x)), X2);
                                plotLine(a, X2, Y2, c, 'linewidth', 2)
                            case "heatmap"
                                if type(k) == "sell_price"
                                    cmap = rbg;
                                else
                                    cmap = flipud(rbg);
                                end
                                plotHeatmap(a, X, Y, cmap)
                            otherwise
                                plotLine(a, X, Y, c)
                        end

                    case 'renewables'
                        ylabel 'Renewables (%)'
                        plotLine(a, X, T.renewables, [0 0.5 0])
                        yline(a, 100, 'w--')
                        linkaxes([a a], 'x'), xlim([min(X) max(T.stop)])
                        if mode(k) == "5min"
                            plotSpread(a, X, T.renewables, T2.start, T2.renewables, [0 0.5 0])
                        end
                end
                if mode(k) ~= "heatmap"
                    yline(a, 0, 'w--', 'HandleVisibility', 'off')
                    ylim(a, ylim(a) + [-5 5])
                end
                A = [A a]; %#ok<AGROW>
            end

            ind = arrayfun(@(x)isdatetime(x.XLim), A);
            if any(ind)
                linkaxes(A(ind), 'x')
            end
            ind = arrayfun(@(x)isduration(x.YLim)&isduration(x.YLim), A);
            if any(ind)
                linkaxes(A(ind), 'xy')
            end
            if k == numel(type)
                file = sprintf('plots/%g.png', gcf().Number);
                figsave(gcf, file, [1920 1080])
            end

        end

        function T = plotPrediction(obj, span, rez)
            if nargin<3 || isempty(rez), rez = 30; end

            T = obj.getData('prices', span, rez);

            % Plot
            figure(1), clf
            ax(1) = subplot(3, 1, 1:2);

            hold on, grid on, ylabel 'Price (c)'
            plotLine(T.start, T.buy_price, 'r')
            plotLine(T.start, T.sell_price, 'b')

            % plotline(T2.start, T2.buy_price, ':b')


            % plotspread(T.start, T.buy_price, T.buy_low, T.buy_high, 'r')
            
            % x = [T.start T.stop]';
            % buy = [T.buy_price T.buy_price]';
            % buyL = [T.buy_low T.buy_low]';
            % buyH = [T.buy_high T.buy_high]';
            % sell = [T.sell_price T.sell_price]';
            % sellL = [T.sell_low T.sell_low]';
            % sellH = [T.sell_high T.sell_high]';
            % plotspread(x, buy, buyL, buyH, 'r')
            % plotspread(x, sell, sellL, sellH, 'b')
            % xline(datetime('now', 'TimeZone', 'UTC'), 'k')
            % yline(0, 'k')
            % xtickformat('dd HH:mm')
            % set(gca,'XAxisLocation','top')
            % ylim([min(sell(:)) max(buy(:))])
            % plot(x(:), buy(:)-sell(:), 'k:','LineWidth',1.5)
            % 
            ax(2) = subplot(3, 1, 3);
            hold on, grid on, ylabel 'Renewables (%)'
            plotLine(T.start, T.renewables, 'b')
            % y = [T.renewables T.renewables]';
            % plotspread(x(:), y(:), y(:)*0, y(:), 'g')
            % xtickformat('dd HH:mm')
            % xline(datetime('now', 'TimeZone', 'UTC'), 'k')
            yline([0 100], 'k')
            linkaxes(ax, 'x')
            xlim([min(T.start) max(T.start)])
        end

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

        function T = getData(obj, type, span, rez)
            % Read or download prices or usage data

            if nargin<3 || isempty(rez), rez = 30; end

            % Check span
            if ~isempty(obj.activeFrom)
                span{1} = max(checkdate(span{1}), checkdate(obj.activeFrom));
            end

            % Step through days
            T = []; % Large table to hold all data
            for day = checkdate(span{1}) : checkdate(span{end})

                % Set output file path (no extension)
                switch type
                    case 'usage',  file = fullfile(obj.datafold, sprintf('%s_%s_%gmin', obj.nmi,   type, rez), char(day, 'yyyyMMdd'));
                    case 'prices', file = fullfile(obj.datafold, sprintf('%s_%s_%gmin', obj.state, type, rez), char(day, 'yyyyMMdd'));
                end
                [~, ~] = mkdir(fileparts(file));

                % Check if cached files exist
                json_file = dir([file '.json']);
                parquet_file = dir([file '.parquet']);

                % Check if cached file is stale
                if ~isempty(json_file) && ...                            % if JSON file exists, but ...
                        datetime(json_file.date) < day + 1 + 1/24 && ... % file was saved near day's end, and ...
                        datetime(json_file.date) + 0.5/24 < datetime     % file is more then 30 min old, then
                    delete(fullfile(json_file.folder, json_file.name))   % delete the file, as it may be stale
                    json_file = [];
                    if ~isempty(parquet_file)
                        delete(fullfile(parquet_file.folder, parquet_file.name))
                        parquet_file = [];
                    end
                end
                
                if ~isempty(parquet_file)
                    % Load cached parquet
                    t = parquetread([file '.parquet']);

                else
                    % Load cached json
                    if ~isempty(json_file)
                        json = fileread([file '.json']);

                    else
                        % Download
                        url_span = sprintf('startDate=%s&endDate=%s', char(day, 'yyyy-MM-dd'), char(day, 'yyyy-MM-dd')); % Time span component
                        url = ['https://api.amber.com.au/v1/sites/' obj.siteId '/' type '?' url_span '&resolution=' num2str(rez)]; % REST URL query
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
                    parquetwrite([file '.parquet'], t); % Save as parquete file

                end
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
                    T = T(:, {'startTime' 'duration' 'perKwh' 'renewables' 'channelType'});

                    % Use positive values for feedin
                    T.perKwh(T.channelType=="feedIn") = -T.perKwh(T.channelType=="feedIn");

                    % Convert channelType from rows to columns
                    T = unstack(T, 'perKwh', 'channelType');

                    % Improve column names
                    T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'general' 'feedIn'  'controlledLoad'  'Time'}, {'buy_price' 'sell_price' 'tariff_price' ''});

                    % Re-order columns
                    T = movevars(T, {'buy_price' 'sell_price' 'tariff_price' 'renewables'}, 'After', 'duration');

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
                    T.Properties.VariableNames = regexprep(T.Properties.VariableNames, {'(.*)_(.*)' 'general' 'feedIn' 'controlledLoad' '_perKwh' 'kwh' 'Time'}, {'$2_$1' 'buy' 'sell' 'tariff' '_price' 'amount' ''});

                    % Re-order columns
                    T = movevars(T, {'buy_amount' 'buy_price' 'sell_amount' 'sell_price' 'tariff_amount' 'tariff_price'}, 'After', 'duration');
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
                obj.downloadForecastOnce([48 48], 30); % Download 24 hr @ 30 min
                obj.downloadForecastOnce([12 12],  5); % Download 1 hr @ 5 min (optional)
            end
        end

        function downloadForecastOnce(obj, span, rez)
            % Download current price forecast, once.
            %   amber().downloadForecastOnce(span, rez)
            % - File name is nem time at start of download.
            % - Prints local time to screen.
            fold = fullfile(obj.datafold, sprintf('%s_%s_%gmin', obj.state, 'forecast', rez), 'raw');
            if ~isfolder(fold)
                mkdir(fold);
            end
            start_time = datetime('now', 'TimeZone', 'local'); % Download start time (local)
            [err, json] = obj.geturl(sprintf('https://api.amber.com.au/v1/sites/%s/prices/current?previous=%g&next=%g&resolution=%g', obj.siteId, span, rez)); % Download
            d = jsondecode(json);
            start_time.TimeZone = d{1}.nemTime(end-5:end); % Switch to nem time zone
            filewrite(fullfile(fold, [char(start_time, 'yyyyMMdd_HHmmss') '.json']), json)
            if err
                fprintf(2, 'Error: %s\n', json) % Print errors to screen
            end
        end

        function T = getForecastData(obj, span, rez, forecast_limit)
            % Read forecast data from files

            if nargin<4 || isempty(forecast_limit)
                forecast_limit = [];
            end

            all_files = dir(fullfile(obj.datafold, sprintf('%s_forecast_%gmin', obj.state, rez), 'raw', '*.json'));
            all_times = datetime(extractBetween({all_files.name}, 1, 15), 'InputFormat', 'yyyyMMdd_HHmmss');

            T = [];
            for day = checkdate(span{1}) : checkdate(span{2})

                parquet = fullfile(obj.datafold, sprintf('%s_forecast_%gmin', obj.state, rez), [char(day, 'yyyyMMdd') '.parquet']);
                if isfile(parquet)
                    t = parquetread(parquet);
                else
                    % Read files on time (approx)
                    files = all_files(all_times >= day - 1 & all_times <= day + 1.1);
                    files = fullfile({files.folder}, {files.name});
                    t = cellfun(@obj.readForecastFile, files, 'UniformOutput', false);
                    t = vertcat(t{:});

                    % Remove duplicates
                    if ~isempty(t)
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
            T.forecast.Format = 'hh:mm';
            
            if ~isempty(forecast_limit)
                T = T(T.forecast < duration(forecast_limit, 0, 0), :);
            end
        end

        function T = readForecastFile(~, file)
            % Read forecast JSON file and output a table
            data = jsondecode(fileread(file));

            % Extract required fields and make a table
            C = repmat({nan}, numel(data), 3); % cell array is faster then table
            for k = 1:numel(data)
                C(k, 1:2) = {data{k}.startTime data{k}.channelType};
                if data{k}.type == "ActualInterval"
                    C{k, 3} = data{k}.perKwh;
                elseif isfield(data{k}, 'advancedPrice')
                    C{k, 3} = data{k}.advancedPrice.predicted;
                end
            end
            T = cell2table(C, 'VariableNames', {'start' 'channelType' 'price'}); % Convert cell array to table

            % Format time
            T.start = datetime(extractBetween(T.start, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'Format', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
            T.start.TimeZone = data{1}.nemTime(end-5:end); % Use NEM timezone

            % Compute forecast period
            t = data{find(cellfun(@(x)x.type == "CurrentInterval", data), 1)}.startTime;
            current_time = datetime(extractBetween(t, 1, 16), 'InputFormat', 'yyyy-MM-dd''T''HH:mm', 'TimeZone', 'UTC');
            T = addvars(T, T.start - current_time, 'After', 'start', 'NewVariableNames', 'forecast');
            T.forecast.Format = 'hh:mm';

            % Compute query time
            [~, f] = fileparts(file);
            t = datetime(f, 'InputFormat', 'yyyyMMdd_HHmmss');
            offset = minutes(mod(minute(t) -  mod(minute(t), 5), 30)); % Round down to nearest 5 minutes
            T = addvars(T, T.start + offset, 'After', 'start', 'NewVariableNames', 'query');

            % Pivot data
            T.channelType = regexprep(T.channelType, {'general' 'feedIn' 'controlledLoad'}, {'buy_price' 'sell_price' 'tariff_price'}); % Rename terms
            T = unstack(T, 'price', 'channelType');

            % Flip sell sign
            T.sell_price = -T.sell_price;
        end

        function data = prices_current(obj)
            data = obj.geturl('https://api.amber.com.au/v1/sites/01J23BAP2SFA218BMV8A73Y9Z9/prices/current?next=48&previous=48');
        end

        function data = usage(obj)
            data = obj.geturl('https://api.amber.com.au/v1/sites/01J23BAP2SFA218BMV8A73Y9Z9/usage?startDate=2025-01-01&endDate=2025-01-01');
        end

        function [err, msg] = geturl(obj, url)

            % Delay to avoid friquent downloads
            persistent time_of_last_download
            delay_between_downloads = 5; % (sec)
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

function plotLine(ax, x, y, color, varargin)
% Plot a line
[X, Y] = makeSteps(x, y);
if isduration(x)
    ind = find(diff(X(:))<0);
    [i, j] = sort([1:numel(X) ind']);
    X = X(i);
    Y = Y(i);
    X(diff(j)<0) = NaN;
    Y(diff(j)<0) = NaN;
end
plot(ax, X(:), Y(:), 'color', color, 'LineWidth', 1, varargin{:})
end

% function plotHeatmap(ax, x, y, cmap, tod_step)
% 
% % Defaults
% if nargin<5 || isempty(step), tod_step = minutes(mode(diff(x))); end
% 
% % Get time of day and date
% tod = timeofday(x); % Time of day > Y
% day = x - tod; % Date > X
% 
% % Form an array - time vs data
% tod_edges = duration(0, 0:tod_step:24*60, 0, 0);
% day_edges = min(day):max(day)+1;
% [~, ~, tod_i] = histcounts(tod, tod_edges); % Bin based on time
% [~, ~, day_i] = histcounts(day, day_edges); % Bin based on day
% A = accumarray([tod_i day_i], y);
% 
% % Display heat map
% h = imagesc(ax, day_edges([1 end-1])+0.5, tod_edges([1 end-1]) + tod_step/2/24/60 , A);
% colormap(ax, cmap)
% clim([-1 1]*min(max(A(:)), 160))
% p = ax.Position;
% hc = colorbar;
% set(hc, 'color', [0.6 0.6 0.6]);
% ax.Position = p; % Display colorbar, don't move plot
% set(hc, 'Position', hc.Position.*[1 1 0.6 1]-[0.01 0 0 0]);
% xline(xlim, 'w'), yline(ylim, 'w') % Draw a box around the plot
% ax.YAxis.TickLabelFormat = 'hh:mm';
% 
% % Set the custom data cursor callback function
% dcm = datacursormode(gcf);
% h.UserData = struct('A', A, 'tod_edges', tod_edges, 'day_edges', day_edges, 'ax', ax); % Store the data in the axis UserData
% set(dcm, 'UpdateFcn', @dataTip);
% end

% function txt = dataTip(~, event)
% % Custom data cursor function
% h = event.Target; % Get axis that triggered the event
% ud = h.UserData;  % Retrieve the UserData struct
% 
% if isempty(ud)
%     txt = ''; return
% end
% 
% % Get the datetime positions based on the cursor position
% [~, ~, day_i] = histcounts(num2ruler(event.Position(1), ud.ax.XAxis), ud.day_edges);
% [~, ~, tod_i] = histcounts(num2ruler(event.Position(2), ud.ax.YAxis), ud.tod_edges);
% 
% % Format the data tip text
% txt = sprintf('Value: %.2f\nTime: %s\nDay: %s', ud.A(tod_i, day_i), ...
%     char(ud.tod_edges(tod_i)), char(ud.day_edges(day_i)));
% end

function plotSpread(ax, x, y, x2, y2, color)
% Plots a region about x,y defined by x2,y2.
x = x + seconds(0.01); % HACK to fix patch
[X, Y] = makeSteps(x, y); % Makes into teps
[X2, Y2] = makeSteps(x2, y2);
XX = [X(:); flipud(X2(:))]; % Ford and then reverse
YY = [Y(:); flipud(Y2(:))];
patch(ax, XX, YY, color, 'FaceAlpha', 0.3, 'EdgeColor', color, 'EdgeAlpha', 0.2);
end

function [X, Y] = makeSteps(x, y)
% Given x,y at start of intervals, create X,Y for the intervals
dx = diff(x);
if isduration(x)
    dx = mod(dx, 1); % wrap -23:30 to 00:30
end
x2 = x + dx([1:end end]);
X = [x x2]';
Y = [y y]';
end

function y = agl(x, f)
if isdatetime(x)
    x = timeofday(x);
end
switch f
    case 'buy_price'
        prices = {'00:00' 47.41; '01:00' 34.94; '06:00' 47.41; '10:00' 31.78; '15:00' 47.41; '24:00' NaN};
        ind = discretize(x, duration(prices(:, 1), 'InputFormat', 'hh:mm'));
        y = cat(1, prices{ind, 2});
    case 'sell_price'
        y = zeros(size(x)) + 6;
    case 'tariff_price'
        y = nan(size(x));
    case 'supply'
        y = 1.0356;
end
end

function y = amb(~, f)
switch f
    case 'supply'
        y = 0.99 + 0.6576;
end
end

function [c, cmap, cstr] = col(str)
str = char(str);
switch str(1:3)
    case 'buy', c = [1.0 0.3 0.3]; cmap = flipud(rbg);
    case 'sel', c = [0.3 1.0 0.3]; cmap = rbg;
    case 'tar', c = [1.0 0.3 1.0]; cmap = flipud(rbg);
end
cstr = sprintf('\\\\color[rgb]{%g %g %g}', c);
end

function mybar3
clf, hold on
nx = 30;
ny = 50;
A = rand(ny, nx);
B = kron(A, [1 1;1 1]);
B = padarray(B, [1 1]);
x = kron(0:nx, [1 1]);
y = kron(0:ny, [1 1]);
surf(x, y, B, B, 'FaceColor', 'interp', 'EdgeAlpha', 0.1, 'HitTest', 0)
% imagesc(x, y, A)
colorbar, colormap(jet)
view(0, 90)
end
