%% test_softdata_workflow.m
% Demonstration script for loading and visualizing RAMP-corrected soft data
%
% This script shows the complete workflow for:
%   1. Loading RAMP parquet files
%   2. Creating soft data structure
%   3. Visualizing mean and variance fields
%   4. Testing with BME krigingME
%
% Prerequisites:
%   - Parquet files in 1data/CTM/:
%       lambda1_UKML_YYYY_v3-parallel.parquet
%       lambda2_UKML_YYYY_v3-parallel.parquet
%   - TOAR observational data available

clear; close all; clc;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                  SOFT DATA WORKFLOW DEMONSTRATION\n');
fprintf('========================================================================\n');
fprintf('\n');

%% Configuration
% Test with a single year first, then expand
TEST_YEARS = 2017;  % Start with 2017 only
MODEL_NAME = 'UKML';
RAMP_VERSION = 3;

% Spatial bounds (optional - comment out to use full domain)
% CONUS bounds
SPATIAL_BOUNDS = [-125 -65 24 50];

% Thinning factor (1 = no thinning, 2 = every 2nd point, etc.)
THINNING_FACTOR = 1;  % Use 2 or 3 if memory is an issue

%% Step 1: Load Observational Data
fprintf('STEP 1: Loading observational data...\n');
fprintf('======================================\n');

obs = getTOARobservationalData('all', [2015 2020], 0);

fprintf('Observational data loaded:\n');
fprintf('  Stations: %d\n', size(obs.Z, 1));
fprintf('  Time periods: %d\n', size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

%% Step 2: Load RAMP Data from Parquet Files
fprintf('\n');
fprintf('STEP 2: Loading RAMP-corrected CTM data...\n');
fprintf('==========================================\n');

% Set path to parquet files
PARQUET_DIR = fullfile('1data', 'CTM');

if ~exist(PARQUET_DIR, 'dir')
    error('Parquet directory not found: %s\nPlease create and place parquet files there.', PARQUET_DIR);
end

% Check if parquet files exist
testFile = sprintf('lambda1_%s_%d_v%d-parallel.parquet', MODEL_NAME, TEST_YEARS(1), RAMP_VERSION);
if ~exist(fullfile(PARQUET_DIR, testFile), 'file')
    error('Parquet file not found: %s\nExpected location: %s', testFile, fullfile(PARQUET_DIR, testFile));
end

% Load RAMP data (will create cache on first run)
ctmData = loadRAMPdata(MODEL_NAME, TEST_YEARS, PARQUET_DIR, 0);

%% Step 3: Create Soft Data Structure
fprintf('\n');
fprintf('STEP 3: Creating soft data structure...\n');
fprintf('========================================\n');

% Set options
options = struct();
if exist('SPATIAL_BOUNDS', 'var')
    options.spatialBounds = SPATIAL_BOUNDS;
end
options.thinningFactor = THINNING_FACTOR;
options.minVariance = 0.01;
options.removeHardData = 0;  % Don't remove for now (can enable later)

% Create soft data structure
softData = createSoftDataStructure(ctmData, obs, options);

%% Step 4: Visualize Soft Data
fprintf('\n');
fprintf('STEP 4: Creating visualization plots...\n');
fprintf('========================================\n');

% Plot first month (mean and variance)
plotSoftData(softData, obs, 1, 'both');

% Plot a few more months if available
if length(softData.tME) >= 6
    fprintf('\nPlotting additional months...\n');
    plotSoftData(softData, obs, [3 6 9], 'mean');
end

%% Step 5: Save Soft Data Structure
fprintf('\n');
fprintf('STEP 5: Saving soft data structure...\n');
fprintf('======================================\n');

softDataDir = '2softdata';
if ~exist(softDataDir, 'dir')
    mkdir(softDataDir);
end

saveFile = sprintf('softData_%s_%d-%d.mat', ...
    MODEL_NAME, min(TEST_YEARS), max(TEST_YEARS));
savePath = fullfile(softDataDir, saveFile);

save(savePath, 'softData', '-v7.3');
fprintf('Soft data saved to: %s\n', savePath);

fileInfo = dir(savePath);
fprintf('File size: %.1f MB\n', fileInfo.bytes / 1024^2);

%% Step 6: Test with BME KrigingME
fprintf('\n');
fprintf('STEP 6: Testing soft data with BME krigingME...\n');
fprintf('================================================\n');

% Get GO and covariance for a simple test
fprintf('Calculating global offset (GO scenario 3)...\n');
go = getTOARglobalOffset(obs, 3, 0, 0, 0);

fprintf('Calculating covariance...\n');
cov = getTOARautoCov(obs, go, 'holecos', 0);

% Get knowledge base WITH soft data
fprintf('Creating knowledge base with soft data...\n');
BMEmethod = '11000132';  % Note: digit 2 is now '1' for soft data
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod);

fprintf('\nKnowledge base created:\n');
fprintf('  Hard data points: %d\n', length(KS.harddata.z));
fprintf('  Soft data points: %d\n', length(KS.softdata.z));
fprintf('  Ratio (soft:hard): %.1f:1\n', length(KS.softdata.z)/length(KS.harddata.z));

% Test kriging at a few estimation points
fprintf('\nTesting krigingME with soft data...\n');

% Pick 5 random hard data points to test
nTest = min(5, length(KS.harddata.p));
testIdx = randperm(length(KS.harddata.p), nTest);

fprintf('Estimating at %d test locations...\n', nTest);

for i = 1:nTest
    pk = KS.harddata.p(testIdx(i), :);

    % Estimate using hard data only (remove test point)
    ch_train = KS.harddata.p;
    ch_train(testIdx(i), :) = [];
    zh_train = KS.harddata.z;
    zh_train(testIdx(i)) = [];

    % Call krigingME with soft data
    tic;
    [xk_mean, xk_var] = krigingME(pk, ch_train, KS.softdata.p, zh_train, ...
        KS.softdata.z, KS.softdata.vs, KG.covmodel, KG.covparam, ...
        BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, KG.order);
    tElapsed = toc;

    % True value (for comparison)
    zh_true = KS.harddata.z(testIdx(i));

    % Add GO back for interpretation
    gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, pk(1:2), pk(3));
    yk_est = xk_mean + gok;
    yk_true = zh_true + gok;

    fprintf('  Point %d: True=%.1f, Est=%.1f, Error=%.1f ppb, Std=%.2f ppb (%.3f sec)\n', ...
        i, yk_true, yk_est, abs(yk_true - yk_est), sqrt(xk_var), tElapsed);
end

fprintf('\n✓ Soft data integration successful!\n');

%% Summary
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         WORKFLOW COMPLETE\n');
fprintf('========================================================================\n');
fprintf('\nSummary:\n');
fprintf('  CTM Model: %s (RAMP v%d)\n', MODEL_NAME, RAMP_VERSION);
fprintf('  Years processed: %s\n', mat2str(TEST_YEARS));
fprintf('  Soft data points: %d\n', size(softData.sMS, 1));
fprintf('  Temporal coverage: %d months\n', length(softData.tME));
fprintf('  BME method: %s (with soft data)\n', BMEmethod);
fprintf('  Data cached: %s\n', savePath);
fprintf('  Plots: 2softdata/plots/\n');
fprintf('\nNext steps:\n');
fprintf('  1. Expand to more years: TEST_YEARS = 2015:2020\n');
fprintf('  2. Run validation with soft data (modify validation scripts)\n');
fprintf('  3. Compare results with/without soft data\n');
fprintf('\n');
