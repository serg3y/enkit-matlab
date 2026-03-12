%% Inputs
scenario_name = 'Andrew';
output_fold = fullfile('C:\MATLAB\enkit\simbattery', scenario_name);

switch scenario_name
    case 'Andrew'
        usage_data_fold = 'C:\MATLAB\enkit\meter\data\Andrew';
        analysis_period = ["2024-03-30" "2025-03-29"]; tariff_list = "Origin JS";
        
        analysis_period = ["2024-07-01" "2025-03-29"]; tariff_list = ["Amber RTOU+amber" "Amber RTOU+sa"]
        battery_capacities = [0:5 7:2:10 15:5:40];
        apply_curtailment = true;
    case 'Jenka'
        % Daily import|export = 7.87|24.07 kWh
        usage_data_fold = 'C:\MATLAB\enkit\meter\data\Gene';
        analysis_period = ["2024-09-13" "2025-09-13"];
        battery_capacities = [0:0.1:2 3:10 12:2:30];
        apply_curtailment = true;
        tariff_list = "Origin JS";
    case 'Jason'
        % Daily import|export = 7.87|24.07 kWh
        usage_data_fold = 'C:\MATLAB\enkit\meter\data\Gene';
        analysis_period = ["2025-09-13" "2026-01-01"];
        battery_capacities = [0 5 10 15 20 25 30];
        apply_curtailment = true;
        tariff_list = "Amber RTOU+sa";
end

%% Load usage data
T = nem().read(usage_data_fold, analysis_period);
[T.tod, T.date] = timeofdaylocal(T.time);
rez = 5/60;

% Add import/export columns (kW -> kWh per timestep)
T.import_kwh = T.import_kw * rez;
T.export_kwh = -T.export_kw * rez;  % export_kw is negative by convention
if hascolumn(T, 'cl_kw')
    T.import_kwh = T.import_kwh + T.cl_kw * rez;
    T.cl_kw = [];
end

% Fill data holes with zero (treat missing intervals as no activity)
T.import_kwh(isnan(T.import_kwh)) = 0;
T.export_kwh(isnan(T.export_kwh)) = 0;

%% Simulate
sim_net_cost = nan(numel(battery_capacities), numel(tariff_list));

for tariff_idx = 1 : numel(tariff_list)

    % Get price
    [T.import_price, T.export_price, T.supply_charge] = tariffs(tariff_list(tariff_idx), T.time);
    T.supply_charge = T.supply_charge ./ 100;

    % Fill missing prices (treat unknown intervals as zero cost)
    T.import_price(isnan(T.import_price)) = 0;
    T.export_price(isnan(T.export_price)) = 0;

    % Curtailemnt
    if apply_curtailment
        T.export_price = max(T.export_price, 0); % HACK, should block export rather then clipping price
    end

    % Loop over battery capacities
    for capacity_idx = 1 : numel(battery_capacities)
        [T.soc_kwh, T.discharged_kwh, T.charged_kwh, T.sim_import_kwh, T.sim_export_kwh] = simbattery(T.time, T.import_kwh, T.export_kwh, battery_capacities(capacity_idx));
        T.import_cost = T.import_kwh .* T.import_price / 100;
        T.export_revenue = T.export_kwh .* T.export_price / 100;
        T.sim_import_cost = T.sim_import_kwh .* T.import_price / 100;
        T.sim_export_revenue = T.sim_export_kwh .* T.export_price / 100;

        % Results
        num_days = ceil(days(range(T.time)));
        sim_net_cost(capacity_idx, tariff_idx) = (sum(T.sim_import_cost, 'omitnan') + sum(T.supply_charge, 'omitnan') - sum(T.sim_export_revenue, 'omitnan')) / num_days * 365;
        fprintf('%g %.1f\n', battery_capacities(capacity_idx), sim_net_cost(capacity_idx));

        % Detailed Plots
        % detailedplot(-1, T, '')
        % detailedplot(-2, T, 'date')
        detailedplot(-3, T, 'tod')
    end

end

% return

%% Plots results
figmode(-4, 'dark')
subplot(2,1,1)
for tariff_idx = 1 : numel(tariff_list)
    if numel(battery_capacities)>1
        plot(battery_capacities, sim_net_cost(:, tariff_idx), 'LineWidth', 1.5, 'DisplayName', tariff_list(tariff_idx))
    end
end
xlabel 'Battery Capacity (kWh)', ylabel 'Bill ($/yr)', legend show
subplot(2,1,2)
for tariff_idx = 1 : numel(tariff_list)
    if numel(battery_capacities)>1
        plot(battery_capacities, sim_net_cost(1, tariff_idx) - sim_net_cost(:, tariff_idx), 'LineWidth', 1.5, 'DisplayName', tariff_list(tariff_idx))
    end
end
xlabel 'Battery Capacity (kWh)', ylabel 'Saving ($/yr)', legend show
figsave(gcf, [output_fold '.png'], [600 400])


%%
function detailedplot(h, T, mode)

% Average
if mode
    T2 = groupsummary(T, mode, @sum, ["import_kwh" "export_kwh" "supply_charge" "discharged_kwh" "charged_kwh" "sim_import_kwh" "sim_export_kwh" "import_cost" "export_revenue" "sim_import_cost" "sim_export_revenue"]);
    T3 = groupsummary(T, mode, @mean, ["import_price" "export_price" "soc_kwh"]);
    T4 = groupsummary(T, mode, {@min @max}, "soc_kwh");
    T = [T2(:, [1 3:end]) T3(:, 3:end)];
    T.soc_kwh_min = T4.fun1_soc_kwh;
    T.soc_kwh_max = T4.fun2_soc_kwh;
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'fun1_', '');
    T.time = T.(mode);
end

figmode(h, 'dark')
args = {'EdgeAlpha', 0.8, 'FaceAlpha', 0.05};
margins = [0.06 0.04 0.02 0.04]; % L T R B
spacing = [0.08 0.01]; % W H

axis_stack(1, 4, 1, 2, margins, spacing, 'Initial Import and Export')
plotspread2(gca, T.time, T.import_kwh, [], 'r', sprintf('Imports %.0f kWh', sum(T.import_kwh)), args{:})
plotspread2(gca, T.time, T.export_kwh, [], 'g', sprintf('Exports %.0f kWh', sum(T.export_kwh)), args{:})
ylabel kWh
legend show location SE

axis_stack(2, 4, 1, 2, margins, spacing, 'Adjusted Import and Export')
plotspread2(gca, T.time, T.sim_import_kwh, [], 'r', sprintf('Imports %.0f kWh', sum(T.sim_import_kwh)), args{:})
plotspread2(gca, T.time, T.sim_export_kwh, [], 'g', sprintf('Exports %.0f kWh', sum(T.sim_export_kwh)), args{:})
ylabel kWh
legend show location SE

axis_stack(3, 4, 1, 2, margins, spacing, 'Battery Charge and Discharge')
plotspread2(gca, T.time, T.discharged_kwh, [], 'r', sprintf('Battery discharge %.0f kWh', sum(T.discharged_kwh)), args{:})
plotspread2(gca, T.time, T.charged_kwh,    [], 'g', sprintf('Battery charge %.0f kWh',    sum(T.charged_kwh)),    args{:})
ylabel kWh
legend show location SE

axis_stack(4, 4, 1, 2, margins, spacing, 'Battery State of Charge (SOC)')
plotspread2(gca, T.time, T.soc_kwh, [], 'g', sprintf('Avg SOC %.1f kWh', mean(T.soc_kwh)), args{:})
if hascolumn(T, 'soc_kwh_max')
    plotspread2(gca, T.time, T.soc_kwh_max, [], 'b', 'Max SOC', 'EdgeAlpha', 0.3, 'FaceAlpha', 0)
    plotspread2(gca, T.time, T.soc_kwh_min, [], 'r', 'Min SOC', 'EdgeAlpha', 0.3, 'FaceAlpha', 0)
end
ylim([0 max(ylim)*1.1 + 0.1])
ylabel kWh
legend show location SE

axis_stack(1, 3, 2, 2, margins, spacing, 'Electricity prices')
plotspread2(gca, T.time, T.import_price, [], 'r', sprintf('Avg Import price %.3g c/kWh', mean(T.import_price)), args{:})
plotspread2(gca, T.time, T.export_price, [], 'g', sprintf('Avg Export price %.3g c/kWh', mean(T.export_price)), args{:})
ylabel $
ylim([0 max(ylim)*1.1])
legend show location SE

axis_stack(2, 3, 2, 2, margins, spacing, sprintf('Initial Bill $%.0f', sum(T.import_cost) - sum(T.export_revenue)))
plotspread2(gca, T.time, T.import_cost,    [], 'r', sprintf('Import $%.0f', sum(T.import_cost)),    args{:})
plotspread2(gca, T.time, T.export_revenue, [], 'g', sprintf('Export $%.0f', sum(T.export_revenue)), args{:})
ylabel $
legend show location SE

axis_stack(3, 3, 2, 2, margins, spacing, sprintf('Adjusted Bill $%.0f', sum(T.sim_import_cost) - sum(T.sim_export_revenue)))
plotspread2(gca, T.time, T.sim_import_cost,    [], 'r', sprintf('Import $%.0f', sum(T.sim_import_cost)),    args{:})
plotspread2(gca, T.time, T.sim_export_revenue, [], 'g', sprintf('Export $%.0f', sum(T.sim_export_revenue)), args{:})
ylabel $
legend show location SE

linkallaxes
xlim([min(T.time) max(T.time)])

% figsave(gcf, [output ' ' num2str(capacity) ' ' mode '.png'], [1200 900])
end
