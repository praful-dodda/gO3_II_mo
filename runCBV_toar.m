function [cbvResults, cbvStats] = runCBV_toar(valParam)
% runCBV_toar - Run Checker-Board Validation for TOAR BME analysis
%
% Performs checker-board validation (CBV) by dividing the spatial
% domain into a checkerboard pattern, training on one set of squares, and
% validating on the complementary set. Processes monthly with ±1 year
% temporal windows and supports multi-soft datasets using STUG format.
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
%              .BMEmethod       - BME method code (default: '10000133' for multi-soft)
%              .valYears        - Years to validate (default: [2017])
%              .valMonths       - Months to validate (default: 1:12)
%              .boxSizes        - Array of box sizes in degrees (default: [2, 2.5, 3, 3.5, 4, 4.5, 5])
%              .forceEstimation - Force re-calculation (default: 1)
%              .plotResults     - Create plots (default: 1)
%
% OUTPUTS:
%   cbvResults - Cell array of monthly result structures
%   cbvStats   - Table with statistics for each box size/fold/year
%
% DESCRIPTION:
%   For each box size → fold → year → month:
%     1. Generate checkerboard spatial pattern
%     2. Train BME model on training squares (±1 year temporal window)
%     3. Validate on validation squares (target month only)
%     4. Filter to only s/t locations with observations
%     5. Save monthly results to disk
%   Then aggregate monthly results into annual statistics.
%
% EXAMPLES:
%   % Basic usage with multi-soft datasets
%   valParam.valYears = 2017;
%   valParam.valMonths = 1:12;
%   valParam.boxSizes = [2, 3, 4, 5];
%   valParam.BMEmethod = '10000133';  % Multi-soft STUG format
%   [results, stats] = runCBV_toar(valParam);
%
%   % Single month test
%   valParam.valYears = 2017;
%   valParam.valMonths = 6;  % June only
%   valParam.boxSizes = 3.0;
%   [results, stats] = runCBV_toar(valParam);
%
% SEE ALSO:
%   evaluateFold_CBV_monthly, getCheckerBoard, calculateValidationStats

%% Set Defaults
if nargin < 1
    valParam = struct();
end

if ~isfield(valParam, 'stationTypes'), valParam.stationTypes = 'all'; end
if ~isfield(valParam, 'timeRange'), valParam.timeRange = [2015 2020]; end
if ~isfield(valParam, 'logTransf'), valParam.logTransf = 0; end
if ~isfield(valParam, 'goScenario'), valParam.goScenario = 3; end
if ~isfield(valParam, 'temporalModel'), valParam.temporalModel = 'exponentialC'; end
if ~isfield(valParam, 'BMEmethod'), valParam.BMEmethod = '10000133'; end
if ~isfield(valParam, 'valYears'), valParam.valYears = 2017; end
if ~isfield(valParam, 'valMonths'), valParam.valMonths = 1:12; end
if ~isfield(valParam, 'boxSizes'), valParam.boxSizes = [2.0 2.5 3.0 3.5 4.0 4.5 5.0]; end
if ~isfield(valParam, 'forceEstimation'), valParam.forceEstimation = 1; end
if ~isfield(valParam, 'plotResults'), valParam.plotResults = 1; end
if ~isfield(valParam, 'goPlot'), valParam.goPlot = 0; end
if ~isfield(valParam, 'forceGO'), valParam.forceGO = 0; end
if ~isfield(valParam, 'forceCov'), valParam.forceCov = 0; end

%% Print Configuration
fprintf('\n========================================\n');
fprintf('  CHECKER-BOARD VALIDATION (CBV)\n');
fprintf('  Monthly Processing with ±1 Year Window\n');
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
fprintf('    Method: %s\n', BMEparam.BMEmethod8digits);
fprintf('    nhmax: %d\n', BMEparam.nhmax);
fprintf('    nsmax: %d\n', BMEparam.nsmax);
fprintf('    dmax: [%.1f, %.1f, %.1f]\n', BMEparam.dmax);
fprintf('    Data format: %s\n', BMEparam.dataFormat);

%% Setup Output Directory
cbvDir = fullfile('7validation', 'CBV');
monthlyDir = fullfile(cbvDir, 'monthly');
if ~exist(monthlyDir, 'dir')
    mkdir(monthlyDir);
end

%% Initialize Results Storage
nBoxSizes = length(valParam.boxSizes);
nFolds = 2;  % Always 2 folds (forward and reverse)
nYears = length(valParam.valYears);

cbvResults = cell(nBoxSizes, nFolds, nYears);
statsData = [];

%% Main CBV Loop
fprintf('\n========================================\n');
fprintf('  RUNNING CBV (MONTHLY PROCESSING)\n');
fprintf('========================================\n');

totalRuns = nBoxSizes * nFolds * nYears;
currentRun = 0;

for iBox = 1:nBoxSizes
    boxSize = valParam.boxSizes(iBox);

    fprintf('\n=== Box Size: %.1f degrees ===\n', boxSize);

    for iFold = 1:nFolds
        fprintf('\n--- Fold %d/%d ---\n', iFold, nFolds);

        % Generate Checkerboard Pattern
        fprintf('  Generating checkerboard pattern...\n');
        [trainMask, valMask] = getCheckerBoard(obs.sMS, boxSize, iFold, valParam.plotResults);

        for iYear = 1:nYears
            valYear = valParam.valYears(iYear);
            currentRun = currentRun + 1;

            fprintf('\n>>> Run %d/%d: Box=%.1f°, Fold=%d, Year=%d <<<\n', ...
                currentRun, totalRuns, boxSize, iFold, valYear);

            % Initialize annual accumulators
            Y_obs_all = [];
            Y_est_all = [];
            Y_estNoGo_all = [];
            sk_all = [];
            tk_all = [];
            XkBMEv_all = [];
            gok_all = [];

            %% Monthly Loop
            for iMonth = 1:length(valParam.valMonths)
                valMonth = valParam.valMonths(iMonth);

                fprintf('\n  [Month %d/%d] %d-%02d\n', iMonth, length(valParam.valMonths), ...
                    valYear, valMonth);

                % Check for cached monthly results
                monthFilename = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d_%02d.mat', ...
                    valParam.BMEmethod, valParam.goScenario, boxSize, iFold, ...
                    valYear, valMonth);
                monthPath = fullfile(monthlyDir, monthFilename);

                if exist(monthPath, 'file') && ~valParam.forceEstimation
                    fprintf('    Loading cached monthly results...\n');
                    load(monthPath, 'monthResults');
                else
                    % Evaluate this month
                    tic;
                    monthResults = evaluateFold_CBV_monthly(obs, go, cov, BMEparam, ...
                        trainMask, valMask, valYear, valMonth);
                    evalTime = toc;

                    fprintf('    Month evaluation completed in %.1f seconds\n', evalTime);

                    % Save monthly results
                    save(monthPath, 'monthResults', 'valParam', '-v7.3');
                    fprintf('    Saved: %s\n', monthFilename);
                end

                % Accumulate monthly results for annual statistics
                if monthResults.nValid > 0
                    Y_obs_all = [Y_obs_all; monthResults.Y_obs];
                    Y_est_all = [Y_est_all; monthResults.Y_est];
                    Y_estNoGo_all = [Y_estNoGo_all; monthResults.Y_estNoGo];
                    sk_all = [sk_all; monthResults.sk];
                    tk_all = [tk_all; monthResults.tk'];
                    XkBMEv_all = [XkBMEv_all; monthResults.XkBMEv];
                    gok_all = [gok_all; monthResults.gok];
                end
            end

            %% Compute Annual Statistics
            if ~isempty(Y_obs_all)
                fprintf('\n  Computing annual statistics for %d...\n', valYear);

                % Create annual results structure
                annualResults.Y_obs = Y_obs_all;
                annualResults.Y_est = Y_est_all;
                annualResults.Y_estNoGo = Y_estNoGo_all;
                annualResults.sk = sk_all;
                annualResults.tk = tk_all;
                annualResults.XkBMEv = XkBMEv_all;
                annualResults.gok = gok_all;
                annualResults.nTrain = sum(trainMask);
                annualResults.nVal = sum(valMask);

                % Compute validation metrics
                annualStats = calculateValidationStats(Y_obs_all, Y_est_all);
                annualStats.BoxSize = boxSize;
                annualStats.Fold = iFold;
                annualStats.Year = valYear;
                annualStats.nTrain = sum(trainMask);
                annualStats.nVal = sum(valMask);

                % Display key metrics
                fprintf('  Annual validation metrics for %d:\n', valYear);
                fprintf('    N = %d\n', annualStats.N);
                fprintf('    R² = %.3f\n', annualStats.R2);
                fprintf('    RMSE = %.2f %s\n', annualStats.RMSE, obs.Zunit);
                fprintf('    MAE = %.2f %s\n', annualStats.MAE, obs.Zunit);
                fprintf('    NMB = %.1f%%\n', annualStats.NMB);

                % Save annual results
                annualFilename = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                    valParam.BMEmethod, valParam.goScenario, boxSize, iFold, valYear);
                annualPath = fullfile(cbvDir, annualFilename);
                save(annualPath, 'annualResults', 'annualStats', 'valParam', '-v7.3');
                fprintf('  Saved annual: %s\n', annualFilename);

                % Store results
                cbvResults{iBox, iFold, iYear} = annualResults;

                % Accumulate statistics
                if isempty(statsData)
                    statsData = annualStats;
                else
                    statsData(end+1) = annualStats;
                end
            else
                warning('No valid validation pairs for box=%.1f, fold=%d, year=%d', ...
                    boxSize, iFold, valYear);
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
    fprintf('\nValidation Statistics by Box Size, Fold, and Year:\n');
    disp(cbvStats(:, {'BoxSize', 'Fold', 'Year', 'N', 'R2', 'RMSE', 'MAE', 'NMB'}));

    % Save summary table
    summaryFilename = sprintf('CBV_summary_BME%s_go%d.csv', ...
        valParam.BMEmethod, valParam.goScenario);
    summaryPath = fullfile(cbvDir, summaryFilename);
    writetable(cbvStats, summaryPath);
    fprintf('\nSummary table saved: %s\n', summaryFilename);

    % Also save as .mat
    summaryMatPath = fullfile(cbvDir, sprintf('CBV_summary_BME%s_go%d.mat', ...
        valParam.BMEmethod, valParam.goScenario));
    save(summaryMatPath, 'cbvStats', 'valParam', '-v7.3');
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
