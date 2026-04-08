%% Example: Monthly CBV Performance Analysis & Cross-Model Comparison
%
% This script demonstrates how to aggregate per-month CBV results and
% compare model performance across calendar months. Prerequisites:
%   - runCBV_toar has been completed for each BME method
%   - Monthly .mat files exist in 7validation/CBV/monthly/
%
% Three figures are produced:
%   1. Seasonal cycle of R², RMSE, NMB, ME (mean ± std across years)
%   2. Chronological time series of RMSE and R² month by month
%   3. Grouped bar comparison of RMSE and NMB per month across models
%      (only when more than one method is supplied)
%
% See also: aggregateCBVmonthlyStats, plotCBVmonthly, runCBV_toar

clear; clc;

fprintf('\n========================================\n');
fprintf('  MONTHLY CBV ANALYSIS & MODEL COMPARISON\n');
fprintf('========================================\n');

%% ============================================================
%% 1. Common base configuration
%% ============================================================
valParam = struct();
valParam.goScenario = 3;          % Global offset scenario
valParam.valYears   = 2005:2019;  % Full TOAR-II period
valParam.valMonths  = 1:12;       % All calendar months
valParam.boxSizes   = [2.0 2.5 3.0 3.5 4.0 4.5 5.0];
valParam.nFolds     = 2;

% Canonical box size for monthly analysis
opts.boxSize = 3.0;   % Change to match the box size used in your CBV run

%% ============================================================
%% 2. Aggregate monthly stats for each method
%%    Edit BMEmethod codes to match your actual runs.
%% ============================================================

% --- Method 1: Hard data only (baseline, no CTM soft data) ---
valParam.BMEmethod = '10000132';
T1 = aggregateCBVmonthlyStats(valParam, opts);

% --- Method 2: Hard + first CTM soft data combination ---
% valParam.BMEmethod = '11000142';
% T2 = aggregateCBVmonthlyStats(valParam, opts);

% --- Method 3: Hard + second CTM combination ---
% valParam.BMEmethod = '11000142-01';   % e.g. MERRA2-GMI
% T3 = aggregateCBVmonthlyStats(valParam, opts);

% --- Add more methods as needed ---

%% ============================================================
%% 3. Quick console summary per method
%% ============================================================
monthAbbr = {'Jan','Feb','Mar','Apr','May','Jun', ...
             'Jul','Aug','Sep','Oct','Nov','Dec'};

for T = {T1}   % add T2, T3, ... here when ready
    t = T{1};
    if isempty(t), continue; end
    method = t.Properties.UserData.BMEmethod;
    fprintf('\nMethod BME%s  (box=%.1f, n_rows=%d):\n', ...
        method, t.Properties.UserData.boxSize, height(t));
    fprintf('  %-4s  %6s  %6s  %7s\n', 'Mon', 'R²', 'RMSE', 'NMB(%)');
    for m = 1:12
        idx = t.Month == m;
        if ~any(idx), continue; end
        fprintf('  %-4s  %6.3f  %6.2f  %+7.2f\n', ...
            monthAbbr{m}, ...
            mean(t.R2(idx),   'omitnan'), ...
            mean(t.RMSE(idx), 'omitnan'), ...
            mean(t.NMB(idx),  'omitnan'));
    end
end

%% ============================================================
%% 4. Single-method plots (seasonal cycle + time series)
%% ============================================================
fprintf('\nGenerating single-method plots...\n');
plotCBVmonthly(T1, valParam);

%% ============================================================
%% 5. Multi-model comparison
%%    Uncomment when T2, T3, etc. are ready
%% ============================================================
% fprintf('\nGenerating multi-model comparison plots...\n');
% plotCBVmonthly(T1, valParam, T2);          % two methods
% plotCBVmonthly(T1, valParam, T2, T3);      % three methods

fprintf('\n========================================\n');
fprintf('  DONE — figures saved in 7validation/CBV/figures/\n');
fprintf('========================================\n\n');
