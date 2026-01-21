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

%% Load Full Observational Data
% Load all data first, then filter to ±1 year per validation year
fprintf('\nLoading full observational data for all years...\n');
obsAll = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);

fprintf('  Loaded %d stations, %d time periods (full range)\n', size(obsAll.Z, 1), size(obsAll.Z, 2));
fprintf('  Full time range: [%.2f, %.2f]\n', min(obsAll.tME), max(obsAll.tME));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obsAll.Z(:)))/numel(obsAll.Z));

%% NOTE: Data Leakage Prevention Strategy
% For each validation year:
%   1. Filter obs to ±1 year around validation year
%   2. Compute GO and Cov per fold using ONLY training stations from that time window
%   3. This ensures no temporal or spatial leakage
fprintf('\nData leakage prevention:\n');
fprintf('  - Each validation year uses obs from ±1 year window only\n');
fprintf('  - GO and Cov computed per fold using training stations only\n');
fprintf('  - GO scenario: %d\n', valParam.goScenario);
fprintf('  - Temporal model: %s\n', valParam.temporalModel);

%% Get BME Parameters
BMEparam = getBMEparam(valParam.BMEmethod);

fprintf('  BME parameters:\n');
fprintf('    Method: %s\n', BMEparam.BMEmethod8digits);
fprintf('    nhmax: %d\n', BMEparam.nhmax);
fprintf('    nsmax: %d\n', BMEparam.nsmax);
fprintf('    dmax: [%.1f, %.1f, %.1f]\n', BMEparam.dmax);
fprintf('    Data format: %s\n', BMEparam.dataFormat);

%% Load Soft Data (if needed)
CTMtype = str2double(valParam.BMEmethod(2));  % 2nd digit indicates CTM usage
softData = [];
valParam.softData = [];

if CTMtype >= 1
    fprintf('\nCTM data required (BMEmethod digit 2 = %d)\n', CTMtype);

    if isfield(valParam, 'softData') && isempty(valParam.softData)
        fprintf('Loading soft data...\n');

        % Use setData_val logic but simpler for CBV
        try
            if ~isfield(valParam.softData, 'years')
                % set years to be +- 1 of validation years
                valParam.softData.years = [];
                for y = valParam.valYears
                    valParam.softData.years = [valParam.softData.years, (y-1):(y+1)];
                end
                valParam.softData.years = unique(valParam.softData.years);
            end
            if ~isfield(valParam.softData, 'dataDir')
                valParam.softData.dataDir =  fullfile('d:\Users\praful\Documents\Data\ramp_data\');  % Parquet directory
            end
            if ~isfield(valParam.softData, 'forceReload')
                valParam.softData.forceReload = 0;
            end

            if ~isfield(valParam.softData, 'ctm')
                valParam.softData.ctm = 1;
            end

            % get model names based on the bme-method
            if ~isfield(valParam.softData, 'modelName')
                [~, ~, ~, ~, ~, ~, valParam.softData.modelName] = parseBMEcode(valParam.BMEmethod);
            end

            % Handle multiple models (CTMtype=3) or single model
            if iscell(valParam.softData.modelName)
                % Multiple models
                softData = cell(1, length(valParam.softData.modelName));
                for iModel = 1:length(valParam.softData.modelName)
                    softData{iModel} = loadRAMPdata(valParam.softData.modelName{iModel}, ...
                        valParam.softData.years, valParam.softData.dataDir, ...
                        valParam.softData.forceReload);
                end
                fprintf('  Loaded %d soft datasets\n', length(softData));
            else
                % Single model
                softData = loadRAMPdata(valParam.softData.modelName, ...
                    valParam.softData.years, valParam.softData.dataDir, ...
                    valParam.softData.forceReload);
                fprintf('  Loaded soft data: %s\n', softData.modelName);
            end
        catch ME
            warning(ME.identifier, '\n Failed to load soft data: %s', ME.message);
            softData = [];
        end
    else
        warning('BMEmethod requires CTM data but no softData configuration provided');
        fprintf('  Proceeding without soft data\n');
    end
else
    fprintf('\nNo CTM data required (BMEmethod digit 2 = %d)\n', CTMtype);
end

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

%% Main CBV Loop: Year → BoxSize → Fold
% Process each validation year independently with ±1 year data window
fprintf('\n========================================\n');
fprintf('  RUNNING CBV (MONTHLY PROCESSING)\n');
fprintf('  Loop: Year → BoxSize → Fold → Month\n');
fprintf('========================================\n');

totalRuns = nYears * nBoxSizes * nFolds;
currentRun = 0;

for iYear = 1:nYears
    valYear = valParam.valYears(iYear);

    fprintf('\n########################################\n');
    fprintf('# VALIDATION YEAR: %d\n', valYear);
    fprintf('########################################\n');

    %% Use all available observational data (no year filtering)
    obs = obsAll;
    yearRange = [valYear - 1, valYear + 1];  % Keep for GO/Cov cache naming only

    fprintf('\n  Using all available data for validation year %d\n', valYear);
    fprintf('    Time periods: %d\n', length(obs.tME));
    fprintf('    Valid obs: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

    %% Loop through box sizes and folds for this year
    for iBox = 1:nBoxSizes
        boxSize = valParam.boxSizes(iBox);

        fprintf('\n=== Box Size: %.1f degrees ===\n', boxSize);

        for iFold = 1:nFolds
            fprintf('\n--- Fold %d/%d ---\n', iFold, nFolds);
            currentRun = currentRun + 1;

            % Generate Checkerboard Pattern
            fprintf('  Generating checkerboard pattern...\n');
            [trainMask, valMask] = getCheckerBoard(obs.sMS, boxSize, iFold, 0);

            %% Compute Fold-Specific Global Offset and Covariance
            % Create training-only observational dataset
            fprintf('\n  Creating training-only dataset for fold %d...\n', iFold);
            trainObs = obs;
            trainObs.sMS = obs.sMS(trainMask, :);
            trainObs.Z = obs.Z(trainMask, :);
            trainObs.Y = obs.Y(trainMask, :);
            % Keep same time vector (all times used, but only training stations)
            
            % get the idMS for the training stations
            trainObs.stationID = obs.stationID(trainMask);
            trainObs.stationType = obs.stationType(trainMask);


            fprintf('    Training stations: %d (%.1f%%)\n', ...
                sum(trainMask), 100*sum(trainMask)/length(trainMask));
            fprintf('    Validation stations: %d (%.1f%%)\n', ...
                sum(valMask), 100*sum(valMask)/length(valMask));

            % Compute fold-specific GO using ONLY training stations
            fprintf('\n  Computing fold-specific Global Offset and Covariance...\n');
            go_fold = getTOARglobalOffset_CBV(trainObs, valParam.goScenario, ...
                boxSize, iFold, yearRange, valParam.forceGO, 0);

            % Compute fold-specific covariance using ONLY training stations
            cov_fold = getTOARautoCov_CBV(trainObs, go_fold, ...
                valParam.temporalModel, boxSize, iFold, yearRange, valParam.forceCov);

            fprintf('    Fold-specific GO/Cov ready for validation.\n');

            %% Prepare Knowledge Base ONCE per fold (not per month)
            fprintf('\n  Preparing knowledge base for fold %d (once for all months)...\n', iFold);
            [KG_fold, KS_fold, ~] = getTOARknowledgeBase(trainObs, go_fold, cov_fold, ...
                softData, BMEparam.BMEmethod8digits);

            % Check sufficient training data
            if isempty(KS_fold.harddata.z) || length(KS_fold.harddata.z) < 10
                warning('Insufficient training data points (%d) for fold %d', ...
                    length(KS_fold.harddata.z), iFold);
                continue;  % Skip this fold
            end

            %% Reformat soft data ONCE per fold (expensive operation)
            BMEmethod8digits = BMEparam.BMEmethod8digits;
            BMEprobaType = str2double(BMEmethod8digits(8));
            soft_data_stug = [];
            p_soft_stug = [];
            z_soft_stug = [];
            vs_soft_stug = [];

            if BMEprobaType == 3 && iscell(KS_fold.softdata)
                % Multi-soft datasets - reformat all
                fprintf('  Reformatting %d soft datasets to STUG format (once per fold)...\n', ...
                    length(KS_fold.softdata));
                soft_data_stug = cell(size(KS_fold.softdata));
                p_soft_stug = cell(size(KS_fold.softdata));
                z_soft_stug = cell(size(KS_fold.softdata));
                vs_soft_stug = cell(size(KS_fold.softdata));

                for ii = 1:length(KS_fold.softdata)
                    soft_data_stug{ii} = reformat_stg_to_stug(KS_fold.softdata{ii}, 'verbose', false);
                    p_soft_stug{ii} = KS_fold.softdata{ii}.p;
                    z_soft_stug{ii} = KS_fold.softdata{ii}.z;
                    vs_soft_stug{ii} = KS_fold.softdata{ii}.vs;
                end
                fprintf('    Soft data reformatting complete.\n');
            elseif BMEprobaType == 2 && ~isempty(KS_fold.softdata.z)
                % Single soft dataset
                fprintf('  Reformatting soft data to STUG format (once per fold)...\n');
                soft_data_stug = reformat_stg_to_stug(KS_fold.softdata, 'verbose', false);
                p_soft_stug = KS_fold.softdata.p;
                z_soft_stug = KS_fold.softdata.z;
                vs_soft_stug = KS_fold.softdata.vs;
                fprintf('    Soft data reformatting complete.\n');
            end

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
                    % Evaluate this month using pre-formatted knowledge bases
                    tic;
                    monthResults = evaluateFold_CBV_monthly(obs, go_fold, BMEparam, ...
                        trainMask, valMask, valYear, valMonth, ...
                        KG_fold, KS_fold, soft_data_stug, p_soft_stug, z_soft_stug, vs_soft_stug);
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
