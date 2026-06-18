%% test_population_grid_coverage.m
% Verify that the BME estimation grid covers every populated cell in the GBD
% population dataset.
%
% The production estimation grid is built by
%   getTOARmapGrid(mapResolution, keepOnlyLand=true, includeAntarctica=false)
% which (a) keeps only points inside the coastlines.mat land polygon and
% (b) drops everything at latitude <= -60. Coastal / island populated cells, or
% small landmasses the coarse grid never samples, may end up with NO nearby land
% grid point and therefore no ozone estimate.
%
% This script flags every population cell whose nearest land grid point is
% farther than one grid spacing (would require extrapolation), and quantifies
% the gap BOTH by cell count and POPULATION-WEIGHTED (the number that matters
% for GBD exposure). It writes breakdown CSVs by GBD region and country and
% diagnostic maps.
%
% Reuses getTOARmapGrid.m unchanged. Sibling of test_land_grid_filtering.m.

clear; close all; clc;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('            POPULATION vs ESTIMATION-GRID COVERAGE CHECK\n');
fprintf('========================================================================\n\n');

%% ====================================================================
%                         CONFIGURATION
% ====================================================================

gridRes           = 1.0;     % estimation grid resolution (deg) - match runBME_estimation
keepOnlyLand      = true;    % match runBME_estimation
includeAntarctica = false;   % match runBME_estimation
coastBuffer       = gridRes/2; % dilate land mask outward by 1/2 cell (0 = legacy mask)
forcePopCoverage  = true;    % force-include nearest grid node to every pop cell (match production)
coverageThreshold = gridRes; % a cell is "uncovered" if nearest land grid pt > this (deg)
passTarget        = 0.999;   % pop-weighted coverage required to declare PASS

popCsv  = fullfile('Population-Data', 'PopulationData2019.csv');
outDir  = fullfile('1data', 'grids', 'population_coverage');
coastFile = fullfile('1data', 'coastlines.mat');

if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('Grid resolution     : %.2f deg\n', gridRes);
fprintf('keepOnlyLand        : %d\n', keepOnlyLand);
fprintf('includeAntarctica   : %d\n', includeAntarctica);
fprintf('Coast buffer        : %.2f deg (land-mask dilation)\n', coastBuffer);
fprintf('Force pop coverage  : %d (snap nearest node to every pop cell)\n', forcePopCoverage);
fprintf('Coverage threshold  : %.2f deg (nearest land grid point)\n', coverageThreshold);
fprintf('Population CSV       : %s\n', popCsv);
fprintf('Output directory     : %s\n\n', outDir);

%% ====================================================================
%                    STEP 1: LOAD POPULATION DATA
% ====================================================================

fprintf('--- Step 1: Loading population data (selected columns) ---\n');
tic;

wantCols = {'Longitude', 'Latitude', 'POP', 'CountryName', 'GBDRegion', 'WHORegion'};
opts = detectImportOptions(popCsv);
availCols = opts.VariableNames;
selCols = wantCols(ismember(wantCols, availCols));
missingCols = setdiff(wantCols, availCols);
if ~isempty(missingCols)
    warning('Population CSV missing expected columns: %s', strjoin(missingCols, ', '));
end
opts.SelectedVariableNames = selCols;
df = readtable(popCsv, opts);

nCells = height(df);
fprintf('  Loaded %d population cells in %.1f s\n', nCells, toc);

% Coordinates and population vector
lon = df.Longitude;
lat = df.Latitude;
if ismember('POP', df.Properties.VariableNames)
    pop = df.POP;
else
    warning('No POP column found - using uniform weights (cell-count only).');
    pop = ones(nCells, 1);
end
pop(isnan(pop)) = 0;
totalPop = sum(pop);
fprintf('  Total population (sum of POP weights): %.4g\n\n', totalPop);

%% ====================================================================
%                    STEP 2: BUILD ESTIMATION GRID
% ====================================================================

fprintf('--- Step 2: Building estimation grid ---\n');
popChoices = {'', popCsv};                        % off / same CSV we are checking against
popCoverFile = popChoices{forcePopCoverage + 1};
ck = getTOARmapGrid(gridRes, keepOnlyLand, includeAntarctica, [0 0], coastBuffer, popCoverFile);
fprintf('  Estimation grid: %d land points\n\n', size(ck, 1));

%% ====================================================================
%                    STEP 3: NEAREST-NEIGHBOR COVERAGE
% ====================================================================

fprintf('--- Step 3: Nearest land grid point per population cell ---\n');
tic;
[~, D] = knnsearch(ck, [lon, lat]);   % Euclidean distance in degrees
covered = D <= coverageThreshold;
uncovered = ~covered;
fprintf('  knnsearch over %d cells vs %d grid points in %.1f s\n\n', ...
    nCells, size(ck, 1), toc);

%% ====================================================================
%                    STEP 4: METRICS
% ====================================================================

fprintf('========================================================================\n');
fprintf('                            COVERAGE METRICS\n');
fprintf('========================================================================\n');

cellCov = mean(covered);
popCov  = sum(pop(covered)) / totalPop;

fprintf('Cell-count coverage       : %.3f%%  (%d / %d cells covered)\n', ...
    100*cellCov, sum(covered), nCells);
fprintf('Population-weighted cover : %.4f%%  (uncovered pop = %.4g)\n', ...
    100*popCov, sum(pop(uncovered)));

% Cause split for uncovered cells
belowAntarctica = uncovered & (lat <= -60);
landOrResMiss   = uncovered & (lat >  -60);
fprintf('\nUncovered cell causes:\n');
fprintf('  Below -60 lat (Antarctica cutoff): %d cells, pop = %.4g\n', ...
    sum(belowAntarctica), sum(pop(belowAntarctica)));
fprintf('  Land-mask / resolution miss      : %d cells, pop = %.4g\n', ...
    sum(landOrResMiss), sum(pop(landOrResMiss)));
fprintf('\n');

%% ====================================================================
%                    STEP 5: BREAKDOWN TABLES
% ====================================================================

fprintf('--- Step 5: Uncovered breakdown by region / country ---\n');

byRegion  = local_breakdown(df, 'GBDRegion',   uncovered, pop, totalPop);
byCountry = local_breakdown(df, 'CountryName', uncovered, pop, totalPop);

regionCsv  = fullfile(outDir, 'population_coverage_by_region.csv');
countryCsv = fullfile(outDir, 'population_coverage_by_country.csv');
if ~isempty(byRegion),  writetable(byRegion,  regionCsv);  end
if ~isempty(byCountry), writetable(byCountry, countryCsv); end
fprintf('  Region breakdown  -> %s\n', regionCsv);
fprintf('  Country breakdown -> %s\n', countryCsv);

% Print top offenders
if ~isempty(byRegion)
    fprintf('\nTop GBD regions by uncovered population:\n');
    topN = min(10, height(byRegion));
    disp(byRegion(1:topN, :));
end
if ~isempty(byCountry)
    fprintf('Top countries by uncovered population:\n');
    topN = min(15, height(byCountry));
    disp(byCountry(1:topN, :));
end

%% ====================================================================
%                    STEP 6: VISUALIZATION
% ====================================================================

fprintf('\n--- Step 6: Generating diagnostic figures ---\n');

% Load coastline overlay if available
haveCoast = false;
if exist(coastFile, 'file')
    try
        C = load(coastFile, 'coastlon', 'coastlat');
        haveCoast = true;
    catch
        haveCoast = false;
    end
end

% Subsample covered cells for plotting speed
nCov = sum(covered);
covIdx = find(covered);
maxPlot = 200000;
if nCov > maxPlot
    covIdx = covIdx(round(linspace(1, nCov, maxPlot)));
end

% --- Figure 1: world coverage map ---
f1 = figure('Position', [80 80 1500 750], 'Color', 'w');
hold on;
scatter(lon(covIdx), lat(covIdx), 1, [0.75 0.75 0.75], 'filled');
scatter(lon(uncovered), lat(uncovered), 4, 'r', 'filled');
if haveCoast
    plot(C.coastlon, C.coastlat, 'k-', 'LineWidth', 0.3);
end
xlabel('Longitude (\circ)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Latitude (\circ)', 'FontSize', 14, 'FontWeight', 'bold');
title(sprintf(['Population coverage by %.1f\\circ estimation grid  |  ' ...
    'pop-weighted %.3f%%, cells %.2f%%'], gridRes, 100*popCov, 100*cellCov), ...
    'FontSize', 16, 'FontWeight', 'bold');
legend({'Covered cells', 'Uncovered cells', 'Coastline'}, 'Location', 'southwest', ...
    'FontSize', 12);
axis equal; xlim([-180 180]); ylim([-90 90]); grid on;
set(gca, 'FontSize', 12);
saveas(f1, fullfile(outDir, 'population_coverage_map.png'));
fprintf('  Coverage map -> %s\n', fullfile(outDir, 'population_coverage_map.png'));

% --- Figure 2: uncovered cells colored by population ---
if any(uncovered)
    f2 = figure('Position', [100 100 1500 700], 'Color', 'w');
    hold on;
    if haveCoast
        plot(C.coastlon, C.coastlat, 'k-', 'LineWidth', 0.3);
    end
    popU = pop(uncovered);
    cvals = log10(max(popU, 1));
    scatter(lon(uncovered), lat(uncovered), 12, cvals, 'filled');
    cb = colorbar; cb.Label.String = 'log_{10}(POP)';
    cb.Label.FontSize = 12;
    xlabel('Longitude (\circ)', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel('Latitude (\circ)', 'FontSize', 14, 'FontWeight', 'bold');
    title(sprintf('Uncovered population cells (%d cells, pop = %.4g)', ...
        sum(uncovered), sum(popU)), 'FontSize', 16, 'FontWeight', 'bold');
    axis equal; xlim([-180 180]); ylim([-90 90]); grid on;
    set(gca, 'FontSize', 12);
    saveas(f2, fullfile(outDir, 'population_uncovered_by_pop.png'));
    fprintf('  Uncovered-by-POP map -> %s\n', fullfile(outDir, 'population_uncovered_by_pop.png'));
end

% --- Figure 3: uncovered population by GBD region ---
if ~isempty(byRegion)
    f3 = figure('Position', [120 120 1100 650], 'Color', 'w');
    topN = min(15, height(byRegion));
    barData = byRegion.UncoveredPOP(1:topN);
    barh(barData);
    set(gca, 'YTick', 1:topN, 'YTickLabel', byRegion.Group(1:topN), 'FontSize', 11);
    set(gca, 'YDir', 'reverse');
    xlabel('Uncovered population', 'FontSize', 14, 'FontWeight', 'bold');
    title('Uncovered population by GBD region', 'FontSize', 16, 'FontWeight', 'bold');
    grid on;
    saveas(f3, fullfile(outDir, 'population_uncovered_by_region.png'));
    fprintf('  Uncovered-by-region bar -> %s\n', fullfile(outDir, 'population_uncovered_by_region.png'));
end

%% ====================================================================
%                    STEP 7: VERDICT
% ====================================================================

fprintf('\n========================================================================\n');
fprintf('                               VERDICT\n');
fprintf('========================================================================\n');
if popCov >= passTarget
    fprintf('PASS: population-weighted coverage %.4f%% >= %.4f%% target.\n', ...
        100*popCov, 100*passTarget);
    fprintf('The %.1f\\circ land grid (no Antarctica) covers essentially all population.\n', gridRes);
else
    fprintf('WARNING: population-weighted coverage %.4f%% < %.4f%% target.\n', ...
        100*popCov, 100*passTarget);
    fprintf('Uncovered population = %.4g (%.4f%% of total). See breakdown CSVs and maps.\n', ...
        sum(pop(uncovered)), 100*(1-popCov));
    fprintf('Consider mitigations: buffer coastline mask, nearest-grid fallback in\n');
    fprintf('exposure sampling, or finer mapResolution.\n');
end
fprintf('========================================================================\n\n');

%% ---- local helper -------------------------------------------------------
function tbl = local_breakdown(df, groupVar, uncovered, pop, totalPop)
% Per-group uncovered counts and population, sorted by uncovered POP desc.
tbl = table();
if ~ismember(groupVar, df.Properties.VariableNames)
    warning('Group variable %s not present - skipping breakdown.', groupVar);
    return;
end
g = df.(groupVar);
if iscell(g)
    g = string(g);
elseif ischar(g)
    g = string(g);
end
g = categorical(g);
cats = categories(g);
n = numel(cats);

Group        = strings(n, 1);
UncoveredN   = zeros(n, 1);
TotalN       = zeros(n, 1);
UncoveredPOP = zeros(n, 1);
TotalPOP     = zeros(n, 1);
for i = 1:n
    inG = (g == cats{i});
    Group(i)        = string(cats{i});
    TotalN(i)       = sum(inG);
    UncoveredN(i)   = sum(inG & uncovered);
    TotalPOP(i)     = sum(pop(inG));
    UncoveredPOP(i) = sum(pop(inG & uncovered));
end
PctPopUncovered  = 100 * UncoveredPOP ./ max(TotalPOP, eps);
PctOfGlobalGap   = 100 * UncoveredPOP ./ max(totalPop, eps);

tbl = table(Group, UncoveredN, TotalN, UncoveredPOP, TotalPOP, ...
    PctPopUncovered, PctOfGlobalGap);
% Keep only groups with some uncovered population, sort by uncovered POP desc
tbl = tbl(tbl.UncoveredPOP > 0, :);
if ~isempty(tbl)
    tbl = sortrows(tbl, 'UncoveredPOP', 'descend');
end
end
