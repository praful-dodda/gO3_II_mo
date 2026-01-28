function [figPaths, tablePaths] = plotConfigComparison(configs, opts)
% plotConfigComparison - Side-by-side comparison of multiple configurations
%
% Creates visualizations comparing performance metrics across different
% soft data configurations

figPaths = {};
tablePaths = {};

nConfigs = length(configs);
if nConfigs < 2
    warning('Need at least 2 configurations for comparison');
    return;
end

%% Get unique years across all configurations
allYears = [];
for iConfig = 1:nConfigs
    if ~isempty(configs(iConfig).data)
        allYears = [allYears, [configs(iConfig).data.Year]];
    end
end
uniqueYears = unique(allYears);
uniqueYears = uniqueYears(~isnan(uniqueYears));

%% Compute statistics for each configuration (overall and by year)
configStats = struct();
configStatsByYear = struct();

for iConfig = 1:nConfigs
    data = configs(iConfig).data;

    if isempty(data)
        continue;
    end

    % OVERALL statistics (all years combined)
    Y_obs_all = [];
    Y_est_all = [];
    for i = 1:length(data)
        Y_obs_all = [Y_obs_all; data(i).Y_obs(:)];
        Y_est_all = [Y_est_all; data(i).Y_est(:)];
    end

    configStats(iConfig).name = configs(iConfig).name;
    configStats(iConfig).N = length(Y_obs_all);
    configStats(iConfig).R2 = calculateR2(Y_obs_all, Y_est_all);
    configStats(iConfig).RMSE = sqrt(mean((Y_obs_all - Y_est_all).^2));
    configStats(iConfig).MAE = mean(abs(Y_obs_all - Y_est_all));
    configStats(iConfig).NMB = 100 * mean(Y_est_all - Y_obs_all) / mean(Y_obs_all);
    configStats(iConfig).MeanObs = mean(Y_obs_all);
    configStats(iConfig).MeanEst = mean(Y_est_all);

    % BY-YEAR statistics
    for iYear = 1:length(uniqueYears)
        year = uniqueYears(iYear);

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
            idx = (iYear-1)*nConfigs + iConfig;
            configStatsByYear(idx).config = iConfig;
            configStatsByYear(idx).configName = configs(iConfig).name;
            configStatsByYear(idx).year = year;
            configStatsByYear(idx).N = length(Y_obs_year);
            configStatsByYear(idx).R2 = calculateR2(Y_obs_year, Y_est_year);
            configStatsByYear(idx).RMSE = sqrt(mean((Y_obs_year - Y_est_year).^2));
            configStatsByYear(idx).MAE = mean(abs(Y_obs_year - Y_est_year));
            configStatsByYear(idx).NMB = 100 * mean(Y_est_year - Y_obs_year) / mean(Y_obs_year);
        end
    end

    % Compute regional breakdown
    regionNames = unique(vertcat(data.regions));
    for iReg = 1:length(regionNames)
        region = regionNames{iReg};

        % Collect data for this region
        Y_obs_reg = [];
        Y_est_reg = [];
        for i = 1:length(data)
            idx = strcmp(data(i).regions, region);
            Y_obs_reg = [Y_obs_reg; data(i).Y_obs(idx)];
            Y_est_reg = [Y_est_reg; data(i).Y_est(idx)];
        end

        if ~isempty(Y_obs_reg)
            configStats(iConfig).regional.(strrep(region, ' ', '_')).R2 = calculateR2(Y_obs_reg, Y_est_reg);
            configStats(iConfig).regional.(strrep(region, ' ', '_')).RMSE = sqrt(mean((Y_obs_reg - Y_est_reg).^2));
            configStats(iConfig).regional.(strrep(region, ' ', '_')).N = length(Y_obs_reg);
        end
    end
end

%% Save summary tables
if opts.saveTables
    % Overall summary
    summaryFile = fullfile(opts.saveDir, 'config_comparison_summary.csv');
    T = table();
    for iConfig = 1:nConfigs
        if ~isfield(configStats, 'name') || iConfig > length(configStats)
            continue;
        end
        T.Configuration{iConfig} = configStats(iConfig).name;
        T.N(iConfig) = configStats(iConfig).N;
        T.R2(iConfig) = configStats(iConfig).R2;
        T.RMSE(iConfig) = configStats(iConfig).RMSE;
        T.MAE(iConfig) = configStats(iConfig).MAE;
        T.NMB(iConfig) = configStats(iConfig).NMB;
        T.MeanObs(iConfig) = configStats(iConfig).MeanObs;
        T.MeanEst(iConfig) = configStats(iConfig).MeanEst;
    end
    writetable(T, summaryFile);
    tablePaths{end+1} = summaryFile;
    fprintf('  Saved overall summary table: %s\n', summaryFile);

    % By-year summary
    if ~isempty(configStatsByYear)
        byYearFile = fullfile(opts.saveDir, 'config_comparison_by_year.csv');
        T_year = struct2table(configStatsByYear);
        writetable(T_year, byYearFile);
        tablePaths{end+1} = byYearFile;
        fprintf('  Saved by-year summary table: %s\n', byYearFile);
    end
end

%% Figure 1: Bar chart comparison by year (separate panels for each year)
metrics = opts.metrics;
nMetrics = length(metrics);
nYears = length(uniqueYears);

fig = figure('Visible', opts.visible, 'Position', [100, 100, 400*nYears, 300*nMetrics]);

for iMetric = 1:nMetrics
    metric = metrics{iMetric};

    for iYear = 1:nYears
        year = uniqueYears(iYear);
        subplot(nMetrics, nYears, (iMetric-1)*nYears + iYear);

        % Get values for this year
        values = [];
        labels = {};
        for iConfig = 1:nConfigs
            % Find stats for this config and year
            idx = find([configStatsByYear.config] == iConfig & [configStatsByYear.year] == year, 1);
            if ~isempty(idx) && isfield(configStatsByYear(idx), metric)
                values(end+1) = configStatsByYear(idx).(metric);
                labels{end+1} = configStats(iConfig).name;
            else
                values(end+1) = NaN;
                labels{end+1} = configStats(iConfig).name;
            end
        end

        % Create bar plot
        validIdx = ~isnan(values);
        if any(validIdx)
            b = bar(values, 'FaceColor', [0.3, 0.6, 0.8]);
            set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 45);
            ylabel(metric);
            title(sprintf('%d', year));
            grid on;

            % Highlight best performer
            if strcmp(metric, 'R2')
                [~, bestIdx] = max(values);
            elseif ismember(metric, {'RMSE', 'MAE'})
                [~, bestIdx] = min(abs(values));
            else  % NMB
                [~, bestIdx] = min(abs(values));
            end

            if ~isnan(values(bestIdx))
                hold on;
                bar(bestIdx, values(bestIdx), 'FaceColor', [0.2, 0.8, 0.3]);
                hold off;
            end

            % Add value labels
            for i = 1:length(values)
                if ~isnan(values(i))
                    text(i, values(i), sprintf('%.2f', values(i)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'FontSize', 7);
                end
            end
        end
    end
end

sgtitle('Configuration Performance Comparison by Year', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
figFile = fullfile(opts.saveDir, 'config_comparison_by_year.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 2: Spider/Radar plot for multi-metric comparison
fig = figure('Visible', opts.visible, 'Position', [100, 100, 800, 800]);

% Normalize metrics to 0-1 scale
nMetrics = length(metrics);
normalizedData = zeros(nConfigs, nMetrics);

for iMetric = 1:nMetrics
    metric = metrics{iMetric};
    values = [];
    for iConfig = 1:nConfigs
        if isfield(configStats, metric)
            values(end+1) = configStats(iConfig).(metric);
        else
            values(end+1) = NaN;
        end
    end

    % Normalize: higher is better for all metrics
    if strcmp(metric, 'R2')
        % R2: higher is better, already 0-1
        normalizedData(:, iMetric) = values(:) / max(values);
    else
        % RMSE, MAE, NMB: lower is better, invert
        normalizedData(:, iMetric) = 1 - (abs(values(:)) / max(abs(values)));
    end
end

% Create spider plot
theta = linspace(0, 2*pi, nMetrics+1);
colors = lines(nConfigs);

hold on;
for iConfig = 1:nConfigs
    dataPoint = [normalizedData(iConfig, :), normalizedData(iConfig, 1)];
    plot(theta, dataPoint, 'o-', 'LineWidth', 2, 'Color', colors(iConfig, :), ...
        'MarkerFaceColor', colors(iConfig, :), 'MarkerSize', 8, ...
        'DisplayName', configStats(iConfig).name);
end

% Add metric labels
ax = gca;
ax.ThetaTick = rad2deg(theta(1:end-1));
ax.ThetaTickLabel = metrics;
ax.RLim = [0, 1];
ax.RGrid = 'on';
ax.ThetaGrid = 'on';

title('Multi-Metric Performance (Normalized)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best');
polarplot(ax);

% Save figure
figFile = fullfile(opts.saveDir, 'config_comparison_spider.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 3: Regional performance heatmap
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 600]);

% Get all unique regions
allRegions = {};
for iConfig = 1:nConfigs
    if isfield(configStats(iConfig), 'regional')
        regionFields = fieldnames(configStats(iConfig).regional);
        allRegions = unique([allRegions; regionFields]);
    end
end

if ~isempty(allRegions)
    % Create heatmap data for R2
    heatmapData = NaN(length(allRegions), nConfigs);

    for iConfig = 1:nConfigs
        if ~isfield(configStats(iConfig), 'regional')
            continue;
        end
        for iReg = 1:length(allRegions)
            region = allRegions{iReg};
            if isfield(configStats(iConfig).regional, region)
                heatmapData(iReg, iConfig) = configStats(iConfig).regional.(region).R2;
            end
        end
    end

    % Create heatmap
    imagesc(heatmapData);
    colormap(jet);
    colorbar;
    caxis([0, 1]);

    % Labels
    set(gca, 'XTick', 1:nConfigs);
    set(gca, 'XTickLabel', {configStats.name}, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:length(allRegions));

    % Convert region field names back to readable format
    regionLabels = cell(size(allRegions));
    for i = 1:length(allRegions)
        regionLabels{i} = strrep(allRegions{i}, '_', ' ');
    end
    set(gca, 'YTickLabel', regionLabels);

    title('Regional R² by Configuration', 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('Configuration');
    ylabel('Region');

    % Add text annotations
    for iReg = 1:length(allRegions)
        for iConfig = 1:nConfigs
            if ~isnan(heatmapData(iReg, iConfig))
                text(iConfig, iReg, sprintf('%.2f', heatmapData(iReg, iConfig)), ...
                    'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end

    % Save figure
    figFile = fullfile(opts.saveDir, 'config_comparison_regional.png');
    print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
    figPaths{end+1} = figFile;
    if strcmp(opts.visible, 'off')
        close(fig);
    end

    % Save regional table
    if opts.saveTables
        regionalFile = fullfile(opts.saveDir, 'config_comparison_regional.csv');
        T_regional = array2table(heatmapData, 'VariableNames', {configStats.name}, ...
            'RowNames', regionLabels);
        writetable(T_regional, regionalFile, 'WriteRowNames', true);
        tablePaths{end+1} = regionalFile;
        fprintf('  Saved regional table: %s\n', regionalFile);
    end
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
