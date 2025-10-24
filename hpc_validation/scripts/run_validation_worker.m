function run_validation_worker(goScenario, valYears)
% run_validation_worker - HPC worker script for LOOCV validation
%
% SYNTAX:
%   run_validation_worker(goScenario, valYears)
%
% INPUTS:
%   goScenario - Global offset scenario (2, 3, 6, or 7)
%   valYears   - Years to validate (e.g., [2016 2017 2018 2019])
%
% EXAMPLE:
%   run_validation_worker(3, [2016 2017 2018 2019])
%
% This script is designed to run as a single HPC job for one GO scenario
% across all specified years and months.

%% Parse Input Arguments
if ischar(goScenario)
    goScenario = str2double(goScenario);
end

if ischar(valYears)
    % Parse year range string like "2016:2019" or "[2016 2017 2018 2019]"
    valYears = str2num(valYears); %#ok<ST2NM>
end

%% Setup Paths and Environment
fprintf('\n========================================\n');
fprintf('  TOAR LOOCV VALIDATION WORKER\n');
fprintf('========================================\n');
fprintf('Job Configuration:\n');
fprintf('  Global Offset Scenario: %d\n', goScenario);
fprintf('  Validation Years: %s\n', mat2str(valYears));
fprintf('  Start Time: %s\n', datestr(now));
fprintf('  Hostname: %s\n', getenv('HOSTNAME'));

% Add BMELIB to path if needed
if ~exist('BMEprobaMoments', 'file')
    bmelibPath = '../BMELIB2.0b';
    if exist(bmelibPath, 'dir')
        addpath(genpath(bmelibPath));
        fprintf('  Added BMELIB to path: %s\n', bmelibPath);
    else
        error('BMELIB not found. Please set correct path.');
    end
end

%% Set Validation Parameters
valParam = struct();

% Data parameters
valParam.stationTypes = 'all';
valParam.timeRange = [min(valYears)-1, max(valYears)+1];  % Load extra year for GO/cov
valParam.logTransf = 0;

% Global offset
valParam.goScenario = goScenario;
valParam.goPlot = 0;
valParam.forceGO = 0;  % Use cached GO if available

% Covariance
valParam.temporalModel = 'holecos';
valParam.forceCov = 0;  % Use cached covariance if available

% BME method
valParam.BMEmethod = '10000132';

% Validation configuration
valParam.valYears = valYears;
valParam.valMonths = 1:12;
valParam.method = 'loocv';
valParam.forceEstimation = 0;  % Use cached monthly results if available
valParam.plotResults = 0;  % No plots on HPC (create later)

% Soft data (none for now)
valParam.softData = [];

fprintf('\n========================================\n');

%% Load Observational Data
fprintf('Step 1/5: Loading observational data...\n');
tic;
obs = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);
tLoad = toc;
fprintf('  Data loaded in %.1f seconds\n', tLoad);
fprintf('  Stations: %d, Time periods: %d\n', size(obs.Z, 1), size(obs.Z, 2));

%% Calculate Global Offset
fprintf('\nStep 2/5: Calculating global offset (scenario %d)...\n', goScenario);
tic;
go = getTOARglobalOffset(obs, valParam.goScenario, valParam.goPlot, valParam.forceGO, 0);
tGO = toc;
fprintf('  Global offset calculated in %.1f seconds\n', tGO);

%% Calculate Covariance
fprintf('\nStep 3/5: Calculating covariance model...\n');
tic;
cov = getTOARautoCov(obs, go, valParam.temporalModel, valParam.forceCov);
tCov = toc;
fprintf('  Covariance calculated in %.1f seconds\n', tCov);

%% Get BME Parameters
fprintf('\nStep 4/5: Setting up BME parameters...\n');
[~, ~, BMEparam] = getTOARknowledgeBase(obs, go, cov, valParam.softData, valParam.BMEmethod);
fprintf('  BME method: %s\n', BMEparam.BMEmethod8digits);
fprintf('  nhmax=%d, nsmax=%d\n', BMEparam.nhmax, BMEparam.nsmax);
fprintf('  Search: %.1f deg, %.1f yr\n', BMEparam.dmax(1), BMEparam.dmax(2));

%% Run Validation
fprintf('\nStep 5/5: Running LOOCV validation...\n');
fprintf('  Years: %s\n', mat2str(valParam.valYears));
fprintf('  Months: %s\n', mat2str(valParam.valMonths));
fprintf('  Total months: %d\n', length(valParam.valYears) * length(valParam.valMonths));

tic;
[valOut, valPairOut] = validateTOARsBME(obs, go, cov, BMEparam, valParam);
tVal = toc;

%% Display Results
fprintf('\n========================================\n');
fprintf('  VALIDATION COMPLETE\n');
fprintf('========================================\n');
fprintf('Timing Summary:\n');
fprintf('  Data loading:    %8.1f sec\n', tLoad);
fprintf('  Global offset:   %8.1f sec\n', tGO);
fprintf('  Covariance:      %8.1f sec\n', tCov);
fprintf('  Validation:      %8.1f sec (%.1f min)\n', tVal, tVal/60);
fprintf('  Total:           %8.1f sec (%.1f min)\n', tLoad+tGO+tCov+tVal, (tLoad+tGO+tCov+tVal)/60);

fprintf('\nValidation Statistics:\n');
disp(valOut);

fprintf('\nValidation Pairs: %d\n', length(valPairOut.Y_obs));

%% Save Summary Results
resultsDir = fullfile('7validation', 'hpc_results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

summaryFile = sprintf('validation_summary_go%d_y%s.mat', ...
    goScenario, mat2str(valParam.valYears));
summaryPath = fullfile(resultsDir, summaryFile);

% Save summary with timing info
summary.valOut = valOut;
summary.valParam = valParam;
summary.nPairs = length(valPairOut.Y_obs);
summary.timing.dataLoad = tLoad;
summary.timing.globalOffset = tGO;
summary.timing.covariance = tCov;
summary.timing.validation = tVal;
summary.timing.total = tLoad + tGO + tCov + tVal;
summary.jobInfo.goScenario = goScenario;
summary.jobInfo.valYears = valYears;
summary.jobInfo.hostname = getenv('HOSTNAME');
summary.jobInfo.completedAt = datestr(now);

save(summaryPath, 'summary', 'valOut', 'valPairOut', 'valParam', '-v7.3');
fprintf('\nSummary saved: %s\n', summaryPath);

fprintf('\nJob finished: %s\n', datestr(now));
fprintf('========================================\n\n');

end
