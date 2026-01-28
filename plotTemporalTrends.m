function figPaths = plotTemporalTrends(configs, opts)
% plotTemporalTrends - Analyze temporal stability of configurations
%
% Creates visualizations showing how performance changes over time for
% different configurations

figPaths = {};

nConfigs = length(configs);
if nConfigs < 1
    warning('No configurations to analyze');
    return;
end

%% Compute year-by-year statistics for each configuration
yearlyStats = struct();

for iConfig = 1:nConfigs
    data = configs(iConfig).data;

    if isempty(data)
        continue;
    end

    % Get unique years
    years = unique([data.Year]);

    for iYear = 1:length(years)
        year = years(iYear);

        % Collect data for this year
        Y_obs_year = [];
        Y_est_year = [];

        for i = 1:length(data)
            if data(i).Year == year
                Y_obs_year = [Y_obs_year; data(i).Y_obs(:)];
                Y_est_year = [Y_est_year; data(i).Y_est(:)];
            end
        end

        if ~isempty(Y_obs_year)
            idx = (iConfig-1)*length(years) + iYear;
            yearlyStats(idx).config = iConfig;
            yearlyStats(idx).configName = configs(iConfig).name;
            yearlyStats(idx).year = year;
            yearlyStats(idx).N = length(Y_obs_year);
            yearlyStats(idx).R2 = calculateR2(Y_obs_year, Y_est_year);
            yearlyStats(idx).RMSE = sqrt(mean((Y_obs_year - Y_est_year).^2));
            yearlyStats(idx).MAE = mean(abs(Y_obs_year - Y_est_year));
            yearlyStats(idx).NMB = 100 * mean(Y_est_year - Y_obs_year) / mean(Y_obs_year);
        end
    end
end

if isempty(yearlyStats)
    warning('No yearly statistics computed');
    return;
end

%% Figure 1: Year-by-year performance trends
metrics = opts.metrics;
nMetrics = length(metrics);

fig = figure('Visible', opts.visible, 'Position', [100, 100, 1600, 400*nMetrics]);

colors = lines(nConfigs);

for iMetric = 1:nMetrics
    subplot(nMetrics, 1, iMetric);

    metric = metrics{iMetric};
    hold on;

    % Plot trend for each configuration
    for iConfig = 1:nConfigs
        % Extract data for this config
        configIdx = [yearlyStats.config] == iConfig;
        years = [yearlyStats(configIdx).year];
        values = [yearlyStats(configIdx).(metric)];

        if ~isempty(years)
            [years_sorted, sortIdx] = sort(years);
            values_sorted = values(sortIdx);

            plot(years_sorted, values_sorted, 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8, ...
                'Color', colors(iConfig, :), ...
                'MarkerFaceColor', colors(iConfig, :), ...
                'DisplayName', configs(iConfig).name);
        end
    end

    xlabel('Year');
    ylabel(metric);
    title(sprintf('%s Trends Over Time', metric));
    legend('Location', 'best');
    grid on;
    hold off;
end

sgtitle('Temporal Performance Trends', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
figFile = fullfile(opts.saveDir, 'temporal_trends_metrics.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 2: Temporal consistency (coefficient of variation)
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1000, 600]);

% Compute CV for each config and metric
cvData = zeros(nConfigs, nMetrics);
configNames = cell(1, nConfigs);

for iConfig = 1:nConfigs
    configNames{iConfig} = configs(iConfig).name;

    configIdx = [yearlyStats.config] == iConfig;

    for iMetric = 1:nMetrics
        metric = metrics{iMetric};
        values = [yearlyStats(configIdx).(metric)];

        if ~isempty(values) && mean(abs(values)) > 0
            cvData(iConfig, iMetric) = std(values) / mean(abs(values));
        else
            cvData(iConfig, iMetric) = NaN;
        end
    end
end

% Create grouped bar chart
bar(cvData);
set(gca, 'XTickLabel', configNames, 'XTickLabelRotation', 45);
ylabel('Coefficient of Variation');
xlabel('Configuration');
title('Temporal Consistency (Lower = More Stable)', 'FontSize', 12, 'FontWeight', 'bold');
legend(metrics, 'Location', 'best');
grid on;

% Save figure
figFile = fullfile(opts.saveDir, 'temporal_consistency.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 3: Best configuration by year
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 600]);

% Get all years
allYears = unique([yearlyStats.year]);

% For each year, find best config for each metric
bestConfigs = zeros(length(allYears), nMetrics);

for iYear = 1:length(allYears)
    year = allYears(iYear);
    yearIdx = [yearlyStats.year] == year;

    for iMetric = 1:nMetrics
        metric = metrics{iMetric};
        values = [yearlyStats(yearIdx).(metric)];
        configsForYear = [yearlyStats(yearIdx).config];

        if strcmp(metric, 'R2')
            [~, bestIdx] = max(values);
        else  % RMSE, MAE, NMB - lower abs is better
            [~, bestIdx] = min(abs(values));
        end

        if ~isempty(bestIdx)
            bestConfigs(iYear, iMetric) = configsForYear(bestIdx);
        end
    end
end

% Create stacked plot showing winner for each year/metric
for iMetric = 1:nMetrics
    subplot(nMetrics, 1, iMetric);

    % Create bar chart
    barData = zeros(length(allYears), nConfigs);
    for iYear = 1:length(allYears)
        winnerConfig = bestConfigs(iYear, iMetric);
        if winnerConfig > 0
            barData(iYear, winnerConfig) = 1;
        end
    end

    bar(allYears, barData, 'stacked');
    ylabel(metrics{iMetric});
    title(sprintf('Best Configuration by Year (%s)', metrics{iMetric}));
    ylim([0, 1.2]);
    set(gca, 'YTick', [0, 1]);
    set(gca, 'YTickLabel', {'', 'Winner'});
    grid on;

    if iMetric == nMetrics
        xlabel('Year');
        legend(configNames, 'Location', 'southoutside', 'Orientation', 'horizontal');
    end
end

sgtitle('Winner Analysis by Year and Metric', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
figFile = fullfile(opts.saveDir, 'temporal_winners.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Save temporal trends table
if opts.saveTables
    tableFile = fullfile(opts.saveDir, 'temporal_trends.csv');

    T = struct2table(yearlyStats);
    writetable(T, tableFile);

    fprintf('  Saved temporal trends table: %s\n', tableFile);
    figPaths{end+1} = tableFile;  % Add to paths even though it's a table
end

end

function r2 = calculateR2(obs, est)
% Calculate R-squared
    validIdx = ~isnan(obs) & ~isnan(est);
    obs = obs(validIdx);
    est = est(validIdx);

    if isempty(obs)
        r2 = NaN;
        return;
    end

    SS_res = sum((obs - est).^2);
    SS_tot = sum((obs - mean(obs)).^2);

    if SS_tot == 0
        r2 = NaN;
    else
        r2 = 1 - SS_res / SS_tot;
    end
end
