function plotCBCVresults(cbcvResults, cbcvStats, valParam)
% plotCBCVresults - Create validation plots for CBCV results
%
% SYNTAX:
%   plotCBCVresults(cbcvResults, cbcvStats, valParam)
%
% INPUTS:
%   cbcvResults - Cell array of results from runCBCV_toar
%   cbcvStats   - Table of statistics from runCBCV_toar
%   valParam    - Validation parameters structure
%
% OUTPUTS:
%   Creates figures showing validation results

%% Create Figure Directory
figDir = fullfile('7validation', 'CBCV', 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% Plot 1: Scatter Plots for Each Box Size/Fold

nBoxSizes = size(cbcvResults, 1);
nFolds = size(cbcvResults, 2);

% Create subplot grid
figure('Position', [100 100 1200 800]);

for iBox = 1:nBoxSizes
    for iFold = 1:nFolds
        subplot(nBoxSizes, nFolds, (iBox-1)*nFolds + iFold);

        results = cbcvResults{iBox, iFold};

        if ~isempty(results) && results.nVal > 0
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
            idx = (cbcvStats.BoxSize == valParam.boxSizes(iBox)) & ...
                  (cbcvStats.Fold == iFold);
            if any(idx)
                stats = cbcvStats(idx, :);
                title(sprintf('Box=%.0f°, Fold=%d\nR²=%.3f, RMSE=%.1f', ...
                    valParam.boxSizes(iBox), iFold, stats.R2, stats.RMSE));
            end
        else
            text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center');
            axis off;
        end
    end
end

% Save
sgtitle(sprintf('CBCV Scatter Plots - BME%s, GO%d', ...
    valParam.BMEmethod, valParam.goScenario));
saveas(gcf, fullfile(figDir, sprintf('CBCV_scatter_BME%s_go%d.png', ...
    valParam.BMEmethod, valParam.goScenario)));

%% Plot 2: Performance vs Box Size

if height(cbcvStats) > 0
    figure('Position', [150 150 1000 600]);

    % R² vs box size
    subplot(2, 2, 1);
    for iFold = 1:nFolds
        idx = cbcvStats.Fold == iFold;
        plot(cbcvStats.BoxSize(idx), cbcvStats.R2(idx), 'o-', ...
            'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
        hold on;
    end
    xlabel('Box Size (degrees)');
    ylabel('R²');
    title('R² vs Box Size');
    legend('Location', 'best');
    grid on;

    % RMSE vs box size
    subplot(2, 2, 2);
    for iFold = 1:nFolds
        idx = cbcvStats.Fold == iFold;
        plot(cbcvStats.BoxSize(idx), cbcvStats.RMSE(idx), 'o-', ...
            'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
        hold on;
    end
    xlabel('Box Size (degrees)');
    ylabel('RMSE (ppbv)');
    title('RMSE vs Box Size');
    legend('Location', 'best');
    grid on;

    % NMB vs box size
    subplot(2, 2, 3);
    for iFold = 1:nFolds
        idx = cbcvStats.Fold == iFold;
        plot(cbcvStats.BoxSize(idx), cbcvStats.NMB(idx), 'o-', ...
            'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
        hold on;
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
        idx = cbcvStats.Fold == iFold;
        plot(cbcvStats.BoxSize(idx), cbcvStats.nVal(idx), 'o-', ...
            'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', sprintf('Fold %d', iFold));
        hold on;
    end
    xlabel('Box Size (degrees)');
    ylabel('Validation Points');
    title('Sample Size vs Box Size');
    legend('Location', 'best');
    grid on;

    sgtitle(sprintf('CBCV Performance Metrics - BME%s, GO%d', ...
        valParam.BMEmethod, valParam.goScenario));
    saveas(gcf, fullfile(figDir, sprintf('CBCV_metrics_BME%s_go%d.png', ...
        valParam.BMEmethod, valParam.goScenario)));
end

fprintf('  Plots saved to: %s\n', figDir);

end
