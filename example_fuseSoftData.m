%% example_fuseSoftData.m
% Example usage of fuseSoftData for combining multiple RAMP-corrected models
%
% Author: Praful Dodda
% Date: November 2025

%% Load your RAMP-corrected soft data
% Replace these with your actual file paths

% softData_CAMx = load('path/to/RAMP_CAMx.mat');
% softData_CMAQ = load('path/to/RAMP_CMAQ.mat');
% softData_M3fusion = load('path/to/RAMP_M3fusion.mat');

%% Create synthetic example data for demonstration
fprintf('Creating synthetic test data...\n');

nGrid = 1000;
nMonths = 24;

% Shared coordinates
lat = 25 + 25*rand(nGrid, 1);
lon = -125 + 55*rand(nGrid, 1);
sMS = [lat, lon];
tME = 2016 + (0:23)/12;  % 2016-2017 monthly
years = [2016, 2017];

% Model 1: CAMx - lower variance, slight high bias
softData_CAMx = struct();
softData_CAMx.modelName = 'CAMx';
softData_CAMx.years = years;
softData_CAMx.lat = lat;
softData_CAMx.lon = lon;
softData_CAMx.sMS = sMS;
softData_CAMx.tME = tME;
softData_CAMx.Z = single(40 + 10*randn(nGrid, nMonths) + 5);  % biased +5
softData_CAMx.Zv = single(25 + 10*rand(nGrid, nMonths));      % var 25-35
softData_CAMx.Zname = 'CAMx-RAMP';
softData_CAMx.Zunit = 'ppb';
softData_CAMx.Zlabel = 'CAMx RAMP-corrected MDA8 Ozone';
softData_CAMx.nGrid = nGrid;
softData_CAMx.nMonths = nMonths;

% Model 2: CMAQ - higher variance, less bias
softData_CMAQ = struct();
softData_CMAQ.modelName = 'CMAQ';
softData_CMAQ.years = years;
softData_CMAQ.lat = lat;
softData_CMAQ.lon = lon;
softData_CMAQ.sMS = sMS;
softData_CMAQ.tME = tME;
softData_CMAQ.Z = single(40 + 10*randn(nGrid, nMonths));      % unbiased
softData_CMAQ.Zv = single(40 + 20*rand(nGrid, nMonths));      % var 40-60
softData_CMAQ.Zname = 'CMAQ-RAMP';
softData_CMAQ.Zunit = 'ppb';
softData_CMAQ.Zlabel = 'CMAQ RAMP-corrected MDA8 Ozone';
softData_CMAQ.nGrid = nGrid;
softData_CMAQ.nMonths = nMonths;

%% Method 1: Spatially Varying Selection
% Best when models have distinct geographic strengths
% Picks the "champion" model at each location based on minimum variance

fprintf('\n=== SPATIALLY VARYING SELECTION ===\n');
fused_selection = fuseSoftData({softData_CAMx, softData_CMAQ}, 'selection');

% Check which model dominated
fprintf('CAMx selected at %.1f%% of points\n', ...
    100*mean(fused_selection.modelSelected(:) == 1));

%% Method 2: Bayesian Model Averaging (BMA)
% Best for rigorous uncertainty quantification
% Accounts for both within-model and between-model uncertainty

fprintf('\n=== BAYESIAN MODEL AVERAGING ===\n');
fused_bma = fuseSoftData({softData_CAMx, softData_CMAQ}, 'bma');

% Check weights
fprintf('Mean CAMx weight: %.3f\n', mean(fused_bma.weights.CAMx(:)));
fprintf('Mean CMAQ weight: %.3f\n', mean(fused_bma.weights.CMAQ(:)));

%% Method 3: Concatenation
% Simply stacks all data - lets BME handle weighting during kriging
% Useful when you want to preserve all information

fprintf('\n=== CONCATENATION ===\n');
fused_concat = fuseSoftData({softData_CAMx, softData_CMAQ}, 'concat');

fprintf('Total points: %d (was %d per model)\n', ...
    fused_concat.nGrid, softData_CAMx.nGrid);

%% Compare output structures
fprintf('\n=== OUTPUT STRUCTURE COMPARISON ===\n');

fprintf('\nSelection output:\n');
fprintf('  Z size: [%d x %d]\n', size(fused_selection.Z));
fprintf('  Zv size: [%d x %d]\n', size(fused_selection.Zv));
fprintf('  Has modelSelected: %s\n', mat2str(isfield(fused_selection, 'modelSelected')));

fprintf('\nBMA output:\n');
fprintf('  Z size: [%d x %d]\n', size(fused_bma.Z));
fprintf('  Zv size: [%d x %d]\n', size(fused_bma.Zv));
fprintf('  Has weights: %s\n', mat2str(isfield(fused_bma, 'weights')));

fprintf('\nConcat output:\n');
fprintf('  Z size: [%d x %d]\n', size(fused_concat.Z));
fprintf('  Zv size: [%d x %d]\n', size(fused_concat.Zv));
fprintf('  Has modelIndex: %s\n', mat2str(isfield(fused_concat, 'modelIndex')));

%% Use with krigingME_stg
% The fused data can be used directly with your existing BME code

% Example (pseudocode):
% softdata.sMS = fused_bma.sMS;
% softdata.tME = fused_bma.tME;
% softdata.Z = fused_bma.Z;
% softdata.Xvs = fused_bma.Zv;  % Note: krigingME_stg uses Xvs
%
% [zk, vk] = krigingME_stg(pk, harddata, softdata, covmodel, covparam, ...
%                          nhmax, nsmax, dmax, order, options);

%% Visualize disagreement (where BMA variance inflates)
% The "disagreement penalty" shows where models diverge

if nGrid > 0
    % Calculate disagreement metric for first time step
    Z_diff = abs(softData_CAMx.Z(:,1) - softData_CMAQ.Z(:,1));
    avg_std = sqrt((softData_CAMx.Zv(:,1) + softData_CMAQ.Zv(:,1)) / 2);
    disagreement = Z_diff ./ avg_std;
    
    % Variance inflation from BMA
    avg_input_var = (softData_CAMx.Zv(:,1) + softData_CMAQ.Zv(:,1)) / 2;
    var_inflation = fused_bma.Zv(:,1) ./ avg_input_var;
    
    fprintf('\n=== DISAGREEMENT ANALYSIS (Month 1) ===\n');
    fprintf('Mean normalized disagreement: %.2f\n', mean(disagreement));
    fprintf('Max normalized disagreement: %.2f\n', max(disagreement));
    fprintf('Mean variance inflation (BMA): %.2fx\n', mean(var_inflation));
    fprintf('Points with >2x variance inflation: %.1f%%\n', ...
        100*mean(var_inflation > 2));
end

%% Save fused data
% save('fused_bma.mat', '-struct', 'fused_bma');
% save('fused_selection.mat', '-struct', 'fused_selection');
% save('fused_concat.mat', '-struct', 'fused_concat');

fprintf('\nExample complete!\n');
