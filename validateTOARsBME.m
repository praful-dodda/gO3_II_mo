function [valOut, valPairOut] = validateTOARsBME(obs, go, cov, BMEparam, valParam)
% validateTOARsBME - Monthly Leave-One-Out Cross Validation for TOAR BME
%
% Performs LOOCV month-by-month to avoid memory issues and provide
% realistic validation matching operational BME estimation approach
%
% SYNTAX:
%   [valOut, valPairOut] = validateTOARsBME(obs, go, cov, BMEparam, valParam)
%
% INPUTS:
%   obs       - Structure from getTOARobservationalData
%   go        - Structure from getTOARglobalOffset
%   cov       - Structure from getTOARautoCov
%   BMEparam  - BME parameters structure
%   valParam  - Validation parameters structure:
%               .valYears        - Years to validate (e.g., [2016 2017])
%               .valMonths       - Months to validate (e.g., 1:12 or [6 7 8])
%               .forceEstimation - Force re-calculation (1) or use saved (0)
%               .plotResults     - Create validation plots (0/1)
%
% OUTPUTS:
%   valOut     - Table with overall validation statistics
%   valPairOut - Structure with all obs/predicted pairs
%
% EXAMPLE:
%   valParam.valYears = [2016 2017];
%   valParam.valMonths = 1:12;
%   valParam.forceEstimation = 0;
%   valParam.plotResults = 1;
%   [valOut, valPairOut] = validateTOARsBME(obs, go, cov, BMEparam, valParam);

%% Input Validation
if nargin < 5
    error('All 5 inputs required. See help validateTOARsBME');
end

% Set defaults
if ~isfield(valParam, 'valYears'), valParam.valYears = 2016; end
if ~isfield(valParam, 'valMonths'), valParam.valMonths = 1:12; end
if ~isfield(valParam, 'forceEstimation'), valParam.forceEstimation = 0; end
if ~isfield(valParam, 'plotResults'), valParam.plotResults = 1; end

%% Setup
fprintf('\n========================================\n');
fprintf('  TOAR BME MONTHLY CROSS VALIDATION\n');
fprintf('========================================\n');
fprintf('Configuration:\n');
fprintf('  BME method: %s\n', BMEparam.BMEmethod8digits);
fprintf('  GO scenario: %d\n', go.scenario);
fprintf('  Years: %s\n', mat2str(valParam.valYears));
fprintf('  Months: %s\n', mat2str(valParam.valMonths));
fprintf('  Temporal search: ±%.2f years\n', BMEparam.dmax(2));

% Create output directory
valDir = '7validation';
if ~exist(valDir, 'dir')
    mkdir(valDir);
end

% Initialize accumulators for all results
Y_obs_all = [];
Y_est_all = [];
Y_estNoGo_all = [];
sk_all = [];
tk_all = [];
XkBMEv_all = [];

%% Monthly Validation Loop
totalMonths = length(valParam.valYears) * length(valParam.valMonths);
currentMonth = 0;

for iYear = 1:length(valParam.valYears)
    valYear = valParam.valYears(iYear);

    for iMonth = valParam.valMonths
        currentMonth = currentMonth + 1;

        fprintf('\n--- Month %d/%d: Year %d, Month %d ---\n', ...
            currentMonth, totalMonths, valYear, iMonth);

        % Create filename for this month
        valFilename = sprintf('TOAR_LOOCV_BME%s_go%d_y%d_m%02d.mat', ...
            BMEparam.BMEmethod8digits, go.scenario, valYear, iMonth);
        valPath = fullfile(valDir, valFilename);

        % Check if already computed
        if exist(valPath, 'file') && ~valParam.forceEstimation
            fprintf('  Loading cached results...\n');
            load(valPath, 'valResults');
        else
            % Perform monthly validation
            fprintf('  Performing LOOCV for this month...\n');
            valResults = validateTOAR_monthly(obs, go, cov, BMEparam, ...
                valYear, iMonth);

            % Save results
            save(valPath, 'valResults', '-v7.3');
            fprintf('  Results saved: %s\n', valFilename);
        end

        % Check if results are valid
        if isempty(valResults) || ~isfield(valResults, 'Y_obs')
            fprintf('  WARNING: No valid results for this month\n');
            continue;
        end

        % Accumulate results (back-transform if log transformation was used)
        if obs.logTransf == 1
            % Back-transform from log space to original concentration space
            Y_obs_all = [Y_obs_all; exp(valResults.Y_obs)];
            Y_est_all = [Y_est_all; exp(valResults.Y_est)];
            Y_estNoGo_all = [Y_estNoGo_all; exp(valResults.Y_estNoGo)];
        else
            Y_obs_all = [Y_obs_all; valResults.Y_obs];
            Y_est_all = [Y_est_all; valResults.Y_est];
            Y_estNoGo_all = [Y_estNoGo_all; valResults.Y_estNoGo];
        end
        sk_all = [sk_all; valResults.sk];
        tk_all = [tk_all; valResults.tk];
        if isfield(valResults, 'XkBMEv')
            XkBMEv_all = [XkBMEv_all; valResults.XkBMEv];
        end

        fprintf('  Valid pairs this month: %d\n', length(valResults.Y_obs));
    end
end

%% Calculate Overall Statistics
fprintf('\n========================================\n');
fprintf('  CALCULATING OVERALL STATISTICS\n');
fprintf('========================================\n');

if isempty(Y_obs_all)
    warning('No validation data available');
    valOut = [];
    valPairOut = [];
    return;
end

fprintf('Total validation pairs: %d\n', length(Y_obs_all));

% Calculate validation metrics
valStats = calculateValidationStats(Y_obs_all, Y_est_all, obs);

% Create results table
valOut = struct2table(valStats);

% Display results
fprintf('\n--- Validation Metrics ---\n');
fprintf('  N: %d\n', valStats.N);
fprintf('  Pearson R: %.3f\n', valStats.PearsonR);
fprintf('  R²: %.3f\n', valStats.R2);
fprintf('  RMSE: %.2f %s\n', valStats.RMSE, obs.Zunit);
fprintf('  MAE: %.2f %s\n', valStats.MAE, obs.Zunit);
fprintf('  ME: %.2f %s\n', valStats.ME, obs.Zunit);
fprintf('  MBE: %.2f %s\n', valStats.MBE, obs.Zunit);
fprintf('  NMB: %.1f%%\n', valStats.NMB);
fprintf('  NME: %.1f%%\n', valStats.NME);

%% Package Output
valPairOut.Y_obs = Y_obs_all;
valPairOut.Y_est = Y_est_all;
valPairOut.Y_estNoGo = Y_estNoGo_all;
valPairOut.sk = sk_all;
valPairOut.tk = tk_all;
if ~isempty(XkBMEv_all)
    valPairOut.XkBMEv = XkBMEv_all;
end

%% Save Combined Results
combinedFilename = sprintf('TOAR_LOOCV_BME%s_go%d_y%s_combined.mat', ...
    BMEparam.BMEmethod8digits, go.scenario, mat2str(valParam.valYears));
save(fullfile(valDir, combinedFilename), 'valOut', 'valPairOut', 'valParam', '-v7.3');
fprintf('\nCombined results saved: %s\n', combinedFilename);

%% Create Validation Plots
if valParam.plotResults
    fprintf('\n========================================\n');
    fprintf('  CREATING VALIDATION PLOTS\n');
    fprintf('========================================\n');
    plotTOARvalidation(valPairOut, valStats, valParam, obs, go, BMEparam);
end

fprintf('\n========================================\n');
fprintf('  VALIDATION COMPLETE\n');
fprintf('========================================\n\n');

end
