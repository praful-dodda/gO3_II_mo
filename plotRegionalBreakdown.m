function figPaths = plotRegionalBreakdown(resultsData, varargin)
% plotRegionalBreakdown - Detailed regional performance analysis
%
% Creates comprehensive regional breakdown plots showing performance
% metrics, sample sizes, and spatial patterns by geographic region.
%
% SYNTAX:
%   figPaths = plotRegionalBreakdown(resultsData)
%   figPaths = plotRegionalBreakdown(resultsData, 'Name', Value, ...)
%
% INPUTS:
%   resultsData - Structure or struct array with fields:
%                 .Y_obs    - Observed values
%                 .Y_est    - Estimated values
%                 .sk       - Spatial coordinates [lon, lat]
%                 Optional: .regions, .BoxSize, .Year, etc.
%
% OPTIONAL PARAMETERS:
%   'saveDir'     - Directory to save figures (default: './figs_regional')
%   'dpi'         - Figure resolution (default: 300)
%   'visible'     - 'on' or 'off' for figure visibility (default: 'off')
%   'titlePrefix' - Prefix for figure titles (default: '')
%   'regions'     - Cell array of region labels (auto-assigned if not provided)
%   'metrics'     - Cell array of metrics to compute (default: {'R2', 'RMSE', 'MAE', 'NMB'})
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% CREATED PLOTS:
%   1. Regional performance summary table (heatmap)
%   2. Regional scatter plots (grid of regions)
%   3. Regional sample size map
%   4. Regional metric comparison (bar charts)
%
% EXAMPLE:
%   % From CBV results
%   data = load('./7validation/CBV/CBV_*.mat');
%   resultsData.Y_obs = data.annualResults.Y_obs;
%   resultsData.Y_est = data.annualResults.Y_est;
%   resultsData.sk = data.annualResults.sk;
%   figPaths = plotRegionalBreakdown(resultsData);

%% Parse inputs
p = inputParser;
addRequired(p, 'resultsData', @isstruct);
addParameter(p, 'saveDir', './figs_regional', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'titlePrefix', '', @ischar);
addParameter(p, 'regions', [], @iscell);
addParameter(p, 'metrics', {'R2', 'RMSE', 'MAE', 'NMB'}, @iscell);

parse(p, resultsData, varargin{:});
opts = p.Results;

if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('=== Regional Performance Breakdown ===\n');

figPaths = {};

%% Aggregate data if struct array
if length(resultsData) > 1
    Y_obs = [];
    Y_est = [];
    sk = [];
    regions = {};

    for i = 1:length(resultsData)
        Y_obs = [Y_obs; resultsData(i).Y_obs(:)];
        Y_est = [Y_est; resultsData(i).Y_est(:)];
        sk = [sk; resultsData(i).sk];
        if isfield(resultsData(i), 'regions')
            regions = [regions; resultsData(i).regions(:)];
        end
    end
else
    Y_obs = resultsData.Y_obs(:);
    Y_est = resultsData.Y_est(:);
    sk = resultsData.sk;
    regions = {};
    if isfield(resultsData, 'regions')
        regions = resultsData.regions(:);
    end
end

% Filter valid data
validIdx = ~isnan(Y_obs) & ~isnan(Y_est);
Y_obs = Y_obs(validIdx);
Y_est = Y_est(validIdx);
sk = sk(validIdx, :);

% Assign regions if not provided
if isempty(regions)
    if ~isempty(opts.regions)
        regions = opts.regions(validIdx);
    else
        regions = assignRegions(sk(:,1), sk(:,2));
    end
else
    regions = regions(validIdx);
end

uniqueRegions = unique(regions);
nRegions = length(uniqueRegions);

fprintf('  Found %d regions\n', nRegions);
fprintf('  Total valid observations: %d\n', length(Y_obs));

%% Compute regional statistics
regionalStats = struct();
for i = 1:nRegions
    region = uniqueRegions{i};
    regionMask = strcmp(regions, region);

    Y_obs_reg = Y_obs(regionMask);
    Y_est_reg = Y_est(regionMask);

    regionalStats(i).region = region;
    regionalStats(i).N = length(Y_obs_reg);
    regionalStats(i).R2 = calculateR2(Y_obs_reg, Y_est_reg);
    regionalStats(i).RMSE = sqrt(mean((Y_obs_reg - Y_est_reg).^2));
    regionalStats(i).MAE = mean(abs(Y_obs_reg - Y_est_reg));
    regionalStats(i).NMB = 100 * mean(Y_est_reg - Y_obs_reg) / mean(Y_obs_reg);
    regionalStats(i).MeanObs = mean(Y_obs_reg);
    regionalStats(i).MeanEst = mean(Y_est_reg);

    fprintf('  %s: N=%d, R²=%.3f, RMSE=%.2f\n', region, regionalStats(i).N, ...
        regionalStats(i).R2, regionalStats(i).RMSE);
end

%% Plot 1: Regional performance heatmap
figPaths = [figPaths; plotRegionalHeatmap(regionalStats, opts)];

%% Plot 2: Regional scatter plots
figPaths = [figPaths; plotRegionalScatters(Y_obs, Y_est, regions, uniqueRegions, opts)];

%% Plot 3: Regional sample size map
figPaths = [figPaths; plotRegionalSampleMap(sk, regions, uniqueRegions, opts)];

%% Plot 4: Regional metric comparison
figPaths = [figPaths; plotRegionalMetrics(regionalStats, opts)];

fprintf('=== Regional breakdown complete: %d figures created ===\n', length(figPaths));

end

%% ========================================================================
%% SUBFUNCTION: Regional Performance Heatmap
%% ========================================================================
function figPath = plotRegionalHeatmap(regionalStats, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 900 600]);

% Extract data
regions = {regionalStats.region}';
metrics = opts.metrics;
nRegions = length(regions);
nMetrics = length(metrics);

% Create matrix for heatmap
dataMatrix = NaN(nRegions, nMetrics);
for i = 1:nRegions
    for j = 1:nMetrics
        if isfield(regionalStats(i), metrics{j})
            dataMatrix(i, j) = regionalStats(i).(metrics{j});
        end
    end
end

% Normalize each column for better visualization
dataMatrixNorm = dataMatrix;
for j = 1:nMetrics
    if strcmp(metrics{j}, 'R2')
        % R² already 0-1
        dataMatrixNorm(:, j) = dataMatrix(:, j);
    else
        % Normalize to 0-1 (inverse for error metrics)
        minVal = min(dataMatrix(:, j));
        maxVal = max(dataMatrix(:, j));
        if strcmp(metrics{j}, 'RMSE') || strcmp(metrics{j}, 'MAE')
            % Lower is better
            dataMatrixNorm(:, j) = 1 - (dataMatrix(:, j) - minVal) / (maxVal - minVal);
        else
            % Higher is better
            dataMatrixNorm(:, j) = (dataMatrix(:, j) - minVal) / (maxVal - minVal);
        end
    end
end

% Create heatmap
imagesc(dataMatrixNorm');
colormap(flipud(hot));
cb = colorbar;
ylabel(cb, 'Normalized Performance (1=best)', 'FontSize', 11);

% Set axis labels
set(gca, 'XTick', 1:nRegions, 'XTickLabel', regions, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:nMetrics, 'YTickLabel', metrics);
xlabel('Region', 'FontSize', 12);
ylabel('Metric', 'FontSize', 12);
title([opts.titlePrefix 'Regional Performance Summary'], 'FontSize', 14, 'FontWeight', 'bold');

% Add text annotations with actual values
for i = 1:nRegions
    for j = 1:nMetrics
        if ~isnan(dataMatrix(i, j))
            if strcmp(metrics{j}, 'NMB')
                textStr = sprintf('%.1f%%', dataMatrix(i, j));
            else
                textStr = sprintf('%.3f', dataMatrix(i, j));
            end
            text(i, j, textStr, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'FontSize', 9, 'FontWeight', 'bold', ...
                'Color', 'w');
        end
    end
end

set(gca, 'FontSize', 10);

basename = 'regional_performance_heatmap';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Regional Scatter Plots
%% ========================================================================
function figPath = plotRegionalScatters(Y_obs, Y_est, regions, uniqueRegions, opts)

nRegions = length(uniqueRegions);
nCols = ceil(sqrt(nRegions));
nRows = ceil(nRegions / nCols);

fig = figure('Visible', opts.visible, 'Position', [100 100 300*nCols 300*nRows]);

for i = 1:nRegions
    region = uniqueRegions{i};
    regionMask = strcmp(regions, region);

    Y_obs_reg = Y_obs(regionMask);
    Y_est_reg = Y_est(regionMask);

    % Compute statistics
    R = corrcoef(Y_obs_reg, Y_est_reg);
    R2 = R(1,2)^2;
    RMSE = sqrt(mean((Y_obs_reg - Y_est_reg).^2));
    N = length(Y_obs_reg);

    % Create subplot
    subplot(nRows, nCols, i);
    hold on;

    % Scatter
    scatter(Y_obs_reg, Y_est_reg, 10, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.4);

    % 1:1 line
    xlims = xlim;
    ylims = ylim;
    minVal = min([xlims(1) ylims(1)]);
    maxVal = max([xlims(2) ylims(2)]);
    plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 1.5);

    xlabel('Observed', 'FontSize', 9);
    ylabel('Estimated', 'FontSize', 9);
    title(region, 'FontSize', 11, 'FontWeight', 'bold');

    % Add statistics
    text(0.05, 0.95, sprintf('R²=%.3f\nRMSE=%.2f\nN=%d', R2, RMSE, N), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
        'BackgroundColor', 'w', 'EdgeColor', 'k');

    axis equal;
    grid on;
    set(gca, 'FontSize', 8);
end

sgtitle([opts.titlePrefix 'Regional Scatter Plots'], 'FontSize', 14, 'FontWeight', 'bold');

basename = 'regional_scatters';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Regional Sample Size Map
%% ========================================================================
function figPath = plotRegionalSampleMap(sk, regions, uniqueRegions, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1000 600]);

% Assign colors by region
nRegions = length(uniqueRegions);
colors = lines(nRegions);

hold on;
for i = 1:nRegions
    region = uniqueRegions{i};
    regionMask = strcmp(regions, region);

    scatter(sk(regionMask, 1), sk(regionMask, 2), 20, colors(i,:), 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', ...
        sprintf('%s (n=%d)', region, sum(regionMask)));
end

xlabel('Longitude (°)', 'FontSize', 12);
ylabel('Latitude (°)', 'FontSize', 12);
title([opts.titlePrefix 'Regional Sample Distribution'], 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'eastoutside', 'FontSize', 9);
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

basename = 'regional_sample_map';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Regional Metric Comparison
%% ========================================================================
function figPath = plotRegionalMetrics(regionalStats, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1200 800]);

metrics = opts.metrics;
nMetrics = length(metrics);
regions = {regionalStats.region}';
nRegions = length(regions);

for i = 1:nMetrics
    subplot(2, 2, i);

    metric = metrics{i};
    values = [regionalStats.(metric)]';

    % Bar chart
    bar(values, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'k');
    set(gca, 'XTick', 1:nRegions, 'XTickLabel', regions, 'XTickLabelRotation', 45);

    % Add value labels on bars
    for j = 1:nRegions
        if strcmp(metric, 'NMB')
            text(j, values(j), sprintf('%.1f%%', values(j)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 8, 'FontWeight', 'bold');
        else
            text(j, values(j), sprintf('%.3f', values(j)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 8, 'FontWeight', 'bold');
        end
    end

    ylabel(metric, 'FontSize', 11);
    title(metric, 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', 10);
end

sgtitle([opts.titlePrefix 'Regional Metric Comparison'], 'FontSize', 14, 'FontWeight', 'bold');

basename = 'regional_metrics';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% HELPER: Calculate R²
%% ========================================================================
function R2 = calculateR2(Y_obs, Y_est)
SSres = sum((Y_obs - Y_est).^2);
SStot = sum((Y_obs - mean(Y_obs)).^2);
R2 = 1 - SSres / SStot;
end
