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
    figPaths = [figPaths; plotTemporalResiduals(tk, residuals, sk(:,2), opts)];
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
    smoothRes = simpleLOWESS(sortedEst, sortedRes, 0.1);
    plot(sortedEst, smoothRes, 'r-', 'LineWidth', 2.5);
catch
    % Skip if smoothing fails
end

xlabel('Predicted Value (ppb)', 'FontSize', 12);
ylabel('Residual (Obs - Pred) (ppb)', 'FontSize', 12);
title([opts.titlePrefix 'Residuals vs Predicted Values'], 'FontSize', 14, 'FontWeight', 'bold');

% Calculate percentages outside ±2SD
pctAbove = 100 * sum(residuals > 2*stdRes) / length(residuals);
pctBelow = 100 * sum(residuals < -2*stdRes) / length(residuals);
pctOutside = pctAbove + pctBelow;

% Add statistics with percentages
text(0.05, 0.95, sprintf(['Mean: %.3f\nStd: %.3f\n2σ: %.3f\n' ...
    'Above +2σ: %.1f%%\nBelow -2σ: %.1f%%\nOutside ±2σ: %.1f%% (expect ~5%%)'], ...
    mean(residuals), stdRes, 2*stdRes, pctAbove, pctBelow, pctOutside), ...
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

scatter(sk(:,1), sk(:,2), 8, residuals, 'filled', 'LineWidth', 0.5);
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
function figPath = plotTemporalResiduals(tk, residuals, latitude, opts)
% Separate by hemisphere
isNorth = latitude >= 0;
isSouth = latitude < 0;

fig = figure('Visible', opts.visible, 'Position', [100 100 1400 600]);

% Overall Residuals Panel
subplot(3, 1, 1);
plotHemisphere(tk, residuals, 'Overall', opts);

% Northern Hemisphere Panel
subplot(3, 1, 2);
plotHemisphere(tk(isNorth), residuals(isNorth), 'Northern Hemisphere', opts);

% Southern Hemisphere Panel
subplot(3, 1, 3);
plotHemisphere(tk(isSouth), residuals(isSouth), 'Southern Hemisphere', opts);

% Overall title
sgtitle([opts.titlePrefix 'Temporal Trend of Residuals by Hemisphere'], ...
    'FontSize', 14, 'FontWeight', 'bold');

basename = 'temporal_residuals_hemispheres';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end
end

%% ========================================================================
%% HELPER: Plot hemisphere temporal residuals
%% ========================================================================
function plotHemisphere(tk, residuals, hemTitle, opts)
if isempty(tk)
    text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center', ...
        'FontSize', 14, 'Color', [0.5 0.5 0.5]);
    title(hemTitle, 'FontSize', 12, 'FontWeight', 'bold');
    return;
end

% Convert decimal years to datetime for better formatting
years = floor(tk);
fractionalYear = tk - years;
months = round(fractionalYear * 12) + 1;
months(months > 12) = 12;
dates = datetime(years, months, 15);  % Mid-month

% Bin by month
uniqueDates = unique(dateshift(dates, 'start', 'month'));
meanResid = NaN(length(uniqueDates), 1);
stdResid = NaN(length(uniqueDates), 1);
nPoints = NaN(length(uniqueDates), 1);

for i = 1:length(uniqueDates)
    timeBin = dateshift(dates, 'start', 'month') == uniqueDates(i);
    meanResid(i) = mean(residuals(timeBin));
    stdResid(i) = std(residuals(timeBin));
    nPoints(i) = sum(timeBin);
end

% Plot with error bars
hold on;
errorbar(uniqueDates, meanResid, stdResid, 'o-', 'LineWidth', 1.5, ...
    'MarkerSize', 5, 'MarkerFaceColor', [0.2 0.4 0.8], 'Color', [0.2 0.4 0.8]);

% Zero line
plot([min(uniqueDates) max(uniqueDates)], [0 0], 'k--', 'LineWidth', 2);

% Format x-axis to show months nicely
xlabel('Time', 'FontSize', 11);
ylabel('Mean Residual (ppb)', 'FontSize', 11);
title(sprintf('%s (n=%d)', hemTitle, length(residuals)), ...
    'FontSize', 12, 'FontWeight', 'bold');

% Smart date formatting based on time span
timeSpan = max(uniqueDates) - min(uniqueDates);
if timeSpan <= years(365)  % Less than 1 year
    xtickformat('MMM yyyy');
    ax = gca;
    ax.XAxis.TickLabelRotation = 45;
elseif timeSpan <= years(730)  % 1-2 years
    xtickformat('MMM yy');
    ax = gca;
    ax.XAxis.TickLabelRotation = 45;
else  % More than 2 years
    xtickformat('yyyy');
end

grid on;
set(gca, 'FontSize', 10);

% Add summary statistics
text(0.02, 0.98, sprintf('Mean: %.3f\nStd: %.3f\nN: %d', ...
    mean(residuals), std(residuals), length(residuals)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 9);

hold off;
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
