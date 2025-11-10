function aggregate_results(goScenarios, valYears)
% aggregate_results - Aggregate and compare validation results from all GO scenarios
%
% SYNTAX:
%   aggregate_results(goScenarios, valYears)
%
% INPUTS:
%   goScenarios - Vector of GO scenarios to compare (e.g., [2 3 6 7])
%   valYears    - Years validated (e.g., [2016 2017 2018 2019])
%
% EXAMPLE:
%   aggregate_results([2 3 6 7], [2016 2017 2018 2019])

if nargin < 1, goScenarios = [2 3 6 7]; end
if nargin < 2, valYears = [2016 2017 2018 2019]; end

fprintf('\n========================================\n');
fprintf('  AGGREGATE VALIDATION RESULTS\n');
fprintf('========================================\n');
fprintf('GO Scenarios: %s\n', mat2str(goScenarios));
fprintf('Years: %s\n', mat2str(valYears));

%% Load All Results
resultsDir = fullfile('..', '7validation', 'hpc_results');

if ~exist(resultsDir, 'dir')
    error('Results directory not found: %s', resultsDir);
end

nScenarios = length(goScenarios);
results = cell(nScenarios, 1);
summaries = cell(nScenarios, 1);

fprintf('\nLoading results...\n');
for i = 1:nScenarios
    go = goScenarios(i);

    filename = sprintf('validation_summary_go%d_y%s.mat', go, mat2str(valYears));
    filepath = fullfile(resultsDir, filename);

    if exist(filepath, 'file')
        fprintf('  GO %d: Loading %s\n', go, filename);
        load(filepath, 'summary', 'valOut', 'valPairOut');
        results{i}.valOut = valOut;
        results{i}.valPairOut = valPairOut;
        summaries{i} = summary;
    else
        warning('  GO %d: Results not found (%s)', go, filename);
        results{i} = [];
        summaries{i} = [];
    end
end

%% Create Comparison Table
fprintf('\n========================================\n');
fprintf('  VALIDATION STATISTICS COMPARISON\n');
fprintf('========================================\n');

% Extract metrics
metrics = {'PearsonR', 'R2', 'RMSE', 'MAE', 'ME', 'MBE', 'NMB', 'NME', 'IOA', 'FAC2', 'N'};
nMetrics = length(metrics);

comparisonTable = table();
comparisonTable.Metric = metrics';

for i = 1:nScenarios
    if ~isempty(results{i})
        go = goScenarios(i);
        colName = sprintf('GO_%d', go);

        values = NaN(nMetrics, 1);
        for m = 1:nMetrics
            metric = metrics{m};
            if isfield(results{i}.valOut, metric)
                values(m) = results{i}.valOut.(metric);
            end
        end

        comparisonTable.(colName) = values;
    end
end

disp(comparisonTable);

%% Identify Best Scenario
fprintf('\n========================================\n');
fprintf('  BEST PERFORMING SCENARIOS\n');
fprintf('========================================\n');

% Higher is better
higherBetter = {'PearsonR', 'R2', 'IOA', 'FAC2'};
% Lower is better
lowerBetter = {'RMSE', 'MAE', 'ME', 'MBE', 'NMB', 'NME'};

for m = 1:length(higherBetter)
    metric = higherBetter{m};
    if ismember(metric, comparisonTable.Metric)
        idx = find(strcmp(comparisonTable.Metric, metric));

        vals = [];
        validGOs = [];
        for i = 1:nScenarios
            colName = sprintf('GO_%d', goScenarios(i));
            if ismember(colName, comparisonTable.Properties.VariableNames)
                vals(end+1) = comparisonTable.(colName)(idx);
                validGOs(end+1) = goScenarios(i);
            end
        end

        if ~isempty(vals) && ~all(isnan(vals))
            [maxVal, maxIdx] = max(vals);
            fprintf('  %8s: GO %d (%.4f)\n', metric, validGOs(maxIdx), maxVal);
        end
    end
end

for m = 1:length(lowerBetter)
    metric = lowerBetter{m};
    if ismember(metric, comparisonTable.Metric)
        idx = find(strcmp(comparisonTable.Metric, metric));

        vals = [];
        validGOs = [];
        for i = 1:nScenarios
            colName = sprintf('GO_%d', goScenarios(i));
            if ismember(colName, comparisonTable.Properties.VariableNames)
                vals(end+1) = comparisonTable.(colName)(idx);
                validGOs(end+1) = goScenarios(i);
            end
        end

        if ~isempty(vals) && ~all(isnan(vals))
            [minVal, minIdx] = min(vals);
            fprintf('  %8s: GO %d (%.4f)\n', metric, validGOs(minIdx), minVal);
        end
    end
end

%% Create Comparison Plots
fprintf('\n========================================\n');
fprintf('  CREATING COMPARISON PLOTS\n');
fprintf('========================================\n');

plotDir = fullfile('..', '7validation', 'comparison_plots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

% Figure 1: Metrics Bar Chart
figure('Position', [100 100 1200 800], 'Color', 'w');

metricsToPlot = {'PearsonR', 'R2', 'RMSE', 'MAE', 'NMB', 'IOA'};
nSubplots = length(metricsToPlot);
nRows = 2;
nCols = 3;

for m = 1:nSubplots
    subplot(nRows, nCols, m);

    metric = metricsToPlot{m};
    if ismember(metric, comparisonTable.Metric)
        idx = find(strcmp(comparisonTable.Metric, metric));

        vals = [];
        labels = {};
        for i = 1:nScenarios
            colName = sprintf('GO_%d', goScenarios(i));
            if ismember(colName, comparisonTable.Properties.VariableNames)
                vals(end+1) = comparisonTable.(colName)(idx);
                labels{end+1} = sprintf('GO %d', goScenarios(i));
            end
        end

        bar(vals, 'FaceColor', 'b', 'EdgeColor', 'k');
        set(gca, 'XTickLabel', labels);
        ylabel(metric, 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('%s Comparison', metric), 'FontSize', 14);
        grid on;

        % Highlight best
        if ismember(metric, higherBetter)
            [~, bestIdx] = max(vals);
        else
            [~, bestIdx] = min(vals);
        end
        hold on;
        bar(bestIdx, vals(bestIdx), 'FaceColor', 'g', 'EdgeColor', 'k');
    end
end

sgtitle('Validation Metrics Comparison Across GO Scenarios', ...
    'FontSize', 16, 'FontWeight', 'bold');

filename = sprintf('metrics_comparison_go%s_y%s.png', ...
    mat2str(goScenarios), mat2str(valYears));
print(fullfile(plotDir, filename), '-dpng', '-r300');
fprintf('  Saved: %s\n', filename);

% Figure 2: Scatter Plots
figure('Position', [100 100 1400 1000], 'Color', 'w');

validScenarios = find(~cellfun(@isempty, results));
nValid = length(validScenarios);

for i = 1:nValid
    subplot(2, 2, i);

    idx = validScenarios(i);
    go = goScenarios(idx);

    Y_obs = results{idx}.valPairOut.Y_obs;
    Y_est = results{idx}.valPairOut.Y_est;

    scatter(Y_obs, Y_est, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;

    minVal = min([Y_obs; Y_est]);
    maxVal = max([Y_obs; Y_est]);
    plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 2);

    axis equal;
    xlim([minVal maxVal]);
    ylim([minVal maxVal]);
    grid on;

    xlabel('Observed (ppb)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Predicted (ppb)', 'FontSize', 11, 'FontWeight', 'bold');

    statsText = sprintf('GO Scenario %d\nR² = %.3f\nRMSE = %.2f ppb\nN = %d', ...
        go, results{idx}.valOut.R2, results{idx}.valOut.RMSE, results{idx}.valOut.N);

    text(0.05, 0.95, statsText, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', 'white', 'EdgeColor', 'black');
end

sgtitle('Observed vs Predicted by GO Scenario', ...
    'FontSize', 16, 'FontWeight', 'bold');

filename = sprintf('scatter_comparison_go%s_y%s.png', ...
    mat2str(goScenarios), mat2str(valYears));
print(fullfile(plotDir, filename), '-dpng', '-r300');
fprintf('  Saved: %s\n', filename);

%% Save Comparison Table
comparisonFile = sprintf('comparison_table_go%s_y%s.csv', ...
    mat2str(goScenarios), mat2str(valYears));
writetable(comparisonTable, fullfile(plotDir, comparisonFile));
fprintf('  Saved: %s\n', comparisonFile);

%% Timing Summary
fprintf('\n========================================\n');
fprintf('  COMPUTATIONAL TIMING SUMMARY\n');
fprintf('========================================\n');

for i = 1:nScenarios
    if ~isempty(summaries{i})
        go = goScenarios(i);
        fprintf('\nGO Scenario %d:\n', go);
        fprintf('  Data loading:    %8.1f sec\n', summaries{i}.timing.dataLoad);
        fprintf('  Global offset:   %8.1f sec\n', summaries{i}.timing.globalOffset);
        fprintf('  Covariance:      %8.1f sec\n', summaries{i}.timing.covariance);
        fprintf('  Validation:      %8.1f sec (%.1f min)\n', ...
            summaries{i}.timing.validation, summaries{i}.timing.validation/60);
        fprintf('  Total:           %8.1f sec (%.1f min)\n', ...
            summaries{i}.timing.total, summaries{i}.timing.total/60);
        fprintf('  Hostname:        %s\n', summaries{i}.jobInfo.hostname);
        fprintf('  Completed:       %s\n', summaries{i}.jobInfo.completedAt);
    end
end

fprintf('\n========================================\n');
fprintf('  AGGREGATION COMPLETE\n');
fprintf('========================================\n');
fprintf('Plots saved to: %s\n', plotDir);
fprintf('\n');

close all;

end
