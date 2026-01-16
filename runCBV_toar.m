function [cbvResults, cbvStats] = runCBV_toar(valParam)
% runCBV_toar - Run Checker-Board Validation for TOAR BME analysis
%
% Performs checker-board validation (CBV) with monthly processing,
% dividing spatial domain into checkerboard pattern for spatial independence.
%
% SYNTAX:
%   [cbvResults, cbvStats] = runCBV_toar(valParam)
%
% INPUTS:
%   valParam - Structure with fields:
%              .stationTypes    - Station types (default: 'all')
%              .timeRange       - [startYear endYear] (default: [2015 2020])
%              .logTransf       - Log transform (0/1, default: 0)
%              .goScenario      - Global offset scenario (default: 3)
%              .temporalModel   - Temporal covariance model (default: 'exponentialC')
%              .BMEmethod       - BME method code (default: '10000132')
%              .valYears        - Years to validate (default: [2016])
%              .valMonths       - Months to validate (default: 1:12)
%              .boxSizes        - Box sizes in degrees (default: [5, 10, 15])
%              .forceEstimation - Force re-calculation (default: 0)
%              .plotResults     - Create plots (default: 1)
%              .plotCheckerboard - Plot checkerboard pattern (default: 0)
%
% OUTPUTS:
%   cbvResults - Cell array of monthly results
%   cbvStats   - Table with aggregated statistics
%
% SEE ALSO:
%   evaluateFold_CBV_monthly, getCheckerBoard, computeMetrics

%% Set Defaults
if nargin < 1, valParam = struct(); end

if ~isfield(valParam, 'stationTypes'), valParam.stationTypes = 'all'; end
if ~isfield(valParam, 'timeRange'), valParam.timeRange = [2015 2020]; end
if ~isfield(valParam, 'logTransf'), valParam.logTransf = 0; end
if ~isfield(valParam, 'goScenario'), valParam.goScenario = 3; end
if ~isfield(valParam, 'temporalModel'), valParam.temporalModel = 'exponentialC'; end
if ~isfield(valParam, 'BMEmethod'), valParam.BMEmethod = '10000132'; end
if ~isfield(valParam, 'valYears'), valParam.valYears = 2016; end
if ~isfield(valParam, 'valMonths'), valParam.valMonths = 1:12; end
if ~isfield(valParam, 'boxSizes'), valParam.boxSizes = [5, 10, 15]; end
if ~isfield(valParam, 'forceEstimation'), valParam.forceEstimation = 0; end
if ~isfield(valParam, 'plotResults'), valParam.plotResults = 1; end
if ~isfield(valParam, 'plotCheckerboard'), valParam.plotCheckerboard = 0; end
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

%% Load Data
fprintf('\nLoading observational data...\n');
obs = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);

fprintf('  Loaded %d stations, %d time periods\n', size(obs.Z, 1), size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

%% Load Global Offset and Covariance
fprintf('\nLoading global offset and covariance...\n');
go = getTOARglobalOffset(obs, valParam.goScenario, valParam.goPlot, valParam.forceGO, 0);
cov = getTOARautoCov(obs, go, valParam.temporalModel, valParam.forceCov);

%% Get BME Parameters
BMEparam = getBMEparam(valParam.BMEmethod);
BMEparam.dataFormat = 'stug';  % Force STUG format for CBV

% Prepare knowledge base from full data (for soft data if needed)
fprintf('\nPreparing knowledge base...\n');
[KG, KS, ~] = getTOARknowledgeBase(obs, go, cov, valParam.softData, ...
    valParam.BMEmethod, BMEparam.dataFormat);

fprintf('  nhmax: %d, nsmax: %d\n', BMEparam.nhmax, BMEparam.nsmax);

%% Setup Output Directory
cbvDir = fullfile('7validation', 'CBV');
if ~exist(cbvDir, 'dir'), mkdir(cbvDir); end

%% Initialize Results Storage
nBoxSizes = length(valParam.boxSizes);
nFolds = 2;
nYears = length(valParam.valYears);
nMonths = length(valParam.valMonths);

cbvResults = cell(nBoxSizes, nFolds, nYears, nMonths);
statsArray = [];

%% Main CBV Loop
fprintf('\n========================================\n');
fprintf('  RUNNING CBV\n');
fprintf('========================================\n');

totalRuns = nBoxSizes * nFolds * nYears * nMonths;
currentRun = 0;

for iBox = 1:nBoxSizes
    boxSize = valParam.boxSizes(iBox);

    % Generate checkerboard pattern (same for all times)
    fprintf('\n--- Box Size: %.1f degrees ---\n', boxSize);
    [trainMask_fold1, valMask_fold1] = getCheckerBoard(obs.sMS, boxSize, 1, ...
        valParam.plotCheckerboard && iBox == 1);  % Plot only once
    [trainMask_fold2, valMask_fold2] = getCheckerBoard(obs.sMS, boxSize, 2, 0);

    for iFold = 1:nFolds
        % Select masks for this fold
        if iFold == 1
            trainMask = trainMask_fold1;
            valMask = valMask_fold1;
        else
            trainMask = trainMask_fold2;
            valMask = valMask_fold2;
        end

        fprintf('\n>>> Fold %d <<<\n', iFold);

        for iYear = 1:nYears
            valYear = valParam.valYears(iYear);

            for iMonth = 1:length(valParam.valMonths)
                valMonth = valParam.valMonths(iMonth);
                currentRun = currentRun + 1;

                fprintf('\n[%d/%d] Box=%.1f°, Fold=%d, Year=%d, Month=%d\n', ...
                    currentRun, totalRuns, boxSize, iFold, valYear, valMonth);

                %% Check for Cached Results
                resultFilename = sprintf('CBV_BME%s_go%d_box%.0f_fold%d_y%d_m%02d.mat', ...
                    valParam.BMEmethod, valParam.goScenario, boxSize, iFold, valYear, valMonth);
                resultPath = fullfile(cbvDir, resultFilename);

                if exist(resultPath, 'file') && ~valParam.forceEstimation
                    fprintf('  Loading cached results...\n');
                    load(resultPath, 'monthResults');
                else
                    %% Evaluate This Month
                    monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, BMEparam, ...
                        trainMask, valMask, valYear, valMonth);

                    if ~isempty(monthResults)
                        % Save monthly results
                        save(resultPath, 'monthResults', 'valParam', '-v7.3');
                        fprintf('  Saved: %s\n', resultFilename);
                    end
                end

                %% Store Results
                cbvResults{iBox, iFold, iYear, iMonth} = monthResults;

                %% Accumulate for Annual Statistics
                if ~isempty(monthResults) && monthResults.nValid > 0
                    % Store monthly info for aggregation
                    if isempty(statsArray)
                        statsArray = struct('BoxSize', boxSize, 'Fold', iFold, ...
                            'Year', valYear, 'Month', valMonth, 'monthResults', monthResults);
                    else
                        statsArray(end+1) = struct('BoxSize', boxSize, 'Fold', iFold, ...
                            'Year', valYear, 'Month', valMonth, 'monthResults', monthResults);
                    end
                end
            end
        end
    end
end

%% Aggregate Annual Statistics
fprintf('\n========================================\n');
fprintf('  AGGREGATING STATISTICS\n');
fprintf('========================================\n');

cbvStats = table();

% Group by box size, fold, and year
for iBox = 1:nBoxSizes
    boxSize = valParam.boxSizes(iBox);

    for iFold = 1:nFolds
        for iYear = 1:nYears
            valYear = valParam.valYears(iYear);

            % Collect all months for this configuration
            idx = [statsArray.BoxSize] == boxSize & ...
                  [statsArray.Fold] == iFold & ...
                  [statsArray.Year] == valYear;

            if sum(idx) == 0, continue; end

            % Aggregate obs and est across all months
            Y_obs_all = [];
            Y_est_all = [];
            XkBMEv_all = [];

            for k = find(idx)
                Y_obs_all = [Y_obs_all; statsArray(k).monthResults.Y_obs];
                Y_est_all = [Y_est_all; statsArray(k).monthResults.Y_est];
                XkBMEv_all = [XkBMEv_all; statsArray(k).monthResults.XkBMEv];
            end

            % Compute annual statistics
            if ~isempty(Y_obs_all)
                stats = computeMetrics(Y_est_all, Y_obs_all, sqrt(XkBMEv_all));
                stats.BoxSize = boxSize;
                stats.Fold = iFold;
                stats.Year = valYear;
                stats.N = length(Y_obs_all);

                % Append to table
                if isempty(cbvStats)
                    cbvStats = struct2table(stats);
                else
                    cbvStats = [cbvStats; struct2table(stats)];
                end

                fprintf('Box=%.1f°, Fold=%d, Year=%d: N=%d, r²=%.3f, RMSE=%.2f\n', ...
                    boxSize, iFold, valYear, stats.N, stats.r2, stats.RMSE);
            end
        end
    end
end

%% Save Summary
if ~isempty(cbvStats)
    summaryFilename = sprintf('CBV_summary_BME%s_go%d.csv', ...
        valParam.BMEmethod, valParam.goScenario);
    summaryPath = fullfile(cbvDir, summaryFilename);
    writetable(cbvStats, summaryPath);
    fprintf('\nSummary saved: %s\n', summaryFilename);
end

%% Create Plots
if valParam.plotResults && ~isempty(cbvStats)
    fprintf('\nCreating CBV plots...\n');
    plotCBVresults(cbvResults, cbvStats, valParam);
end

fprintf('\n========================================\n');
fprintf('  CBV COMPLETED\n');
fprintf('========================================\n\n');

end
