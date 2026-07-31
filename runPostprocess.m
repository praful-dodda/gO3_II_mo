function runPostprocess(cfg)
% runPostprocess - Driver for the 1990-2022 ozone post-processing (analyses A-F)
%
% Wires together the post-processing pipeline described in POSTPROCESSING_PLAN.txt
% with the user's chosen options:
%   D1  annual mean AND OSDMA8 (warm-season running-mean max)
%   D2  per-year BEST method for the trend/seasonal/peak/exposure figures
%   D3  WHO ozone targets (60/70/100 ug/m3) for exposure
%   D4  NetCDF + PNG for gridded fields
%   D5  all three region sets (area-code, GBD, WHO)
%
% USAGE:
%   runPostprocess               % uses the defaults below
%   runPostprocess(cfg)          % override any default field via struct cfg
%
% Edit the DEFAULTS block, or pass a cfg struct with the same field names.
%
% Pipeline:
%   A  bestMethodByYear         -> csv/best_method_by_year.csv
%   .  assembleBMEcube (each best method) + composeBestMethodCube (D2)
%   .  computeGridWeights       -> cubes/grid_weights.mat
%   C/D annualSeasonalSeries    -> csv/*series*, csv/regional_trends.csv
%   B  trendMaps                -> maps/trend_sen_*.nc/.png
%   E  peakMonthAnalysis        -> maps/peak_month_*.nc/.png, csv/peak_month_trend.csv
%   F  exposureMetrics          -> csv/exposure_*.csv
%   F  regionalCountrySummary   -> csv/country_trends.csv
%
% SEE ALSO: assembleBMEcube, composeBestMethodCube, annualSeasonalSeries,
%           trendMaps, peakMonthAnalysis, exposureMetrics, regionalCountrySummary

%% ===================== DEFAULTS (edit or override via cfg) ===============
d = struct();
d.methodConfig = struct('goScenario', 3, 'logTransf', 0, 'areaCode', 0, ...
    'mapResolution', 1.0, 'dataFormat', 'stug', 'keepOnlyLand', 1);
d.yearRange       = [1990 2004];
d.fallbackMethod  = '13000313-02';      % used for years without a best entry
d.bestMethodCsv   = '';                 % user year->method CSV; overrides auto step A
d.srcDir          = '5BMEspatialPlots';
d.cbvDir          = fullfile('7validation', 'CBV');
d.popCsv          = fullfile('Population-Data', 'PopulationData2019.csv');
d.outDir          = '8postprocess';
d.whoThresholdsUgm3 = [60 70 100];
d.ugPerPpb        = 2.0;
d.earlyDecade     = [1990 1999];
d.lateDecade      = [2013 2022];
d.writeNetCDF     = true;
d.writePNG        = true;
d.breakpoints     = [];        % two-period trend split year(s); [] = midpoint
d.run = struct('A', true, 'CD', true, 'TS', true, 'B', true, 'E', true, ...
    'F', true, 'report', true);

if nargin < 1 || isempty(cfg), cfg = struct(); end
cfg = local_merge(d, cfg);

csvDir = fullfile(cfg.outDir, 'csv');
mapDir = fullfile(cfg.outDir, 'maps');
cubeDir = fullfile(cfg.outDir, 'cubes');
local_ensureDir(cfg.outDir); local_ensureDir(csvDir);
local_ensureDir(mapDir); local_ensureDir(cubeDir);

fprintf('\n=== TOAR-II ozone post-processing (%d-%d) ===\n', ...
    cfg.yearRange(1), cfg.yearRange(2));

%% ---- Analysis A: best method per year ----------------------------------
bestT = table();
if ~isempty(cfg.bestMethodCsv)
    fprintf('\n[A] Year->method from CSV: %s\n', cfg.bestMethodCsv);
    bestT = loadBestMethodCsv(cfg.bestMethodCsv, cfg.yearRange);
    cfg.run.A = false;                  % custom table wins over auto step A
elseif cfg.run.A
    fprintf('\n[A] Best method per year...\n');
    bestT = bestMethodByYear(struct('cbvDir', cfg.cbvDir, 'outDir', csvDir, ...
        'save', true, 'verbose', true));
end
% provenance: persist whichever table drove the run
if height(bestT) > 0
    writetable(bestT, fullfile(csvDir, 'best_method_by_year.csv'));
end

%% ---- Load the per-method cubes needed, then compose D2 cube -------------
fprintf('\n[.] Assembling per-year best-method cube...\n');
cube = loadCompositeCube(cfg, bestT);

%% ---- Grid weights (shared) ---------------------------------------------
fprintf('\n[.] Grid weights (area / population / regions)...\n');
weights = computeGridWeights(cube, struct('popCsv', cfg.popCsv, ...
    'outDir', cubeDir, 'save', true, 'verbose', true));

%% ---- Analyses C/D: regional series + trends ----------------------------
if cfg.run.CD
    fprintf('\n[C/D] Annual + seasonal regional series and trends...\n');
    annualSeasonalSeries(cube, weights, struct('outDir', csvDir, ...
        'save', true, 'verbose', true));
end

%% ---- Trend statistics: OLS + AR(1) and two-period (DeLang/Becker) -------
if cfg.run.TS
    fprintf('\n[TS] OLS + AR(1) and two-period regional trends...\n');
    trendAnalysisDeLang(cube, struct('outDir', cfg.outDir, ...
        'breakpoints', cfg.breakpoints, 'writeNetCDF', cfg.writeNetCDF, ...
        'writePNG', cfg.writePNG, 'verbose', true));
end

%% ---- Analysis B: per-cell trend maps -----------------------------------
if cfg.run.B
    fprintf('\n[B] Per-cell trend maps...\n');
    trendMaps(cube, struct('outDir', mapDir, 'earlyDecade', cfg.earlyDecade, ...
        'lateDecade', cfg.lateDecade, 'writeNetCDF', cfg.writeNetCDF, ...
        'writePNG', cfg.writePNG, 'verbose', true));
end

%% ---- Analysis E: peak-month shift --------------------------------------
if cfg.run.E
    fprintf('\n[E] Peak-month shift...\n');
    peakMonthAnalysis(cube, struct('weights', weights, 'outDir', cfg.outDir, ...
        'writeNetCDF', cfg.writeNetCDF, 'writePNG', cfg.writePNG, 'verbose', true));
end

%% ---- Analysis F: exposure + country roll-up ----------------------------
if cfg.run.F
    fprintf('\n[F] WHO exposure + country roll-up...\n');
    exposureMetrics(cube, weights, struct('thresholdsUgm3', cfg.whoThresholdsUgm3, ...
        'ugPerPpb', cfg.ugPerPpb, 'outDir', csvDir, 'save', true, 'verbose', true));
    regionalCountrySummary(cube, weights, struct('outDir', csvDir, ...
        'save', true, 'verbose', true));
end

%% ---- README / manifest -------------------------------------------------
local_writeReadme(cfg);

%% ---- Paper report (figures + HTML) -------------------------------------
if cfg.run.report
    fprintf('\n[R] Building paper figures + HTML report...\n');
    try
        makePaperReport(cube, weights, struct('outDir', cfg.outDir, ...
            'method', 'best-per-year', 'yearRange', cfg.yearRange, ...
            'whoThresholdsUgm3', cfg.whoThresholdsUgm3, 'ugPerPpb', cfg.ugPerPpb));
    catch ME
        warning('runPostprocess:report', 'Report generation failed: %s', ME.message);
    end
end

fprintf('\n=== Post-processing complete. Outputs in %s/ ===\n', cfg.outDir);

end

% ========================================================================
function s = local_merge(d, c)
% Shallow merge of struct c onto defaults d (one level; methodConfig/run too).
s = d;
f = fieldnames(c);
for i = 1:numel(f)
    if isstruct(c.(f{i})) && isfield(d, f{i}) && isstruct(d.(f{i}))
        sub = d.(f{i});
        g = fieldnames(c.(f{i}));
        for j = 1:numel(g), sub.(g{j}) = c.(f{i}).(g{j}); end
        s.(f{i}) = sub;
    else
        s.(f{i}) = c.(f{i});
    end
end
end

% ========================================================================
function local_ensureDir(p)
if ~exist(p, 'dir'), mkdir(p); end
end

% ========================================================================
function local_writeReadme(cfg)
p = fullfile(cfg.outDir, 'README.txt');
fid = fopen(p, 'w');
if fid < 0, return; end
c = onCleanup(@() fclose(fid));
fprintf(fid, 'TOAR-II BME ozone post-processing outputs (%d-%d)\n', ...
    cfg.yearRange(1), cfg.yearRange(2));
fprintf(fid, 'Generated by runPostprocess.m on %s\n\n', datestr(now)); %#ok<TNOW1,DATST>
fprintf(fid, 'Trend method: Theil-Sen slope + Mann-Kendall p-value (trendSenMK.m).\n');
fprintf(fid, 'Metrics: AnnualMean and OSDMA8 (6-month running-mean peak; computeOSDMA8.m).\n');
fprintf(fid, 'Figures use the per-year BEST method (composeBestMethodCube.m).\n');
fprintf(fid, 'Population weighting: static %s.\n\n', cfg.popCsv);
fprintf(fid, 'cubes/  consolidated per-method data cubes + grid_weights.mat\n');
fprintf(fid, 'csv/    tidy summary tables:\n');
fprintf(fid, '   best_method_by_year.csv      Year, BestMethod, R2, RMSE, runner-up, margin\n');
fprintf(fid, '   method_year_skill.csv        median CBV skill per method/year\n');
fprintf(fid, '   regional_series.csv          per-year area/pop-weighted series (all metrics/regions)\n');
fprintf(fid, '   regional_trends.csv          Sen slope (per decade) + p for every series\n');
fprintf(fid, '   annual_means_global_regional.csv  annual+OSDMA8 subset of regional_series\n');
fprintf(fid, '   seasonal_means_trends.csv    DJF/MAM/JJA/SON + amplitude subset\n');
fprintf(fid, '   popweighted_annual.csv       population-weighted annual subset\n');
fprintf(fid, '   exposure_by_threshold.csv    WHO-target population/area exposure per year\n');
fprintf(fid, '   exposure_trends.csv          trend in %% population exposed\n');
fprintf(fid, '   peak_month_trend.csv         regional mean peak month + shift (days/decade)\n');
fprintf(fid, '   country_trends.csv           per-country recent levels + trends\n');
fprintf(fid, 'maps/   gridded fields (point NetCDF + PNG):\n');
fprintf(fid, '   trend_sen_<metric>_<method>_<period>.nc/.png   per-cell Sen slope + signif\n');
fprintf(fid, '   peak_month_<period>.nc , peak_month_shift_<period>.png\n\n');
fprintf(fid, 'Units: ozone ppb; slopes ppb/decade; peak shift days/decade; exposure persons / %%.\n');
fprintf(fid, 'WHO thresholds applied to OSDMA8: %s ug/m3 (= %s ppb at %.2f ug/m3 per ppb).\n', ...
    mat2str(cfg.whoThresholdsUgm3), mat2str(cfg.whoThresholdsUgm3/cfg.ugPerPpb), cfg.ugPerPpb);
end
