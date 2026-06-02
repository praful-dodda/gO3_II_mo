function figPaths = plotPhase4TimeSeries(yearlyData, configs, colors, lineStyles, markers, lineWidths, opts)
% plotPhase4TimeSeries - Generate time-series plots with distinct styling and NaN handling
%
% Creates time-series visualizations showing how performance metrics change
% over time for different model configurations. Handles missing years gracefully
% by using NaN values (lines break at missing data points).
%
% SYNTAX:
%   figPaths = plotPhase4TimeSeries(yearlyData, configs, colors, lineStyles, markers, lineWidths, opts)
%
% INPUTS:
%   yearlyData  - Structure with fields:
%                   .years    - Vector of all years (e.g., 2005:2020)
%                   .values   - nConfigs x nYears x nMetrics array of metric values
%                               (NaN for missing years)
%                   .N        - nConfigs x nYears array of sample sizes
%   configs     - Structure array with fields: .name, .data
%   colors      - nConfigs x 3 matrix of RGB colors
%   lineStyles  - Cell array of line style strings
%   markers     - Cell array of marker strings
%   lineWidths  - nConfigs x 1 vector of line widths
%   opts        - Options structure with fields:
%                   .metrics   - Cell array of metric names
%                   .saveDir   - Directory to save figures
%                   .dpi       - Figure resolution
%                   .visible   - 'on' or 'off'
%
% OUTPUTS:
%   figPaths - Cell array of paths to generated figures
%
% FEATURES:
%   - Handles missing years with NaN (lines break at gaps)
%   - Unique colors, line styles, and line widths per model
%   - Lighter colors/dashed lines for simple methods, brighter/solid for complex
%   - Multi-panel figure (one subplot per metric)
%   - Proper legend with all configurations
%   - Year-over-year heatmap visualization
%
% SEE ALSO: plotCBVresults_Phase4, getCBVmodelStyles

figPaths = {};

%% Extract data dimensions
allYears = yearlyData.years;
nYears = length(allYears);
nConfigs = size(yearlyData.values, 1);
metrics = opts.metrics;
nMetrics = length(metrics);

if nConfigs < 1 || nYears < 1
    warning('No data to plot');
    return;
end

% Box-size label for titles (e.g., "20 deg CBV")
if isfield(opts, 'boxSize') && ~isempty(opts.boxSize)
    boxLabel = sprintf('%g%s CBV', opts.boxSize, char(176));
else
    boxLabel = 'CBV';
end

% Manuscript-quality font sizes (text was too small for publication)
axFont    = 15;   % tick labels
labelFont = 16;   % axis labels
titleFont = 18;   % titles
legFont   = 13;   % legend

%% Figure 1: Time-series with all metrics (multi-panel)

% Determine which configs have any non-NaN data across all metrics
hasData = false(nConfigs, 1);
for iConfig = 1:nConfigs
    hasData(iConfig) = any(~isnan(yearlyData.values(iConfig, :, :)), 'all');
end

% Scale figure height to accommodate legend rows
nLegendCols = 6;
legendRows = ceil(sum(hasData) / nLegendCols);
legendHeight = legendRows * 25;  % ~25px per row
fig1 = figure('Visible', opts.visible, 'Position', [100, 100, 1600, 350*nMetrics + legendHeight + 40]);

plotHandles = gobjects(nConfigs, 1);

for iMetric = 1:nMetrics
    subplot(nMetrics, 1, iMetric);
    hold on;

    metric = metrics{iMetric};

    % Plot each configuration
    for iConfig = 1:nConfigs
        % Extract values for this config and metric
        values = squeeze(yearlyData.values(iConfig, :, iMetric));

        % Plot with assigned style (NaN creates gaps automatically)
        h = plot(allYears, values, ...
            'LineStyle', lineStyles{iConfig}, ...
            'Color', colors(iConfig, :), ...
            'Marker', markers{iConfig}, ...
            'LineWidth', lineWidths(iConfig), ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', colors(iConfig, :), ...
            'DisplayName', configs(iConfig).name);

        % Store handles from first subplot for the shared legend
        if iMetric == 1
            plotHandles(iConfig) = h;
        end
    end

    % Formatting
    set(gca, 'FontSize', axFont);
    xlabel('Year', 'FontSize', labelFont);
    ylabel(metric, 'FontSize', labelFont);
    title(sprintf('%s | %s', metric, boxLabel), 'FontSize', titleFont, 'FontWeight', 'bold');

    % Set x-axis to show all years
    xlim([min(allYears)-0.5, max(allYears)+0.5]);
    xticks(allYears);

    ylim auto;
    
    % if Metric is R2, set y-axis limits to [0, 1]
    % if strcmpi(metric, 'R2')
    %     ylim([0.6, 0.87]);
    % elseif strcmpi(metric, 'RMSE')
    %     ylim([4 9.5])
    % else
    %     ylim auto;
    % end

    % Add grid
    grid on;
    box on;

    hold off;
end

% Store subplot positions before legend creation (southoutside resizes axes)
axHandles = gobjects(nMetrics, 1);
axPositions = cell(nMetrics, 1);
for i = 1:nMetrics
    axHandles(i) = subplot(nMetrics, 1, i);
    axPositions{i} = axHandles(i).Position;
end

% Add shared legend at bottom (only models with data)
lgd = legend(plotHandles(hasData), {configs(hasData).name}, ...
    'Orientation', 'horizontal', 'NumColumns', min(nLegendCols, sum(hasData)));
lgd.FontSize = legFont;
lgd.Units = 'normalized';
lgd.Position(1) = 0.5 - lgd.Position(3)/2;  % Center horizontally
lgd.Position(2) = 0.01;                       % Place at bottom of figure

% Restore subplot positions so legend doesn't shrink them
for i = 1:nMetrics
    axHandles(i).Position = axPositions{i};
end

% Save figure
figFile1 = fullfile(opts.saveDir, 'phase4_timeseries_metrics.png');
print(fig1, figFile1, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile1;
fprintf('  Saved: %s\n', figFile1);

if strcmp(opts.visible, 'off')
    close(fig1);
end

%% Figure 2: Year-over-year heatmap (for primary metric, usually R2)
primaryMetricIdx = 1;  % R2
if nMetrics >= 1
    fig2 = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 600]);

    % Prepare heatmap data
    heatmapData = squeeze(yearlyData.values(:, :, primaryMetricIdx));

    % Create heatmap
    imagesc(heatmapData);
    colormap(jet);
    colorbar;

    % Set axis labels
    set(gca, 'XTick', 1:nYears, 'XTickLabel', arrayfun(@num2str, allYears, 'UniformOutput', false));
    set(gca, 'YTick', 1:nConfigs, 'YTickLabel', {configs.name});
    set(gca, 'XTickLabelRotation', 45, 'FontSize', axFont);

    xlabel('Year', 'FontSize', labelFont);
    ylabel('Configuration', 'FontSize', labelFont);
    title(sprintf('%s Heatmap | %s', metrics{primaryMetricIdx}, boxLabel), ...
        'FontSize', titleFont, 'FontWeight', 'bold');

    % Add value annotations
    for iConfig = 1:nConfigs
        for iYear = 1:nYears
            val = heatmapData(iConfig, iYear);
            if ~isnan(val)
                % Choose text color based on background
                if val > mean(heatmapData(:), 'omitnan')
                    textColor = 'w';
                else
                    textColor = 'k';
                end
                text(iYear, iConfig, sprintf('%.2f', val), ...
                    'HorizontalAlignment', 'center', ...
                    'Color', textColor, 'FontSize', 11, 'FontWeight', 'bold');
            else
                text(iYear, iConfig, 'N/A', ...
                    'HorizontalAlignment', 'center', ...
                    'Color', [0.5, 0.5, 0.5], 'FontSize', 11);
            end
        end
    end

    % Save figure
    figFile2 = fullfile(opts.saveDir, 'phase4_yearly_heatmap.png');
    print(fig2, figFile2, '-dpng', sprintf('-r%d', opts.dpi));
    figPaths{end+1} = figFile2;
    fprintf('  Saved: %s\n', figFile2);

    if strcmp(opts.visible, 'off')
        close(fig2);
    end
end

%% Figure 3: Individual metric plots with confidence bands (optional)
if isfield(opts, 'plotIndividualMetrics') && opts.plotIndividualMetrics
    for iMetric = 1:nMetrics
        fig3 = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 560]);

        metric = metrics{iMetric};
        hold on;

        % Plot each configuration with markers
        indivHandles = gobjects(nConfigs, 1);
        indivHasData = false(nConfigs, 1);
        for iConfig = 1:nConfigs
            values = squeeze(yearlyData.values(iConfig, :, iMetric));
            indivHasData(iConfig) = any(~isnan(values));

            indivHandles(iConfig) = plot(allYears, values, ...
                'LineStyle', lineStyles{iConfig}, ...
                'Color', colors(iConfig, :), ...
                'Marker', markers{iConfig}, ...
                'LineWidth', lineWidths(iConfig), ...
                'MarkerSize', 10, ...
                'MarkerFaceColor', colors(iConfig, :), ...
                'DisplayName', configs(iConfig).name);
        end

        xlabel('Year', 'FontSize', 12);
        ylabel(metric, 'FontSize', 12);
        title(sprintf('%s Trends Over Time', metric), 'FontSize', 14, 'FontWeight', 'bold');

        xlim([min(allYears)-0.5, max(allYears)+0.5]);
        xticks(allYears);
        grid on;
        box on;

        legend(indivHandles(indivHasData), {configs(indivHasData).name}, ...
            'Location', 'southoutside', 'Orientation', 'horizontal', 'NumColumns', min(4, sum(indivHasData)));
        hold off;

        % Save figure
        figFile3 = fullfile(opts.saveDir, sprintf('phase4_timeseries_%s.png', lower(metric)));
        print(fig3, figFile3, '-dpng', sprintf('-r%d', opts.dpi));
        figPaths{end+1} = figFile3;
        fprintf('  Saved: %s\n', figFile3);

        if strcmp(opts.visible, 'off')
            close(fig3);
        end
    end
end

%% Figure 4: Winner analysis by year
fig4 = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 350*nMetrics]);

for iMetric = 1:nMetrics
    subplot(nMetrics, 1, iMetric);

    metric = metrics{iMetric};
    metricValues = squeeze(yearlyData.values(:, :, iMetric));

    % Find best configuration per year
    bestConfigs = zeros(1, nYears);
    for iYear = 1:nYears
        yearValues = metricValues(:, iYear);

        % Skip if all NaN
        if all(isnan(yearValues))
            bestConfigs(iYear) = NaN;
            continue;
        end

        % Determine best (higher is better for R2, lower for others)
        if strcmpi(metric, 'R2')
            [~, bestIdx] = max(yearValues);
        else
            [~, bestIdx] = min(abs(yearValues));
        end
        bestConfigs(iYear) = bestIdx;
    end

    % Create stacked bar showing winners
    barData = zeros(nYears, nConfigs);
    for iYear = 1:nYears
        if ~isnan(bestConfigs(iYear))
            barData(iYear, bestConfigs(iYear)) = 1;
        end
    end

    % Use configuration colors for bars
    b = bar(allYears, barData, 'stacked');
    for iConfig = 1:nConfigs
        b(iConfig).FaceColor = colors(iConfig, :);
        b(iConfig).DisplayName = configs(iConfig).name;
    end

    ylabel(metric, 'FontSize', labelFont);
    title(sprintf('Best Configuration by Year (%s) | %s', metric, boxLabel), ...
        'FontSize', titleFont - 2, 'FontWeight', 'bold');
    ylim([0, 1.2]);
    set(gca, 'YTick', [0, 1], 'YTickLabel', {'', 'Winner'}, 'FontSize', axFont);
    xlim([min(allYears)-0.5, max(allYears)+0.5]);
    xticks(allYears);
    grid on;

    if iMetric == nMetrics
        xlabel('Year', 'FontSize', labelFont);
    end
end

% Add legend at bottom (only models with data)
winnerHasData = false(nConfigs, 1);
for iConfig = 1:nConfigs
    winnerHasData(iConfig) = any(~isnan(yearlyData.values(iConfig, :, :)), 'all');
end
% Collect bar handles from last subplot
barHandles = b;
lgd = legend(barHandles(winnerHasData), {configs(winnerHasData).name}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'NumColumns', min(4, sum(winnerHasData)));
lgd.FontSize = legFont;
lgd.Position(2) = 0.01;

sgtitle(sprintf('Winner Analysis by Year | %s', boxLabel), ...
    'FontSize', titleFont, 'FontWeight', 'bold');

% Save figure
figFile4 = fullfile(opts.saveDir, 'phase4_winners.png');
print(fig4, figFile4, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile4;
fprintf('  Saved: %s\n', figFile4);

if strcmp(opts.visible, 'off')
    close(fig4);
end

%% Figure 5: Model comparison summary (average across years)
fig5 = figure('Visible', opts.visible, 'Position', [100, 100, 1200, 500]);

% Compute average metrics per configuration (ignoring NaN)
avgMetrics = zeros(nConfigs, nMetrics);
for iConfig = 1:nConfigs
    for iMetric = 1:nMetrics
        values = squeeze(yearlyData.values(iConfig, :, iMetric));
        avgMetrics(iConfig, iMetric) = mean(values, 'omitnan');
    end
end

% Plot R2 and RMSE on two independent y-axes (different scales/units).
x = 1:nConfigs;
iR2   = find(strcmpi(metrics, 'R2'), 1);
iRMSE = find(strcmpi(metrics, 'RMSE'), 1);
cR2   = [0.20 0.40 0.70];   % blue  -> R2 (left)
cRMSE = [0.85 0.40 0.15];   % orange-> RMSE (right)

if ~isempty(iR2) && ~isempty(iRMSE)
    yyaxis left;
    bR2 = bar(x - 0.2, avgMetrics(:, iR2), 0.35, 'FaceColor', cR2, 'EdgeColor', 'none');
    ylabel('R^2', 'FontSize', labelFont);
    ylim([0 1]);
    set(gca, 'YColor', cR2);

    yyaxis right;
    bRM = bar(x + 0.2, avgMetrics(:, iRMSE), 0.35, 'FaceColor', cRMSE, 'EdgeColor', 'none');
    ylabel('RMSE (ppb)', 'FontSize', labelFont);
    set(gca, 'YColor', cRMSE);

    legend([bR2 bRM], {'R^2', 'RMSE'}, 'Location', 'best', 'FontSize', legFont);
else
    % Fallback: single-axis grouped bars if R2/RMSE not both present
    bar(x, avgMetrics, 0.8);
    ylabel('Metric Value', 'FontSize', labelFont);
    legend(metrics, 'Location', 'best', 'FontSize', legFont);
end

set(gca, 'XTick', x, 'XTickLabel', {configs.name}, 'XTickLabelRotation', 45, 'FontSize', axFont);
xlabel('Configuration', 'FontSize', labelFont);
title(sprintf('Average Performance Across Years | %s', boxLabel), ...
    'FontSize', titleFont, 'FontWeight', 'bold');
grid on;

% Save figure
figFile5 = fullfile(opts.saveDir, 'phase4_summary.png');
print(fig5, figFile5, '-dpng', sprintf('-r%d', opts.dpi));
figPaths{end+1} = figFile5;
fprintf('  Saved: %s\n', figFile5);

if strcmp(opts.visible, 'off')
    close(fig5);
end

end
