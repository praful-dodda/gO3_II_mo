function [cbvResults, cbvStats] = runCBV_toar(valParam)
% runCBV_toar - Run Checker-Board Validation for TOAR BME analysis
%
% Performs checker-board validation (CBV) by dividing the spatial
% domain into a checkerboard pattern, training on one set of squares, and
% validating on the complementary set. Tests multiple box sizes and both
% fold orientations.
%
% SYNTAX:
%   [cbvResults, cbvStats] = runCBV_toar(valParam)
%
% INPUTS:
%   valParam - Structure with fields:
%              .stationTypes    - Station types to include (default: 'all')
%              .timeRange       - [startYear endYear] (default: [2015 2020])
%              .logTransf       - Log transform (0/1, default: 0)
%              .goScenario      - Global offset scenario (default: 3)
%              .temporalModel   - Temporal covariance model (default: 'exponentialC')
%              .BMEmethod       - BME method code (default: '10000132')
%              .valYears        - Years to validate (default: [2016])
%              .valMonths       - Months to validate (default: 1:12)
%              .boxSizes        - Array of box sizes in degrees (default: [5, 10, 15])
%              .forceEstimation - Force re-calculation (default: 1)
%              .plotResults     - Create plots (default: 1)
%
% OUTPUTS:
%   cbvResults - Cell array {nBoxSizes × nFolds} of result structures
%   cbvStats   - Table with statistics for each box size and fold
%
% DESCRIPTION:
%   For each box size:
%     For each fold (forward and reverse):
%       1. Generate checkerboard spatial pattern
%       2. Train BME model on training squares
%       3. Validate on validation squares
%       4. Compute validation metrics
%       5. Save results
%
%   The checkerboard pattern ensures spatial independence between training
%   and validation sets, unlike LOOCV which has spatial correlation.
%
% EXAMPLES:
%   % Basic usage with defaults
%   valParam.valYears = 2016;
%   valParam.boxSizes = [5, 10];
%   [results, stats] = runCBV_toar(valParam);
%
%   % Multiple years and box sizes
%   valParam.valYears = [2016 2017];
%   valParam.valMonths = [6 7 8];  % Summer only
%   valParam.boxSizes = [5, 10, 15, 20];
%   valParam.BMEmethod = '11000142-01';  % With soft data
%   [results, stats] = runCBV_toar(valParam);
%
% SEE ALSO:
%   evaluateFold_CBV, getCheckerBoard, calculateValidationStats, run_TOARvalidation

%% Set Defaults
if nargin < 1
    valParam = struct();
end

if ~isfield(valParam, 'stationTypes'), valParam.stationTypes = 'all'; end
if ~isfield(valParam, 'timeRange'), valParam.timeRange = [2015 2020]; end
if ~isfield(valParam, 'logTransf'), valParam.logTransf = 0; end
if ~isfield(valParam, 'goScenario'), valParam.goScenario = 3; end
if ~isfield(valParam, 'temporalModel'), valParam.temporalModel = 'exponentialC'; end
if ~isfield(valParam, 'BMEmethod'), valParam.BMEmethod = '10000132'; end
if ~isfield(valParam, 'valYears'), valParam.valYears = 2016; end
if ~isfield(valParam, 'valMonths'), valParam.valMonths = 1:12; end
if ~isfield(valParam, 'boxSizes'), valParam.boxSizes = [5, 10, 15]; end
if ~isfield(valParam, 'forceEstimation'), valParam.forceEstimation = 1; end
if ~isfield(valParam, 'plotResults'), valParam.plotResults = 1; end
if ~isfield(valParam, 'goPlot'), valParam.goPlot = 0; end
if ~isfield(valParam, 'forceGO'), valParam.forceGO = 0; end
if ~isfield(valParam, 'forceCov'), valParam.forceCov = 0; end
if ~isfield(valParam, 'softData'), valParam.softData = []; end

%% Print Configuration
fprintf('\n========================================\n');
fprintf('  CHECKER-BOARD VALIDATION (CBV)\n');
fprintf('========================================\n');
fprintf('Configuration:\n');
fprintf('  BME method: %s\n', valParam.BMEmethod);
fprintf('  GO scenario: %d\n', valParam.goScenario);
fprintf('  Years: %s\n', mat2str(valParam.valYears));
fprintf('  Months: %s\n', mat2str(valParam.valMonths));
fprintf('  Box sizes: %s degrees\n', mat2str(valParam.boxSizes));
fprintf('  Station types: %s\n', valParam.stationTypes);

%% Load Data
fprintf('\nLoading observational data...\n');
obs = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);

fprintf('  Loaded %d stations, %d time periods\n', size(obs.Z, 1), size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

% Note: Soft data (CTM models) loaded inside evaluateFold_CBV if needed
% via getTOARknowledgeBase

%% Load Global Offset and Covariance Models
fprintf('\nLoading global offset and covariance models...\n');
go = getTOARglobalOffset(obs, valParam.goScenario, ...
    valParam.goPlot, valParam.forceGO, 0);

cov = getTOARautoCov(obs, go, valParam.temporalModel, valParam.forceCov);

fprintf('  Global offset scenario: %d\n', go.scenario);
fprintf('  Covariance models: %s\n', strjoin(cov.covmodel, ', '));

%% Get BME Parameters
BMEparam = getBMEparam(valParam.BMEmethod);

fprintf('  BME parameters:\n');
fprintf('    nhmax: %d\n', BMEparam.nhmax);
fprintf('    nsmax: %d\n', BMEparam.nsmax);
fprintf('    dmax: [%.1f, %.1f, %.1f]\n', BMEparam.dmax);

%% Setup Output Directory
cbvDir = fullfile('7validation', 'CBV');
if ~exist(cbvDir, 'dir')
    mkdir(cbvDir);
end

%% Initialize Results Storage
nBoxSizes = length(valParam.boxSizes);
nFolds = 2;  % Always 2 folds (forward and reverse)
cbvResults = cell(nBoxSizes, nFolds);
statsData = [];

%% Main CBV Loop
fprintf('\n========================================\n');
fprintf('  RUNNING CBV\n');
fprintf('========================================\n');

totalRuns = nBoxSizes * nFolds;
currentRun = 0;

for iBox = 1:nBoxSizes
    boxSize = valParam.boxSizes(iBox);

    fprintf('\n--- Box Size: %.1f degrees ---\n', boxSize);

    for iFold = 1:nFolds
        currentRun = currentRun + 1;

        fprintf('\n>>> Run %d/%d: Box=%.1f°, Fold=%d <<<\n', ...
            currentRun, totalRuns, boxSize, iFold);

        %% Check for Cached Results
        resultFilename = sprintf('CBV_BME%s_go%d_box%.0f_fold%d_y%s.mat', ...
            valParam.BMEmethod, valParam.goScenario, boxSize, iFold, ...
            strjoin(arrayfun(@num2str, valParam.valYears, 'UniformOutput', false), '-'));
        resultPath = fullfile(cbvDir, resultFilename);

        if exist(resultPath, 'file') && ~valParam.forceEstimation
            fprintf('  Loading cached results...\n');
            load(resultPath, 'foldResults', 'foldStats');
        else
            %% Generate Checkerboard Pattern
            fprintf('  Generating checkerboard pattern (box=%.1f°, fold=%d)...\n', ...
                boxSize, iFold);
            [trainMask, valMask] = getCheckerBoard(obs.sMS, boxSize, iFold);

            %% Evaluate This Fold
            fprintf('  Evaluating fold...\n');
            tic;
            foldResults = evaluateFold_CBV(obs, go, cov, BMEparam, ...
                trainMask, valMask, valParam);
            evalTime = toc;

            fprintf('  Fold evaluation completed in %.1f seconds\n', evalTime);

            %% Compute Metrics
            if foldResults.nVal > 0
                fprintf('  Computing validation metrics...\n');
                foldStats = calculateValidationStats(foldResults.Y_obs, foldResults.Y_est);
                foldStats.BoxSize = boxSize;
                foldStats.Fold = iFold;
                foldStats.nTrain = foldResults.nTrain;
                foldStats.nVal = foldResults.nVal;
                foldStats.EvalTime = evalTime;

                % Display key metrics
                fprintf('  Validation metrics:\n');
                fprintf('    N = %d\n', foldStats.N);
                fprintf('    R² = %.3f\n', foldStats.R2);
                fprintf('    RMSE = %.2f %s\n', foldStats.RMSE, obs.Zunit);
                fprintf('    MAE = %.2f %s\n', foldStats.MAE, obs.Zunit);
                fprintf('    NMB = %.1f%%\n', foldStats.NMB);
            else
                warning('No valid validation pairs for box=%.1f, fold=%d', boxSize, iFold);
                foldStats = struct();
                foldStats.BoxSize = boxSize;
                foldStats.Fold = iFold;
                foldStats.N = 0;
            end

            %% Save Results
            save(resultPath, 'foldResults', 'foldStats', 'valParam', '-v7.3');
            fprintf('  Results saved: %s\n', resultFilename);
        end

        %% Store Results
        cbvResults{iBox, iFold} = foldResults;

        % Accumulate statistics
        if ~isempty(foldStats) && foldStats.N > 0
            if isempty(statsData)
                statsData = foldStats;
            else
                statsData(end+1) = foldStats;
            end
        end
    end
end

%% Create Statistics Table
fprintf('\n========================================\n');
fprintf('  CBV SUMMARY\n');
fprintf('========================================\n');

if ~isempty(statsData)
    cbvStats = struct2table(statsData);

    % Display summary
    disp(cbvStats(:, {'BoxSize', 'Fold', 'N', 'R2', 'RMSE', 'MAE', 'NMB', 'nTrain', 'nVal'}));

    % Save summary table
    summaryFilename = sprintf('CBV_summary_BME%s_go%d.csv', ...
        valParam.BMEmethod, valParam.goScenario);
    summaryPath = fullfile(cbvDir, summaryFilename);
    writetable(cbvStats, summaryPath);
    fprintf('\nSummary table saved: %s\n', summaryFilename);
else
    cbvStats = table();
    warning('No valid statistics to summarize');
end

%% Create Plots (Optional)
if valParam.plotResults && ~isempty(cbvStats)
    fprintf('\nCreating CBV plots...\n');
    plotCBVresults(cbvResults, cbvStats, valParam);
end

fprintf('\n========================================\n');
fprintf('  CBV COMPLETED\n');
fprintf('========================================\n\n');

end
