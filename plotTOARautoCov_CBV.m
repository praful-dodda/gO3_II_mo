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
%   figPaths - Cell array of saved figure paths (one combined figure)
%
% CREATED PLOTS (single 3-panel figure):
%   - Top-left : Spatial covariance fit (experimental + fitted model)
%   - Top-right: Temporal covariance fit (experimental + fitted model)
%   - Bottom   : Training vs validation station locations
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

%% Combined diagnostic figure (3 panels):
%   - Top-left : Spatial Covariance Fit (matches getTOARautoCov_updated.m style)
%   - Top-right: Temporal Covariance Fit
%   - Bottom   : Training vs Validation station map (spans full width)
%  Fitted curves are reconstructed from the stored BME model
%  (cov.covmodel/cov.covparam) via coord2K: spatial = lag [r,0,0],
%  temporal = [0,0,t]. Both covariance panels show covariance (not semivariance).
fig1 = figure('Visible', opts.visible, 'Position', [100, 100, 1100, 850]);
haveModel = isfield(cov, 'covmodel') && isfield(cov, 'covparam');

% --- Top-left: Spatial Covariance Fit ---
ax1 = subplot(2, 2, 1);
hold(ax1, 'on');
if isfield(cov, 'rLag') && isfield(cov, 'Cr')
    plot(ax1, cov.rLag, cov.Cr, 'bo', 'MarkerFaceColor', 'b', 'DisplayName', 'Experimental');
end
if haveModel && isfield(cov, 'rLag') && ~isempty(cov.rLag)
    r_fine = linspace(0, max(cov.rLag), 500)';
    Cs = coord2K([r_fine, zeros(numel(r_fine), 2)], [0 0 0], cov.covmodel, cov.covparam);
    plot(ax1, r_fine, Cs, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');
end
xlabel(ax1, 'Spatial Lag (deg)'); ylabel(ax1, 'Covariance');
title(ax1, 'Spatial Covariance Fit'); grid(ax1, 'on');
legend(ax1, 'show', 'Location', 'best'); hold(ax1, 'off');

% --- Top-right: Temporal Covariance Fit ---
ax2 = subplot(2, 2, 2);
hold(ax2, 'on');
if isfield(cov, 'tLag') && isfield(cov, 'Ct')
    plot(ax2, cov.tLag, cov.Ct, 'bo', 'MarkerFaceColor', 'b', 'DisplayName', 'Experimental');
end
if haveModel && isfield(cov, 'tLag') && ~isempty(cov.tLag) && max(cov.tLag) > 0
    t_fine = linspace(0, max(cov.tLag), 500)';
    Ctf = coord2K([zeros(numel(t_fine), 2), t_fine], [0 0 0], cov.covmodel, cov.covparam);
    plot(ax2, t_fine, Ctf, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fitted Model');
end
xlabel(ax2, 'Temporal Lag (Years)'); ylabel(ax2, 'Covariance');
title(ax2, 'Temporal Covariance Fit'); grid(ax2, 'on');
legend(ax2, 'show', 'Location', 'best'); hold(ax2, 'off');

% --- Bottom (full width): Training vs Validation Stations ---
ax3 = subplot(2, 2, [3 4]);
hold(ax3, 'on');
plot(ax3, obs.sMS(valMask, 1), obs.sMS(valMask, 2), 'o', ...
    'MarkerSize', 6, 'MarkerFaceColor', [1.0 0.6 0.2], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', 'Validation stations');
plot(ax3, obs.sMS(trainMask, 1), obs.sMS(trainMask, 2), 'o', ...
    'MarkerSize', 6, 'MarkerFaceColor', [0.2 0.6 1.0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', 'Training stations');
xlabel(ax3, 'Longitude (deg.)'); ylabel(ax3, 'Latitude (deg.)');
title(ax3, sprintf('Training vs Validation Stations (Training: %d, Validation: %d)', ...
    sum(trainMask), sum(valMask)));
legend(ax3, 'show', 'Location', 'best'); axis(ax3, 'equal'); grid(ax3, 'on'); hold(ax3, 'off');

% Enhanced title with CBV context (fold, GO, box, year range)
sgtitle(fig1, sprintf('CBV Fold %d Covariance: GO=%d, Box=%.1f deg, %d-%d (Training Stations Only)', ...
    foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2)), 'FontWeight', 'bold');

% Save combined diagnostic figure
basename1 = sprintf('TOARcov_go%d_CBV_box%.1f_fold%d_%d-%d_diagnostic', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig1, basename1, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig1);
end

fprintf('  Created %d diagnostic plot for CBV covariance fold %d\n', length(figPaths), foldIdx);

end
