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

%% Figure 1: Time-series with all metrics (multi-panel)
fig1 = figure('Visible', opts.visible, 'Position', [100, 100, 1600, 350*nMetrics]);

for iMetric = 1:nMetrics
    subplot(nMetrics, 1, iMetric);
    hold on;

    metric = metrics{iMetric};

    % Plot each configuration
    for iConfig = 1:nConfigs
        % Extract values for this config and metric
        values = squeeze(yearlyData.values(iConfig, :, iMetric));

        % Plot with assigned style (NaN creates gaps automatically)
        plot(allYears, values, ...
            'LineStyle', lineStyles{iConfig}, ...
            'Color', colors(iConfig, :), ...
            'Marker', markers{iConfig}, ...
            'LineWidth', lineWidths(iConfig), ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', colors(iConfig, :), ...
            'DisplayName', configs(iConfig).name);
    end

    % Formatting
    xlabel('Year');
    ylabel(metric);
    title(sprintf('%s Over Time', metric), 'FontSize', 11, 'FontWeight', 'bold');

    % Set x-axis to show all years
    xlim([min(allYears)-0.5, max(allYears)+0.5]);
    xticks(allYears);

    % Add grid
    grid on;
    box on;

    hold off;
end

% Add shared legend at bottom
lgd = legend('Location', 'southoutside', 'Orientation', 'horizontal', 'NumColumns', min(4, nConfigs));
lgd.Position(2) = 0.01;  % Move legend to very bottom

% Overall title
sgtitle('Phase 4: Time-Series Performance Analysis', 'FontSize', 14, 'FontWeight', 'bold');

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
    set(gca, 'XTickLabelRotation', 45);

    xlabel('Year');
    ylabel('Configuration');
    title(sprintf('Year-over-Year %s Heatmap', metrics{primaryMetricIdx}), ...
        'FontSize', 12, 'FontWeight', 'bold');

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
                    'Color', textColor, 'FontSize', 8);
            else
                text(iYear, iConfig, 'N/A', ...
                    'HorizontalAlignment', 'center', ...
                    'Color', [0.5, 0.5, 0.5], 'FontSize', 8);
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
        fig3 = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 500]);

        metric = metrics{iMetric};
        hold on;

        % Plot each configuration with markers
        for iConfig = 1:nConfigs
            values = squeeze(yearlyData.values(iConfig, :, iMetric));

            plot(allYears, values, ...
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

        legend('Location', 'best');
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

    ylabel(metric);
    title(sprintf('Best Configuration by Year (%s)', metric), 'FontSize', 11);
    ylim([0, 1.2]);
    set(gca, 'YTick', [0, 1], 'YTickLabel', {'', 'Winner'});
    xlim([min(allYears)-0.5, max(allYears)+0.5]);
    xticks(allYears);
    grid on;

    if iMetric == nMetrics
        xlabel('Year');
    end
end

% Add legend at bottom
lgd = legend({configs.name}, 'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'NumColumns', min(4, nConfigs));
lgd.Position(2) = 0.01;

sgtitle('Winner Analysis by Year and Metric', 'FontSize', 14, 'FontWeight', 'bold');

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

% Create grouped bar chart
barWidth = 0.8;
x = 1:nConfigs;
b = bar(x, avgMetrics, barWidth);

% Apply colors to bars (color each group by configuration)
for iConfig = 1:nConfigs
    % For grouped bars, we need to set edge colors instead
end

% Alternative: Create side-by-side comparison
set(gca, 'XTick', x, 'XTickLabel', {configs.name}, 'XTickLabelRotation', 45);
xlabel('Configuration');
ylabel('Metric Value');
title('Average Performance Across Years', 'FontSize', 12, 'FontWeight', 'bold');
legend(metrics, 'Location', 'best');
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
