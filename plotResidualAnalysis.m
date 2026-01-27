function figPaths = plotResidualAnalysis(resultsData, varargin)
% plotResidualAnalysis - Comprehensive residual analysis plots
%
% Creates diagnostic plots for analyzing residuals (observed - predicted)
% to identify systematic biases, spatial patterns, and model inadequacies.
%
% SYNTAX:
%   figPaths = plotResidualAnalysis(resultsData)
%   figPaths = plotResidualAnalysis(resultsData, 'Name', Value, ...)
%
% INPUTS:
%   resultsData - Structure or struct array with fields:
%                 .Y_obs    - Observed values
%                 .Y_est    - Estimated values
%                 .sk       - Spatial coordinates [lon, lat]
%                 .tk       - Temporal coordinates (optional)
%                 Additional optional fields: .regions, .Year, .BoxSize, etc.
%
% OPTIONAL PARAMETERS:
%   'saveDir'    - Directory to save figures (default: './figs_residuals')
%   'dpi'        - Figure resolution (default: 300)
%   'visible'    - 'on' or 'off' for figure visibility (default: 'off')
%   'titlePrefix' - Prefix for figure titles (default: '')
%   'regions'    - Cell array of region labels (auto-assigned if not provided)
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% CREATED PLOTS:
%   1. Residual scatter plot (residuals vs predicted)
%   2. Residual histogram with normality test
%   3. Q-Q plot for normality check
%   4. Spatial residual map
%   5. Residual boxplot by region
%   6. Temporal residual trend (if temporal data available)
%
% EXAMPLE:
%   % From CBV results
%   data = load('./7validation/CBV/CBV_*.mat');
%   resultsData.Y_obs = data.annualResults.Y_obs;
%   resultsData.Y_est = data.annualResults.Y_est;
%   resultsData.sk = data.annualResults.sk;
%   figPaths = plotResidualAnalysis(resultsData);

%% Parse inputs
p = inputParser;
addRequired(p, 'resultsData', @isstruct);
addParameter(p, 'saveDir', './figs_residuals', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'titlePrefix', '', @ischar);
addParameter(p, 'regions', [], @iscell);

parse(p, resultsData, varargin{:});
opts = p.Results;

if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('=== Residual Analysis ===\n');

figPaths = {};

%% Aggregate data if struct array
if length(resultsData) > 1
    Y_obs = [];
    Y_est = [];
    sk = [];
    tk = [];
    regions = {};

    for i = 1:length(resultsData)
        Y_obs = [Y_obs; resultsData(i).Y_obs(:)];
        Y_est = [Y_est; resultsData(i).Y_est(:)];
        sk = [sk; resultsData(i).sk];
        if isfield(resultsData(i), 'tk')
            tk = [tk; resultsData(i).tk(:)];
        end
        if isfield(resultsData(i), 'regions')
            regions = [regions; resultsData(i).regions(:)];
        end
    end
else
    Y_obs = resultsData.Y_obs(:);
    Y_est = resultsData.Y_est(:);
    sk = resultsData.sk;
    tk = [];
    if isfield(resultsData, 'tk')
        tk = resultsData.tk(:);
    end
    regions = {};
    if isfield(resultsData, 'regions')
        regions = resultsData.regions(:);
    end
end

% Compute residuals
validIdx = ~isnan(Y_obs) & ~isnan(Y_est);
Y_obs = Y_obs(validIdx);
Y_est = Y_est(validIdx);
residuals = Y_obs - Y_est;
sk = sk(validIdx, :);
if ~isempty(tk)
    tk = tk(validIdx);
end
if ~isempty(regions)
    regions = regions(validIdx);
elseif ~isempty(opts.regions)
    regions = opts.regions(validIdx);
else
    % Assign regions if not provided
    regions = assignRegions(sk(:,1), sk(:,2));
end

fprintf('  Valid observations: %d\n', length(residuals));
fprintf('  Mean residual: %.3f\n', mean(residuals));
fprintf('  Std residual: %.3f\n', std(residuals));

%% Plot 1: Residuals vs Predicted
figPaths = [figPaths; plotResidualsVsPredicted(Y_est, residuals, opts)];

%% Plot 2: Residual Histogram with Normality Test
figPaths = [figPaths; plotResidualHistogram(residuals, opts)];

%% Plot 3: Q-Q Plot
figPaths = [figPaths; plotQQplot(residuals, opts)];

%% Plot 4: Spatial Residual Map
figPaths = [figPaths; plotSpatialResiduals(sk, residuals, opts)];

%% Plot 5: Residual Boxplot by Region
if ~isempty(regions)
    figPaths = [figPaths; plotResidualsByRegion(residuals, regions, opts)];
end

%% Plot 6: Temporal Residual Trend
if ~isempty(tk)
    figPaths = [figPaths; plotTemporalResiduals(tk, residuals, opts)];
end

fprintf('=== Residual analysis complete: %d figures created ===\n', length(figPaths));

end

%% ========================================================================
%% SUBFUNCTION: Residuals vs Predicted
%% ========================================================================
function figPath = plotResidualsVsPredicted(Y_est, residuals, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);
hold on;

% Scatter plot with transparency
scatter(Y_est, residuals, 10, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.3);

% Zero line
plot([min(Y_est) max(Y_est)], [0 0], 'k--', 'LineWidth', 2);

% Add ±2 std lines
stdRes = std(residuals);
plot([min(Y_est) max(Y_est)], [2*stdRes 2*stdRes], 'r--', 'LineWidth', 1.5);
plot([min(Y_est) max(Y_est)], [-2*stdRes -2*stdRes], 'r--', 'LineWidth', 1.5);

% LOWESS smooth line to show trend
try
    [sortedEst, sortIdx] = sort(Y_est);
    sortedRes = residuals(sortIdx);
    smoothRes = smooth(sortedEst, sortedRes, 0.1, 'loess');
    plot(sortedEst, smoothRes, 'r-', 'LineWidth', 2.5);
catch
    % Skip if smooth not available
end

xlabel('Predicted Value (ppb)', 'FontSize', 12);
ylabel('Residual (Obs - Pred) (ppb)', 'FontSize', 12);
title([opts.titlePrefix 'Residuals vs Predicted Values'], 'FontSize', 14, 'FontWeight', 'bold');

% Add statistics
text(0.05, 0.95, sprintf('Mean: %.3f\nStd: %.3f\n2σ: %.3f', ...
    mean(residuals), stdRes, 2*stdRes), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);

grid on;
set(gca, 'FontSize', 11);

basename = 'residuals_vs_predicted';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Residual Histogram
%% ========================================================================
function figPath = plotResidualHistogram(residuals, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);

% Histogram
histogram(residuals, 50, 'Normalization', 'pdf', 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'k');
hold on;

% Overlay normal distribution
mu = mean(residuals);
sigma = std(residuals);
x = linspace(min(residuals), max(residuals), 200);
y = normpdf(x, mu, sigma);
plot(x, y, 'r-', 'LineWidth', 2.5);

% Perform normality tests
[h_ks, p_ks] = kstest((residuals - mu) / sigma);
[h_jb, p_jb] = jbtest(residuals);

xlabel('Residual (ppb)', 'FontSize', 12);
ylabel('Probability Density', 'FontSize', 12);
title([opts.titlePrefix 'Residual Distribution'], 'FontSize', 14, 'FontWeight', 'bold');

% Add statistics
text(0.6, 0.95, sprintf('Mean: %.3f\nStd: %.3f\nSkewness: %.3f\nKurtosis: %.3f\n\nKS test p=%.3f %s\nJB test p=%.3f %s', ...
    mu, sigma, skewness(residuals), kurtosis(residuals), ...
    p_ks, ternary(h_ks, '(reject)', '(normal)'), ...
    p_jb, ternary(h_jb, '(reject)', '(normal)')), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 9);

legend({'Residuals', 'Normal fit'}, 'Location', 'northwest');
grid on;
set(gca, 'FontSize', 11);

basename = 'residual_histogram';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Q-Q Plot
%% ========================================================================
function figPath = plotQQplot(residuals, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 700 700]);

% Standardize residuals
residStd = (residuals - mean(residuals)) / std(residuals);

% Q-Q plot
qqplot(residStd);
hold on;

% Enhance formatting
h = findobj(gca, 'Type', 'line');
set(h(1), 'MarkerSize', 4, 'Marker', 'o', 'MarkerFaceColor', [0.2 0.4 0.8]);
set(h(2), 'LineWidth', 2, 'Color', 'r');
set(h(3), 'LineWidth', 1.5, 'Color', 'k', 'LineStyle', '--');

xlabel('Theoretical Quantiles', 'FontSize', 12);
ylabel('Sample Quantiles', 'FontSize', 12);
title([opts.titlePrefix 'Q-Q Plot for Residuals'], 'FontSize', 14, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 11);

basename = 'residual_qqplot';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Spatial Residual Map
%% ========================================================================
function figPath = plotSpatialResiduals(sk, residuals, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1000 600]);

% Create diverging colormap (blue-white-red)
n = 256;
cmap = [linspace(0, 1, n/2)', linspace(0, 1, n/2)', ones(n/2, 1); ...
        ones(n/2, 1), linspace(1, 0, n/2)', linspace(1, 0, n/2)'];

scatter(sk(:,1), sk(:,2), 30, residuals, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
colormap(cmap);
cb = colorbar;
ylabel(cb, 'Residual (ppb)', 'FontSize', 12);

% Set symmetric color limits
maxAbs = max(abs(residuals));
caxis([-maxAbs maxAbs]);

xlabel('Longitude (°)', 'FontSize', 12);
ylabel('Latitude (°)', 'FontSize', 12);
title([opts.titlePrefix 'Spatial Distribution of Residuals'], 'FontSize', 14, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

basename = 'spatial_residuals';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Residuals by Region
%% ========================================================================
function figPath = plotResidualsByRegion(residuals, regions, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1000 600]);

uniqueRegions = unique(regions);
nRegions = length(uniqueRegions);

% Prepare data for boxplot
residByRegion = cell(nRegions, 1);
for i = 1:nRegions
    residByRegion{i} = residuals(strcmp(regions, uniqueRegions{i}));
end

% Create boxplot
boxplot(cat(1, residByRegion{:}), ...
    repelem(1:nRegions, cellfun(@length, residByRegion)), ...
    'Labels', uniqueRegions, 'Colors', [0.2 0.4 0.8]);
hold on;

% Add zero line
plot([0.5 nRegions+0.5], [0 0], 'k--', 'LineWidth', 2);

ylabel('Residual (ppb)', 'FontSize', 12);
xlabel('Region', 'FontSize', 12);
title([opts.titlePrefix 'Residuals by Region'], 'FontSize', 14, 'FontWeight', 'bold');
grid on;
set(gca, 'XTickLabelRotation', 45, 'FontSize', 10);

basename = 'residuals_by_region';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Temporal Residuals
%% ========================================================================
function figPath = plotTemporalResiduals(tk, residuals, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1200 500]);

% Bin by time (monthly averages)
uniqueTimes = unique(floor(tk * 12) / 12);  % Monthly bins
meanResid = NaN(length(uniqueTimes), 1);
stdResid = NaN(length(uniqueTimes), 1);

for i = 1:length(uniqueTimes)
    timeBin = (floor(tk * 12) / 12) == uniqueTimes(i);
    meanResid(i) = mean(residuals(timeBin));
    stdResid(i) = std(residuals(timeBin));
end

% Plot with error bars
errorbar(uniqueTimes, meanResid, stdResid, 'o-', 'LineWidth', 1.5, ...
    'MarkerSize', 6, 'MarkerFaceColor', [0.2 0.4 0.8], 'Color', [0.2 0.4 0.8]);
hold on;

% Zero line
plot([min(uniqueTimes) max(uniqueTimes)], [0 0], 'k--', 'LineWidth', 2);

xlabel('Time (year)', 'FontSize', 12);
ylabel('Mean Residual (ppb)', 'FontSize', 12);
title([opts.titlePrefix 'Temporal Trend of Residuals'], 'FontSize', 14, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 11);

basename = 'temporal_residuals';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% HELPER: Ternary operator
%% ========================================================================
function result = ternary(condition, trueVal, falseVal)
if condition
    result = trueVal;
else
    result = falseVal;
end
end
