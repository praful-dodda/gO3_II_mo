function figPaths = plotTOARautoCov_CBV(obs, go, cov, boxSize, foldIdx, yearRange, trainMask, valMask, varargin)
% plotTOARautoCov_CBV - Plot fold-specific covariance with diagnostic information
%
% Creates diagnostic plots for CBV showing the fitted covariance model
% and residuals from training stations only
%
% SYNTAX:
%   figPaths = plotTOARautoCov_CBV(obs, go, cov, boxSize, foldIdx, yearRange, trainMask, valMask)
%   figPaths = plotTOARautoCov_CBV(..., 'Name', Value, ...)
%
% INPUTS:
%   obs        - Full observational data structure (all stations)
%   go         - Fold-specific global offset structure
%   cov        - Fold-specific covariance structure
%   boxSize    - Checker box size in degrees
%   foldIdx    - Fold index (1 or 2)
%   yearRange  - [startYear endYear] used for covariance computation
%   trainMask  - Logical mask for training stations
%   valMask    - Logical mask for validation stations
%
% OPTIONAL PARAMETERS:
%   'saveDir'   - Directory to save figures (default: './3covariance/CBV/figs/box{boxSize}')
%   'dpi'       - Resolution in DPI (default: 300)
%   'visible'   - 'on' or 'off' for figure visibility (default: 'off')
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% CREATED PLOTS:
%   1. Fitted covariance model with experimental variogram
%   2. Training vs validation station locations
%
% EXAMPLE:
%   figPaths = plotTOARautoCov_CBV(obs, go_fold, cov_fold, 3.0, 1, [2016 2018], ...
%       trainMask, valMask, 'visible', 'off');

%% Parse inputs
p = inputParser;
addRequired(p, 'obs');
addRequired(p, 'go');
addRequired(p, 'cov');
addRequired(p, 'boxSize');
addRequired(p, 'foldIdx');
addRequired(p, 'yearRange');
addRequired(p, 'trainMask');
addRequired(p, 'valMask');
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));

parse(p, obs, go, cov, boxSize, foldIdx, yearRange, trainMask, valMask, varargin{:});
opts = p.Results;

% Set default save directory
if isempty(opts.saveDir)
    opts.saveDir = sprintf('./3covariance/CBV/figs/box%.1f', boxSize);
end

figPaths = {};

%% Figure 1: Fitted Covariance Model
fig1 = figure('Visible', opts.visible);

% Plot experimental variogram points (if available)
if isfield(cov, 'lag') && isfield(cov, 'gamma')
    hold on;
    plot(cov.lag, cov.gamma, 'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b');
end

% Plot fitted covariance model
if isfield(cov, 'covmodel') && isfield(cov, 'covparam')
    hold on;
    % Create distance vector
    maxDist = max(cov.lag);
    distVec = linspace(0, maxDist, 200);

    % Evaluate covariance model
    covVec = coord2K([0 0 0], [distVec' zeros(length(distVec),1) zeros(length(distVec),1)], ...
        cov.covmodel, cov.covparam);

    plot(distVec, cov.var - covVec, 'r-', 'LineWidth', 2);

    xlabel('Distance', 'FontSize', 12);
    ylabel('Semivariance', 'FontSize', 12);
    title(sprintf('Fold %d Covariance Model (Training Stations Only)\nGO %d, Box %.1f deg, Years %d-%d', ...
        foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2)), 'FontSize', 14);
    legend({'Experimental variogram', 'Fitted model'}, 'Location', 'best');
    grid on;
    set(gca, 'FontSize', 12);
else
    % Simple plot if detailed info not available
    text(0.5, 0.5, sprintf('Covariance model for fold %d\nGO %d, Box %.1f deg, Years %d-%d', ...
        foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2)), ...
        'HorizontalAlignment', 'center', 'FontSize', 14);
    axis off;
end

% Save figure 1
basename1 = sprintf('TOARcov_go%d_CBV_box%.1f_fold%d_%d-%d_model', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig1, basename1, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig1);
end

%% Figure 2: Training vs Validation Stations (same as GO checkerboard but for reference)
fig2 = figure('Visible', opts.visible);
hold on;

% Plot validation stations (orange)
plot(obs.sMS(valMask, 1), obs.sMS(valMask, 2), 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [1.0 0.6 0.2], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

% Plot training stations (blue)
plot(obs.sMS(trainMask, 1), obs.sMS(trainMask, 2), 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.6 1.0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

xlabel('Longitude (deg.)', 'FontSize', 12);
ylabel('Latitude (deg.)', 'FontSize', 12);
title(sprintf('CBV Fold %d: Covariance Fit (Training Stations Only)\nGO %d, Box %.1f deg, Years %d-%d\nTraining: %d, Validation: %d', ...
    foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2), sum(trainMask), sum(valMask)), 'FontSize', 14);
legend({'Validation stations', 'Training stations'}, 'Location', 'best');
axis equal;
grid on;
set(gca, 'FontSize', 12);

% Save figure 2
basename2 = sprintf('TOARcov_go%d_CBV_box%.1f_fold%d_%d-%d_stations', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig2, basename2, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig2);
end

fprintf('  Created %d diagnostic plots for CBV covariance fold %d\n', length(figPaths), foldIdx);

end
