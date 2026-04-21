function figPaths = plotCBVmonthly_Phase1(cbvMonthlyDir, varargin)
% plotCBVmonthly_Phase1 - Monthly CBV plotting (Phase 1: scatter, metrics, regional)
%
% Parallel to plotCBVresults_Phase1 but operates on monthly .mat files
% and groups results by calendar month (Jan–Dec) instead of by year.
%
% SYNTAX:
%   figPaths = plotCBVmonthly_Phase1(cbvMonthlyDir)
%   figPaths = plotCBVmonthly_Phase1(cbvMonthlyDir, 'Name', Value, ...)
%
% INPUTS:
%   cbvMonthlyDir - Directory containing monthly CBV .mat files
%                   (e.g., '7validation/CBV/monthly')
%
% OPTIONAL PARAMETERS:
%   'saveDir'     - Directory to save figures (default: cbvMonthlyDir/../figs_monthly_phase1)
%   'dpi'         - Figure resolution (default: 300)
%   'visible'     - 'on' or 'off' (default: 'off')
%   'filePattern' - Glob pattern to match monthly files (default: 'CBV_*_??_??.mat')
%   'years'       - Years to include (default: [] = all)
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% PRODUCES:
%   CBV_monthly_scatter_by_month.png  — 4x3 scatter grid, one panel per month
%   CBV_monthly_metrics_by_month.png  — R², RMSE, MAE, NMB vs Jan-Dec
%   CBV_monthly_regional_by_month.png — Region × month R² heatmap
%
% SEE ALSO:
%   plotCBVresults_Phase1, plotCBVmonthly_Phase2, example_plotCBV_monthly

%% Parse inputs
p = inputParser;
addRequired(p, 'cbvMonthlyDir', @ischar);
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', 'CBV_*_??_??.mat', @ischar);
addParameter(p, 'years', [], @isnumeric);

parse(p, cbvMonthlyDir, varargin{:});
opts = p.Results;

if isempty(opts.saveDir)
    opts.saveDir = fullfile(cbvMonthlyDir, '..', 'figs_monthly_phase1');
end
if ~exist(opts.saveDir, 'dir'), mkdir(opts.saveDir); end

monthAbbr = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};

fprintf('=== Monthly Phase 1: CBV Plotting at Monthly Resolution ===\n');
fprintf('Results directory: %s\n', cbvMonthlyDir);
fprintf('Save directory: %s\n', opts.saveDir);

%% Load all monthly CBV result files
resultFiles = dir(fullfile(cbvMonthlyDir, opts.filePattern));
if isempty(resultFiles)
    error('No monthly CBV files found matching: %s\n  in: %s', opts.filePattern, cbvMonthlyDir);
end

fprintf('Found %d monthly CBV files\n', length(resultFiles));

allData = [];
for i = 1:length(resultFiles)
    filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);
    [~, fname, ~] = fileparts(resultFiles(i).name);

    % Extract Year and Month: ..._YYYY_MM  (same naming as runCBV_toar line 346)
    ymMatch = regexp(fname, '_(\d{4})_(\d{2})$', 'tokens');
    if isempty(ymMatch), continue; end
    fileYear  = str2double(ymMatch{1}{1});
    fileMonth = str2double(ymMatch{1}{2});

    % Filter by requested years
    if ~isempty(opts.years) && ~ismember(fileYear, opts.years), continue; end

    % Extract BoxSize and Fold from filename
    boxMatch  = regexp(fname, '_box([\d.]+)_', 'tokens');
    foldMatch = regexp(fname, '_fold(\d+)_', 'tokens');
    fileBoxSize = NaN;  fileFold = NaN;
    if ~isempty(boxMatch),  fileBoxSize = str2double(boxMatch{1}{1}); end
    if ~isempty(foldMatch), fileFold    = str2double(foldMatch{1}{1}); end

    try
        data = load(filePath);
        if ~isfield(data, 'monthResults'), continue; end
        mr = data.monthResults;

        if isempty(mr.Y_obs) || isempty(mr.Y_est), continue; end

        entry          = struct();
        entry.Y_obs    = mr.Y_obs(:);
        entry.Y_est    = mr.Y_est(:);
        entry.sk       = mr.sk;           % [n × 2]: [lon, lat]
        entry.tk       = mr.tk(:);
        entry.Year     = fileYear;
        entry.Month    = fileMonth;
        entry.BoxSize  = fileBoxSize;
        entry.Fold     = fileFold;
        if isfield(mr, 'XkBMEv'), entry.XkBMEv = mr.XkBMEv(:); end

        % Per-file validation stats (mirrors runCBV_toar line 395)
        entry.stats = calculateValidationStats(mr.Y_obs, mr.Y_est);

        % Regional assignment (same as plotCBVresults_Phase1 line 102)
        entry.regions = assignRegions(mr.sk(:,1), mr.sk(:,2));

        allData = [allData; entry]; %#ok<AGROW>
    catch ME
        warning('plotCBVmonthly_Phase1:loadFail', 'Failed to load %s: %s', fname, ME.message);
    end
end

if isempty(allData)
    error('No valid monthly data found. Check filePattern and directory.');
end

fprintf('Loaded %d monthly entries\n', length(allData));

uniqueFolds = unique([allData.Fold]);
figPaths    = {};

%% Figure 1: Scatter by calendar month
fprintf('\nCreating scatter by month...\n');
figPaths = [figPaths; plotScatterByMonth(allData, monthAbbr, opts)];

%% Figure 2: Metrics by month
fprintf('Creating metrics by month...\n');
figPaths = [figPaths; plotMetricsByMonth(allData, uniqueFolds, monthAbbr, opts)];

%% Figure 3: Regional heatmap by month
fprintf('Creating regional heatmap by month...\n');
figPaths = [figPaths; plotRegionalByMonth(allData, monthAbbr, opts)];

fprintf('\n=== Monthly Phase 1 complete — %d figures in %s ===\n', length(figPaths), opts.saveDir);

end  % main function


%% ========================================================================
%% SUBFUNCTION: Scatter by calendar month (4x3 grid)
%% Mirrors plotCBVresults_Phase1 plotScatterByYear but grouped by month
%% ========================================================================
function figPaths = plotScatterByMonth(allData, monthAbbr, opts)

figPaths = {};

fig = figure('Visible', opts.visible, 'Position', [100 100 1200 900]);

for m = 1:12
    % Pool all years, folds, box sizes for this calendar month
    idx = find([allData.Month] == m);
    Y_obs_m = [];
    Y_est_m = [];
    for k = idx
        Y_obs_m = [Y_obs_m; allData(k).Y_obs]; %#ok<AGROW>
        Y_est_m = [Y_est_m; allData(k).Y_est]; %#ok<AGROW>
    end

    validIdx = ~isnan(Y_obs_m) & ~isnan(Y_est_m) & isfinite(Y_obs_m) & isfinite(Y_est_m);
    Y_obs_v  = Y_obs_m(validIdx);
    Y_est_v  = Y_est_m(validIdx);

    subplot(3, 4, m);
    hold on;

    if numel(Y_obs_v) >= 2
        R2   = corr(Y_obs_v, Y_est_v)^2;
        RMSE = sqrt(mean((Y_obs_v - Y_est_v).^2));
        N    = numel(Y_obs_v);

        scatter(Y_obs_v, Y_est_v, 5, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.2);

        allVals = [Y_obs_v; Y_est_v];
        lim = [min(allVals)*0.95, max(allVals)*1.05];
        plot(lim, lim, 'k--', 'LineWidth', 1.5);
        xlim(lim); ylim(lim);

        text(0.05, 0.95, sprintf('R² = %.3f\nRMSE = %.2f ppbv\nN = %d', R2, RMSE, N), ...
            'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
            'BackgroundColor', 'w', 'EdgeColor', 'k');
    else
        text(0.5, 0.5, 'No data', 'Units', 'normalized', 'HorizontalAlignment', 'center');
    end

    title(monthAbbr{m}, 'FontWeight', 'bold', 'FontSize', 11);
    xlabel('Observed (ppbv)', 'FontSize', 9);
    ylabel('Estimated (ppbv)', 'FontSize', 9);
    axis square; grid on; set(gca, 'FontSize', 8);
end

sgtitle('CBV Scatter by Calendar Month (All Years, Folds, Box Sizes)', 'FontSize', 13, 'FontWeight', 'bold');

basename = 'CBV_monthly_scatter_by_month';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;
if strcmp(opts.visible, 'off'), close(fig); end

end


%% ========================================================================
%% SUBFUNCTION: Metrics by month (2x2, per-fold lines + average)
%% Mirrors plotCBVresults_Phase1 plotMetricsByBoxSize but x-axis = months
%% ========================================================================
function figPaths = plotMetricsByMonth(allData, uniqueFolds, monthAbbr, opts)

figPaths = {};

metrics      = {'R2', 'RMSE', 'MAE', 'NMB'};
metricLabels = {'R²', 'RMSE (ppbv)', 'MAE (ppbv)', 'NMB (%)'};

fig = figure('Visible', opts.visible, 'Position', [100 100 1200 800]);

for iMetric = 1:4
    subplot(2, 2, iMetric);
    hold on;

    metricName = metrics{iMetric};

    % Per-fold: average over years for each calendar month
    foldMeans = NaN(12, length(uniqueFolds));
    for fi = 1:length(uniqueFolds)
        iFold = uniqueFolds(fi);
        for m = 1:12
            idx = find([allData.Month] == m & [allData.Fold] == iFold);
            if isempty(idx), continue; end
            % Each entry already has computed stats; average over years
            vals = arrayfun(@(e) e.stats.(metricName), allData(idx));
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                foldMeans(m, fi) = mean(vals);
            end
        end
    end

    % Average and std across folds
    avgMeans = mean(foldMeans, 2, 'omitnan');
    avgStd   = std(foldMeans, 0, 2, 'omitnan');

    % Per-fold lines (mirrors plotCBVresults_Phase1 lines 283-294)
    markers = {'o', '^', 's', 'd'};
    fColors = {[0.8 0.3 0.3], [0.3 0.8 0.3], [0.3 0.3 0.8], [0.8 0.8 0.3]};
    for fi = 1:length(uniqueFolds)
        ci = min(fi, 4);
        plot(1:12, foldMeans(:, fi), [markers{ci} '-'], ...
            'Color', fColors{ci}, 'LineWidth', 1.5, 'MarkerSize', 7, ...
            'MarkerFaceColor', fColors{ci}, ...
            'DisplayName', sprintf('Fold %d', uniqueFolds(fi)));
    end

    % Average with error bars (mirrors Phase1 lines 297-301)
    errorbar(1:12, avgMeans, avgStd, 'ko-', 'LineWidth', 2.5, 'MarkerSize', 9, ...
        'MarkerFaceColor', 'k', 'CapSize', 8, 'DisplayName', 'Average ± std');

    % Zero reference for bias metrics
    if ismember(metricName, {'NMB', 'ME', 'MBE'})
        yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    end

    set(gca, 'XTick', 1:12, 'XTickLabel', monthAbbr, 'XLim', [0.5 12.5]);
    xlabel('Month', 'FontSize', 11);
    ylabel(metricLabels{iMetric}, 'FontSize', 11);
    title(metricLabels{iMetric}, 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 8);
    grid on; set(gca, 'FontSize', 10);
end

sgtitle('CBV Metrics by Calendar Month (Per-Fold Lines and Average)', 'FontSize', 14, 'FontWeight', 'bold');

basename = 'CBV_monthly_metrics_by_month';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;
if strcmp(opts.visible, 'off'), close(fig); end

end


%% ========================================================================
%% SUBFUNCTION: Regional heatmap (regions × months)
%% Mirrors plotCBVresults_Phase1 plotRegionalPerformance but cols = months
%% ========================================================================
function figPaths = plotRegionalByMonth(allData, monthAbbr, opts)

figPaths = {};

% Collect all regions present in the data
allRegions = {};
for i = 1:length(allData)
    allRegions = [allRegions; allData(i).regions]; %#ok<AGROW>
end
uniqueRegions = unique(allRegions);
nRegions = length(uniqueRegions);

fprintf('  Found %d regions: %s\n', nRegions, strjoin(uniqueRegions, ', '));

% Build R² matrix [nRegions × 12]
R2_mat = NaN(nRegions, 12);
N_mat  = zeros(nRegions, 12);

for iReg = 1:nRegions
    region = uniqueRegions{iReg};
    for m = 1:12
        idx = find([allData.Month] == m);
        Y_obs_rm = [];
        Y_est_rm = [];
        for k = idx
            mask = strcmp(allData(k).regions, region);
            Y_obs_rm = [Y_obs_rm; allData(k).Y_obs(mask)]; %#ok<AGROW>
            Y_est_rm = [Y_est_rm; allData(k).Y_est(mask)]; %#ok<AGROW>
        end
        validIdx = ~isnan(Y_obs_rm) & ~isnan(Y_est_rm) & isfinite(Y_obs_rm) & isfinite(Y_est_rm);
        if sum(validIdx) >= 10
            R2_mat(iReg, m) = corr(Y_obs_rm(validIdx), Y_est_rm(validIdx))^2;
            N_mat(iReg, m)  = sum(validIdx);
        end
    end
end

% Heatmap (mirrors plotCBVresults_Phase1 lines 378-419)
fig = figure('Visible', opts.visible, 'Position', [100 100 1200 max(400, 60*nRegions + 150)]);

cmap = [linspace(1, 0.2, 256)', linspace(1, 0.4, 256)', linspace(1, 0.8, 256)'];
imagesc(R2_mat);
colormap(cmap);
cb = colorbar;
ylabel(cb, 'R²', 'FontSize', 12);
caxis([0.5 1.0]);

set(gca, 'XTick', 1:12, 'XTickLabel', monthAbbr);
set(gca, 'YTick', 1:nRegions, 'YTickLabel', uniqueRegions);
xlabel('Month', 'FontSize', 12);
ylabel('Region', 'FontSize', 12);
title('CBV Performance (R²) by Region and Calendar Month', 'FontSize', 14, 'FontWeight', 'bold');

% Annotate cells
for iReg = 1:nRegions
    for m = 1:12
        if ~isnan(R2_mat(iReg, m))
            text(m, iReg, sprintf('%.2f\n(n=%d)', R2_mat(iReg, m), N_mat(iReg, m)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 7, 'FontWeight', 'bold');
        end
    end
end
set(gca, 'FontSize', 10);

basename = 'CBV_monthly_regional_by_month';
figPath = saveTOARfigure(fig, basename, opts.saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;
if strcmp(opts.visible, 'off'), close(fig); end

end
