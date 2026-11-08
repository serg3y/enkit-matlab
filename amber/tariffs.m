function [buy_price, sell_price, supply] = tariffs(tariff, time, rrp_override)
% Returns electricity buy and sell prices for various providers at a
% given date, time, or time-of-day (inc GST). Data loaded from tariffs.json.
%   [buy_price, sell_price, supply] = tariffs(tariff, time, rrp_override)
%
% RRP Integration:
%   RRP (Regional Reference Price) is the live NEM wholesale spot price 
%   (e.g., SA1). This adjustment ONLY applies to wholesale/spot pass-through 
%   plans (e.g., Amber); standard retail plans ignore RRP and use static rates. 
%   When a wholesale source (rrp_source) is specified, the function dynamically 
%   fetches live AEMO or Amber spot prices and combines them with the base 
%   network and retail fees defined in tariffs.json.
%
% Example:
%   time = datetime('2025-07-02') + hours(0:0.5:23.5)
%   [buy_price, sell_price, supply] = tariffs('Origin JS', time)
%   plotsteps(gca, time, buy_price)
%
% Example:
%   tariffs('plot all')

%#ok<*NBRAK2>

% Load tariff database from JSON
jsonPath = fullfile(fileparts(mfilename('fullpath')), 'tariffs.json');
if ~isfile(jsonPath)
    jsonPath = 'tariffs.json'; % fallback to current directory
end

rawJson = jsondecode(fileread(jsonPath));
nTariffs = numel(rawJson);

% Preallocate cell arrays for table conversion
dateCell = cell(nTariffs, 1);
tariffCell = cell(nTariffs, 1);
supplyVec = nan(nTariffs, 1);
buy_tod_cell = cell(nTariffs, 1);
buy_fees_cell = cell(nTariffs, 1);
sell_tod_cell = cell(nTariffs, 1);
sell_fees_cell = cell(nTariffs, 1);
export_limit_vec = inf(nTariffs, 1);
rrp_buy_vec = nan(nTariffs, 1);
rrp_sell_vec = nan(nTariffs, 1);
rrp_source_cell = cell(nTariffs, 1);

for i = 1:nTariffs
    item = rawJson(i);
    dateCell{i} = item.effective_date;
    tariffCell{i} = item.name;

    if isfield(item, 'supply_charge') && ~isempty(item.supply_charge) && isnumeric(item.supply_charge)
        supplyVec(i) = item.supply_charge;
    end

    if isfield(item, 'buy') && ~isempty(item.buy)
        buy_tod_cell{i} = cellfun(@(x) x(1), {item.buy.hours});
        buy_fees_cell{i} = [item.buy.rate];
    else
        buy_tod_cell{i} = 0;
        buy_fees_cell{i} = 0;
    end

    if isfield(item, 'sell') && ~isempty(item.sell)
        sell_tod_cell{i} = cellfun(@(x) x(1), {item.sell.hours});
        sell_fees_cell{i} = [item.sell.rate];
    else
        sell_tod_cell{i} = 0;
        sell_fees_cell{i} = 0;
    end

    if isfield(item, 'export_limit') && isnumeric(item.export_limit)
        export_limit_vec(i) = item.export_limit;
    end
    if isfield(item, 'rrp_buy') && ~isempty(item.rrp_buy)
        rrp_buy_vec(i) = item.rrp_buy;
    end
    if isfield(item, 'rrp_sell') && ~isempty(item.rrp_sell)
        rrp_sell_vec(i) = item.rrp_sell;
    end
    if isfield(item, 'rrp_source') && ~isempty(item.rrp_source)
        rrp_source_cell{i} = item.rrp_source;
    else
        rrp_source_cell{i} = '';
    end
end

% Build MATLAB table matching original schema
T = table(datetime(dateCell, 'TimeZone', '+10'), ...
    string(tariffCell), ...
    supplyVec, ...
    buy_tod_cell, ...
    buy_fees_cell, ...
    sell_tod_cell, ...
    sell_fees_cell, ...
    export_limit_vec, ...
    rrp_buy_vec, ...
    rrp_sell_vec, ...
    string(rrp_source_cell), ...
    'VariableNames', {'date', 'tariff', 'supply', 'buy_tod', 'buy_fees', 'sell_tod', 'sell_fees', 'export_limit', 'rrp_buy', 'rrp_sell', 'rrp_source'});

% Exit if needed (No inputs)
if ~nargin
    buy_price = T;
    return
elseif nargin==1 && ischar(tariff) && tariff == "plot all"
    time = datetime('2026-07-02') + hours(0:0.5:23.5);
    tariffList = unique(T.tariff, 'stable')';
    clf, hold on
    for k = numel(tariffList):-1:1
        a(k) = subplot(ceil(numel(tariffList)/3),3,k); ylim([-15 65]), title(tariffList(k) + " 2026")
        hold on, grid on
        [buy_price, ~, ~] = tariffs(tariffList(k), time);
        plotstepspread(gca, time, buy_price, [], 'r')
    end
    linkaxes(a,'xy')
    return
elseif nargin==1
    buy_price = T(strcmpi(T.tariff, tariff), :);
    return
end

% Select target tariff
T = T(strcmpi(T.tariff, tariff), :);
if isempty(T)
    error('Invalid tariff selection: %s', tariff)
end

n = numel(time);
buy_price = nan(n, 1);
sell_price = nan(n, 1);
supply = nan(n, 1);

% Handle Duration inputs (Time of Day evaluation)
if isduration(time)
    tod = time(:);
    T_row = T(1, :); % Use first matching effective tariff
    
    ii = discretize(tod, hours([T_row.buy_tod{1} 24]));
    ii(isnan(ii)) = numel(T_row.buy_tod{1});
    buy_price = T_row.buy_fees{1}(ii);

    ii = discretize(tod, hours([T_row.sell_tod{1} 24]));
    ii(isnan(ii)) = numel(T_row.sell_tod{1});
    sell_price = T_row.sell_fees{1}(ii);
    
    supply(:) = 0;

    if nargin >= 3 && ~isempty(rrp_override)
        rrp = rrp_override(:);
        if numel(rrp) == n
            buy_price = buy_price + rrp .* T_row.rrp_buy;
            sell_price = sell_price - rrp .* T_row.rrp_sell;
        end
    end
    return;
end

% Handle Datetime inputs
time = datetime(time, 'TimeZone', 'Australia/Adelaide');
step = days(mode(diff(time)));

tariff_ind = discretize(time, [T.date; T.date(end) + years(100)]);
tariff_ind_list = reshape(unique(rmmissing(tariff_ind)), 1, []);

for k = tariff_ind_list
    idx = (tariff_ind == k);
    tod = timeofdaylocal(time(idx));

    ii = discretize(tod, hours([T.buy_tod{k} 24]));
    ii(isnan(ii)) = numel(T.buy_tod{k});
    buy_price(idx) = T.buy_fees{k}(ii);

    ii = discretize(tod, hours([T.sell_tod{k} 24]));
    ii(isnan(ii)) = numel(T.sell_tod{k});
    sell_price(idx) = T.sell_fees{k}(ii);

    supply(idx) = T.supply(k) * step;
end

% Wholesale tariffs integration (Override or fetched)
if nargin >= 3 && ~isempty(rrp_override)
    rrp = rrp_override(:);
    if numel(rrp) == n
        valid = tariff_ind > 0;
        buy_press_mask = valid;
        buy_price(buy_press_mask) = buy_price(buy_press_mask) + rrp(buy_press_mask) .* T.rrp_buy(tariff_ind(buy_press_mask));
        sell_price(buy_press_mask) = sell_price(buy_press_mask) - rrp(buy_press_mask) .* T.rrp_sell(tariff_ind(buy_press_mask));
    end
else
    switch lower(T.rrp_source{1})
        case '' % do not add wholesale prices
        case {'nsw' 'qld' 'sa' 'tas' 'vic'}
            T2 = aemo().getPrice(T.rrp_source{1}, [min(time) max(time) + minutes(5)]);
            if isa(T2, 'timetable')
                t2_time = T2.Properties.RowTimes;
            else
                varNames = T2.Properties.VariableNames;
                matchingIdx = find(contains(lower(varNames), {'time', 'date', 'settlement'}));
                t2_time = T2{:, matchingIdx(1)};
            end
            [~, ind] = ismember(time, t2_time);
            rrp = nan(n, 1);
            valid = ind > 0;
            rrp(valid) = T2.price_ckwh(ind(valid));
            buy_price(tariff_ind>0) = buy_price(tariff_ind>0) + rrp(tariff_ind>0) .* T.rrp_buy(tariff_ind(tariff_ind>0));
            sell_price(tariff_ind>0) = sell_price(tariff_ind>0) - rrp(tariff_ind>0) .* T.rrp_sell(tariff_ind(tariff_ind>0));
        case 'amber'
            T2 = amber().getPrices([min(time) max(time)]);
            buy_price = nan(n, 1);
            sell_price = nan(n, 1);
            if isempty(T2), return, end
            [~, ind] = ismember(time, T2.time);
            valid = ind > 0;
            buy_price(valid) = T2.buy_price(ind(valid));
            sell_price(valid) = -T2.sell_price(ind(valid));
    end
end
end