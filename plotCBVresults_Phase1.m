function figPaths = plotCBVresults_Phase1(cbvResultsDir, varargin)
% plotCBVresults_Phase1 - Enhanced CBV plotting (Phase 1: Core improvements)
%
% Creates comprehensive visualization of CBV results including:
% 1. Multi-panel scatter plots by year
% 2. Combined fold/average metrics by box size
% 3. Regional performance breakdown
%
% SYNTAX:
%   figPaths = plotCBVresults_Phase1(cbvResultsDir)
%   figPaths = plotCBVresults_Phase1(cbvResultsDir, 'Name', Value, ...)
%
% INPUTS:
%   cbvResultsDir - Directory containing CBV result .mat files
%
% OPTIONAL PARAMETERS:
%   'saveDir'    - Directory to save figures (default: cbvResultsDir/figs_phase1)
%   'dpi'        - Figure resolution (default: 300)
%   'visible'    - 'on' or 'off' for figure visibility (default: 'off')
%   'filePattern' - Pattern to match result files (default: 'CBV_*.mat')
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% EXAMPLE:
%   figPaths = plotCBVresults_Phase1('./7validation/CBV', 'visible', 'on');

%% Parse inputs
p = inputParser;
addRequired(p, 'cbvResultsDir', @ischar);
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', 'CBV_*.mat', @ischar);

parse(p, cbvResultsDir, varargin{:});
opts = p.Results;

% Set default save directory
if isempty(opts.saveDir)
    opts.saveDir = fullfile(cbvResultsDir, 'figs_phase1');
end

if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('=== Phase 1: Enhanced CBV Plotting ===\n');
fprintf('Results directory: %s\n', cbvResultsDir);
fprintf('Save directory: %s\n', opts.saveDir);

%% Load all CBV result files
resultFiles = dir(fullfile(cbvResultsDir, opts.filePattern));
if isempty(resultFiles)
    error('No CBV result files found matching pattern: %s', opts.filePattern);
end

fprintf('Found %d CBV result files\n', length(resultFiles));

% Aggregate data across all files
allData = [];
for i = 1:length(resultFiles)
    filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);
    try
        data = load(filePath);

        % Extract key information
        if isfield(data, 'annualResults') && isfield(data, 'annualStats')
            entry = struct();
            entry.Y_obs = data.annualResults.Y_obs;
            entry.Y_est = data.annualResults.Y_est;
            entry.sk = data.annualResults.sk;
            entry.tk = data.annualResults.tk;
            entry.BoxSize = data.annualStats.BoxSize;
            entry.Fold = data.annualStats.Fold;
            entry.Year = data.annualStats.Year;
            entry.stats = data.annualStats;
            entry.valParam = data.valParam;

            % Assign regions
            entry.regions = assignRegions(entry.sk(:,1), entry.sk(:,2));

            % Extract year from tk if not in stats
            if ~isfield(entry, 'Year') || isempty(entry.Year)
                entry.Year = floor(mean(entry.tk));
            end

            allData = [allData; entry];
        end
    catch ME
        warning('Failed to load %s: %s', resultFiles(i).name, ME.message);
    end
end

if isempty(allData)
    error('No valid data found in result files');
end

fprintf('Loaded data from %d result files\n', length(allData));

%% Extract unique values
uniqueYears = unique([allData.Year]);
uniqueBoxSizes = unique([allData.BoxSize]);
uniqueFolds = unique([allData.Fold]);

fprintf('Years: %s\n', mat2str(uniqueYears));
fprintf('Box sizes: %s\n', mat2str(uniqueBoxSizes));
fprintf('Folds: %s\n', mat2str(uniqueFolds));

figPaths = {};

%% Plot 1: Multi-panel scatter plots by year
fprintf('\nCreating multi-panel scatter plots by year...\n');
figPaths = [figPaths; plotScatterByYear(allData, uniqueYears, opts)];

%% Plot 2: Combined fold/average metrics by box size
fprintf('\nCreating combined fold/average metrics plots...\n');
figPaths = [figPaths; plotMetricsByBoxSize(allData, uniqueBoxSizes, uniqueFolds, opts)];

%% Plot 3: Regional performance analysis
fprintf('\nCreating regional performance plots...\n');
figPaths = [figPaths; plotRegionalPerformance(allData, uniqueBoxSizes, opts)];

fprintf('\n=== Phase 1 plotting complete ===\n');
fprintf('Created %d figures in %s\n', length(figPaths), opts.saveDir);

end

%% ========================================================================
%% SUBFUNCTION: Multi-panel scatter plots by year
%% ========================================================================
function figPaths = plotScatterByYear(allData, uniqueYears, opts)

figPaths = {};

% Determine subplot layout
nYears = length(uniqueYears);
nCols = ceil(sqrt(nYears));
nRows = ceil(nYears / nCols);

% Create figure
fig = figure('Visible', opts.visible, 'Position', [100 100 300*nCols 300*nRows]);

for iYear = 1:nYears
    year = uniqueYears(iYear);

    % Get data for this year (aggregate across folds and box sizes)
    yearIdx = find([allData.Year] == year);
    Y_obs_year = [];
    Y_est_year = [];

    for idx = yearIdx
        Y_obs_year = [Y_obs_year; allData(idx).Y_obs];
        Y_est_year = [Y_est_year; allData(idx).Y_est];
    end

    % Compute statistics
    validIdx = ~isnan(Y_obs_year) & ~isnan(Y_est_year);
    Y_obs_valid = Y_obs_year(validIdx);
    Y_est_valid = Y_est_year(validIdx);

    R = corrcoef(Y_obs_valid, Y_est_valid);
    R2 = R(1,2)^2;
    RMSE = sqrt(mean((Y_obs_valid - Y_est_valid).^2));
    N = length(Y_obs_valid);

    % Create subplot
    subplot(nRows, nCols, iYear);
    hold on;

    % Scatter plot with transparency
    scatter(Y_obs_valid, Y_est_valid, 10, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.3);

    % 1:1 line
    xlims = xlim;
    ylims = ylim;
    minVal = min([xlims(1) ylims(1)]);
    maxVal = max([xlims(2) ylims(2)]);
    plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 1.5);

    % Labels and title
    xlabel('Observed (ppb)', 'FontSize', 10);
    ylabel('Estimated (ppb)', 'FontSize', 10);
    title(sprintf('Year %d', year), 'FontSize', 12, 'FontWeight', 'bold');

    % Add statistics text
    text(0.05, 0.95, sprintf('R² = %.3f\nRMSE = %.2f ppb\nN = %d', R2, RMSE, N), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9, ...
        'BackgroundColor', 'w', 'EdgeColor', 'k');

    axis equal;
    grid on;
    set(gca, 'FontSize', 9);
end

sgtitle('CBV Performance by Year (All Folds and Box Sizes)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
basename = 'CBV_scatter_by_year';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Combined fold/average metrics by box size
%% ========================================================================
function figPaths = plotMetricsByBoxSize(allData, uniqueBoxSizes, uniqueFolds, opts)

figPaths = {};

% Metrics to plot
metrics = {'R2', 'RMSE', 'MAE', 'NMB'};
metricLabels = {'R²', 'RMSE (ppb)', 'MAE (ppb)', 'NMB (%)'};

% Create figure with 4 subplots
fig = figure('Visible', opts.visible, 'Position', [100 100 1200 800]);

for iMetric = 1:length(metrics)
    subplot(2, 2, iMetric);
    hold on;

    metricName = metrics{iMetric};

    % Collect data for each box size and fold
    foldData = struct();
    for iFold = uniqueFolds
        foldData(iFold).boxSizes = [];
        foldData(iFold).values = [];
    end

    avgData = struct('boxSizes', [], 'means', [], 'stds', []);

    for iBox = 1:length(uniqueBoxSizes)
        boxSize = uniqueBoxSizes(iBox);

        % Get values for each fold
        foldValues = [];
        for iFold = uniqueFolds
            idx = find([allData.BoxSize] == boxSize & [allData.Fold] == iFold);
            if ~isempty(idx)
                % Aggregate across years for this fold
                vals = [allData(idx).stats];
                if isfield(vals, metricName)
                    metricVals = [vals.(metricName)];
                    meanVal = mean(metricVals);

                    foldData(iFold).boxSizes(end+1) = boxSize;
                    foldData(iFold).values(end+1) = meanVal;
                    foldValues(end+1) = meanVal;
                end
            end
        end

        % Compute average and std across folds
        if ~isempty(foldValues)
            avgData.boxSizes(end+1) = boxSize;
            avgData.means(end+1) = mean(foldValues);
            avgData.stds(end+1) = std(foldValues);
        end
    end

    % Plot individual folds with different markers
    markers = {'o', '^', 's', 'd'};
    colors = {[0.8 0.3 0.3], [0.3 0.8 0.3], [0.3 0.3 0.8], [0.8 0.8 0.3]};

    for iFold = uniqueFolds
        if iFold <= length(markers)
            plot(foldData(iFold).boxSizes, foldData(iFold).values, ...
                [markers{iFold} '-'], 'MarkerSize', 8, 'LineWidth', 1.5, ...
                'Color', colors{iFold}, 'MarkerFaceColor', colors{iFold}, ...
                'DisplayName', sprintf('Fold %d', iFold));
        end
    end

    % Plot average with error bars
    if ~isempty(avgData.means)
        errorbar(avgData.boxSizes, avgData.means, avgData.stds, ...
            'ko-', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'k', ...
            'DisplayName', 'Average ± std', 'CapSize', 10);
    end

    xlabel('Box Size (degrees)', 'FontSize', 11);
    ylabel(metricLabels{iMetric}, 'FontSize', 11);
    title(metricLabels{iMetric}, 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    set(gca, 'FontSize', 10);
end

sgtitle('CBV Metrics by Box Size (Individual Folds and Average)', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
basename = 'CBV_metrics_by_boxsize';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;

if strcmp(opts.visible, 'off')
    close(fig);
end

end

%% ========================================================================
%% SUBFUNCTION: Regional performance analysis
%% ========================================================================
function figPaths = plotRegionalPerformance(allData, uniqueBoxSizes, opts)

figPaths = {};

% Get all unique regions
allRegions = {};
for i = 1:length(allData)
    allRegions = [allRegions; allData(i).regions];
end
uniqueRegions = unique(allRegions);

fprintf('  Found %d regions: %s\n', length(uniqueRegions), strjoin(uniqueRegions, ', '));

% Compute R² by region and box size
nRegions = length(uniqueRegions);
nBoxSizes = length(uniqueBoxSizes);

R2_byRegion = NaN(nRegions, nBoxSizes);
N_byRegion = zeros(nRegions, nBoxSizes);

for iReg = 1:nRegions
    region = uniqueRegions{iReg};

    for iBox = 1:nBoxSizes
        boxSize = uniqueBoxSizes(iBox);

        % Aggregate data for this region and box size
        Y_obs_all = [];
        Y_est_all = [];

        for i = 1:length(allData)
            if allData(i).BoxSize == boxSize
                % Find points in this region
                regionMask = strcmp(allData(i).regions, region);
                Y_obs_all = [Y_obs_all; allData(i).Y_obs(regionMask)];
                Y_est_all = [Y_est_all; allData(i).Y_est(regionMask)];
            end
        end

        % Compute R² for this region/box size
        validIdx = ~isnan(Y_obs_all) & ~isnan(Y_est_all);
        if sum(validIdx) >= 10
            Y_obs_valid = Y_obs_all(validIdx);
            Y_est_valid = Y_est_all(validIdx);
            R = corrcoef(Y_obs_valid, Y_est_valid);
            R2_byRegion(iReg, iBox) = R(1,2)^2;
            N_byRegion(iReg, iBox) = sum(validIdx);
        end
    end
end

% Create heatmap
fig = figure('Visible', opts.visible, 'Position', [100 100 800 600]);

% Create custom colormap (white to blue)
cmap = [linspace(1, 0.2, 256)', linspace(1, 0.4, 256)', linspace(1, 0.8, 256)'];

imagesc(R2_byRegion);
colormap(cmap);
cb = colorbar;
ylabel(cb, 'R²', 'FontSize', 12);
caxis([0.5 1.0]);

% Set axis labels
set(gca, 'XTick', 1:nBoxSizes, 'XTickLabel', arrayfun(@num2str, uniqueBoxSizes, 'UniformOutput', false));
set(gca, 'YTick', 1:nRegions, 'YTickLabel', uniqueRegions);
xlabel('Box Size (degrees)', 'FontSize', 12);
ylabel('Region', 'FontSize', 12);
title('CBV Performance (R²) by Region and Box Size', 'FontSize', 14, 'FontWeight', 'bold');

% Add text annotations with R² values
for iReg = 1:nRegions
    for iBox = 1:nBoxSizes
        if ~isnan(R2_byRegion(iReg, iBox))
            text(iBox, iReg, sprintf('%.3f\n(n=%d)', R2_byRegion(iReg, iBox), N_byRegion(iReg, iBox)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 8, 'FontWeight', 'bold');
        end
    end
end

set(gca, 'FontSize', 10);

% Save figure
basename = 'CBV_regional_performance';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;

if strcmp(opts.visible, 'off')
    close(fig);
end

end
