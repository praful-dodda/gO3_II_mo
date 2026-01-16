%% Example: Checker-Board Validation for TOAR BME
%
% This script demonstrates how to run checker-board validation (CBV)
% for TOAR ozone data using the BME framework.
%
% CBV provides spatial independence between training and validation sets,
% unlike LOOCV which has spatial correlation issues.
%
% Author: Based on TOAR-II BME framework
% Date: January 2025

clear; clc;

fprintf('\n========================================\n');
fprintf('  EXAMPLE: CHECKER-BOARD VALIDATION\n');
fprintf('========================================\n');

%% Configuration

% Validation parameters
valParam = struct();

% Data parameters
valParam.stationTypes = 'all';        % Station types to include
valParam.timeRange = [2015 2020];     % Full data range
valParam.logTransf = 0;               % No log transform

% Model parameters
valParam.goScenario = 3;              % Global offset scenario (90° spatial, 20 years temporal)
valParam.temporalModel = 'exponentialC';  % Temporal covariance model
valParam.BMEmethod = '10000132';      % Hard data only, nhmax=100, krigingME

% Validation configuration
valParam.method = 'cbv';             % Checker-board validation
valParam.valYears = 2016;             % Year(s) to validate
valParam.valMonths = 1:12;            % All months
valParam.boxSizes = [5, 10, 15];      % Test multiple box sizes (degrees)

% Execution options
valParam.forceEstimation = 0;         % Use cached results if available
valParam.plotResults = 1;             % Create validation plots

%% Display Configuration
fprintf('\nValidation Configuration:\n');
fprintf('  Method: %s\n', valParam.method);
fprintf('  BME method: %s\n', valParam.BMEmethod);
fprintf('  GO scenario: %d\n', valParam.goScenario);
fprintf('  Years: %s\n', mat2str(valParam.valYears));
fprintf('  Months: %s\n', mat2str(valParam.valMonths));
fprintf('  Box sizes: %s degrees\n', mat2str(valParam.boxSizes));

%% Run CBV

fprintf('\nRunning CBV...\n');
tic;

[cbvResults, cbvStats] = run_TOARvalidation(valParam);

elapsedTime = toc;
fprintf('\nTotal time: %.1f seconds (%.1f minutes)\n', elapsedTime, elapsedTime/60);

%% Display Results

fprintf('\n========================================\n');
fprintf('  CBV RESULTS SUMMARY\n');
fprintf('========================================\n');

if ~isempty(cbvStats)
    % Display statistics table
    disp(cbvStats);

    % Summary statistics across all runs
    fprintf('\nSummary across all box sizes and folds:\n');
    fprintf('  Mean R²: %.3f ± %.3f\n', mean(cbvStats.R2), std(cbvStats.R2));
    fprintf('  Mean RMSE: %.2f ± %.2f ppbv\n', mean(cbvStats.RMSE), std(cbvStats.RMSE));
    fprintf('  Mean MAE: %.2f ± %.2f ppbv\n', mean(cbvStats.MAE), std(cbvStats.MAE));
    fprintf('  Mean NMB: %.1f ± %.1f%%\n', mean(cbvStats.NMB), std(cbvStats.NMB));

    % Compare across box sizes
    fprintf('\nPerformance by box size:\n');
    for boxSize = unique(cbvStats.BoxSize)'
        idx = cbvStats.BoxSize == boxSize;
        fprintf('  %.0f degrees: R²=%.3f, RMSE=%.2f ppbv (n=%d folds)\n', ...
            boxSize, mean(cbvStats.R2(idx)), mean(cbvStats.RMSE(idx)), sum(idx));
    end
else
    warning('No statistics available');
end

%% Compare with Different BME Methods (Optional)

% Uncomment to test with soft data
% fprintf('\n========================================\n');
% fprintf('  COMPARING WITH SOFT DATA\n');
% fprintf('========================================\n');
%
% valParam2 = valParam;
% valParam2.BMEmethod = '11000142-01';  % Hard + MERRA2-GMI soft data
% [cbvResults2, cbvStats2] = run_TOARvalidation(valParam2);
%
% fprintf('\nComparison:\n');
% fprintf('  Hard only:     R²=%.3f, RMSE=%.2f\n', mean(cbvStats.R2), mean(cbvStats.RMSE));
% fprintf('  Hard + Soft:   R²=%.3f, RMSE=%.2f\n', mean(cbvStats2.R2), mean(cbvStats2.RMSE));

fprintf('\n========================================\n');
fprintf('  EXAMPLE COMPLETED\n');
fprintf('========================================\n\n');

%% Notes
%
% Output files are saved in: 7validation/CBV/
%
% File naming convention:
%   CBV_BME[method]_go[scenario]_box[size]_fold[1or2]_y[years].mat
%
% Each file contains:
%   - foldResults: Detailed prediction results
%   - foldStats: Validation statistics
%   - valParam: Configuration used
%
% Summary table:
%   CBV_summary_BME[method]_go[scenario].csv
%
