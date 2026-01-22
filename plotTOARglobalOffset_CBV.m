function figPaths = plotTOARglobalOffset_CBV(obs, go, boxSize, foldIdx, yearRange, trainMask, valMask, varargin)
% plotTOARglobalOffset_CBV - Plot fold-specific global offset with diagnostic checkerboard
%
% Creates diagnostic plots for CBV showing the checkerboard pattern and
% fold-specific global offset field
%
% SYNTAX:
%   figPaths = plotTOARglobalOffset_CBV(obs, go, boxSize, foldIdx, yearRange, trainMask, valMask)
%   figPaths = plotTOARglobalOffset_CBV(..., 'Name', Value, ...)
%
% INPUTS:
%   obs        - Full observational data structure (all stations)
%   go         - Fold-specific global offset structure
%   boxSize    - Checker box size in degrees
%   foldIdx    - Fold index (1 or 2)
%   yearRange  - [startYear endYear] used for GO computation
%   trainMask  - Logical mask for training stations
%   valMask    - Logical mask for validation stations
%
% OPTIONAL PARAMETERS:
%   'saveDir'   - Directory to save figures (default: './2globalOffset/CBV/figs/box{boxSize}')
%   'dpi'       - Resolution in DPI (default: 300)
%   'visible'   - 'on' or 'off' for figure visibility (default: 'off')
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% CREATED PLOTS:
%   1. Checkerboard pattern with training/validation stations
%   2. Smoothed spatial trend of GO (training stations only)
%   3. Temporal mean trend
%
% EXAMPLE:
%   figPaths = plotTOARglobalOffset_CBV(obs, go_fold, 3.0, 1, [2016 2018], ...
%       trainMask, valMask, 'visible', 'off');

%% Parse inputs
p = inputParser;
addRequired(p, 'obs');
addRequired(p, 'go');
addRequired(p, 'boxSize');
addRequired(p, 'foldIdx');
addRequired(p, 'yearRange');
addRequired(p, 'trainMask');
addRequired(p, 'valMask');
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));

parse(p, obs, go, boxSize, foldIdx, yearRange, trainMask, valMask, varargin{:});
opts = p.Results;

% Set default save directory
if isempty(opts.saveDir)
    opts.saveDir = sprintf('./2globalOffset/CBV/figs/box%.1f', boxSize);
end

figPaths = {};

%% Figure 1: Checkerboard Pattern with Training/Validation Stations
fig1 = figure('Visible', opts.visible);
hold on;

% Plot validation stations (orange)
plot(obs.sMS(valMask, 1), obs.sMS(valMask, 2), 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [1.0 0.6 0.2], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

% Plot training stations (blue)
plot(obs.sMS(trainMask, 1), obs.sMS(trainMask, 2), 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.6 1.0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

% Add checkerboard grid
lonRange = [min(obs.sMS(:,1)) max(obs.sMS(:,1))];
latRange = [min(obs.sMS(:,2)) max(obs.sMS(:,2))];
lonEdges = floor(lonRange(1)/boxSize)*boxSize : boxSize : ceil(lonRange(2)/boxSize)*boxSize;
latEdges = floor(latRange(1)/boxSize)*boxSize : boxSize : ceil(latRange(2)/boxSize)*boxSize;

for i = 1:length(lonEdges)
    plot([lonEdges(i) lonEdges(i)], [latRange(1)-5 latRange(2)+5], 'k-', 'LineWidth', 0.5);
end
for j = 1:length(latEdges)
    plot([lonRange(1)-5 lonRange(2)+5], [latEdges(j) latEdges(j)], 'k-', 'LineWidth', 0.5);
end

xlabel('Longitude (deg.)', 'FontSize', 12);
ylabel('Latitude (deg.)', 'FontSize', 12);
title(sprintf('CBV Fold %d: Box %.1f deg, Years %d-%d\nTraining: %d stations (blue), Validation: %d stations (orange)', ...
    foldIdx, boxSize, yearRange(1), yearRange(2), sum(trainMask), sum(valMask)), 'FontSize', 14);
legend({'Validation stations', 'Training stations'}, 'Location', 'best');
axis equal;
axis([lonRange(1)-5 lonRange(2)+5 latRange(1)-2 latRange(2)+2]);
grid on;
set(gca, 'FontSize', 12);

% Save figure 1
basename1 = sprintf('TOARgo_go%d_CBV_box%.1f_fold%d_%d-%d_checkerboard', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig1, basename1, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig1);
end

%% Figure 2: Smoothed Spatial Trend (Training Stations Only)
fig2 = figure('Visible', opts.visible);

% Get display area
ax = [lonRange(1)-5 lonRange(2)+5 latRange(1)-2 latRange(2)+2];

% Create interpolated background
[xgkm, ygkm] = meshgrid(ax(1):0.5:ax(2), ax(3):0.5:ax(4));
[zgkm] = griddata(go.sMS(:,1), go.sMS(:,2), go.ms, xgkm, ygkm);
zgkm = reshape(zgkm, size(xgkm));

colormap(redyellow);
pcolor(xgkm, ygkm, zgkm);
shading interp;
cb = colorbar;
ylabel(cb, obs.Ylabel, 'FontSize', 12);
hold on;
axis(ax);

% Overlay training stations
plot(go.sMSraw(:,1), go.sMSraw(:,2), '.k', 'MarkerSize', 6);

title(sprintf('Fold %d Spatial Trend (Training Stations Only)\nGO Scenario %d, Box %.1f deg, Years %d-%d', ...
    foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2)), 'FontSize', 14);
xlabel('Longitude (deg.)', 'FontSize', 12);
ylabel('Latitude (deg.)', 'FontSize', 12);
set(gca, 'FontSize', 12);

% Save figure 2
basename2 = sprintf('TOARgo_go%d_CBV_box%.1f_fold%d_%d-%d_spatial', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig2, basename2, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig2);
end

%% Figure 3: Temporal Mean Trend
fig3 = figure('Visible', opts.visible);
hold on;
htRaw = plot(go.tMEraw, go.mtRaw, 'o-r', 'LineWidth', 1.5, 'MarkerSize', 4);
ht = plot(go.tME, go.mt, '.-k', 'LineWidth', 1.5);
xlabel('Time (years)', 'FontSize', 12);
ylabel(obs.Ylabel, 'FontSize', 12);
title(sprintf('Fold %d Temporal Mean Trend (Training Stations Only)\nGO Scenario %d, Box %.1f deg, Years %d-%d', ...
    foldIdx, go.scenario, boxSize, yearRange(1), yearRange(2)), 'FontSize', 14);
legend([htRaw ht], 'Raw mean trend', 'Smoothed mean trend', 'Location', 'best');
grid on;
set(gca, 'FontSize', 12);

% Save figure 3
basename3 = sprintf('TOARgo_go%d_CBV_box%.1f_fold%d_%d-%d_temporal', ...
    go.scenario, boxSize, foldIdx, yearRange(1), yearRange(2));
figPaths{end+1} = saveTOARfigure(fig3, basename3, opts.saveDir, 'dpi', opts.dpi);

if strcmp(opts.visible, 'off')
    close(fig3);
end

fprintf('  Created %d diagnostic plots for CBV fold %d\n', length(figPaths), foldIdx);

end
