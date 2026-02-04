%% runCBV.m
% Standalone script to run Checker-Board Validation (CBV) for TOAR ozone data
%
% This script provides a clean interface for running CBV without using
% analysisTOAR.m. It ensures proper data leakage prevention by:
%   1. Using ±1 year data window for each validation year
%   2. Computing fold-specific GO and Covariance using training stations only
%   3. Caching results efficiently per (year, box, fold)
%
% Quick start: Modify parameters below, then run the script
%
% USAGE:
%   1. Set validation parameters in sections below
%   2. Run: >> runCBV
%   3. Results saved to: ./7validation/CBV/
%
% SEE ALSO: runCBV_toar, evaluateFold_CBV_monthly, getCheckerBoard

clear; close all;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('               CHECKER-BOARD VALIDATION (CBV) FOR TOAR\n');
fprintf('========================================================================\n');
fprintf('\n');

%% ====================================================================
%                    DATA CONFIGURATION
% ====================================================================

% Station types to include
valParam.stationTypes = 'all';  % 'all', 'urban', 'rural', or {'urban','rural'}

% Time range for loading data (should cover all validation years ± 1 year)
% Example: To validate 2017, load 2015-2020 so ±1 year window is available
valParam.timeRange = [2010 2015];  % [startYear endYear]

% Log transformation
valParam.logTransf = 0;  % 0=no, 1=yes (use 0 for regular concentrations)

%% ====================================================================
%                    VALIDATION CONFIGURATION
% ====================================================================

% Years to validate
valParam.valYears = [2013 2014];  % e.g., 2017 or [2016 2017 2018]

% Months to validate (within each year)
valParam.valMonths = 1:12;  % All months, or specific: [6 7 8] for JJA

% Checker box sizes to test (degrees)
valParam.boxSizes = 5.0;  % e.g., [2.0, 3.0, 4.0, 5.0]

%% ====================================================================
%                    GLOBAL OFFSET CONFIGURATION
% ====================================================================

% Global offset scenario (controls spatial/temporal smoothing)
%   0 = Zero (no offset)
%   1 = Flat (constant mean)
%   2 = Domain-wide S/T smoothing
%   3 = Regional S/T smoothing (RECOMMENDED)
%   6 = Local S/T smoothing
valParam.goScenario = 3;

% Force re-estimation of GO (useful if parameters changed)
valParam.forceGO = 1;  % 0=use cached, 1=force new estimation

% Plotting level for global offset
valParam.goPlot = 0;  % 0=no plots, 1=basic (not recommended during CBV)

%% ====================================================================
%                    COVARIANCE CONFIGURATION
% ====================================================================

% Temporal covariance model
valParam.temporalModel = 'holecos';  % 'exponential' or 'holecos'

% Force re-estimation
valParam.forceCov = 1;  % 0=use cached, 1=force new estimation

%% ====================================================================
%                    BME METHOD CONFIGURATION
% ====================================================================

% 8-digit BME method code: [obsType][CTMtype][RAMP][RAMP][RAMP][nsmax][nhmax][BMEtype]
%
% Digit 1 (obsType): 0=none, 1=hard only, 2=hard+soft obs
% Digit 2 (CTMtype): 0=none, 1=single CTM, 3=multi-CTM
% Digits 3-5 (RAMP): Correction parameters (0=none, 01=MERRA2GMI, 02=M3fusion, etc.)
% Digit 6 (nsmax): 0=0, 1=3, 2=4, 3=10, 4=50, 5=100, 6=200 soft data neighbors
% Digit 7 (nhmax): 1=50, 2=100, 3=200 hard data neighbors
% Digit 8 (BMEtype): 2=krigingME, 3=krigingME with multi-soft support
%
% Common configurations:
%   '10000133' = Hard data only, nhmax=200, nsmax=5, krigingME multi-soft format (DEFAULT)
%   '13000133-01' = Hard + MERRA2GMI, nhmax=50, nsmax=0, krigingME
%   '13000133-02' = Hard + M3fusion, nhmax=50, nsmax=0, krigingME
%   '13000133-xx' = Hard + multi-CTM, nhmax=200, nsmax=5, krigingME multi-soft format
%
%   01:MERRA2-GMI; 02:M3fusion; 04:OMI-MLS; 08:IASI-GOME2; 10:UKML;
%   20:NJML; 06:M3fusion+OMI-MLS; 0A:M3fusion+IASI-GOME2; 12:M3fusion+UKML;
%
% MULTIPLE METHODS: Use cell array to run multiple configurations at once
% valParam.BMEmethod = {'10000133', '13000313-02', '13000313-12'};

% SINGLE METHOD: Use string for one configuration
valParam.BMEmethod = {'10000133', '13000313-01', '13000313-04'};

%% ====================================================================
%                    SOFT DATA CONFIGURATION (if using CTM)
% ====================================================================

% Only needed if BMEmethod digit 2 >= 1 (CTM data required)
% Leave empty or comment out if not using soft data

% Example: Single CTM model
% valParam.softData.modelName = 'MERRA2GMI';

% Example: Multiple CTM models (for BMEmethod with digit 2 = 3)
% valParam.softData.modelName = {'MERRA2GMI', 'M3fusion'};

% Soft data configuration (optional, auto-detected if not specified)
% valParam.softData.years = [];  % Auto: ±1 year of each validation year
% valParam.softData.dataDir = fullfile('1data', 'CTM', 'ramp_data');
% valParam.softData.forceReload = 0;

%% ====================================================================
%                    EXECUTION CONTROL
% ====================================================================

% Force re-estimation of monthly results (ignore cache)
valParam.forceEstimation = 0;  % 0=use cached monthly results, 1=recompute

% Create plots after validation
valParam.plotResults = 1;  % 0=no plots, 1=create plots

% Run methods in parallel (requires Parallel Computing Toolbox)
% Only used if BMEmethod is a cell array with multiple methods
valParam.runParallel = false;  % true=parallel, false=sequential

%% ====================================================================
%                    RUN VALIDATION
% ====================================================================

% Convert single method to cell array for uniform processing
if ischar(valParam.BMEmethod)
    bmeMethods = {valParam.BMEmethod};
    multipleMethodsMode = false;
elseif iscell(valParam.BMEmethod)
    bmeMethods = valParam.BMEmethod;
    multipleMethodsMode = true;
else
    error('valParam.BMEmethod must be a string or cell array of strings');
end

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         CONFIGURATION SUMMARY\n');
fprintf('========================================================================\n');
fprintf('Validation years: %s\n', mat2str(valParam.valYears));
fprintf('Validation months: %s\n', mat2str(valParam.valMonths));
fprintf('Box sizes: %s degrees\n', mat2str(valParam.boxSizes));
if multipleMethodsMode
    fprintf('BME methods: %d configurations\n', length(bmeMethods));
    for i = 1:length(bmeMethods)
        fprintf('  [%d] %s\n', i, bmeMethods{i});
    end
else
    fprintf('BME method: %s\n', bmeMethods{1});
end
fprintf('GO scenario: %d\n', valParam.goScenario);
fprintf('Temporal model: %s\n', valParam.temporalModel);
fprintf('Station types: %s\n', valParam.stationTypes);
fprintf('Data time range: [%d, %d]\n', valParam.timeRange(1), valParam.timeRange(2));
if multipleMethodsMode && valParam.runParallel
    fprintf('Execution mode: PARALLEL\n');
else
    fprintf('Execution mode: SEQUENTIAL\n');
end
fprintf('\n');

% Confirm before running (comment out to skip)
% response = input('Proceed with validation? (y/n): ', 's');
% if ~strcmpi(response, 'y')
%     fprintf('Validation cancelled.\n');
%     return;
% end

%% Run CBV for each method
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                      STARTING VALIDATION\n');
fprintf('========================================================================\n');
fprintf('\n');

% Initialize storage for all methods
allCbvResults = cell(length(bmeMethods), 1);
allCbvStats = cell(length(bmeMethods), 1);
methodTimes = zeros(length(bmeMethods), 1);

totalTic = tic;

if multipleMethodsMode && valParam.runParallel
    % PARALLEL EXECUTION
    fprintf('Running %d methods in PARALLEL...\n\n', length(bmeMethods));

    parfor iMethod = 1:length(bmeMethods)
        methodTic = tic;

        % Create method-specific parameter structure
        valParamMethod = valParam;
        valParamMethod.BMEmethod = bmeMethods{iMethod};

        fprintf('[Method %d/%d] Starting: %s\n', iMethod, length(bmeMethods), bmeMethods{iMethod});

        try
            [allCbvResults{iMethod}, allCbvStats{iMethod}] = runCBV_toar(valParamMethod);
            methodTimes(iMethod) = toc(methodTic);
            fprintf('[Method %d/%d] Completed in %.1f minutes: %s\n', ...
                iMethod, length(bmeMethods), methodTimes(iMethod)/60, bmeMethods{iMethod});
        catch ME
            fprintf('[Method %d/%d] FAILED: %s\n', iMethod, length(bmeMethods), bmeMethods{iMethod});
            fprintf('  Error: %s\n', ME.message);
            allCbvResults{iMethod} = [];
            allCbvStats{iMethod} = [];
            methodTimes(iMethod) = toc(methodTic);
        end
    end

else
    % SEQUENTIAL EXECUTION
    if multipleMethodsMode
        fprintf('Running %d methods SEQUENTIALLY...\n\n', length(bmeMethods));
    end

    for iMethod = 1:length(bmeMethods)
        methodTic = tic;

        % Create method-specific parameter structure
        valParamMethod = valParam;
        valParamMethod.BMEmethod = bmeMethods{iMethod};

        fprintf('========================================================================\n');
        fprintf('Method %d/%d: %s\n', iMethod, length(bmeMethods), bmeMethods{iMethod});
        fprintf('========================================================================\n\n');

        try
            [allCbvResults{iMethod}, allCbvStats{iMethod}] = runCBV_toar(valParamMethod);
            methodTimes(iMethod) = toc(methodTic);
            fprintf('\n[Method %d/%d] Completed in %.1f minutes\n\n', ...
                iMethod, length(bmeMethods), methodTimes(iMethod)/60);
        catch ME
            fprintf('\n[Method %d/%d] FAILED: %s\n', iMethod, length(bmeMethods), ME.message);
            fprintf('  Stack: %s\n', ME.stack(1).name);
            allCbvResults{iMethod} = [];
            allCbvStats{iMethod} = [];
            methodTimes(iMethod) = toc(methodTic);
        end
    end
end

totalTime = toc(totalTic);

% Consolidate results if running single method
if ~multipleMethodsMode
    cbvResults = allCbvResults{1};
    cbvStats = allCbvStats{1};
end

%% Display Results
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                      VALIDATION COMPLETE\n');
fprintf('========================================================================\n');
fprintf('Total execution time: %.1f minutes\n', totalTime/60);
fprintf('\n');

if multipleMethodsMode
    % DISPLAY RESULTS FOR MULTIPLE METHODS
    fprintf('Method execution times:\n');
    fprintf('------------------------------\n');
    for iMethod = 1:length(bmeMethods)
        if ~isempty(allCbvStats{iMethod})
            fprintf('  [%d] %s: %.1f minutes ✓\n', iMethod, bmeMethods{iMethod}, methodTimes(iMethod)/60);
        else
            fprintf('  [%d] %s: %.1f minutes ✗ FAILED\n', iMethod, bmeMethods{iMethod}, methodTimes(iMethod)/60);
        end
    end
    fprintf('\n');

    % Display summary statistics for each method
    fprintf('Method comparison summary:\n');
    fprintf('========================================================================\n');
    for iMethod = 1:length(bmeMethods)
        if ~isempty(allCbvStats{iMethod})
            fprintf('\nMethod %d: %s\n', iMethod, bmeMethods{iMethod});
            fprintf('------------------------------\n');

            cbvStats = allCbvStats{iMethod};
            uniqueYears = unique(cbvStats.Year);
            for iYear = 1:length(uniqueYears)
                year = uniqueYears(iYear);
                yearStats = cbvStats(cbvStats.Year == year, :);

                fprintf('  Year %d:\n', year);
                fprintf('    R²:   %.3f ± %.3f\n', mean(yearStats.R2), std(yearStats.R2));
                fprintf('    RMSE: %.2f ± %.2f ppbv\n', mean(yearStats.RMSE), std(yearStats.RMSE));
                fprintf('    MAE:  %.2f ± %.2f ppbv\n', mean(yearStats.MAE), std(yearStats.MAE));
                fprintf('    NMB:  %.1f ± %.1f %%\n', mean(yearStats.NMB), std(yearStats.NMB));
                fprintf('    N:    %d validation points\n', mean(yearStats.N));
            end
        else
            fprintf('\nMethod %d: %s - FAILED\n', iMethod, bmeMethods{iMethod});
        end
    end

    fprintf('\n========================================================================\n');
    fprintf('Results saved to: ./7validation/CBV/\n');
    fprintf('  - Annual results: CBV_BME{method}_go{scen}_box{size}_fold{fold}_{year}.mat\n');
    fprintf('  - Monthly results: ./monthly/CBV_BME{method}_go{scen}_box{size}_fold{fold}_{year}_{month}.mat\n');
    fprintf('  - Summary tables: CBV_summary_BME{method}_go{scen}.csv (one per method)\n');

    if valParam.plotResults
        fprintf('  - Figures: ./figures/ (organized by method)\n');
    end

else
    % DISPLAY RESULTS FOR SINGLE METHOD
    if ~isempty(cbvStats)
        fprintf('Validation statistics summary:\n');
        fprintf('------------------------------\n');

        % Group by year if multiple years
        uniqueYears = unique(cbvStats.Year);
        for iYear = 1:length(uniqueYears)
            year = uniqueYears(iYear);
            yearStats = cbvStats(cbvStats.Year == year, :);

            fprintf('\nYear %d:\n', year);
            fprintf('  Box sizes tested: %s\n', mat2str(unique(yearStats.BoxSize)));
            fprintf('  Average R²:   %.3f ± %.3f\n', mean(yearStats.R2), std(yearStats.R2));
            fprintf('  Average RMSE: %.2f ± %.2f ppbv\n', mean(yearStats.RMSE), std(yearStats.RMSE));
            fprintf('  Average MAE:  %.2f ± %.2f ppbv\n', mean(yearStats.MAE), std(yearStats.MAE));
            fprintf('  Average NMB:  %.1f ± %.1f %%\n', mean(yearStats.NMB), std(yearStats.NMB));
            fprintf('  Sample size:  %d validation points\n', mean(yearStats.N));
        end

        fprintf('\nResults saved to: ./7validation/CBV/\n');
        fprintf('  - Annual results: CBV_BME{method}_go{scen}_box{size}_fold{fold}_{year}.mat\n');
        fprintf('  - Monthly results: ./monthly/CBV_BME{method}_go{scen}_box{size}_fold{fold}_{year}_{month}.mat\n');
        fprintf('  - Summary table: CBV_summary_BME{method}_go{scen}.csv\n');

        if valParam.plotResults
            fprintf('  - Figures: ./figures/\n');
        end
    else
        warning('No validation statistics generated. Check for errors above.');
    end
end

fprintf('\n');
fprintf('========================================================================\n');
fprintf('\n');
