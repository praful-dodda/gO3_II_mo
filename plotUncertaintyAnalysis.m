function figPaths = plotUncertaintyAnalysis(resultsData, varargin)
% plotUncertaintyAnalysis - Analyze and visualize estimation uncertainty
%
% Creates diagnostic plots for analyzing kriging variance and uncertainty
% calibration to assess whether prediction intervals are reliable.
%
% SYNTAX:
%   figPaths = plotUncertaintyAnalysis(resultsData)
%   figPaths = plotUncertaintyAnalysis(resultsData, 'Name', Value, ...)
%
% INPUTS:
%   resultsData - Structure or struct array with fields:
%                 .Y_obs    - Observed values
%                 .Y_est    - Estimated values
%                 .XkBMEv   - Estimation variances (kriging variance)
%                 .sk       - Spatial coordinates [lon, lat]
%                 Optional: .regions, .Year, .BoxSize, etc.
%
% OPTIONAL PARAMETERS:
%   'saveDir'     - Directory to save figures (default: './figs_uncertainty')
%   'dpi'         - Figure resolution (default: 300)
%   'visible'     - 'on' or 'off' for figure visibility (default: 'off')
%   'titlePrefix' - Prefix for figure titles (default: '')
%   'confidenceLevel' - Confidence level for intervals (default: 0.95)
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% CREATED PLOTS:
%   1. Uncertainty vs error scatter (check if high uncertainty → high error)
%   2. Calibration plot (predicted uncertainty vs actual RMSE)
%   3. Spatial uncertainty map
%   4. Coverage probability plot (empirical vs nominal)
%   5. Uncertainty distribution
%
% EXAMPLE:
%   % From CBV results
%   data = load('./7validation/CBV/CBV_*.mat');
%   resultsData.Y_obs = data.annualResults.Y_obs;
%   resultsData.Y_est = data.annualResults.Y_est;
%   resultsData.XkBMEv = data.annualResults.XkBMEv;
%   resultsData.sk = data.annualResults.sk;
%   figPaths = plotUncertaintyAnalysis(resultsData);

%% Parse inputs
p = inputParser;
addRequired(p, 'resultsData', @isstruct);
addParameter(p, 'saveDir', './figs_uncertainty', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'titlePrefix', '', @ischar);
addParameter(p, 'confidenceLevel', 0.95, @isnumeric);

parse(p, resultsData, varargin{:});
opts = p.Results;

if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('=== Uncertainty Analysis ===\n');

figPaths = {};

%% Aggregate data if struct array
if length(resultsData) > 1
    Y_obs = [];
    Y_est = [];
    XkBMEv = [];
    sk = [];
    regions = {};

    for i = 1:length(resultsData)
        Y_obs = [Y_obs; resultsData(i).Y_obs(:)];
        Y_est = [Y_est; resultsData(i).Y_est(:)];
        if isfield(resultsData(i), 'XkBMEv')
            XkBMEv = [XkBMEv; resultsData(i).XkBMEv(:)];
        end
        sk = [sk; resultsData(i).sk];
        if isfield(resultsData(i), 'regions')
            regions = [regions; resultsData(i).regions(:)];
        end
    end
else
    Y_obs = resultsData.Y_obs(:);
    Y_est = resultsData.Y_est(:);
    XkBMEv = [];
    if isfield(resultsData, 'XkBMEv')
        XkBMEv = resultsData.XkBMEv(:);
    end
    sk = resultsData.sk;
    regions = {};
    if isfield(resultsData, 'regions')
        regions = resultsData.regions(:);
    end
end

if isempty(XkBMEv)
    error('XkBMEv (estimation variance) field required for uncertainty analysis');
end

% Filter valid data
validIdx = ~isnan(Y_obs) & ~isnan(Y_est) & ~isnan(XkBMEv) & XkBMEv > 0;
Y_obs = Y_obs(validIdx);
Y_est = Y_est(validIdx);
XkBMEv = XkBMEv(validIdx);
sk = sk(validIdx, :);

% Compute residuals and absolute errors
residuals = Y_obs - Y_est;
absErrors = abs(residuals);
predStd = sqrt(XkBMEv);  % Prediction standard deviation

fprintf('  Valid observations: %d\n', length(residuals));
fprintf('  Mean prediction std: %.3f\n', mean(predStd));
fprintf('  Median prediction std: %.3f\n', median(predStd));

%% Plot 1: Uncertainty vs Error
figPaths = [figPaths; plotUncertaintyVsError(predStd, absErrors, opts)];

%% Plot 2: Calibration Plot
figPaths = [figPaths; plotCalibration(predStd, absErrors, opts)];

%% Plot 3: Spatial Uncertainty Map
figPaths = [figPaths; plotSpatialUncertainty(sk, predStd, opts)];

%% Plot 4: Coverage Probability
figPaths = [figPaths; plotCoverageProbability(residuals, predStd, opts)];

%% Plot 5: Uncertainty Distribution
figPaths = [figPaths; plotUncertaintyDistribution(predStd, absErrors, opts)];

fprintf('=== Uncertainty analysis complete: %d figures created ===\n', length(figPaths));

end

%% ========================================================================
%% SUBFUNCTION: Uncertainty vs Error
%% ========================================================================
function figPath = plotUncertaintyVsError(predStd, absErrors, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);
hold on;

% Hexagonal binning for large datasets
if length(predStd) > 10000
    hexscatter(predStd, absErrors, 'xlim', [0 max(predStd)], 'ylim', [0 max(absErrors)]);
else
    scatter(predStd, absErrors, 10, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.4);
end

% 1:1 line (ideal calibration)
maxVal = max([max(predStd) max(absErrors)]);
plot([0 maxVal], [0 maxVal], 'k--', 'LineWidth', 2, 'DisplayName', '1:1 line (perfect)');

% Moving average trend
try
    [sortedStd, sortIdx] = sort(predStd);
    sortedErr = absErrors(sortIdx);
    windowSize = max(100, floor(length(sortedStd) / 50));
    trendErr = movmean(sortedErr, windowSize);
    plot(sortedStd, trendErr, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Trend');
catch
    % Skip if movmean not available
end

% Compute correlation
R = corrcoef(predStd, absErrors);
R_value = R(1,2);

xlabel('Predicted Standard Deviation (ppb)', 'FontSize', 12);
ylabel('Absolute Error (ppb)', 'FontSize', 12);
title([opts.titlePrefix 'Uncertainty vs Absolute Error'], 'FontSize', 14, 'FontWeight', 'bold');

text(0.05, 0.95, sprintf('Correlation: %.3f\nN = %d', R_value, length(predStd)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);

legend('Location', 'southeast');
grid on;
set(gca, 'FontSize', 11);

basename = 'uncertainty_vs_error';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Calibration Plot
%% ========================================================================
function figPath = plotCalibration(predStd, absErrors, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);
hold on;

% Bin predictions by uncertainty quantiles
nBins = 10;
[~, edges, binIdx] = histcounts(predStd, nBins);
binCenters = (edges(1:end-1) + edges(2:end)) / 2;

% Compute RMSE in each bin
rmseByBin = NaN(nBins, 1);
meanPredStdByBin = NaN(nBins, 1);
nByBin = NaN(nBins, 1);

for i = 1:nBins
    binMask = binIdx == i;
    if sum(binMask) > 0
        rmseByBin(i) = sqrt(mean(absErrors(binMask).^2));
        meanPredStdByBin(i) = mean(predStd(binMask));
        nByBin(i) = sum(binMask);
    end
end

% Plot calibration
plot(meanPredStdByBin, rmseByBin, 'o-', 'LineWidth', 2, 'MarkerSize', 10, ...
    'MarkerFaceColor', [0.2 0.4 0.8], 'Color', [0.2 0.4 0.8]);

% 1:1 line
maxVal = max([max(meanPredStdByBin) max(rmseByBin)]);
plot([0 maxVal], [0 maxVal], 'k--', 'LineWidth', 2);

% Add sample sizes as text
for i = 1:nBins
    if ~isnan(rmseByBin(i))
        text(meanPredStdByBin(i), rmseByBin(i), sprintf(' n=%d', nByBin(i)), ...
            'FontSize', 8, 'VerticalAlignment', 'bottom');
    end
end

xlabel('Mean Predicted Std Dev (ppb)', 'FontSize', 12);
ylabel('Actual RMSE (ppb)', 'FontSize', 12);
title([opts.titlePrefix 'Uncertainty Calibration'], 'FontSize', 14, 'FontWeight', 'bold');

% Calculate calibration slope
validBins = ~isnan(meanPredStdByBin) & ~isnan(rmseByBin);
if sum(validBins) >= 2
    p = polyfit(meanPredStdByBin(validBins), rmseByBin(validBins), 1);
    text(0.05, 0.95, sprintf('Calibration slope: %.3f\n(1.0 = perfect)', p(1)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);
end

grid on;
axis equal tight;
set(gca, 'FontSize', 11);

basename = 'uncertainty_calibration';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Spatial Uncertainty Map
%% ========================================================================
function figPath = plotSpatialUncertainty(sk, predStd, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1000 600]);

scatter(sk(:,1), sk(:,2), 30, predStd, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
colormap(hot);
cb = colorbar;
ylabel(cb, 'Prediction Std Dev (ppb)', 'FontSize', 12);

xlabel('Longitude (°)', 'FontSize', 12);
ylabel('Latitude (°)', 'FontSize', 12);
title([opts.titlePrefix 'Spatial Distribution of Uncertainty'], 'FontSize', 14, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

basename = 'spatial_uncertainty';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Coverage Probability
%% ========================================================================
function figPath = plotCoverageProbability(residuals, predStd, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);
hold on;

% Calculate coverage at different confidence levels
confidenceLevels = 0.5:0.05:0.99;
nLevels = length(confidenceLevels);
empiricalCoverage = NaN(nLevels, 1);

for i = 1:nLevels
    alpha = 1 - confidenceLevels(i);
    z = norminv(1 - alpha/2);

    % Check how many residuals fall within ±z*predStd
    withinInterval = abs(residuals) <= z * predStd;
    empiricalCoverage(i) = mean(withinInterval);
end

% Plot empirical vs nominal
plot(confidenceLevels * 100, empiricalCoverage * 100, 'o-', 'LineWidth', 2, ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.4 0.8], 'Color', [0.2 0.4 0.8]);

% 1:1 line (perfect calibration)
plot([50 99], [50 99], 'k--', 'LineWidth', 2);

% Highlight 95% level
idx95 = find(confidenceLevels == 0.95);
if ~isempty(idx95)
    plot(95, empiricalCoverage(idx95) * 100, 'ro', 'MarkerSize', 15, 'LineWidth', 2);
    text(95, empiricalCoverage(idx95) * 100 + 2, sprintf('95%%: %.1f%%', empiricalCoverage(idx95) * 100), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

xlabel('Nominal Coverage (%)', 'FontSize', 12);
ylabel('Empirical Coverage (%)', 'FontSize', 12);
title([opts.titlePrefix 'Coverage Probability'], 'FontSize', 14, 'FontWeight', 'bold');

% Add interpretation text
if ~isempty(idx95)
    diff95 = empiricalCoverage(idx95) * 100 - 95;
    if abs(diff95) < 2
        interpretation = 'Well calibrated';
    elseif diff95 > 0
        interpretation = 'Overconfident (too narrow)';
    else
        interpretation = 'Underconfident (too wide)';
    end
    text(0.05, 0.05, sprintf('Status: %s\nDeviation at 95%%: %.1f%%', interpretation, diff95), ...
        'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);
end

grid on;
axis([50 99 50 99]);
set(gca, 'FontSize', 11);

basename = 'coverage_probability';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Uncertainty Distribution
%% ========================================================================
function figPath = plotUncertaintyDistribution(predStd, absErrors, opts)

fig = figure('Visible', opts.visible, 'Position', [100 100 1000 600]);

% Two subplots: uncertainty distribution and error distribution
subplot(1, 2, 1);
histogram(predStd, 50, 'Normalization', 'pdf', 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'k');
xlabel('Prediction Std Dev (ppb)', 'FontSize', 11);
ylabel('Probability Density', 'FontSize', 11);
title('Distribution of Uncertainty', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 10);

subplot(1, 2, 2);
histogram(absErrors, 50, 'Normalization', 'pdf', 'FaceColor', [0.8 0.3 0.3], 'EdgeColor', 'k');
hold on;
histogram(predStd, 50, 'Normalization', 'pdf', 'FaceColor', [0.2 0.4 0.8], ...
    'EdgeColor', 'k', 'FaceAlpha', 0.5);
xlabel('Value (ppb)', 'FontSize', 11);
ylabel('Probability Density', 'FontSize', 11);
title('Comparison: Error vs Uncertainty', 'FontSize', 12, 'FontWeight', 'bold');
legend({'Absolute errors', 'Predicted std'}, 'Location', 'northeast');
grid on;
set(gca, 'FontSize', 10);

sgtitle([opts.titlePrefix 'Uncertainty Distributions'], 'FontSize', 14, 'FontWeight', 'bold');

basename = 'uncertainty_distribution';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% HELPER: Hexagonal scatter plot
%% ========================================================================
function hexscatter(x, y, varargin)
% Simple hexbin scatter - fallback to regular scatter if not available
try
    % Try to use hexscatter if available
    evalc('hexscatter(x, y, varargin{:})');
catch
    % Fallback to regular scatter with alpha
    scatter(x, y, 10, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.3);
end
end
