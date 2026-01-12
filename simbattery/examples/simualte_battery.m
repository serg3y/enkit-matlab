%% Inputs
scenario_name = 'Jenka';
output_fold = fullfile('D:\MATLAB\enkit\simbattery\examples', scenario_name);

switch scenario_name
    case 'Andrew'
        usage_data_fold = 'D:\MATLAB\enkit\meter\data\Andrew';
        analysis_period = ["2024-03-30" "2025-03-29"];
        tariff_list = 'JS';
        battery_capacities = 0:30;
        apply_curtailment = true;
    case 'Jenka'
        % Daily import|export = 7.87|24.07 kWh
        usage_data_fold = 'D:\MATLAB\enkit\meter\data\Jenka';
        analysis_period = ["2024-09-13" "2025-09-13"];
        tariff_list = ["JS" "amber rtou"];
        battery_capacities = [0:0.1:2 3:10 12:2:30];
        apply_curtailment = true;

        battery_capacities = 10
        tariff_list = ["amber rtou"];
        tariff_list = ["JS"];
end

%% Load usage data
T = nem().read(usage_data_fold, analysis_period);
[T.tod, T.date] = timeofdaylocal(T.time);

% Add import/export columns
T.import = T.import_kwh;
T.export = T.export_kwh;
if hascolumn(T, 'cl_kwh')
    T.import = T.import + T.cl_kwh;
end

%% Simulate
sim_net_cost = nan(numel(battery_capacities), numel(tariff_list));

for tariff_idx = 1 : numel(tariff_list)

    % Get price
    if startsWith(tariff_list, 'amber')
        [T.import_price, T.export_price, T.supply_charge] = tariffs(tariff_list(tariff_idx), T.time, 'sa');
    else
        [T.import_price, T.export_price, T.supply_charge] = tariffs(tariff_list(tariff_idx), T.time);
    end
    T.supply_charge = T.supply_charge ./ 100;

    % Curtailemnt
    if apply_curtailment
        T.export_price = max(T.export_price, 0); % HACK, should block export rather then clipping price
    end

    % Loop over battery capacities
    for capacity_idx = 1 : numel(battery_capacities)
        [T.soc, T.discharged, T.charged, T.sim_import, T.sim_export] = simbattery(T.time, T.import, T.export, battery_capacities(capacity_idx));
        T.import_cost = T.import .* T.import_price / 100;
        T.export_revenue = T.export .* T.export_price / 100;
        T.sim_import_cost = T.sim_import .* T.import_price / 100;
        T.sim_export_revenue = T.sim_export .* T.export_price / 100;

        % Results
        num_days = ceil(days(range(T.time)));
        sim_net_cost(capacity_idx, tariff_idx) = (sum(T.sim_import_cost) + sum(T.supply_charge) - sum(T.sim_export_revenue)) / num_days * 365;
        fprintf('%g %.1f\n', battery_capacities(capacity_idx), sim_net_cost(capacity_idx));

        % Detailed Plots
        % detailedplot(-1, T, '')
        % detailedplot(-2, T, 'date')
        detailedplot(-3, T, 'tod')
    end

end

% return

% Plots results
figmode(-4, 'dark', 'handy'), legend show
for tariff_idx = 1 : numel(tariff_list)
    if numel(battery_capacities)>1
        plot(battery_capacities, sim_net_cost(:, tariff_idx), 'LineWidth', 1.5, 'DisplayName', tariff_list(tariff_idx))
    end
end
xlabel 'Battery Capacity (kWh)', ylabel 'Cost ($/yr)'
figsave(gcf, [output_fold '.png'], [600 400])


%%
function detailedplot(h, T, mode)

% Average
if mode
    T2 = groupsummary(T, mode, @sum, ["import" "export" "supply_charge" "discharged" "charged" "sim_import" "sim_export" "import_cost" "export_revenue" "sim_import_cost" "sim_export_revenue"]);
    T3 = groupsummary(T, mode, @mean, ["import_price" "export_price" "soc"]);
    T4 = groupsummary(T, mode, {@min @max}, "soc");
    T = [T2(:, [1 3:end]) T3(:, 3:end)];
    T.soc_min = T4.fun1_soc;
    T.soc_max = T4.fun2_soc;
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'fun1_', '');
    T.time = T.(mode);
end

figmode(h, 'dark', 'handy')
args = {'EdgeAlpha', 0.8, 'FaceAlpha', 0.05};

axis_stack(1, 4, 1, 2, [], [-0.03 0.01], 'Initial Import and Export')
plotspread2(gca, T.time, T.import, [], 'r', sprintf('Imports %.0f kWh', sum(T.import)), args{:})
plotspread2(gca, T.time, T.export, [], 'g', sprintf('Exports %.0f kWh', sum(T.export)), args{:})
ylabel kWh
legend show

axis_stack(2, 4, 1, 2, [], [-0.03 0.01], 'Adjusted Import and Export')
plotspread2(gca, T.time, T.sim_import, [], 'r', sprintf('Imports %.0f kWh', sum(T.sim_import)), args{:})
plotspread2(gca, T.time, T.sim_export, [], 'g', sprintf('Exports %.0f kWh', sum(T.sim_export)), args{:})
ylabel kWh
legend show

axis_stack(3, 4, 1, 2, [], [-0.03 0.01], 'Battery Charge and Discharge')
plotspread2(gca, T.time, T.discharged, [], 'r', sprintf('Battery discharge %.0f kWh', sum(T.discharged)), args{:})
plotspread2(gca, T.time, T.charged,    [], 'g', sprintf('Battery charge %.0f kWh',    sum(T.charged)),    args{:})
ylabel kWh
legend show

axis_stack(4, 4, 1, 2, [], [-0.03 0.01], 'Battery State of Charge (SOC)')
plotspread2(gca, T.time, T.soc, [], 'g', sprintf('Avg SOC %.1f kWh', mean(T.soc)), args{:})
if hascolumn(T, 'soc_max')
    plotspread2(gca, T.time, T.soc_max, [], 'b', 'Max SOC', 'EdgeAlpha', 0.3, 'FaceAlpha', 0)
    plotspread2(gca, T.time, T.soc_min, [], 'r', 'Min SOC', 'EdgeAlpha', 0.3, 'FaceAlpha', 0)
end
ylim([0 max(ylim)*1.1])
ylabel kWh
legend show

axis_stack(1, 3, 2, 2, [], [-0.03 0.01], 'Electricity prices')
plotspread2(gca, T.time, T.import_price, [], 'r', sprintf('Avg Import price %.3g c/kWh', mean(T.import_price)), args{:})
plotspread2(gca, T.time, T.export_price, [], 'g', sprintf('Avg Export price %.3g c/kWh', mean(T.export_price)), args{:})
ylabel $
ylim([0 max(ylim)*1.1])
legend show

axis_stack(2, 3, 2, 2, [], [-0.03 0.01], sprintf('Initial Bill $%.0f', sum(T.import_cost) - sum(T.export_revenue)))
plotspread2(gca, T.time, T.import_cost,    [], 'r', sprintf('Import $%.0f', sum(T.import_cost)),    args{:})
plotspread2(gca, T.time, T.export_revenue, [], 'g', sprintf('Export $%.0f', sum(T.export_revenue)), args{:})
ylabel $
legend show

axis_stack(3, 3, 2, 2, [], [-0.03 0.01], sprintf('Adjusted Bill $%.0f', sum(T.sim_import_cost) - sum(T.sim_export_revenue)))
plotspread2(gca, T.time, T.sim_import_cost,    [], 'r', sprintf('Import $%.0f', sum(T.sim_import_cost)),    args{:})
plotspread2(gca, T.time, T.sim_export_revenue, [], 'g', sprintf('Export $%.0f', sum(T.sim_export_revenue)), args{:})
ylabel $
legend show

linkallaxes
xlim([min(T.time) max(T.time)])

% figsave(gcf, [output ' ' num2str(capacity) ' ' mode '.png'], [1200 900])
end
