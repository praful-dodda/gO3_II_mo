function plotCBVresults(cbvResults, cbvStats, valParam, varargin)
% plotCBVresults - Create validation plots for CBV results
%
% SYNTAX:
%   plotCBVresults(cbvResults, cbvStats, valParam)
%   plotCBVresults(cbvResults, cbvStats, valParam, cbvStats2, cbvStats3, ...)
%
% INPUTS:
%   cbvResults - Cell array of results from runCBV_toar
%   cbvStats   - Table of statistics from runCBV_toar (method 1)
%   valParam   - Validation parameters structure
%   varargin   - Additional cbvStats tables for comparison (optional)
%
% DESCRIPTION:
%   Creates scatter plots and performance comparison plots.
%   If multiple cbvStats tables are provided, creates comparison plots
%   showing performance across different methods and box sizes.
%
% EXAMPLES:
%   % Single method
%   plotCBVresults(results, stats, valParam);
%
%   % Compare multiple methods
%   plotCBVresults(results1, stats1, valParam, stats2, stats3);

%% Create Figure Directory
figDir = fullfile('7validation', 'CBV', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

%% Check for Multiple Methods
multipleMethod = ~isempty(varargin);
if ~isempty(varargin)
    multipleMethod = true;
    nMethods = 1 + length(varargin);  % First stats + additional
    allStats = cell(1, nMethods);
    allStats{1} = cbvStats;
    for i = 1:length(varargin)
        allStats{i+1} = varargin{i};
    end

    % Get method names from BME codes if available
    methodNames = cell(1, nMethods);
    if isfield(valParam, 'BMEmethod')
        methodNames{1} = valParam.BMEmethod;
    else
        methodNames{1} = 'Method 1';
    end
    for i = 2:nMethods
        methodNames{i} = sprintf('Method %d', i);
    end
else
    multipleMethod = false;
    nMethods = 1;
end

%% Plot 1: Performance vs Box Size (Comparison Across Methods)
if multipleMethod
    figure('Position', [100 100 1200 800]);

    metrics = {'r2', 'RMSE', 'MAE', 'ME'};
    metricLabels = {'R²', 'RMSE (ppbv)', 'MAE (ppbv)', 'ME (ppbv)'};
    colors = lines(nMethods);

    for iMetric = 1:4
        subplot(2, 2, iMetric);

        for iMethod = 1:nMethods
            stats = allStats{iMethod};

            if isempty(stats), continue; end

            % Average across folds and years for each box size
            boxSizes = unique(stats.BoxSize);
            metricValues = zeros(length(boxSizes), 1);

            for iBox = 1:length(boxSizes)
                idx = stats.BoxSize == boxSizes(iBox);
                if any(idx)
                    metricValues(iBox) = mean(stats.(metrics{iMetric})(idx), 'omitnan');
                end
            end

            plot(boxSizes, metricValues, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
                'Color', colors(iMethod,:), 'DisplayName', methodNames{iMethod});
            hold on;
        end

        xlabel('Box Size (degrees)');
        ylabel(metricLabels{iMetric});
        title(sprintf('%s vs Box Size', metricLabels{iMetric}));
        legend('Location', 'best');
        grid on;
    end

    sgtitle('CBV Performance: Method Comparison Across Box Sizes');
    saveas(gcf, fullfile(figDir, 'CBV_method_comparison.png'));
end

%% Plot 2: Detailed Performance for Primary Method
figure('Position', [150 150 1200 900]);

boxSizes = unique(cbvStats.BoxSize);
nBoxSizes = length(boxSizes);

% R² vs box size (by fold)
subplot(3, 2, 1);
for iFold = unique(cbvStats.Fold)'
    idx = cbvStats.Fold == iFold;
    boxSizeFold = cbvStats.BoxSize(idx);
    r2Fold = cbvStats.r2(idx);

    [boxSorted, sortIdx] = sort(boxSizeFold);
    plot(boxSorted, r2Fold(sortIdx), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'DisplayName', sprintf('Fold %d', iFold));
    hold on;
end
xlabel('Box Size (°)');
ylabel('R²');
title('R² vs Box Size');
legend('Location', 'best');
grid on;

% RMSE vs box size
subplot(3, 2, 2);
for iFold = unique(cbvStats.Fold)'
    idx = cbvStats.Fold == iFold;
    boxSizeFold = cbvStats.BoxSize(idx);
    rmseFold = cbvStats.RMSE(idx);

    [boxSorted, sortIdx] = sort(boxSizeFold);
    plot(boxSorted, rmseFold(sortIdx), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'DisplayName', sprintf('Fold %d', iFold));
    hold on;
end
xlabel('Box Size (°)');
ylabel('RMSE (ppbv)');
title('RMSE vs Box Size');
legend('Location', 'best');
grid on;

% MAE vs box size
subplot(3, 2, 3);
for iFold = unique(cbvStats.Fold)'
    idx = cbvStats.Fold == iFold;
    boxSizeFold = cbvStats.BoxSize(idx);
    maeFold = cbvStats.MAE(idx);

    [boxSorted, sortIdx] = sort(boxSizeFold);
    plot(boxSorted, maeFold(sortIdx), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'DisplayName', sprintf('Fold %d', iFold));
    hold on;
end
xlabel('Box Size (°)');
ylabel('MAE (ppbv)');
title('MAE vs Box Size');
legend('Location', 'best');
grid on;

% ME (bias) vs box size
subplot(3, 2, 4);
for iFold = unique(cbvStats.Fold)'
    idx = cbvStats.Fold == iFold;
    boxSizeFold = cbvStats.BoxSize(idx);
    meFold = cbvStats.ME(idx);

    [boxSorted, sortIdx] = sort(boxSizeFold);
    plot(boxSorted, meFold(sortIdx), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'DisplayName', sprintf('Fold %d', iFold));
    hold on;
end
xlabel('Box Size (°)');
ylabel('ME (ppbv)');
title('Mean Error vs Box Size');
legend('Location', 'best');
grid on;
yline(0, 'k--', 'LineWidth', 1);

% Sample size vs box size
subplot(3, 2, 5);
for iFold = unique(cbvStats.Fold)'
    idx = cbvStats.Fold == iFold;
    boxSizeFold = cbvStats.BoxSize(idx);
    nFold = cbvStats.N(idx);

    [boxSorted, sortIdx] = sort(boxSizeFold);
    plot(boxSorted, nFold(sortIdx), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'DisplayName', sprintf('Fold %d', iFold));
    hold on;
end
xlabel('Box Size (°)');
ylabel('Validation Points');
title('Sample Size vs Box Size');
legend('Location', 'best');
grid on;

% r² scatter (average performance)
subplot(3, 2, 6);
meanR2 = zeros(nBoxSizes, 1);
meanRMSE = zeros(nBoxSizes, 1);
for iBox = 1:nBoxSizes
    idx = cbvStats.BoxSize == boxSizes(iBox);
    meanR2(iBox) = mean(cbvStats.r2(idx));
    meanRMSE(iBox) = mean(cbvStats.RMSE(idx));
end

yyaxis left
bar(boxSizes, meanR2);
ylabel('Mean R²');
ylim([0 1]);

yyaxis right
plot(boxSizes, meanRMSE, 'ro-', 'LineWidth', 2, 'MarkerSize', 10);
ylabel('Mean RMSE (ppbv)');

xlabel('Box Size (°)');
title('Average Performance by Box Size');
grid on;

sgtitle(sprintf('CBV Detailed Performance - BME%s, GO%d', ...
    valParam.BMEmethod, valParam.goScenario));
saveas(gcf, fullfile(figDir, sprintf('CBV_detailed_BME%s_go%d.png', ...
    valParam.BMEmethod, valParam.goScenario)));

%% Plot 3: Scatter Plots (if cbvResults provided)
if ~isempty(cbvResults)
    % Create scatter plots for representative cases
    figure('Position', [200 200 1400 800]);

    nPlots = min(nBoxSizes * 2, 6);  % Max 6 subplots
    plotIdx = 1;

    for iBox = 1:min(nBoxSizes, 3)
        boxSize = boxSizes(iBox);

        for iFold = 1:2
            if plotIdx > nPlots, break; end

            % Collect all monthly results for this configuration
            Y_obs_all = [];
            Y_est_all = [];

            for iYear = 1:size(cbvResults, 3)
                for iMonth = 1:size(cbvResults, 4)
                    monthRes = cbvResults{iBox, iFold, iYear, iMonth};
                    if ~isempty(monthRes) && monthRes.nValid > 0
                        Y_obs_all = [Y_obs_all; monthRes.Y_obs];
                        Y_est_all = [Y_est_all; monthRes.Y_est];
                    end
                end
            end

            if isempty(Y_obs_all), continue; end

            subplot(2, 3, plotIdx);

            % Scatter plot
            scatter(Y_obs_all, Y_est_all, 20, 'filled', 'MarkerFaceAlpha', 0.3);
            hold on;

            % 1:1 line
            minVal = min([Y_obs_all; Y_est_all]);
            maxVal = max([Y_obs_all; Y_est_all]);
            plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 1.5);

            % Get stats
            idx = (cbvStats.BoxSize == boxSize) & (cbvStats.Fold == iFold);
            if any(idx)
                stats = cbvStats(idx, :);
                meanR2 = mean(stats.r2);
                meanRMSE = mean(stats.RMSE);

                title(sprintf('Box=%.0f°, Fold=%d\nr²=%.3f, RMSE=%.1f ppbv', ...
                    boxSize, iFold, meanR2, meanRMSE));
            else
                title(sprintf('Box=%.0f°, Fold=%d', boxSize, iFold));
            end

            xlabel('Observed (ppbv)');
            ylabel('Estimated (ppbv)');
            axis equal tight;
            grid on;

            plotIdx = plotIdx + 1;
        end
    end

    sgtitle(sprintf('CBV Scatter Plots - BME%s, GO%d', ...
        valParam.BMEmethod, valParam.goScenario));
    saveas(gcf, fullfile(figDir, sprintf('CBV_scatter_BME%s_go%d.png', ...
        valParam.BMEmethod, valParam.goScenario)));
end

fprintf('  Plots saved to: %s\n', figDir);

end
