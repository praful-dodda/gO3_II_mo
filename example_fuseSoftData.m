%% example_fuseSoftData.m
% Example usage of fuseSoftData with visual verification
%
% Demonstrates:
%   1. Basic usage with matching grids
%   2. Handling different spatial resolutions (union grid)
%   3. Visual verification of grid alignment
%
% Author: Praful Dodda
% Date: November 2025

%% ========================================================================
%  EXAMPLE 1: Same spatial grid (standard case)
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# EXAMPLE 1: Models with SAME spatial grid               #\n');
fprintf('##########################################################\n');

% Create synthetic data - same grid for both models
nGrid = 1000;
nMonths = 24;

lat = 25 + 25*rand(nGrid, 1);
lon = -125 + 55*rand(nGrid, 1);
sMS = [lat, lon];
tME = 2016 + (0:23)/12;
years = [2016, 2017];

% Model 1: CAMx - lower variance
softData_CAMx = struct();
softData_CAMx.modelName = 'CAMx';
softData_CAMx.years = years;
softData_CAMx.lat = lat;
softData_CAMx.lon = lon;
softData_CAMx.sMS = sMS;
softData_CAMx.tME = tME;
softData_CAMx.Z = single(40 + 10*randn(nGrid, nMonths) + 5);
softData_CAMx.Zv = single(25 + 10*rand(nGrid, nMonths));
softData_CAMx.Zname = 'CAMx-RAMP';
softData_CAMx.Zunit = 'ppb';
softData_CAMx.Zlabel = 'CAMx RAMP-corrected MDA8 Ozone';
softData_CAMx.nGrid = nGrid;
softData_CAMx.nMonths = nMonths;

% Model 2: CMAQ - higher variance (same grid)
softData_CMAQ = struct();
softData_CMAQ.modelName = 'CMAQ';
softData_CMAQ.years = years;
softData_CMAQ.lat = lat;
softData_CMAQ.lon = lon;
softData_CMAQ.sMS = sMS;
softData_CMAQ.tME = tME;
softData_CMAQ.Z = single(40 + 10*randn(nGrid, nMonths));
softData_CMAQ.Zv = single(40 + 20*rand(nGrid, nMonths));
softData_CMAQ.Zname = 'CMAQ-RAMP';
softData_CMAQ.Zunit = 'ppb';
softData_CMAQ.Zlabel = 'CMAQ RAMP-corrected MDA8 Ozone';
softData_CMAQ.nGrid = nGrid;
softData_CMAQ.nMonths = nMonths;

% Run BMA fusion
fprintf('\n--- BMA Method ---\n');
fused_bma = fuseSoftData({softData_CAMx, softData_CMAQ}, 'bma', 'Verbose', true);

% Visual verification
fprintf('\n--- Visual Verification (Same Grid) ---\n');
verifyGridAlignment({softData_CAMx, softData_CMAQ}, fused_bma, 'TimeIndex', 1);


%% ========================================================================
%  EXAMPLE 2: Different spatial resolutions (union grid)
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# EXAMPLE 2: Models with DIFFERENT spatial resolutions   #\n');
fprintf('##########################################################\n');

% Model A: Coarse grid (12km ~ 0.1° spacing)
% Create a regular grid
nLatCoarse = 20;
nLonCoarse = 25;
latVecCoarse = linspace(30, 32, nLatCoarse);
lonVecCoarse = linspace(-100, -97, nLonCoarse);
[lonGridC, latGridC] = meshgrid(lonVecCoarse, latVecCoarse);
latCoarse = latGridC(:);
lonCoarse = lonGridC(:);
nGridCoarse = length(latCoarse);

softData_Coarse = struct();
softData_Coarse.modelName = 'CoarseModel';
softData_Coarse.years = years;
softData_Coarse.lat = latCoarse;
softData_Coarse.lon = lonCoarse;
softData_Coarse.sMS = [latCoarse, lonCoarse];
softData_Coarse.tME = tME;
softData_Coarse.Z = single(40 + 8*randn(nGridCoarse, nMonths));
softData_Coarse.Zv = single(30 + 15*rand(nGridCoarse, nMonths));
softData_Coarse.Zname = 'Coarse-RAMP';
softData_Coarse.Zunit = 'ppb';
softData_Coarse.Zlabel = 'Coarse Model RAMP-corrected';
softData_Coarse.nGrid = nGridCoarse;
softData_Coarse.nMonths = nMonths;

% Model B: Fine grid (4km ~ 0.04° spacing), partially overlapping region
% Shifted to create partial overlap
nLatFine = 30;
nLonFine = 40;
latVecFine = linspace(30.5, 32.5, nLatFine);  % Overlaps [30.5, 32] with coarse
lonVecFine = linspace(-99.5, -96.5, nLonFine);  % Overlaps [-99.5, -97] with coarse
[lonGridF, latGridF] = meshgrid(lonVecFine, latVecFine);
latFine = latGridF(:);
lonFine = lonGridF(:);
nGridFine = length(latFine);

softData_Fine = struct();
softData_Fine.modelName = 'FineModel';
softData_Fine.years = years;
softData_Fine.lat = latFine;
softData_Fine.lon = lonFine;
softData_Fine.sMS = [latFine, lonFine];
softData_Fine.tME = tME;
softData_Fine.Z = single(42 + 6*randn(nGridFine, nMonths));
softData_Fine.Zv = single(20 + 10*rand(nGridFine, nMonths));  % Lower variance
softData_Fine.Zname = 'Fine-RAMP';
softData_Fine.Zunit = 'ppb';
softData_Fine.Zlabel = 'Fine Model RAMP-corrected';
softData_Fine.nGrid = nGridFine;
softData_Fine.nMonths = nMonths;

fprintf('\nInput grids:\n');
fprintf('  Coarse model: %d points (%dx%d), lat [%.2f, %.2f], lon [%.2f, %.2f]\n', ...
    nGridCoarse, nLatCoarse, nLonCoarse, min(latCoarse), max(latCoarse), min(lonCoarse), max(lonCoarse));
fprintf('  Fine model: %d points (%dx%d), lat [%.2f, %.2f], lon [%.2f, %.2f]\n', ...
    nGridFine, nLatFine, nLonFine, min(latFine), max(latFine), min(lonFine), max(lonFine));

% Calculate expected overlap region
latOverlap = [max(min(latCoarse), min(latFine)), min(max(latCoarse), max(latFine))];
lonOverlap = [max(min(lonCoarse), min(lonFine)), min(max(lonCoarse), max(lonFine))];
fprintf('  Expected overlap: lat [%.2f, %.2f], lon [%.2f, %.2f]\n', ...
    latOverlap(1), latOverlap(2), lonOverlap(1), lonOverlap(2));

% Fuse with BMA
fprintf('\n--- BMA with Different Resolutions ---\n');
fused_multiRes = fuseSoftData({softData_Coarse, softData_Fine}, 'bma', ...
    'SpatialTolerance', 0.001, ...
    'Verbose', true);

% Visual verification - this is the key check
fprintf('\n--- Visual Verification (Different Resolutions) ---\n');
verifyGridAlignment({softData_Coarse, softData_Fine}, fused_multiRes, ...
    'SpatialTolerance', 0.001, ...
    'TimeIndex', 1);

% Report
fprintf('\nUnion grid summary:\n');
fprintf('  Coarse points: %d\n', nGridCoarse);
fprintf('  Fine points: %d\n', nGridFine);
fprintf('  Sum (if no overlap): %d\n', nGridCoarse + nGridFine);
fprintf('  Actual union: %d\n', fused_multiRes.nGrid);
fprintf('  Overlap (matched points): %d\n', (nGridCoarse + nGridFine) - fused_multiRes.nGrid);


%% ========================================================================
%  EXAMPLE 3: Selection method with different grids
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# EXAMPLE 3: Selection method with different grids       #\n');
fprintf('##########################################################\n');

% Use same grids as Example 2
fprintf('\n--- Selection with Different Resolutions ---\n');
fused_selection = fuseSoftData({softData_Coarse, softData_Fine}, 'selection', ...
    'SpatialTolerance', 0.001, ...
    'Verbose', true);

% Visual verification
fprintf('\n--- Visual Verification (Selection) ---\n');
verifyGridAlignment({softData_Coarse, softData_Fine}, fused_selection, ...
    'SpatialTolerance', 0.001, ...
    'TimeIndex', 1);


%% ========================================================================
%  EXAMPLE 4: Concatenation with sorted output
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# EXAMPLE 4: Concatenation with sorting verification     #\n');
fprintf('##########################################################\n');

% Create intentionally unsorted input
nSmall = 100;

% Generate random latitudes in a shuffled order
baseLats = [45; 30; 40; 35; 25];  % 5 base values
nPerBase = nSmall / length(baseLats);  % 20 points per base lat

lat_unsorted = zeros(nSmall, 1);
for i = 1:length(baseLats)
    startIdx = (i-1)*nPerBase + 1;
    endIdx = i*nPerBase;
    lat_unsorted(startIdx:endIdx) = baseLats(i) + rand(nPerBase, 1);
end
lon_unsorted = -100 + 30*rand(nSmall, 1);

softData_Unsorted1 = struct();
softData_Unsorted1.modelName = 'Model1';
softData_Unsorted1.years = years;
softData_Unsorted1.lat = lat_unsorted;
softData_Unsorted1.lon = lon_unsorted;
softData_Unsorted1.sMS = [lat_unsorted, lon_unsorted];
softData_Unsorted1.tME = tME;
softData_Unsorted1.Z = single(40 + 10*randn(nSmall, nMonths));
softData_Unsorted1.Zv = single(30 + 10*rand(nSmall, nMonths));
softData_Unsorted1.Zname = 'M1-RAMP';
softData_Unsorted1.Zunit = 'ppb';
softData_Unsorted1.Zlabel = 'Model 1';
softData_Unsorted1.nGrid = nSmall;
softData_Unsorted1.nMonths = nMonths;

% Second model - same locations, different values
softData_Unsorted2 = softData_Unsorted1;
softData_Unsorted2.modelName = 'Model2';
softData_Unsorted2.Z = single(42 + 8*randn(nSmall, nMonths));
softData_Unsorted2.Zv = single(25 + 15*rand(nSmall, nMonths));

% Check if input is sorted
inputSorted = issorted(lat_unsorted);
fprintf('\nInput data sorted: %s\n', mat2str(inputSorted));

% Concatenate with sorting
fprintf('\n--- Concatenation with Sorting ---\n');
fused_concat = fuseSoftData({softData_Unsorted1, softData_Unsorted2}, 'concat', ...
    'SortOutput', true, ...
    'Verbose', true);

% Verify sorting
fprintf('\n--- Sorting Verification ---\n');
outputSorted = issorted(fused_concat.lat);
fprintf('Output data sorted: %s\n', mat2str(outputSorted));

% Show coordinate distribution
fprintf('\nLatitude range in output:\n');
fprintf('  Min: %.4f\n', min(fused_concat.lat));
fprintf('  Max: %.4f\n', max(fused_concat.lat));
fprintf('  First 5: %s\n', mat2str(fused_concat.lat(1:5)', 4));
fprintf('  Last 5: %s\n', mat2str(fused_concat.lat(end-4:end)', 4));


%% ========================================================================
%  EXAMPLE 5: Three models with mixed resolutions
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# EXAMPLE 5: Three models with mixed resolutions         #\n');
fprintf('##########################################################\n');

% Add a third model with yet another resolution
nLatMed = 25;
nLonMed = 30;
latVecMed = linspace(30.2, 32.2, nLatMed);
lonVecMed = linspace(-99.8, -96.8, nLonMed);
[lonGridM, latGridM] = meshgrid(lonVecMed, latVecMed);
latMed = latGridM(:);
lonMed = lonGridM(:);
nGridMed = length(latMed);

softData_Medium = struct();
softData_Medium.modelName = 'MediumModel';
softData_Medium.years = years;
softData_Medium.lat = latMed;
softData_Medium.lon = lonMed;
softData_Medium.sMS = [latMed, lonMed];
softData_Medium.tME = tME;
softData_Medium.Z = single(41 + 7*randn(nGridMed, nMonths));
softData_Medium.Zv = single(28 + 12*rand(nGridMed, nMonths));
softData_Medium.Zname = 'Medium-RAMP';
softData_Medium.Zunit = 'ppb';
softData_Medium.Zlabel = 'Medium Model RAMP-corrected';
softData_Medium.nGrid = nGridMed;
softData_Medium.nMonths = nMonths;

fprintf('\nThree model grids:\n');
fprintf('  Coarse: %d points\n', nGridCoarse);
fprintf('  Medium: %d points\n', nGridMed);
fprintf('  Fine: %d points\n', nGridFine);
fprintf('  Total: %d points\n', nGridCoarse + nGridMed + nGridFine);

% Fuse all three with BMA
fprintf('\n--- BMA with Three Models ---\n');
fused_three = fuseSoftData({softData_Coarse, softData_Medium, softData_Fine}, 'bma', ...
    'SpatialTolerance', 0.001, ...
    'Verbose', true);

% Visual verification
fprintf('\n--- Visual Verification (Three Models) ---\n');
verifyGridAlignment({softData_Coarse, softData_Medium, softData_Fine}, fused_three, ...
    'SpatialTolerance', 0.001, ...
    'TimeIndex', 1);


%% ========================================================================
%  Summary
%  ========================================================================

fprintf('\n');
fprintf('##########################################################\n');
fprintf('# SUMMARY                                                 #\n');
fprintf('##########################################################\n\n');

fprintf('Key features demonstrated:\n');
fprintf('  1. Same grid fusion (standard BMA/selection)\n');
fprintf('  2. Different resolution fusion via union grid\n');
fprintf('  3. Sorted output for consistent ordering\n');
fprintf('  4. Visual verification of alignment\n');
fprintf('  5. Multi-model (3+) fusion\n\n');

fprintf('Visual verification checks:\n');
fprintf('  - Original grids overlay\n');
fprintf('  - Fused grid colored by coverage\n');
fprintf('  - Overlap region zoom\n');
fprintf('  - Sorting verification\n');
fprintf('  - Value/weight distributions\n\n');

fprintf('Example complete! Check the generated figures.\n\n');
