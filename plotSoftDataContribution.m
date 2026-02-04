function [figPaths, tablePaths] = plotSoftDataContribution(configs, opts)
% plotSoftDataContribution - Analyze incremental value of soft data sources
%
% Creates visualizations showing the contribution of each soft data source

figPaths = {};
tablePaths = {};

nConfigs = length(configs);
if nConfigs < 2
    warning('Need at least 2 configurations for contribution analysis');
    return;
end

%% Compute aggregate statistics for each configuration
configStats = struct();

for iConfig = 1:nConfigs
    data = configs(iConfig).data;

    if isempty(data)
        continue;
    end

    % Aggregate all observations and estimates
    Y_obs_all = [];
    Y_est_all = [];
    for i = 1:length(data)
        Y_obs_all = [Y_obs_all; data(i).Y_obs(:)];
        Y_est_all = [Y_est_all; data(i).Y_est(:)];
    end

    % Compute overall metrics
    configStats(iConfig).name = configs(iConfig).name;
    configStats(iConfig).N = length(Y_obs_all);
    configStats(iConfig).R2 = calculateR2(Y_obs_all, Y_est_all);
    configStats(iConfig).RMSE = sqrt(mean((Y_obs_all - Y_est_all).^2));
    configStats(iConfig).MAE = mean(abs(Y_obs_all - Y_est_all));
    configStats(iConfig).NMB = 100 * mean(Y_est_all - Y_obs_all) / mean(Y_obs_all);

    % Extract CTM models if available
    if ~isempty(data) && isfield(data(1), 'ctmModels')
        configStats(iConfig).models = data(1).ctmModels;
    else
        configStats(iConfig).models = {};
    end
end

if isempty(configStats)
    warning('No configuration statistics computed');
    return;
end

%% Figure 1: Incremental improvement waterfall chart
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 600]);

metrics = opts.metrics;
nMetrics = length(metrics);

for iMetric = 1:nMetrics
    subplot(1, nMetrics, iMetric);

    metric = metrics{iMetric};

    % Get values
    values = zeros(1, nConfigs);
    labels = cell(1, nConfigs);
    for iConfig = 1:nConfigs
        values(iConfig) = configStats(iConfig).(metric);
        labels{iConfig} = configStats(iConfig).name;
    end

    % Compute increments from baseline
    baselineValue = values(opts.baselineConfig);
    increments = values - baselineValue;

    % Create waterfall plot
    if strcmp(metric, 'R2')
        % For R2, positive increment is good
        colors = zeros(nConfigs, 3);
        colors(opts.baselineConfig, :) = [0.5, 0.5, 0.5];  % Gray for baseline
        for iConfig = 1:nConfigs
            if iConfig == opts.baselineConfig
                continue;
            end
            if increments(iConfig) > 0
                colors(iConfig, :) = [0.2, 0.8, 0.3];  % Green for improvement
            else
                colors(iConfig, :) = [0.9, 0.3, 0.2];  % Red for degradation
            end
        end
    else
        % For RMSE, MAE, NMB, negative increment (reduction) is good
        colors = zeros(nConfigs, 3);
        colors(opts.baselineConfig, :) = [0.5, 0.5, 0.5];  % Gray for baseline
        for iConfig = 1:nConfigs
            if iConfig == opts.baselineConfig
                continue;
            end
            if increments(iConfig) < 0  % Reduction is good
                colors(iConfig, :) = [0.2, 0.8, 0.3];  % Green for improvement
            else
                colors(iConfig, :) = [0.9, 0.3, 0.2];  % Red for degradation
            end
        end
    end

    % Plot bars
    hold on;
    for iConfig = 1:nConfigs
        bar(iConfig, increments(iConfig), 'FaceColor', colors(iConfig, :));
    end
    hold off;

    set(gca, 'XTick', 1:nConfigs);
    set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 45);
    ylabel(sprintf('Δ%s from Baseline', metric));
    title(sprintf('%s Incremental Change', metric));
    grid on;

    % Add zero line
    hold on;
    plot([0, nConfigs+1], [0, 0], 'k--', 'LineWidth', 1);
    hold off;

    % Add value labels
    for iConfig = 1:nConfigs
        if increments(iConfig) >= 0
            valign = 'bottom';
        else
            valign = 'top';
        end
        text(iConfig, increments(iConfig), sprintf('%.3f', increments(iConfig)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', valign, 'FontSize', 8);
    end
end

sgtitle('Incremental Performance Improvement', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
figFile = fullfile(opts.saveDir, 'soft_data_incremental.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 2: Cost-benefit matrix
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 800]);

% Compute "complexity" score based on number of models
complexity = zeros(1, nConfigs);
for iConfig = 1:nConfigs
    if isfield(configStats(iConfig), 'models')
        complexity(iConfig) = length(configStats(iConfig).models);
    end
end

% Compute "benefit" score as weighted average of normalized metrics
benefits = zeros(1, nConfigs);
for iConfig = 1:nConfigs
    % Normalize metrics (higher = better)
    r2_norm = configStats(iConfig).R2 / max([configStats.R2]);
    rmse_norm = 1 - (configStats(iConfig).RMSE / max([configStats.RMSE]));
    mae_norm = 1 - (configStats(iConfig).MAE / max([configStats.MAE]));
    nmb_norm = 1 - (abs(configStats(iConfig).NMB) / max(abs([configStats.NMB])));

    % Weighted average
    benefits(iConfig) = 0.4*r2_norm + 0.3*rmse_norm + 0.2*mae_norm + 0.1*nmb_norm;
end

% Scatter plot: complexity vs benefit
scatter(complexity, benefits, 200, 'filled');

% Add labels
for iConfig = 1:nConfigs
    text(complexity(iConfig), benefits(iConfig), sprintf('  %d', iConfig), ...
        'FontSize', 10, 'FontWeight', 'bold');
end

xlabel('Complexity (Number of Soft Data Sources)');
ylabel('Performance Benefit (Normalized Score)');
title('Cost-Benefit Analysis', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% Add quadrant lines
hold on;
meanComplexity = mean(complexity);
meanBenefit = mean(benefits);
plot([meanComplexity, meanComplexity], [0, 1], 'k--', 'LineWidth', 1);
plot([0, max(complexity)+1], [meanBenefit, meanBenefit], 'k--', 'LineWidth', 1);

% Label quadrants
text(0.1, 0.95, 'Low Complexity, High Benefit (IDEAL)', 'FontSize', 10, 'Color', 'g');
text(0.1, 0.05, 'Low Complexity, Low Benefit', 'FontSize', 10);
hold off;

% Add legend with config names
legendStr = cell(1, nConfigs);
for iConfig = 1:nConfigs
    legendStr{iConfig} = sprintf('%d: %s', iConfig, configStats(iConfig).name);
end
text(0.95*max(complexity), 0.3, legendStr, 'FontSize', 8, 'VerticalAlignment', 'top');

% Save figure
figFile = fullfile(opts.saveDir, 'soft_data_cost_benefit.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Figure 3: Performance vs number of sources
fig = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 600]);

for iMetric = 1:nMetrics
    subplot(1, nMetrics, iMetric);

    metric = metrics{iMetric};
    values = [configStats.(metric)];

    plot(complexity, values, 'o-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'b');

    xlabel('Number of Soft Data Sources');
    ylabel(metric);
    title(sprintf('%s vs Complexity', metric));
    grid on;

    % Add labels
    for iConfig = 1:nConfigs
        text(complexity(iConfig), values(iConfig), sprintf('  %d', iConfig), ...
            'FontSize', 8);
    end
end

sgtitle('Performance vs Soft Data Complexity', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
figFile = fullfile(opts.saveDir, 'soft_data_vs_complexity.png');
print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile;
if strcmp(opts.visible, 'off')
    close(fig);
end

%% Save contribution analysis table
if opts.saveTables
    tableFile = fullfile(opts.saveDir, 'soft_data_contribution.csv');

    T = table();
    for iConfig = 1:nConfigs
        T.Configuration{iConfig} = configStats(iConfig).name;
        T.NumSources(iConfig) = complexity(iConfig);

        if isfield(configStats(iConfig), 'models') && ~isempty(configStats(iConfig).models)
            T.Models{iConfig} = strjoin(configStats(iConfig).models, ', ');
        else
            T.Models{iConfig} = 'None';
        end

        T.R2(iConfig) = configStats(iConfig).R2;
        T.RMSE(iConfig) = configStats(iConfig).RMSE;
        T.MAE(iConfig) = configStats(iConfig).MAE;
        T.NMB(iConfig) = configStats(iConfig).NMB;

        % Compute increments from baseline
        T.Delta_R2(iConfig) = configStats(iConfig).R2 - configStats(opts.baselineConfig).R2;
        T.Delta_RMSE(iConfig) = configStats(iConfig).RMSE - configStats(opts.baselineConfig).RMSE;
        T.Delta_MAE(iConfig) = configStats(iConfig).MAE - configStats(opts.baselineConfig).MAE;
        T.Delta_NMB(iConfig) = configStats(iConfig).NMB - configStats(opts.baselineConfig).NMB;

        T.BenefitScore(iConfig) = benefits(iConfig);
    end

    writetable(T, tableFile);
    tablePaths{end+1} = tableFile;
    fprintf('  Saved contribution table: %s\n', tableFile);
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
