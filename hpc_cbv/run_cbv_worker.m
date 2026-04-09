function run_cbv_worker(BMEmethod, valYears, boxSizes)
% run_cbv_worker - HPC worker script for Checker-Board Validation
%
% SYNTAX:
%   run_cbv_worker(BMEmethod, valYears, boxSizes)
%
% INPUTS:
%   BMEmethod - BME method code (e.g., '10000133', '13000313-02')
%   valYears  - Years to validate (e.g., [2016 2017 2018 2019])
%   boxSizes  - Checker box sizes in degrees (e.g., [3.0 4.0 5.0])
%
% EXAMPLE:
%   run_cbv_worker('10000133', [2017 2018], [4.0 5.0])
%
% This script is designed to run as a single HPC job for one BME method
% across all specified years, months, and box sizes. It runs sequentially
% to ensure GO and covariance files are not created simultaneously by
% multiple threads (file conflict avoidance).
%
% NOTE:
%   - Each BME method runs in a separate job
%   - Within each job, all years/months/boxes are processed sequentially
%   - This prevents race conditions on shared files (GO, cov)

%% Parse Input Arguments
if ischar(BMEmethod)
    % BMEmethod is already string, no conversion needed
elseif isnumeric(BMEmethod)
    BMEmethod = num2str(BMEmethod);
end

if ischar(valYears)
    % Parse year range string like "2016:2019" or "[2016 2017 2018 2019]"
    valYears = str2num(valYears); %#ok<ST2NM>
end

if ischar(boxSizes)
    % Parse box sizes string
    boxSizes = str2num(boxSizes); %#ok<ST2NM>
end

%% Setup Paths and Environment
fprintf('\n========================================\n');
fprintf('  TOAR CHECKER-BOARD VALIDATION WORKER\n');
fprintf('========================================\n');
fprintf('Job Configuration:\n');
fprintf('  BME Method: %s\n', BMEmethod);
fprintf('  Validation Years: %s\n', mat2str(valYears));
fprintf('  Box Sizes: %s degrees\n', mat2str(boxSizes));
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

%% Set Validation Parameters (matching runCBV.m structure)
valParam = struct();

% Data parameters
valParam.stationTypes = 'all';
valParam.timeRange = [min(valYears)-1, max(valYears)+1];  % ±1 year padding
valParam.logTransf = 0;

% Validation configuration
valParam.valYears = valYears;
valParam.valMonths = 1:12;  % All months
valParam.boxSizes = boxSizes;

% Global offset
valParam.goScenario = 3;  % Regional S/T smoothing (RECOMMENDED)
valParam.forceGO = 0;     % Use cached GO if available
valParam.goPlot = 0;      % No plots on HPC

% Covariance
valParam.temporalModel = 'holecos';
valParam.forceCov = 0;    % Use cached covariance if available

% BME method
valParam.BMEmethod = BMEmethod;

% Execution control
valParam.forceEstimation = 0;  % Use cached monthly results if available
valParam.plotResults = 0;      % No plots on HPC (create later)

% Soft data (will be loaded automatically based on BME method)
valParam.softData = [];  % Will be set by runCBV_toar if needed

fprintf('\n========================================\n');
fprintf('Parameter Summary:\n');
fprintf('  Station types: %s\n', valParam.stationTypes);
fprintf('  Data range: [%d, %d] (includes ±1 year padding)\n', ...
    valParam.timeRange(1), valParam.timeRange(2));
fprintf('  GO scenario: %d\n', valParam.goScenario);
fprintf('  Temporal model: %s\n', valParam.temporalModel);
fprintf('  Total months to validate: %d (= %d years × %d months)\n', ...
    length(valParam.valYears) * length(valParam.valMonths), ...
    length(valParam.valYears), length(valParam.valMonths));
fprintf('  Total configurations: %d (= %d box sizes × %d months)\n', ...
    length(valParam.boxSizes) * length(valParam.valYears) * length(valParam.valMonths), ...
    length(valParam.boxSizes), length(valParam.valYears) * length(valParam.valMonths));
fprintf('========================================\n\n');

%% Check if soft data needed
[obsType, CTMtype, ~, ~, ~, ~, ctm_models] = parseBMEcode(valParam.BMEmethod);

if CTMtype > 0
    fprintf('Soft data required for BME method %s:\n', valParam.BMEmethod);
    fprintf('  CTM models: %s\n', strjoin(ctm_models, ', '));

    % Load soft data using getTOARSoftData
    % This function handles temporal padding and spatial subsetting
    fprintf('  Loading soft data...\n');
    tic;

    % Create analyzeParam structure needed by getTOARSoftData
    analyzeParam.BMEmethod = valParam.BMEmethod;
    analyzeParam.timeRange = valParam.timeRange;
    analyzeParam.areaCode = 0;  % Global
    analyzeParam.tkVec = linspace(valParam.timeRange(1), ...
        valParam.timeRange(2) + 11/12, ...
        (valParam.timeRange(2) - valParam.timeRange(1) + 1) * 12);

    valParam.softData = getTOARSoftData(valParam.BMEmethod, analyzeParam, ...
        'temporalPadding', 1, ...
        'spatialBuffer', 2, ...
        'forceReload', 0);

    tSoft = toc;
    fprintf('  Soft data loaded in %.1f seconds\n', tSoft);
else
    fprintf('No soft data needed (hard data only)\n');
end

%% Run CBV Validation
fprintf('\n========================================\n');
fprintf('  RUNNING CHECKER-BOARD VALIDATION\n');
fprintf('========================================\n\n');

tic;
[cbvSummary, cbvPairsAll] = runCBV_toar(valParam);
tCBV = toc;

%% Display Results
fprintf('\n========================================\n');
fprintf('  VALIDATION COMPLETE\n');
fprintf('========================================\n');
fprintf('Total time: %.1f seconds (%.1f minutes)\n', tCBV, tCBV/60);

fprintf('\nCBV Summary:\n');
disp(cbvSummary);

fprintf('\nTotal validation pairs: %d\n', length(cbvPairsAll.Y_obs));

%% Save Summary Results
resultsDir = fullfile('7validation', 'CBV', 'hpc_results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Create safe filename (replace special characters)
methodID = strrep(BMEmethod, '-', '_');
methodID = strrep(methodID, ':', '_');

summaryFile = sprintf('cbv_summary_%s_y%s_b%s.mat', ...
    methodID, ...
    strrep(mat2str(valParam.valYears), ' ', '_'), ...
    strrep(mat2str(valParam.boxSizes), ' ', '_'));
summaryPath = fullfile(resultsDir, summaryFile);

% Save summary with timing info and job metadata
summary.cbvSummary = cbvSummary;
summary.valParam = valParam;
summary.nPairs = length(cbvPairsAll.Y_obs);
summary.timing.total = tCBV;
summary.jobInfo.BMEmethod = BMEmethod;
summary.jobInfo.valYears = valYears;
summary.jobInfo.boxSizes = boxSizes;
summary.jobInfo.hostname = getenv('HOSTNAME');
summary.jobInfo.completedAt = datestr(now);

% Save both summary and full pairs
save(summaryPath, 'summary', 'cbvSummary', 'cbvPairsAll', 'valParam', '-v7.3');
fprintf('\nResults saved: %s\n', summaryPath);
fprintf('File size: %.1f MB\n', dir(summaryPath).bytes / 1024^2);

fprintf('\nJob finished: %s\n', datestr(now));
fprintf('========================================\n\n');

end
