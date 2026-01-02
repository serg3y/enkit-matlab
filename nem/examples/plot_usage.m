% Plot electricity usage data.
%
% Instructions:
% 1. Download usage data in NEM12 format:
%    eg https://customer.portal.sapowernetworks.com.au/meterdata/apex/cadenergydashboard
% 2. Set 'data_fold' to be the path to the parent folder.
% 3. Change 'output' folder if required.

%% Inputs

example = 'Serge'; span = [];
data_fold = 'D:\MATLAB\enkit\nem\data\Serge';
% plot_list = ["import_kw" "export_kw"];
plot_list = ["total_kw"];

% example = 'Andrew'; span = []; % 731 days
% data_fold = 'D:\MATLAB\enkit\nem\data\Andrew';
% plot_list = ["import_kw" "cl_kw" "export_kw"];
% plot_list = ["total_kw"];

% example = 'Gene'; span = []; % 729 days
% data_fold = 'D:\MATLAB\enkit\nem\data\Gene';
% plot_list = ["import_kw" "export_kw"];
% plot_list = ["total_kw"];

% example ='Jason';           span = []; % 424 days
% example ='Jason No PV';     span = ["2024-09-19" "2025-02-22"]; % 156 days
% example ='Jason low usage'; span = ["2025-03-13" "2025-05-16"]; %  64 days
% example ='Jason no SS';     span = ["2025-05-17" "2025-08-30"]; % 105 days
% example ='Jason SS';        span = ["2025-08-31" "2025-11-16"]; %  77 days
% data_fold = 'D:\MATLAB\enkit\nem\data\Jason';
% plot_list = ["import_kw" "export_kw"];
% plot_list = ["total_kw"];

% example = 'David'; span = [];
% data_fold = 'D:\MATLAB\enkit\nem\data\David';
% plot_list = ["import_kw" "cl_kw"];
% plot_list = ["total_kw"];

% Select output file name
output = fullfile(data_fold, example);

%% Load meter data
[T, header] = nem().read(data_fold, span);

%% Calculate total (kwh)
T.total_kwh = T.import_kwh;
if hascolumn(T, 'export_kwh')
    T.total_kwh = T.total_kwh - T.export_kwh;    
end
if hascolumn(T, 'cl_kwh')
    T.total_kwh = T.total_kwh + T.cl_kwh;    
end

%% Calculate rates (kw)
ind = endsWith(T.Properties.VariableNames, '_kwh');
rates = T(:, ind) ./ hours(mode(diff(T.time)));
rates.Properties.VariableNames = strip(T.Properties.VariableNames(ind), 'right', 'h');
T = [T rates];

%% Plot
figmode(-1, 'dark', 'handy')
n = numel(plot_list);
clear label_list
for k = 1:n

    % Plot settings
    switch plot_list(k)
        case "import_kw"; col = [1.0 0.3 0.3]; label_list(k) = "Imports";
        case "export_kw"; col = [0.0 0.8 0.0]; label_list(k) = "Exports";
        case "cl_kw";     col = [1.0 0.3 0.3]; label_list(k) = "Controlled Load";
        case "total_kw";  col = [1.0 0.2 0.2; 0.0 0.9 0.0]; label_list(k) = "Total";
    end

    % Plot
    pos = [0 1-1/n*k 1 1/n]; % Axes position: [L B W H]
    ax = heatmapTimeVsDatePlus(T, 'time', plot_list(k), col, example + " - " + label_list(k), {'kW' 'kWh'}, pos);

end

linkallaxes

file = fullfile(data_fold, "Usage - " + example + " - " + strjoin(label_list) + ".png");
figsave(1, file, [1920 1080])
