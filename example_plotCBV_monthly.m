% example_plotCBV_monthly.m
%
% Master orchestration script for monthly CBV analysis.
% Parallel to example_plotCBV.m but operates on monthly .mat files and
% groups results by calendar month (Jan-Dec).
%
% PHASE 1 (plotCBVmonthly_Phase1): per-method
%   - Scatter by month (4x3 grid)
%   - Metrics by month (R², RMSE, MAE, NMB vs Jan-Dec)
%   - Regional heatmap (regions × months)
%
% PHASE 2 (plotCBVmonthly_Phase2): per-method
%   - Residual boxplot by month
%   - Standard residual/uncertainty/regional analysis
%
% PHASE 3 (aggregateCBVmonthlyStats + plotCBVmonthly): all methods together
%   - Seasonal cycle (mean ± std per month)
%   - Chronological time series
%   - Grouped bar comparison (Figure 3)
%   - Delta improvement vs baseline (Figure 4)
%   - Winner-by-month heatmap (Figure 5)
%   - Year-to-year stability (Figure 6)
%
% Prerequisites:
%   runCBV_toar has been completed for all methods listed below.
%   Monthly .mat files must exist in cbvMonthlyDir.

clear; clc;

fprintf('\n========================================\n');
fprintf('  MONTHLY CBV ANALYSIS\n');
fprintf('========================================\n');

%% ============================================================
%% Configuration (mirrors example_plotCBV.m lines 7-42)
%% ============================================================

cbvResultsDir  = './7validation/CBV';
cbvMonthlyDir  = './7validation/CBV/monthly';

% Same 9 methods as example_plotCBV.m
all_methods = {'10000133_go0', '10000133_go3', '13000313-01', '13000313-02', ...
               '13000313-10', '13000313-04', '13000313-20', '13000313-05', ...
               '13000313-06'};

configNames = {
    'Obs. only (flat GO)', ...
    'Obs. only (fine GO)', ...
    'Obs. + MERRA2-GMI', ...
    'Obs. + M3fusion', ...
    'Obs. + UKML', ...
    'Obs. + OMI-MLS', ...
    'Obs. + NJML', ...
    'Obs. + MERRA2-GMI + OMI-MLS', ...
    'Obs. + M3fusion + OMI-MLS'
};

allYears   = [2013, 2014, 2016, 2017];   % use [] for all years
boxSize    = 5;                           % canonical box size (degrees)
goScenario = 3;

% Append go scenario to methods that don't already specify it
% (mirrors example_plotCBV.m lines 33-39)
for i = 1:length(all_methods)
    if ~contains(all_methods{i}, 'go')
        all_methods{i} = sprintf('%s_go%d', all_methods{i}, goScenario);
    end
end

% Select which phases to run
% plotLevels = {'phase1', 'phase2', 'phase3'};
plotLevels = {'phase3'};

%% ============================================================
%% PHASE 1 and PHASE 2: per-method, per-year
%% (mirrors example_plotCBV.m lines 46-94)
%% ============================================================

if ismember('phase1', plotLevels) || ismember('phase2', plotLevels)
    fprintf('\n=== Phase 1 / Phase 2: Per-Method Monthly Plots ===\n');

    for i = 1:length(all_methods)
        method = all_methods{i};

        % File pattern for this method and box size (monthly files)
        % Monthly files: CBV_BME{method}_go{scenario}_box{size}_fold{n}_{year}_{month:02d}.mat
        filePattern = sprintf('CBV_BME%s*_box%d*_????_??.mat', method, boxSize);

        % Check if any files exist
        testFiles = dir(fullfile(cbvMonthlyDir, filePattern));
        if isempty(testFiles)
            fprintf('No monthly files found for method %s — skipping\n', method);
            continue;
        end

        figDir = fullfile(cbvResultsDir, 'figs_monthly', method);

        % Skip if already done
        if exist(figDir, 'dir')
            fprintf('Figures already exist for %s — skipping\n', method);
            continue;
        end

        fprintf('\n--- Processing: %s (%s) ---\n', method, configNames{i});

        if ismember('phase1', plotLevels)
            fprintf('Generating Phase 1 monthly plots...\n');
            plotCBVmonthly_Phase1(cbvMonthlyDir, ...
                'filePattern', filePattern, ...
                'saveDir',     figDir, ...
                'years',       allYears, ...
                'dpi',         300, ...
                'visible',     'on');
            close all;
        end

        if ismember('phase2', plotLevels)
            fprintf('Generating Phase 2 monthly plots...\n');
            plotCBVmonthly_Phase2(cbvMonthlyDir, ...
                'filePattern', filePattern, ...
                'saveDir',     figDir, ...
                'years',       allYears, ...
                'dpi',         300, ...
                'visible',     'on');
            close all;
        end
    end
end

%% ============================================================
%% PHASE 3: Multi-method comparison at monthly resolution
%% (mirrors example_plotCBV.m lines 102-116)
%% ============================================================

if ismember('phase3', plotLevels)
    fprintf('\n=== Phase 3: Multi-Method Monthly Comparison ===\n');

    % Base valParam for aggregateCBVmonthlyStats
    valParam            = struct();
    valParam.goScenario = goScenario;
    valParam.valYears   = allYears;
    valParam.valMonths  = 1:12;
    valParam.nFolds     = 2;

    opts.boxSize        = boxSize;
    opts.forceRecompute = false;

    % Load monthly stats table for each method
    allTables = cell(1, length(all_methods));
    for i = 1:length(all_methods)
        valParam.BMEmethod = all_methods{i};
        fprintf('Loading monthly stats for %s...\n', all_methods{i});
        try
            allTables{i} = aggregateCBVmonthlyStats(valParam, opts);
        catch ME
            warning('Could not aggregate %s: %s', all_methods{i}, ME.message);
            allTables{i} = table();
        end
    end

    % Filter to non-empty tables
    validIdx = ~cellfun(@isempty, allTables);
    if sum(validIdx) == 0
        warning('No valid monthly stats tables — Phase 3 skipped');
    else
        validTables = allTables(validIdx);

        % Set primary method to first valid table
        valParam.BMEmethod = all_methods{find(validIdx, 1)};

        fprintf('Generating Phase 3 comparison plots (%d methods)...\n', sum(validIdx));

        % plotCBVmonthly produces Figures 1-2 always, Figures 3-6 when nMethods>=2
        plotCBVmonthly(validTables{1}, valParam, validTables{2:end});
    end
end

fprintf('\n========================================\n');
fprintf('  MONTHLY ANALYSIS COMPLETE\n');
fprintf('  Phase 1/2 figures: %s/figs_monthly/\n', cbvResultsDir);
fprintf('  Phase 3 figures:   %s/figures/\n', cbvResultsDir);
fprintf('========================================\n\n');
