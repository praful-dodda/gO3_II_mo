function plotCBVresults(cbvResults, cbvStats, valParam, varargin)
% plotCBVresults - Create validation plots for CBV results with multi-method comparison
%
% SYNTAX:
%   plotCBVresults(cbvResults, cbvStats, valParam)
%   plotCBVresults(cbvResults, cbvStats, valParam, cbvStats2, cbvStats3, ...)
%
% INPUTS:
%   cbvResults - Cell array of results from runCBV_toar
%   cbvStats   - Table of statistics from runCBV_toar (first method)
%   valParam   - Validation parameters structure
%   varargin   - Additional cbvStats tables for method comparison
%
% OUTPUTS:
%   Creates figures showing validation results:
%   - Scatter plots for each box size/fold
%   - Performance metrics vs box size
%   - Multi-method comparison (if multiple stats provided)
%
% EXAMPLES:
%   % Single method
%   plotCBVresults(cbvResults, cbvStats, valParam);
%
%   % Compare multiple methods
%   plotCBVresults(results1, stats1, valParam1, stats2, stats3);

%% Create Figure Directory
figDir = fullfile('7validation', 'CBV', 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% Check for Multi-Method Comparison
nMethods = 1 + length(varargin);
multiMethod = (nMethods > 1);

if multiMethod
    fprintf('  Creating multi-method comparison plots (%d methods)...\n', nMethods);
    % Collect all stats tables
    allStats = cell(1, nMethods);
    allStats{1} = cbvStats;
    for i = 1:length(varargin)
        allStats{i+1} = varargin{i};
    end
end

%% Plot 1: Scatter Plots for Each Box Size/Fold (First Method Only)

nBoxSizes = size(cbvResults, 1);
nFolds = size(cbvResults, 2);

% Create subplot grid
figure('Position', [100 100 1200 800]);

for iBox = 1:nBoxSizes
    for iFold = 1:nFolds
        % Handle 2D or 3D cell array
        if ndims(cbvResults) == 3
            results = cbvResults{iBox, iFold, 1};  % First year
        else
            results = cbvResults{iBox, iFold};
        end

        subplot(nBoxSizes, nFolds, (iBox-1)*nFolds + iFold);

        if ~isempty(results) && isfield(results, 'Y_obs') && ~isempty(results.Y_obs)
            % Scatter plot
            scatter(results.Y_obs, results.Y_est, 20, 'filled', 'MarkerFaceAlpha', 0.3);
            hold on;

            % 1:1 line
            minVal = min([results.Y_obs; results.Y_est]);
            maxVal = max([results.Y_obs; results.Y_est]);
            plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 1);

            % Format
            xlabel('Observed (ppbv)');
            ylabel('Estimated (ppbv)');
            axis equal;
            grid on;

            % Get stats for this configuration
            idx = (cbvStats.BoxSize == valParam.boxSizes(iBox)) & ...
                  (cbvStats.Fold == iFold);
            if any(idx)
                stats = cbvStats(idx, :);
                title(sprintf('Box=%.0f°, Fold=%d\nR²=%.3f, RMSE=%.1f', ...
                    valParam.boxSizes(iBox), iFold, mean(stats.R2), mean(stats.RMSE)));
            end
        else
            text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center');
            axis off;
        end
    end
end

% Save
sgtitle(sprintf('CBV Scatter Plots - BME%s, GO%d', ...
    valParam.BMEmethod, valParam.goScenario));
saveas(gcf, fullfile(figDir, sprintf('CBV_scatter_BME%s_go%d.png', ...
    valParam.BMEmethod, valParam.goScenario)));

%% Plot 2: Performance vs Box Size (Single Method)

if height(cbvStats) > 0
    figure('Position', [150 150 1000 600]);

    % R² vs box size
    subplot(2, 2, 1);
    for iFold = 1:nFolds
        idx = cbvStats.Fold == iFold;
        if sum(idx) > 0
            plot(cbvStats.BoxSize(idx), cbvStats.R2(idx), 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
            hold on;
        end
    end
    xlabel('Box Size (degrees)');
    ylabel('R²');
    title('R² vs Box Size');
    legend('Location', 'best');
    grid on;

    % RMSE vs box size
    subplot(2, 2, 2);
    for iFold = 1:nFolds
        idx = cbvStats.Fold == iFold;
        if sum(idx) > 0
            plot(cbvStats.BoxSize(idx), cbvStats.RMSE(idx), 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
            hold on;
        end
    end
    xlabel('Box Size (degrees)');
    ylabel('RMSE (ppbv)');
    title('RMSE vs Box Size');
    legend('Location', 'best');
    grid on;

    % NMB vs box size
    subplot(2, 2, 3);
    for iFold = 1:nFolds
        idx = cbvStats.Fold == iFold;
        if sum(idx) > 0
            plot(cbvStats.BoxSize(idx), cbvStats.NMB(idx), 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
            hold on;
        end
    end
    xlabel('Box Size (degrees)');
    ylabel('NMB (%)');
    title('Normalized Mean Bias vs Box Size');
    legend('Location', 'best');
    grid on;
    yline(0, 'k--');

    % Sample size vs box size
    subplot(2, 2, 4);
    for iFold = 1:nFolds
        idx = cbvStats.Fold == iFold;
        if sum(idx) > 0
            plot(cbvStats.BoxSize(idx), cbvStats.N(idx), 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
            hold on;
        end
    end
    xlabel('Box Size (degrees)');
    ylabel('Validation Points');
    title('Sample Size vs Box Size');
    legend('Location', 'best');
    grid on;

    sgtitle(sprintf('CBV Performance Metrics - BME%s, GO%d', ...
        valParam.BMEmethod, valParam.goScenario));
    saveas(gcf, fullfile(figDir, sprintf('CBV_metrics_BME%s_go%d.png', ...
        valParam.BMEmethod, valParam.goScenario)));
end

%% Plot 3: Performance by Year (if multiple years)

if height(cbvStats) > 0 && isfield(cbvStats, 'Year')
    uniqueYears = unique(cbvStats.Year);

    if length(uniqueYears) > 1
        fprintf('  Creating year-by-year performance plots...\n');

        figure('Position', [175 175 1400 900]);

        % Metrics to plot
        metrics = {'R2', 'RMSE', 'MAE', 'NMB'};
        metricLabels = {'R²', 'RMSE (ppbv)', 'MAE (ppbv)', 'NMB (%)'};

        % Define colors for years
        yearColors = lines(length(uniqueYears));

        for iMetric = 1:length(metrics)
            subplot(2, 2, iMetric);
            hold on;

            for iYear = 1:length(uniqueYears)
                year = uniqueYears(iYear);

                % Get data for this year (averaged across folds)
                yearIdx = cbvStats.Year == year;
                uniqueBoxSizes = unique(cbvStats.BoxSize(yearIdx));
                avgMetric = zeros(size(uniqueBoxSizes));

                for iBox = 1:length(uniqueBoxSizes)
                    boxSize = uniqueBoxSizes(iBox);
                    boxIdx = cbvStats.BoxSize == boxSize & cbvStats.Year == year;
                    avgMetric(iBox) = mean(cbvStats.(metrics{iMetric})(boxIdx));
                end

                % Plot
                plot(uniqueBoxSizes, avgMetric, 'o-', ...
                    'Color', yearColors(iYear, :), ...
                    'LineWidth', 2, 'MarkerSize', 8, ...
                    'DisplayName', sprintf('%d', year));
            end

            xlabel('Box Size (degrees)');
            ylabel(metricLabels{iMetric});
            title(sprintf('%s vs Box Size by Year', metricLabels{iMetric}));
            legend('Location', 'best');
            grid on;

            % Add reference line for NMB
            if strcmp(metrics{iMetric}, 'NMB')
                yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end

        sgtitle(sprintf('CBV Performance by Year - BME%s, GO%d', ...
            valParam.BMEmethod, valParam.goScenario));
        saveas(gcf, fullfile(figDir, sprintf('CBV_by_year_BME%s_go%d.png', ...
            valParam.BMEmethod, valParam.goScenario)));
    end
end

%% Plot 4: Multi-Method Comparison (if multiple methods provided)

if multiMethod
    fprintf('  Creating multi-method comparison...\n');

    % Define colors for methods
    colors = lines(nMethods);

    % Define method names from BME codes
    methodNames = cell(1, nMethods);
    methodNames{1} = cbvStats.Properties.UserData.BMEmethod;
    if isempty(methodNames{1})
        methodNames{1} = valParam.BMEmethod;
    end
    for i = 2:nMethods
        if ~isempty(allStats{i}.Properties.UserData) && ...
           isfield(allStats{i}.Properties.UserData, 'BMEmethod')
            methodNames{i} = allStats{i}.Properties.UserData.BMEmethod;
        else
            methodNames{i} = sprintf('Method %d', i);
        end
    end

    % Create comparison figure
    figure('Position', [200 200 1400 900]);

    % Metrics to compare
    metrics = {'R2', 'RMSE', 'MAE', 'NMB'};
    metricLabels = {'R²', 'RMSE (ppbv)', 'MAE (ppbv)', 'NMB (%)'};

    for iMetric = 1:length(metrics)
        subplot(2, 2, iMetric);
        hold on;

        for iMethod = 1:nMethods
            stats = allStats{iMethod};

            % Average across folds and years for each box size
            uniqueBoxSizes = unique(stats.BoxSize);
            avgMetric = zeros(size(uniqueBoxSizes));

            for iBox = 1:length(uniqueBoxSizes)
                boxSize = uniqueBoxSizes(iBox);
                idx = stats.BoxSize == boxSize;
                avgMetric(iBox) = mean(stats.(metrics{iMetric})(idx));
            end

            % Plot with error bars (std across folds/years)
            plot(uniqueBoxSizes, avgMetric, 'o-', ...
                'Color', colors(iMethod, :), ...
                'LineWidth', 2, 'MarkerSize', 8, ...
                'DisplayName', methodNames{iMethod});
        end

        xlabel('Box Size (degrees)');
        ylabel(metricLabels{iMetric});
        title(sprintf('%s vs Box Size', metricLabels{iMetric}));
        legend('Location', 'best', 'Interpreter', 'none');
        grid on;

        % Add reference line for NMB
        if strcmp(metrics{iMetric}, 'NMB')
            yline(0, 'k--', 'LineWidth', 1);
        end
    end

    sgtitle('Multi-Method CBV Comparison');
    saveas(gcf, fullfile(figDir, 'CBV_multimethod_comparison.png'));

    %% Plot 5: Method Comparison by Fold
    figure('Position', [250 250 1400 600]);

    for iMetric = 1:2  % Just R2 and RMSE for fold comparison
        subplot(1, 2, iMetric);
        hold on;

        for iMethod = 1:nMethods
            stats = allStats{iMethod};

            % Separate by fold
            for iFold = 1:2
                idx = stats.Fold == iFold;
                if sum(idx) > 0
                    uniqueBoxSizes = unique(stats.BoxSize(idx));
                    avgMetric = zeros(size(uniqueBoxSizes));

                    for iBox = 1:length(uniqueBoxSizes)
                        boxSize = uniqueBoxSizes(iBox);
                        boxIdx = stats.BoxSize == boxSize & stats.Fold == iFold;
                        avgMetric(iBox) = mean(stats.(metrics{iMetric})(boxIdx));
                    end

                    % Use different line styles for folds
                    if iFold == 1
                        lineStyle = '-';
                    else
                        lineStyle = '--';
                    end

                    plot(uniqueBoxSizes, avgMetric, lineStyle, ...
                        'Color', colors(iMethod, :), ...
                        'LineWidth', 2, 'MarkerSize', 6, 'Marker', 'o', ...
                        'DisplayName', sprintf('%s (Fold %d)', methodNames{iMethod}, iFold));
                end
            end
        end

        xlabel('Box Size (degrees)');
        ylabel(metricLabels{iMetric});
        title(sprintf('%s by Method and Fold', metricLabels{iMetric}));
        legend('Location', 'best', 'Interpreter', 'none');
        grid on;
    end

    sgtitle('Multi-Method CBV Comparison by Fold');
    saveas(gcf, fullfile(figDir, 'CBV_multimethod_by_fold.png'));
end

fprintf('  Plots saved to: %s\n', figDir);

end
