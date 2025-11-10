%% test_land_grid_filtering.m
% Test script to verify land filtering in getTOARmapGrid.m
%
% This script:
% 1. Tests different grid resolutions
% 2. Compares all-points vs land-only grids
% 3. Measures point reduction and execution time
% 4. Visualizes the results
% 5. Validates that filtering is working correctly

clear; close all; clc;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                TEST LAND GRID FILTERING\n');
fprintf('========================================================================\n');
fprintf('\n');

%% Configuration
% Test multiple resolutions
resolutions = [2.0, 1.0, 0.5, 0.25];
nRes = length(resolutions);

% Storage for results
results = struct();

%% Test Each Resolution
fprintf('Testing %d different resolutions...\n\n', nRes);

for iRes = 1:nRes
    res = resolutions(iRes);

    fprintf('========================================================================\n');
    fprintf('Resolution: %.2f degrees\n', res);
    fprintf('========================================================================\n');

    % Test 1: All points (no land filtering)
    fprintf('\n--- Test 1: All grid points (keepOnlyLand = false) ---\n');
    tic;
    grid_all = getTOARmapGrid(res, false, false);
    time_all = toc;
    nPoints_all = size(grid_all, 1);

    fprintf('  Grid points: %d\n', nPoints_all);
    fprintf('  Time: %.2f seconds\n', time_all);

    % Test 2: Land only
    fprintf('\n--- Test 2: Land points only (keepOnlyLand = true) ---\n');
    tic;
    grid_land = getTOARmapGrid(res, true, false);
    time_land = toc;
    nPoints_land = size(grid_land, 1);

    fprintf('  Land points: %d\n', nPoints_land);
    fprintf('  Time: %.2f seconds\n', time_land);

    % Calculate reduction
    reduction_pct = 100 * (nPoints_all - nPoints_land) / nPoints_all;
    points_saved = nPoints_all - nPoints_land;

    fprintf('\n--- Summary ---\n');
    fprintf('  Points removed: %d (%.1f%% reduction)\n', points_saved, reduction_pct);
    fprintf('  Estimated speedup in estimation: %.1fx\n', nPoints_all / nPoints_land);
    fprintf('  Land coverage: %.1f%% of grid\n', 100 * nPoints_land / nPoints_all);

    % Store results
    results(iRes).resolution = res;
    results(iRes).nPoints_all = nPoints_all;
    results(iRes).nPoints_land = nPoints_land;
    results(iRes).reduction_pct = reduction_pct;
    results(iRes).time_all = time_all;
    results(iRes).time_land = time_land;
    results(iRes).grid_all = grid_all;
    results(iRes).grid_land = grid_land;

    fprintf('\n');
end

%% Summary Table
fprintf('========================================================================\n');
fprintf('                         SUMMARY TABLE\n');
fprintf('========================================================================\n\n');

fprintf('%-12s %12s %12s %12s %12s\n', ...
    'Resolution', 'All Points', 'Land Points', 'Reduction', 'Speedup');
fprintf('%s\n', repmat('-', 70, 1));

for iRes = 1:nRes
    fprintf('%.2f°%9s %12d %12d %10.1f%% %10.1fx\n', ...
        results(iRes).resolution, '', ...
        results(iRes).nPoints_all, ...
        results(iRes).nPoints_land, ...
        results(iRes).reduction_pct, ...
        results(iRes).nPoints_all / results(iRes).nPoints_land);
end

fprintf('\n');

%% Calculate Statistics
fprintf('========================================================================\n');
fprintf('                         STATISTICS\n');
fprintf('========================================================================\n\n');

avg_reduction = mean([results.reduction_pct]);
avg_speedup = mean([results.nPoints_all] ./ [results.nPoints_land]);

fprintf('Average reduction across resolutions: %.1f%%\n', avg_reduction);
fprintf('Average speedup potential: %.1fx\n', avg_speedup);
fprintf('\n');

fprintf('Earth surface coverage (approximate):\n');
fprintf('  Land: ~29%% (actual)\n');
fprintf('  Our filtered grid: %.1f%% (measured)\n', 100 - avg_reduction);
if abs((100 - avg_reduction) - 29) < 5
    matchStr = 'Good';
else
    matchStr = 'Check filtering';
end
fprintf('  Match: %s\n', matchStr);
fprintf('\n');

%% Visualization

% Figure 1: Point count comparison
figure('Position', [100 100 1200 800], 'Color', 'w');

subplot(2, 2, 1);
bar([results.nPoints_all; results.nPoints_land]');
legend({'All Points', 'Land Only'}, 'Location', 'best');
xlabel('Resolution Index', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Number of Points', 'FontSize', 12, 'FontWeight', 'bold');
title('Grid Points: All vs Land Only', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f°', x), ...
    [results.resolution], 'UniformOutput', false));
grid on;

subplot(2, 2, 2);
bar([results.reduction_pct]);
xlabel('Resolution Index', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Reduction (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Point Reduction by Resolution', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f°', x), ...
    [results.resolution], 'UniformOutput', false));
ylim([0 100]);
grid on;

% Add text labels on bars
for i = 1:nRes
    text(i, results(i).reduction_pct + 2, ...
        sprintf('%.1f%%', results(i).reduction_pct), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 10, 'FontWeight', 'bold');
end

subplot(2, 2, 3);
speedups = [results.nPoints_all] ./ [results.nPoints_land];
bar(speedups);
xlabel('Resolution Index', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Speedup Factor', 'FontSize', 12, 'FontWeight', 'bold');
title('Potential Estimation Speedup', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f°', x), ...
    [results.resolution], 'UniformOutput', false));
grid on;

% Add text labels
for i = 1:nRes
    text(i, speedups(i) + 0.05, sprintf('%.1fx', speedups(i)), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 10, 'FontWeight', 'bold');
end

subplot(2, 2, 4);
times = [[results.time_land]' [results.time_all]'];
bar(times);
legend({'Land Filtering Time', 'All Points Time'}, 'Location', 'best');
xlabel('Resolution Index', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('Grid Generation Time', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f°', x), ...
    [results.resolution], 'UniformOutput', false));
grid on;

sgtitle('Land Grid Filtering Performance Analysis', ...
    'FontSize', 16, 'FontWeight', 'bold');

% Save figure
figDir = '1data/grids';
if ~exist(figDir, 'dir'), mkdir(figDir); end
saveas(gcf, fullfile(figDir, 'land_filtering_performance.png'));
fprintf('Performance figure saved to: %s\n', ...
    fullfile(figDir, 'land_filtering_performance.png'));

% Figure 2: Visual comparison for finest resolution
fprintf('\nCreating visual comparison plot...\n');
figure('Position', [100 100 1600 600], 'Color', 'w');

% Find finest resolution (smallest number)
[~, iFine] = min([results.resolution]);
res_fine = results(iFine).resolution;
grid_all_fine = results(iFine).grid_all;
grid_land_fine = results(iFine).grid_land;

% Subplot 1: All points
subplot(1, 3, 1);
scatter(grid_all_fine(:,1), grid_all_fine(:,2), 1, 'b', 'filled');
xlabel('Longitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Latitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('All Grid Points (%.2f°)\n%d points', res_fine, size(grid_all_fine, 1)), ...
    'FontSize', 13, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

% Subplot 2: Land only
subplot(1, 3, 2);
scatter(grid_land_fine(:,1), grid_land_fine(:,2), 1, 'g', 'filled');
xlabel('Longitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Latitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Land Points Only (%.2f°)\n%d points (%.1f%% reduction)', ...
    res_fine, size(grid_land_fine, 1), results(iFine).reduction_pct), ...
    'FontSize', 13, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

% Subplot 3: Removed points (ocean)
subplot(1, 3, 3);
% Find ocean points (in all but not in land)
[~, ia] = setdiff(grid_all_fine, grid_land_fine, 'rows');
ocean_points = grid_all_fine(ia, :);
scatter(ocean_points(:,1), ocean_points(:,2), 1, 'r', 'filled');
xlabel('Longitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Latitude (°)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Removed Points (Ocean) (%.2f°)\n%d points', ...
    res_fine, size(ocean_points, 1)), ...
    'FontSize', 13, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 11);

sgtitle('Visual Comparison: Grid Filtering Results', ...
    'FontSize', 16, 'FontWeight', 'bold');

% Save figure
saveas(gcf, fullfile(figDir, 'land_filtering_visual.png'));
fprintf('Visual comparison saved to: %s\n', ...
    fullfile(figDir, 'land_filtering_visual.png'));

%% Validation Checks
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         VALIDATION CHECKS\n');
fprintf('========================================================================\n\n');

% Check 1: All land points should be subset of all points
fprintf('Check 1: Land points are subset of all points\n');
allValid = true;
for iRes = 1:nRes
    isSubset = all(ismember(results(iRes).grid_land, results(iRes).grid_all, 'rows'));
    if isSubset
        statusStr = 'PASS';
    else
        statusStr = 'FAIL';
    end
    fprintf('  Resolution %.2f°: %s\n', results(iRes).resolution, statusStr);
    allValid = allValid && isSubset;
end
if allValid
    overallStr = 'PASS';
else
    overallStr = 'FAIL';
end
fprintf('  Overall: %s\n\n', overallStr);

% Check 2: Reduction should be reasonable (between 60-75% typically)
fprintf('Check 2: Reduction percentage is reasonable (60-75%%)\n');
for iRes = 1:nRes
    red = results(iRes).reduction_pct;
    isReasonable = (red >= 60) && (red <= 75);
    if isReasonable
        reasonStr = 'PASS';
    else
        reasonStr = 'WARNING';
    end
    fprintf('  Resolution %.2f°: %.1f%% - %s\n', results(iRes).resolution, red, reasonStr);
end
fprintf('\n');

% Check 3: Sample some known land points
fprintf('Check 3: Known land points are included\n');
knownLandPoints = [
    -95.0, 30.0;   % Texas, USA
      0.0, 51.5;   % London, UK
    139.7, 35.7;   % Tokyo, Japan
    151.2, -33.9;  % Sydney, Australia
    -46.6, -23.5   % São Paulo, Brazil
];

for iPt = 1:size(knownLandPoints, 1)
    pt = knownLandPoints(iPt, :);

    % Check in finest resolution grid
    [minDist, idx] = min(sum((grid_land_fine - pt).^2, 2));
    closestPt = grid_land_fine(idx, :);
    dist_km = minDist * 111;  % Rough conversion to km

    isIncluded = dist_km < (res_fine * 111 * 1.5);  % Within 1.5 grid cells

    if isIncluded
        inclStr = 'INCLUDED';
    else
        inclStr = 'MISSING';
    end
    fprintf('  Point (%.1f, %.1f): %s (closest: %.1f km)\n', ...
        pt(1), pt(2), inclStr, dist_km);
end

%% Save Results
fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         SAVING RESULTS\n');
fprintf('========================================================================\n\n');

resultsFile = fullfile(figDir, 'land_filtering_test_results.mat');
save(resultsFile, 'results', 'resolutions');
fprintf('Results saved to: %s\n', resultsFile);

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                         TEST COMPLETE\n');
fprintf('========================================================================\n\n');

fprintf('Summary:\n');
fprintf('  - Tested %d resolutions: %s\n', nRes, ...
    strjoin(arrayfun(@(x) sprintf('%.2f°', x), resolutions, 'UniformOutput', false), ', '));
fprintf('  - Average reduction: %.1f%%\n', avg_reduction);
fprintf('  - Average potential speedup: %.1fx\n', avg_speedup);
fprintf('  - Visual comparisons and performance plots generated\n');
fprintf('  - All validation checks completed\n');
fprintf('\n');
fprintf('Next steps:\n');
fprintf('  1. Review the generated figures in: %s\n', figDir);
fprintf('  2. Verify that reduction percentage matches expected (~71%% for Earth)\n');
fprintf('  3. Check that known land points are included in the grid\n');
fprintf('  4. Use these grids in your BME estimation workflow\n');
fprintf('\n');
