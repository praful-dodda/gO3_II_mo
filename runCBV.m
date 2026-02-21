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
valParam.timeRange = [2000 2005];  % [startYear endYear]

% Log transformation
valParam.logTransf = 0;  % 0=no, 1=yes (use 0 for regular concentrations)

%% ====================================================================
%                    VALIDATION CONFIGURATION
% ====================================================================

% Years to validate
valParam.valYears = 1990:2000;  % e.g., 2017 or [2016 2017 2018]

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
valParam.goScenario = 0;

% Force re-estimation of GO (useful if parameters changed)
valParam.forceGO = 0;  % 0=use cached, 1=force new estimation

% Plotting level for global offset
valParam.goPlot = 0;  % 0=no plots, 1=basic (not recommended during CBV)

%% ====================================================================
%                    COVARIANCE CONFIGURATION
% ====================================================================

% Temporal covariance model
valParam.temporalModel = 'exponential';  % 'exponential' or 'holecos'

% Force re-estimation
valParam.forceCov = 0;  % 0=use cached, 1=force new estimation

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
% Can specify single method or cell array for multiple methods
valParam.BMEmethod = {'10000133','13000313-01', '13000313-10', '13000313-11'};  % or use cell array: {'10000133', '13000313-12'}
valParam.BMEmethod = {'10000133'};

%% ====================================================================
%                    SOFT DATA CONFIGURATION (if using CTM)
% ====================================================================

% Only needed if BMEmethod digit 2 >= 1 (CTM data required)
% Leave empty or comment out if not using soft data

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

%% ====================================================================
%                    RUN VALIDATION
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         CONFIGURATION SUMMARY\n');
fprintf('========================================================================\n');
fprintf('Validation years: %s\n', mat2str(valParam.valYears));
fprintf('Validation months: %s\n', mat2str(valParam.valMonths));
fprintf('Box sizes: %s degrees\n', mat2str(valParam.boxSizes));

% Display BME method(s)
if ischar(valParam.BMEmethod)
    fprintf('BME method: %s\n', valParam.BMEmethod);
elseif iscell(valParam.BMEmethod)
    fprintf('BME methods (%d): %s\n', length(valParam.BMEmethod), strjoin(valParam.BMEmethod, ', '));
end

fprintf('GO scenario: %d\n', valParam.goScenario);
fprintf('Temporal model: %s\n', valParam.temporalModel);
fprintf('Station types: %s\n', valParam.stationTypes);
fprintf('Data time range: [%d, %d]\n', valParam.timeRange(1), valParam.timeRange(2));
fprintf('\n');

%% ====================================================================
%                    VERIFY SOFT DATA FILES
% ====================================================================

% Convert to cell array for consistent processing
if ischar(valParam.BMEmethod)
    methodsToVerify = {valParam.BMEmethod};
else
    methodsToVerify = valParam.BMEmethod;
end

% Verify files for each BME method
allFilesPresent = true;
for iMethod = 1:length(methodsToVerify)
    currentMethod = methodsToVerify{iMethod};

    % Verify soft-data files exist for this method and year range
    [status, ~] = verifySoftDataFiles(currentMethod, valParam.valYears, ...
        'verbose', true, ...
        'throwError', false);  % Don't throw error, just report

    if ~status
        allFilesPresent = false;
    end
end

if ~allFilesPresent
    fprintf('\n');
    fprintf('========================================================================\n');
    fprintf('                     ⚠ WARNING: MISSING FILES\n');
    fprintf('========================================================================\n');
    fprintf('Some soft-data files are missing. You can:\n');
    fprintf('  1. Continue anyway (BME will use only available data)\n');
    fprintf('  2. Cancel and ensure all files are present\n');
    fprintf('  3. Remove methods with missing files from valParam.BMEmethod\n');
    fprintf('========================================================================\n');
    fprintf('\n');

    % Optional: uncomment to require user confirmation
    % response = input('Continue despite missing files? (y/n): ', 's');
    % if ~strcmpi(response, 'y')
    %     fprintf('Validation cancelled.\n');
    %     return;
    % end
end

% Confirm before running (comment out to skip)
% response = input('Proceed with validation? (y/n): ', 's');
% if ~strcmpi(response, 'y')
%     fprintf('Validation cancelled.\n');
%     return;
% end

%% Run CBV
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                      STARTING VALIDATION\n');
fprintf('========================================================================\n');
fprintf('\n');

% Convert single method to cell array for consistent looping
if ischar(valParam.BMEmethod)
    methodList = {valParam.BMEmethod};
else
    methodList = valParam.BMEmethod;
end

% Initialize result containers
allResults = cell(length(methodList), 1);
allStats = [];

tic;
for iMethod = 1:length(methodList)
    close all;
    currentMethod = methodList{iMethod};

    fprintf('\n');
    fprintf('--- Running method %d/%d: %s ---\n', iMethod, length(methodList), currentMethod);
    fprintf('\n');

    % Set current method
    valParam.BMEmethod = currentMethod;

    % Run validation
    [cbvResults, cbvStats] = runCBV_toar(valParam);

    % Store results
    allResults{iMethod} = cbvResults;
    if ~isempty(cbvStats)
        cbvStats.BMEmethod = repmat({currentMethod}, height(cbvStats), 1);
        allStats = [allStats; cbvStats];
    end
end
totalTime = toc;

% Consolidate results
cbvResults = allResults;
cbvStats = allStats;

%% Display Results
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                      VALIDATION COMPLETE\n');
fprintf('========================================================================\n');
fprintf('Total execution time: %.1f minutes\n', totalTime/60);
fprintf('\n');

if ~isempty(cbvStats)
    fprintf('Validation statistics summary:\n');
    fprintf('------------------------------\n');

    % Group by method and year
    if ismember('BMEmethod', cbvStats.Properties.VariableNames)
        uniqueMethods = unique(cbvStats.BMEmethod);
    else
        uniqueMethods = methodList;
    end

    uniqueYears = unique(cbvStats.Year);

    for iMethod = 1:length(uniqueMethods)
        method = uniqueMethods{iMethod};
        methodStats = cbvStats(strcmp(cbvStats.BMEmethod, method), :);

        fprintf('\n--- Method: %s ---\n', method);

        for iYear = 1:length(uniqueYears)
            year = uniqueYears(iYear);
            yearStats = methodStats(methodStats.Year == year, :);

            if ~isempty(yearStats)
                fprintf('\n  Year %d:\n', year);
                fprintf('    Box sizes tested: %s\n', mat2str(unique(yearStats.BoxSize)));
                fprintf('    Average R²:   %.3f ± %.3f\n', mean(yearStats.R2), std(yearStats.R2));
                fprintf('    Average RMSE: %.2f ± %.2f ppbv\n', mean(yearStats.RMSE), std(yearStats.RMSE));
                fprintf('    Average MAE:  %.2f ± %.2f ppbv\n', mean(yearStats.MAE), std(yearStats.MAE));
                fprintf('    Average NMB:  %.1f ± %.1f %%\n', mean(yearStats.NMB), std(yearStats.NMB));
                fprintf('    Sample size:  %d validation points\n', mean(yearStats.N));
            end
        end
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

fprintf('\n');
fprintf('========================================================================\n');
fprintf('\n');
