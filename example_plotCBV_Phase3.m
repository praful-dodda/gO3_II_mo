% example_plotCBV_Phase3.m
% Example script demonstrating Phase 3 comparison tools for CBV results

%% Setup: Define your configuration directories and names
% These should point to directories containing CBV result .mat files
% for different soft data configurations

configDirs = {
    './7validation/CBV_baseline', ...           % No soft data (hard data only)
    './7validation/CBV_M3fusion', ...           % M3fusion only
    './7validation/CBV_OMI_MLS', ...            % M3fusion + OMI-MLS
    './7validation/CBV_OMI_MLS_NJML', ...       % M3fusion + OMI-MLS + NJML
    './7validation/CBV_OMI_MLS_UKML', ...       % M3fusion + OMI-MLS + UKML
    './7validation/CBV_all'                     % All sources: M3fusion + OMI-MLS + IASI-GOME2 + NJML + UKML
};

configNames = {
    'Baseline (no soft)', ...
    'M3fusion only', ...
    'M3fusion + OMI-MLS', ...
    'M3fusion + OMI-MLS + NJML', ...
    'M3fusion + OMI-MLS + UKML', ...
    'All sources'
};

%% Example 1: Basic usage with default settings
fprintf('\n=== Example 1: Basic Usage ===\n');

% Run Phase 3 analysis
% figPaths = plotCBVresults_Phase3(configDirs, configNames);

% This will generate:
% - Configuration comparison plots
% - Temporal trend analysis
% - Soft data contribution analysis
% All saved to default directory './figs_phase3'

%% Example 2: With custom settings
fprintf('\n=== Example 2: Custom Settings ===\n');

% figPaths = plotCBVresults_Phase3(configDirs, configNames, ...
%     'baselineConfig', 1, ...                           % Index of baseline (no soft data)
%     'metrics', {'R2', 'RMSE', 'MAE', 'NMB'}, ...      % Metrics to compare
%     'saveDir', './7validation/figs_comparison', ...    % Custom output directory
%     'dpi', 300, ...                                    % High resolution
%     'visible', 'off', ...                              % Don't show figures (faster)
%     'saveTables', true);                               % Save CSV summary tables

%% Example 3: Minimal configuration comparison
fprintf('\n=== Example 3: Two Configurations ===\n');

% Compare just baseline vs best configuration

configPatterns_minimal = {
    'CBV_BME10000133_go0*.mat', ...
    'CBV_BME10000133_go3*.mat', ...
    'CBV_BME13000313-01_go3*.mat', ...
    'CBV_BME13000313-02_go3*.mat', ...
    'CBV_BME13000313-10_go3*.mat', ...
    'CBV_BME13000313-04_go3*.mat', ...
    'CBV_BME13000313-20_go3*.mat', ...
    'CBV_BME13000313-05_go3*.mat', ...
    'CBV_BME13000313-06_go3*.mat', ...
    'CBV_BME13000313-08_go3*.mat'};


configNames_minimal = {
    'Obs. only (flat GO)', ...
    'Obs. only (fine GO)', ...
    'Obs. + MERRA2-GMI', ...
    'Obs. + M3fusion', ...
    'Obs. + UKML', ...
    'Obs. + OMI-MLS', ...
    'Obs. + NJML', ...
    'Obs. + MERRA2-GMI + OMI-MLS', ...
    'Obs. + M3fusion + OMI-MLS', ...
    'Obs. + IASI-GOME2'
};

configDirs_minimal = {
    './7validation/CBV'
};

% repeat configDirs_minimal for each pattern
configDirs_minimal = repmat(configDirs_minimal, 1, length(configPatterns_minimal));

plot_years = 2017;

figPaths = plotCBVresults_Phase3(configDirs_minimal, configNames_minimal, 'filePattern', configPatterns_minimal, ...
    'baselineConfig', 1, 'metrics', {'R2', 'RMSE'}, 'years', plot_years, 'saveDir', '7validation/CBV/figs_phase3', ...
    'visible', 'on', 'saveTables', false);

%% Example 4: Focus on specific metrics
fprintf('\n=== Example 4: Custom Metrics ===\n');

% Compare only R2 and RMSE
% figPaths = plotCBVresults_Phase3(configDirs, configNames, ...
%     'metrics', {'R2', 'RMSE'}, ...
%     'saveDir', './figs_r2_rmse_only');

%% Example 5: Display figures during generation
fprintf('\n=== Example 5: Interactive Mode ===\n');

% Show figures as they're generated (slower but useful for checking)
% figPaths = plotCBVresults_Phase3(configDirs, configNames, ...
%     'visible', 'on');

%% Expected Outputs

fprintf('\n=== Expected Outputs ===\n\n');

fprintf('FIGURES GENERATED:\n\n');

fprintf('1. Configuration Comparison (plotConfigComparison.m):\n');
fprintf('   - config_comparison_metrics.png\n');
fprintf('     Bar charts showing R2, RMSE, MAE, NMB for each config\n');
fprintf('     Best performer highlighted in green\n\n');

fprintf('   - config_comparison_spider.png\n');
fprintf('     Spider/radar plot showing normalized multi-metric performance\n');
fprintf('     Easy visual comparison across all metrics\n\n');

fprintf('   - config_comparison_regional.png\n');
fprintf('     Heatmap showing R2 performance by region and configuration\n');
fprintf('     Identifies which configs work best in which regions\n\n');

fprintf('2. Temporal Trend Analysis (plotTemporalTrends.m):\n');
fprintf('   - temporal_trends_metrics.png\n');
fprintf('     Line plots showing how each metric changes year-by-year\n');
fprintf('     Identifies stable vs unstable configurations\n\n');

fprintf('   - temporal_consistency.png\n');
fprintf('     Bar chart of coefficient of variation (lower = more stable)\n');
fprintf('     Critical for assessing extrapolation to other time periods\n\n');

fprintf('   - temporal_winners.png\n');
fprintf('     Stacked bars showing which config won each year for each metric\n');
fprintf('     Identifies consistently best performers\n\n');

fprintf('3. Soft Data Contribution (plotSoftDataContribution.m):\n');
fprintf('   - soft_data_incremental.png\n');
fprintf('     Waterfall chart showing incremental improvement from baseline\n');
fprintf('     Green = improvement, Red = degradation\n\n');

fprintf('   - soft_data_cost_benefit.png\n');
fprintf('     Scatter plot: complexity vs benefit\n');
fprintf('     Identifies sweet spot (high benefit, low complexity)\n\n');

fprintf('   - soft_data_vs_complexity.png\n');
fprintf('     Line plots showing diminishing returns as sources are added\n');
fprintf('     Helps decide if additional sources are worth the effort\n\n');

fprintf('CSV TABLES GENERATED:\n\n');

fprintf('   - config_comparison_summary.csv\n');
fprintf('     Overall metrics for each configuration\n\n');

fprintf('   - config_comparison_regional.csv\n');
fprintf('     Regional R2 breakdown by configuration\n\n');

fprintf('   - temporal_trends.csv\n');
fprintf('     Year-by-year statistics for each configuration\n\n');

fprintf('   - soft_data_contribution.csv\n');
fprintf('     Incremental improvements and benefit scores\n\n');

%% Interpreting Results

fprintf('\n=== How to Interpret Results ===\n\n');

fprintf('KEY QUESTIONS TO ANSWER:\n\n');

fprintf('1. Which configuration performs best overall?\n');
fprintf('   → Check config_comparison_metrics.png\n');
fprintf('   → Look for config that wins most metrics\n\n');

fprintf('2. Is the best configuration stable across years?\n');
fprintf('   → Check temporal_trends_metrics.png\n');
fprintf('   → Look for flat/stable trend lines\n');
fprintf('   → Check temporal_consistency.png - lower CV = better\n\n');

fprintf('3. Is adding more soft data worth it?\n');
fprintf('   → Check soft_data_incremental.png\n');
fprintf('   → Check soft_data_cost_benefit.png\n');
fprintf('   → Look for diminishing returns\n\n');

fprintf('4. Does performance vary by region?\n');
fprintf('   → Check config_comparison_regional.png\n');
fprintf('   → May need different configs for different regions\n\n');

fprintf('5. Which soft data sources are most valuable?\n');
fprintf('   → Check soft_data_contribution.csv\n');
fprintf('   → Compare Delta_R2 and Delta_RMSE columns\n');
fprintf('   → Prioritize sources with largest improvements\n\n');

fprintf('DECISION FRAMEWORK:\n\n');

fprintf('For your 1990-2023 dataset:\n');
fprintf('- If best config is stable across 2015-2020:\n');
fprintf('  → More confident it will work for other periods\n');
fprintf('- If best config varies by year:\n');
fprintf('  → May need era-specific strategies\n');
fprintf('- If adding >3 sources gives minimal improvement:\n');
fprintf('  → Simpler config may be better (fewer dependencies)\n');
fprintf('- If one region consistently underperforms:\n');
fprintf('  → May need special handling for that region\n\n');

%% Next Steps After Phase 3

fprintf('\n=== Recommended Next Steps ===\n\n');

fprintf('1. Review all Phase 3 outputs\n');
fprintf('2. Identify top 2-3 candidate configurations\n');
fprintf('3. Check temporal availability of soft data sources\n');
fprintf('   (Use your timeline diagram: M3fusion, OMI-MLS, etc.)\n');
fprintf('4. Define era-specific strategies:\n');
fprintf('   - 1990-2004: Limited data (what''s available?)\n');
fprintf('   - 2005-2019: Optimal fusion period\n');
fprintf('   - 2020-2023: Some sources ended\n');
fprintf('5. Consider ensemble approach if top configs have similar performance\n');
fprintf('6. Prepare to test data degradation scenarios\n');
fprintf('   (Simulate 1990s data sparsity using 2015-2020 data)\n\n');

fprintf('For more information:\n');
fprintf('  help plotCBVresults_Phase3\n');
fprintf('  help plotConfigComparison\n');
fprintf('  help plotTemporalTrends\n');
fprintf('  help plotSoftDataContribution\n\n');
