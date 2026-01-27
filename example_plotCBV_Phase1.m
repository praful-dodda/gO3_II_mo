% example_plotCBV_Phase1.m - Example script for Phase 1 enhanced CBV plotting
%
% This script demonstrates how to use the Phase 1 enhanced plotting functions
% to visualize checker-board validation results.
%
% USAGE:
%   1. Edit cbvResultsDir to point to your CBV results directory
%   2. Run this script
%   3. Find generated figures in the figs_phase1 subdirectory

%% Configuration
% Directory containing CBV result .mat files
cbvResultsDir = './7validation/CBV';

% Optional: specify different file pattern if needed
% filePattern = 'CBV_BME13000313-01_*.mat';  % For specific BME method

%% Generate Phase 1 plots

fprintf('=== Generating Phase 1 Enhanced CBV Plots ===\n\n');

% Option 1: Basic usage (saves figures without displaying)
figPaths = plotCBVresults_Phase1(cbvResultsDir);

% Option 2: Display figures as they're created
% figPaths = plotCBVresults_Phase1(cbvResultsDir, 'visible', 'on');

% Option 3: Save to custom directory with higher DPI
% figPaths = plotCBVresults_Phase1(cbvResultsDir, ...
%     'saveDir', './my_cbv_figures', ...
%     'dpi', 600, ...
%     'visible', 'off');

% Option 4: Process only specific files
% figPaths = plotCBVresults_Phase1(cbvResultsDir, ...
%     'filePattern', 'CBV_BME13000313-01_go3_*.mat');

fprintf('\n=== Plotting Complete ===\n');
fprintf('Generated %d figures:\n', length(figPaths));
for i = 1:length(figPaths)
    fprintf('  %d. %s\n', i, figPaths{i});
end

%% Summary of Created Plots

fprintf('\n=== Plot Descriptions ===\n');
fprintf('1. CBV_scatter_by_year.png\n');
fprintf('   - Multi-panel scatter plots (observed vs estimated)\n');
fprintf('   - One panel per validation year\n');
fprintf('   - Shows R², RMSE, and sample size for each year\n');
fprintf('   - Aggregates across all folds and box sizes\n\n');

fprintf('2. CBV_metrics_by_boxsize.png\n');
fprintf('   - Four panels showing key metrics vs box size\n');
fprintf('   - Individual fold performance (colored markers)\n');
fprintf('   - Average performance with error bars (black line)\n');
fprintf('   - Helps identify optimal box size and fold consistency\n\n');

fprintf('3. CBV_regional_performance.png\n');
fprintf('   - Heatmap of R² by region and box size\n');
fprintf('   - Regions: North America, Europe, East Asia, South Asia,\n');
fprintf('     South America, Africa, Australia, Other\n');
fprintf('   - Shows sample sizes for each cell\n');
fprintf('   - Identifies regional performance patterns\n\n');

fprintf('=== Next Steps ===\n');
fprintf('- Review figures in: %s\n', fullfile(cbvResultsDir, 'figs_phase1'));
fprintf('- Modify region definitions in assignRegions.m if needed\n');
fprintf('- Contact developer for Phase 2 plotting (residuals, uncertainty, etc.)\n');
