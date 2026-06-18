function reportPath = makePaperReport(cube, weights, opts)
% makePaperReport - Paper-ready figures + a detailed HTML results report
%
% Produces a folder of publication figures (8postprocess/figs/*.png) and a
% single HTML report (8postprocess/paper_report.html) that embeds the figures,
% full result tables, and auto-generated findings text with the actual numbers -
% intended as a menu of results to select from for a manuscript.
%
% SYNTAX:
%   reportPath = makePaperReport(cube, weights)
%   reportPath = makePaperReport(cube, weights, opts)
%   makePaperReport()                       % rebuilds cube/weights from cache
%
% INPUTS:
%   cube    - composite cube (assembleBMEcube/composeBestMethodCube). If omitted,
%             it is rebuilt via loadCompositeCube + grid_weights.mat cache.
%   weights - computeGridWeights struct.
%   opts    - (optional): .outDir ('8postprocess'), .method, .yearRange,
%             .whoThresholdsUgm3 ([60 70 100]), .ugPerPpb (2.0), .dpi (150)
%
% OUTPUT: reportPath - full path to the written HTML file.
%
% SEE ALSO: runPostprocess, cubeAnnualMetrics, trendMaps, peakMonthAnalysis

if nargin < 3 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

% Standalone: rebuild cube + weights from caches
if nargin < 1 || isempty(cube)
    cfg = local_cfgForLoad(opts);
    bestT = local_readtable(fullfile(opts.outDir,'csv','best_method_by_year.csv'));
    cube = loadCompositeCube(cfg, bestT);
end
if nargin < 2 || isempty(weights)
    gw = fullfile(opts.outDir, 'cubes', 'grid_weights.mat');
    if exist(gw, 'file'), S = load(gw, 'weights'); weights = S.weights; else
        weights = computeGridWeights(cube, struct('outDir', fullfile(opts.outDir,'cubes'), 'save', false));
    end
end

figDir = fullfile(opts.outDir, 'figs');
csvDir = fullfile(opts.outDir, 'csv');
if ~exist(figDir, 'dir'), mkdir(figDir); end

M = cubeAnnualMetrics(cube);
years = M.years(:);
y0 = years(1); y1 = years(end);

% adaptive early/late thirds for the difference map (record may be < 2 decades)
third = max(1, round((y1 - y0 + 1) / 3));
early = [y0, y0 + third - 1];
late  = [y1 - third + 1, y1];

% per-cell maps (reuse tested analysis fns; no file IO)
Rtr = trendMaps(cube, struct('earlyDecade', early, 'lateDecade', late, ...
    'writeNetCDF', false, 'writePNG', false, 'verbose', false));
Rpk = peakMonthAnalysis(cube, struct('writeNetCDF', false, 'writePNG', false, ...
    'verbose', false));

% region masks for series figures
regs = local_regionMasks(weights);

%% ===================== FIGURES ==========================================
F = struct('file', {}, 'title', {}, 'caption', {}, 'section', {});

F(end+1) = local_figGlobalSeries(M, weights, years, figDir, opts);
F(end+1) = local_figAreaVsPop(M, weights, years, figDir, opts);
F(end+1) = local_figRegionalSeries(M, weights, regs, years, figDir, opts);
F(end+1) = local_figSeasonalSeries(M, weights, years, figDir, opts);
F(end+1) = local_figSeasonalBars(M, weights, regs, years, figDir, opts);
F(end+1) = local_figTrendMap(Rtr.AnnualMean, 'Annual-mean MDA8', figDir, 'trend_annual', opts);
F(end+1) = local_figTrendMap(Rtr.OSDMA8, 'OSDMA8 (peak season)', figDir, 'trend_osdma8', opts);
F(end+1) = local_figDiffMap(Rtr.AnnualMean, early, late, figDir, opts);
F(end+1) = local_figPeakMeanMap(Rpk, figDir, opts);
F(end+1) = local_figPeakShiftMap(Rpk, figDir, opts);
F(end+1) = local_figExposure(M, weights, years, figDir, opts);
F(end+1) = local_figCountryTop(csvDir, figDir, opts);
F(end+1) = local_figBestMethod(csvDir, years, figDir, opts);
F(end+1) = local_figHovmoller(M, weights, years, figDir, opts);
% DeLang/Becker-style trend statistics
F(end+1) = local_figWorldSeries(M, weights, years, figDir, opts);
F(end+1) = local_figSenVsOLS(csvDir, figDir, opts);
F(end+1) = local_figTwoPeriod(csvDir, figDir, opts);
F(end+1) = local_figOLSmap(fullfile(opts.outDir,'maps'), figDir, opts);
F = F(~cellfun(@isempty, {F.file}));

%% ===================== FINDINGS (numbers) ===============================
fnd = local_computeFindings(M, weights, regs, years, Rtr, Rpk, opts);

%% ===================== HTML =============================================
reportPath = fullfile(opts.outDir, 'paper_report.html');
local_writeHTML(reportPath, F, fnd, csvDir, opts, cube, years);
fprintf('  Report written: %s  (%d figures in %s)\n', reportPath, numel(F), figDir);

end

% ========================================================================
% Figure builders
% ========================================================================
function s = local_figGlobalSeries(M, w, years, figDir, opts)
am = local_wser(M.annualMean, w.w_area);
os = local_wser(M.osdma8,     w.w_area);
f = local_fig();
plot(years, am, '-o', 'LineWidth', 1.6, 'Color', [0 0.45 0.74]); hold on;
plot(years, os, '-s', 'LineWidth', 1.6, 'Color', [0.85 0.33 0.10]);
local_trendline(years, am, [0 0.45 0.74]);
local_trendline(years, os, [0.85 0.33 0.10]);
grid on; xlabel('Year'); ylabel('Ozone (ppb)');
legend({'Annual mean','OSDMA8 (peak season)','',''}, 'Location','best');
title('Global land-area-weighted ozone, 1990-2004');
s = local_save(f, figDir, 'global_series', opts, 'Global mean ozone (area-weighted)', ...
    ['Global, land-area-weighted annual-mean MDA8 and OSDMA8 with Theil-Sen ' ...
     'trend lines.'], 'Trends');
end

function s = local_figAreaVsPop(M, w, years, figDir, opts)
a = local_wser(M.annualMean, w.w_area);
p = local_wser(M.annualMean, w.w_pop);
f = local_fig();
plot(years, a, '-o', 'LineWidth', 1.6); hold on;
plot(years, p, '-s', 'LineWidth', 1.6);
grid on; xlabel('Year'); ylabel('Annual-mean MDA8 (ppb)');
legend({'Area-weighted','Population-weighted'}, 'Location','best');
title('Area- vs population-weighted global ozone');
s = local_save(f, figDir, 'area_vs_pop', opts, 'Area- vs population-weighted', ...
    ['The population-weighted curve reflects what people experience; a gap above ' ...
     'the area-weighted curve means population concentrates in higher-ozone regions.'], 'Trends');
end

function s = local_figRegionalSeries(M, w, regs, years, figDir, opts)
f = local_fig(); hold on;
co = lines(numel(regs));
for r = 1:numel(regs)
    ser = local_wserMask(M.annualMean, w.w_pop, regs(r).mask);
    plot(years, ser, '-o', 'LineWidth', 1.4, 'Color', co(r,:));
end
grid on; xlabel('Year'); ylabel('Pop-weighted annual MDA8 (ppb)');
legend({regs.name}, 'Location','best');
title('Regional population-weighted annual ozone');
s = local_save(f, figDir, 'regional_series', opts, 'Regional population-weighted series', ...
    'Population-weighted annual-mean MDA8 for each region.', 'Regional');
end

function s = local_figSeasonalSeries(M, w, years, figDir, opts)
seas = {'DJF','MAM','JJA','SON'};
f = local_fig(); hold on; co = lines(4);
for i = 1:4
    plot(years, local_wser(M.(seas{i}), w.w_area), '-o', 'LineWidth', 1.4, 'Color', co(i,:));
end
grid on; xlabel('Year'); ylabel('Seasonal-mean MDA8 (ppb)');
legend(seas, 'Location','best');
title('Global seasonal-mean ozone');
s = local_save(f, figDir, 'seasonal_series', opts, 'Seasonal series (global)', ...
    'Global area-weighted seasonal-mean MDA8 (calendar seasons).', 'Seasonality');
end

function s = local_figSeasonalBars(M, w, regs, years, figDir, opts)
seas = {'DJF','MAM','JJA','SON'};
slopes = nan(numel(regs), 4);
for r = 1:numel(regs)
    for i = 1:4
        ser = local_wserMask(M.(seas{i}), w.w_area, regs(r).mask);
        tr = trendSenMK(years, ser(:));
        slopes(r,i) = tr.slope * 10;
    end
end
f = local_fig();
bar(slopes); grid on;
set(gca, 'XTickLabel', {regs.name});
ylabel('Trend (ppb / decade)'); legend(seas, 'Location','best');
title('Seasonal ozone trends by region');
s = local_save(f, figDir, 'seasonal_bars', opts, 'Seasonal trends by region', ...
    'Theil-Sen seasonal trends (ppb/decade), area-weighted, per region.', 'Seasonality');
end

function s = local_figTrendMap(res, label, figDir, name, opts)
f = local_fig();
scatter(res.lon, res.lat, 6, res.slopePerDecade, 'filled'); hold on;
sig = res.signif; plot(res.lon(sig), res.lat(sig), 'k.', 'MarkerSize', 1);
colormap(gca, local_div()); cb = colorbar; cb.Label.String = 'ppb / decade';
cmax = local_robustMax(res.slopePerDecade); if cmax>0, clim([-cmax cmax]); end
axis equal; xlim([-180 180]); ylim([-60 85]);
xlabel('Longitude'); ylabel('Latitude');
title([label ' trend (dots: p<0.05)']);
s = local_save(f, figDir, name, opts, [label ' per-cell trend'], ...
    ['Per-cell Theil-Sen slope of ' label '; black dots mark Mann-Kendall p<0.05.'], 'Trends');
end

function s = local_figDiffMap(res, early, late, figDir, opts)
f = local_fig();
scatter(res.lon, res.lat, 6, res.decadalDiff, 'filled');
colormap(gca, local_div()); cb = colorbar; cb.Label.String = 'ppb';
cmax = local_robustMax(res.decadalDiff); if cmax>0, clim([-cmax cmax]); end
axis equal; xlim([-180 180]); ylim([-60 85]);
xlabel('Longitude'); ylabel('Latitude');
title(sprintf('Annual-mean change: %d-%d minus %d-%d', late(1),late(2),early(1),early(2)));
s = local_save(f, figDir, 'diff_map', opts, 'Period-difference map', ...
    sprintf('Mean annual MDA8 over %d-%d minus %d-%d.', late(1),late(2),early(1),early(2)), 'Trends');
end

function s = local_figPeakMeanMap(R, figDir, opts)
f = local_fig();
scatter(R.lon, R.lat, 6, R.meanPeakMonth, 'filled');
colormap(gca, hsv(12)); cb = colorbar; cb.Label.String = 'peak month';
clim([1 12]); axis equal; xlim([-180 180]); ylim([-60 85]);
xlabel('Longitude'); ylabel('Latitude'); title('Mean month of peak ozone');
s = local_save(f, figDir, 'peak_mean_map', opts, 'Mean peak month', ...
    'Circular-mean calendar month of the annual ozone maximum (1=Jan ... 12=Dec).', 'PeakMonth');
end

function s = local_figPeakShiftMap(R, figDir, opts)
f = local_fig();
scatter(R.lon, R.lat, 6, R.shiftDaysPerDecade, 'filled');
colormap(gca, local_div()); cb = colorbar; cb.Label.String = 'days / decade';
cmax = local_robustMax(R.shiftDaysPerDecade); if cmax>0, clim([-cmax cmax]); end
axis equal; xlim([-180 180]); ylim([-60 85]);
xlabel('Longitude'); ylabel('Latitude'); title('Shift in peak ozone month (+ = later)');
s = local_save(f, figDir, 'peak_shift_map', opts, 'Peak-month shift', ...
    'Drift of the peak ozone month (days/decade); positive = later in the year.', 'PeakMonth');
end

function s = local_figExposure(M, w, years, figDir, opts)
thr = opts.whoThresholdsUgm3 / opts.ugPerPpb;
tot = sum(w.w_pop);
f = local_fig(); hold on; co = lines(numel(thr));
leg = cell(1, numel(thr));
for ti = 1:numel(thr)
    pct = nan(numel(years),1);
    for yi = 1:numel(years)
        pct(yi) = 100 * sum(w.w_pop(M.osdma8(:,yi) > thr(ti))) / tot;
    end
    plot(years, pct, '-o', 'LineWidth', 1.5, 'Color', co(ti,:));
    leg{ti} = sprintf('%d ug/m^3 (%.0f ppb)', opts.whoThresholdsUgm3(ti), thr(ti));
end
grid on; xlabel('Year'); ylabel('% population above threshold');
legend(leg, 'Location','best'); title('Population exposed above WHO ozone targets (OSDMA8)');
s = local_save(f, figDir, 'exposure', opts, 'Population exposure to WHO targets', ...
    'Share of population whose peak-season ozone (OSDMA8) exceeds each WHO target.', 'Exposure');
end

function s = local_figCountryTop(csvDir, figDir, opts)
T = local_readtable(fullfile(csvDir, 'country_trends.csv'));
if isempty(T) || ~ismember('SlopeAnnual_ppb_per_decade', T.Properties.VariableNames)
    s = local_emptyFig(); return;
end
T = sortrows(T, 'SlopeAnnual_ppb_per_decade', 'descend');
n = min(20, height(T));
top = T(1:n, :);
f = local_fig();
barh(flipud(top.SlopeAnnual_ppb_per_decade)); grid on;
set(gca, 'YTick', 1:n, 'YTickLabel', flipud(string(top.CountryName)));
xlabel('Annual-mean trend (ppb / decade)');
title(sprintf('Top %d countries by ozone trend', n));
s = local_save(f, figDir, 'country_top', opts, 'Top countries by trend', ...
    'Population-weighted annual-mean MDA8 trend (ppb/decade) for the steepest-rising countries.', 'Regional');
end

function s = local_figBestMethod(csvDir, years, figDir, opts)
T = local_readtable(fullfile(csvDir, 'best_method_by_year.csv'));
if isempty(T), s = local_emptyFig(); return; end
T = T(ismember(T.Year, years), :);
if isempty(T), s = local_emptyFig(); return; end
[um, ~, ic] = unique(string(T.BestMethod), 'stable');
f = local_fig();
scatter(T.Year, ic, 60, 'filled'); grid on;
set(gca, 'YTick', 1:numel(um), 'YTickLabel', um); ylim([0.5 numel(um)+0.5]);
xlabel('Year'); ylabel('Best CBV method'); title('Best-validating method by year (CBV R^2)');
s = local_save(f, figDir, 'best_method', opts, 'Best method by year', ...
    ['Method with the highest CBV R-squared each year (RMSE tie-break). For 1990-2004 only ' ...
     '13000313-02 has spatial estimates, so the composite used it as the fallback.'], 'Methods');
end

function s = local_figHovmoller(M, w, years, figDir, opts)
edges = -60:10:80; centers = edges(1:end-1) + 5;
Z = nan(numel(centers), numel(years));
for b = 1:numel(centers)
    mask = w.lat >= edges(b) & w.lat < edges(b+1);
    if any(mask)
        Z(b, :) = local_wserMask(M.annualMean, w.w_area, mask);
    end
end
f = local_fig();
imagesc(years, centers, Z); set(gca, 'YDir', 'normal');
colormap(gca, parula); cb = colorbar; cb.Label.String = 'MDA8 (ppb)';
xlabel('Year'); ylabel('Latitude'); title('Zonal-mean annual ozone (latitude x time)');
s = local_save(f, figDir, 'hovmoller', opts, 'Latitude-time Hovmoller', ...
    'Area-weighted zonal-mean annual MDA8 in 10-degree latitude bands over time.', 'Regional');
end

% ---- DeLang/Becker-style trend-statistics figures ----------------------
function s = local_figWorldSeries(M, w, years, figDir, opts)
if ~isfield(w, 'worldRegion'), s = local_emptyFig(); return; end
names = w.worldNames;
co = lines(numel(names));
f = local_fig(); hold on;
h = gobjects(0); leg = {};
for r = 1:numel(names)
    mask = w.worldRegion == names{r};
    if ~any(mask), continue; end
    ser = local_wserMask(M.osdma8, w.w_pop, mask);
    hp = plot(years, ser, '-o', 'LineWidth', 1.4, 'Color', co(r,:), 'MarkerSize', 4);
    h(end+1) = hp; leg{end+1} = names{r}; %#ok<AGROW>
end
gl = local_wser(M.osdma8, w.w_pop);
hg = plot(years, gl, 'k--', 'LineWidth', 2);
h(end+1) = hg; leg{end+1} = 'Global';
grid on; xlabel('Year'); ylabel('Pop-weighted OSDMA8 (ppb)');
legend(h, leg, 'Location','eastoutside');
title('World-region population-weighted peak-season ozone (OSDMA8)');
s = local_save(f, figDir, 'world_series', opts, 'World-region OSDMA8 series', ...
    ['Population-weighted OSDMA8 by DeLang-style world region (colours); Global shown as ' ...
     'the black dashed line.'], 'TrendStats');
end

function s = local_figSenVsOLS(csvDir, figDir, opts)
O = local_readtable(fullfile(csvDir, 'trend_ols_regional.csv'));
Sen = local_readtable(fullfile(csvDir, 'regional_trends.csv'));
if isempty(O) || isempty(Sen), s = local_emptyFig(); return; end
sel = @(T) T(T.RegionSet=="world" & T.Metric=="OSDMA8" & T.Weighting=="pop", :);
Os = sel(O); Ss = sel(Sen);
if isempty(Os), s = local_emptyFig(); return; end
[regs, io] = unique(string(Os.Region), 'stable');
olsSlope = Os.SlopePerDecade(io); olsSE = Os.SE(io); olsP = Os.pValue(io);
senSlope = nan(size(regs));
for i = 1:numel(regs)
    m = string(Ss.Region)==regs(i);
    if any(m), senSlope(i) = Ss.SlopePerDecade(find(m,1)); end
end
f = local_fig();
hb = bar([senSlope olsSlope]); grid on; hold on;
% error bars + significance stars on the OLS bars
xo = hb(2).XEndPoints;
errorbar(xo, olsSlope, olsSE, 'k', 'linestyle','none', 'CapSize', 4);
for i = 1:numel(regs)
    if olsP(i) < 0.05
        text(xo(i), olsSlope(i)+olsSE(i), '*', 'HorizontalAlignment','center', ...
            'FontSize', 14, 'FontWeight','bold');
    end
end
set(gca, 'XTick', 1:numel(regs), 'XTickLabel', regs, 'XTickLabelRotation', 30);
ylabel('Trend (ppb / decade)'); legend({'Theil-Sen','OLS (AR(1) se)'}, 'Location','best');
title('Regional OSDMA8 trends: Theil-Sen vs OLS (* = AR(1) p<0.05)');
s = local_save(f, figDir, 'sen_vs_ols', opts, 'Theil-Sen vs OLS regional trends', ...
    ['Pop-weighted OSDMA8 trend per world region by both methods; error bars are the ' ...
     'Weatherhead AR(1)-adjusted OLS standard error; * marks AR(1)-adjusted p<0.05.'], 'TrendStats');
end

function s = local_figTwoPeriod(csvDir, figDir, opts)
T = local_readtable(fullfile(csvDir, 'trend_twoperiod_regional.csv'));
if isempty(T), s = local_emptyFig(); return; end
Ts = T(T.RegionSet=="world" & T.Metric=="OSDMA8" & T.Weighting=="pop", :);
if isempty(Ts), s = local_emptyFig(); return; end
[regs, io] = unique(string(Ts.Region), 'stable');
p1 = Ts.P1Slope(io); p2 = Ts.P2Slope(io);
f = local_fig();
bar([p1 p2]); grid on;
set(gca, 'XTick', 1:numel(regs), 'XTickLabel', regs, 'XTickLabelRotation', 30);
ylabel('Trend (ppb / decade)');
legend({char("Early ("+Ts.P1(1)+")"), char("Late ("+Ts.P2(1)+")")}, 'Location','best');
title('Two-period OSDMA8 trends by world region');
s = local_save(f, figDir, 'two_period', opts, 'Two-period regional trends', ...
    'Pop-weighted OSDMA8 OLS trend in the early vs late sub-period per world region.', 'TrendStats');
end

function s = local_figOLSmap(mapDir, figDir, opts)
d = dir(fullfile(mapDir, 'trend_ols_OSDMA8_*.nc'));
if isempty(d), s = local_emptyFig(); return; end
nc = fullfile(d(1).folder, d(1).name);
try
    lon = ncread(nc,'lon'); lat = ncread(nc,'lat');
    slope = ncread(nc,'ols_slope_ppb_per_decade'); pv = ncread(nc,'pvalue_ar1');
catch
    s = local_emptyFig(); return;
end
f = local_fig();
scatter(lon, lat, 6, slope, 'filled'); hold on;
sig = pv < 0.05; plot(lon(sig), lat(sig), 'k.', 'MarkerSize', 1);
colormap(gca, local_div()); cb = colorbar; cb.Label.String = 'ppb / decade';
cmax = local_robustMax(slope); if cmax>0, clim([-cmax cmax]); end
axis equal; xlim([-180 180]); ylim([-60 85]);
xlabel('Longitude'); ylabel('Latitude');
title('OSDMA8 per-cell OLS trend (dots: AR(1) p<0.05)');
s = local_save(f, figDir, 'ols_trend_map', opts, 'Per-cell OLS trend (OSDMA8)', ...
    'Per-cell OLS slope of OSDMA8; black dots mark Weatherhead AR(1)-adjusted p<0.05.', 'TrendStats');
end

% ========================================================================
% Findings
% ========================================================================
function fnd = local_computeFindings(M, w, regs, years, Rtr, Rpk, opts)
fnd = struct();
fnd.nCells = numel(w.lat); fnd.nMonths = size(M.annualMean,2)*12;
fnd.y0 = years(1); fnd.y1 = years(end); fnd.nYears = numel(years);
fnd.popTotal = sum(w.w_pop);

gA = trendSenMK(years, local_wser(M.annualMean, w.w_area)');
gP = trendSenMK(years, local_wser(M.annualMean, w.w_pop)');
oA = trendSenMK(years, local_wser(M.osdma8,    w.w_area)');
oP = trendSenMK(years, local_wser(M.osdma8,    w.w_pop)');
fnd.glAnnualArea = gA.slope*10; fnd.glAnnualArea_p = gA.pValue;
fnd.glAnnualPop  = gP.slope*10; fnd.glAnnualPop_p  = gP.pValue;
fnd.glOsdmaArea  = oA.slope*10; fnd.glOsdmaPop = oP.slope*10;

% Sen-fitted endpoints (consistent with the slope, unlike raw first/last years)
fnd.glStart = gA.intercept + gA.slope*years(1);
fnd.glEnd   = gA.intercept + gA.slope*years(end);

% per-region pop-weighted annual trend
fnd.regNames = {regs.name};
fnd.regTrend = nan(1, numel(regs));
for r = 1:numel(regs)
    tr = trendSenMK(years, local_wserMask(M.annualMean, w.w_pop, regs(r).mask)');
    fnd.regTrend(r) = tr.slope*10;
end

% map summaries
fnd.cellsRising = 100*mean(Rtr.AnnualMean.slopePerDecade > 0, 'omitnan');
fnd.cellsSig    = 100*mean(Rtr.AnnualMean.signif, 'omitnan');
fnd.medSlope    = median(Rtr.AnnualMean.slopePerDecade, 'omitnan');
fnd.peakSig     = 100*mean(Rpk.pValue < 0.05, 'omitnan');
fnd.peakMedShift= median(Rpk.shiftDaysPerDecade, 'omitnan');

% exposure endpoints
thr = opts.whoThresholdsUgm3 / opts.ugPerPpb; tot = sum(w.w_pop);
fnd.expThr = opts.whoThresholdsUgm3;
fnd.expStart = nan(1,numel(thr)); fnd.expEnd = nan(1,numel(thr));
for ti = 1:numel(thr)
    fnd.expStart(ti) = 100*sum(w.w_pop(M.osdma8(:,1)   > thr(ti)))/tot;
    fnd.expEnd(ti)   = 100*sum(w.w_pop(M.osdma8(:,end) > thr(ti)))/tot;
end

% OLS + AR(1) global OSDMA8 trend (Weatherhead 1998; DeLang/Becker-style)
oa = trendOLSweatherhead(years, local_wser(M.osdma8, w.w_area)');
op = trendOLSweatherhead(years, local_wser(M.osdma8, w.w_pop)');
fnd.olsArea = oa.slopePerDecade; fnd.olsArea_p = oa.pValue;
fnd.olsArea_phi = oa.phi; fnd.olsArea_nStar = oa.nStar;
fnd.olsPop = op.slopePerDecade; fnd.olsPop_p = op.pValue;
end

% ========================================================================
% HTML writer
% ========================================================================
function local_writeHTML(path, F, fnd, csvDir, opts, cube, years)
fid = fopen(path, 'w'); if fid < 0, error('makePaperReport:html','cannot write %s', path); end
clean = onCleanup(@() fclose(fid));
p = @(varargin) fprintf(fid, varargin{:});

p('<!doctype html><html><head><meta charset="utf-8"><title>Ozone Paper-3 Results</title>\n');
p(['<style>body{font-family:Segoe UI,Arial,sans-serif;max-width:1100px;margin:24px auto;' ...
   'color:#222;line-height:1.5;padding:0 16px}h1{border-bottom:3px solid #06c}' ...
   'h2{margin-top:34px;border-bottom:1px solid #ccc;color:#024}figure{margin:18px 0}' ...
   'img{max-width:100%%;border:1px solid #ddd}figcaption{font-size:0.9em;color:#555}' ...
   'table{border-collapse:collapse;font-size:0.86em}td,th{border:1px solid #ccc;padding:3px 7px}' ...
   'th{background:#eef}.kpi{display:inline-block;background:#eef6ff;border:1px solid #cde;' ...
   'border-radius:6px;padding:8px 12px;margin:4px}.scroll{max-height:360px;overflow:auto;border:1px solid #ddd}' ...
   '.note{background:#fffbe6;border:1px solid #ecd97a;padding:8px 12px;border-radius:6px}</style></head><body>\n']);

p('<h1>Tropospheric Ozone Data Fusion - Paper-3 Results</h1>\n');
p('<p><b>Period:</b> %d-%d (%d years, %d months) &nbsp; <b>Grid:</b> %d land cells &nbsp; <b>Composite:</b> %s</p>\n', ...
    fnd.y0, fnd.y1, fnd.nYears, numel(years)*12, fnd.nCells, local_esc(cube.method));
p('<p class="note"><b>Draft results for selection.</b> Generated %s by makePaperReport.m. ', datestr(now)); %#ok<TNOW1,DATST>
p('Trends are Theil-Sen slopes with Mann-Kendall significance. Population weighting uses static 2019 population. ');
p('For 1990-2004 only method 13000313-02 has spatial estimates, so the per-year best-method composite reduces to that method here.</p>\n');

% ---- key findings
p('<h2>1. Key findings at a glance</h2>\n');
p('<div>');
p('<span class="kpi">Global annual mean<br><b>%+.2f ppb/decade</b> (area)<br>p=%.3f</span>', fnd.glAnnualArea, fnd.glAnnualArea_p);
p('<span class="kpi">Global annual mean<br><b>%+.2f ppb/decade</b> (pop)<br>p=%.3f</span>', fnd.glAnnualPop, fnd.glAnnualPop_p);
p('<span class="kpi">Global OSDMA8<br><b>%+.2f ppb/decade</b> (area)</span>', fnd.glOsdmaArea);
p('<span class="kpi">Cells rising<br><b>%.0f%%</b> (%.0f%% sig.)</span>', fnd.cellsRising, fnd.cellsSig);
p('<span class="kpi">Peak-month sig.<br><b>%.0f%%</b> of cells</span>', fnd.peakSig);
p('<span class="kpi">Global OSDMA8 OLS<br><b>%+.2f ppb/decade</b><br>AR(1) p=%.3f</span>', fnd.olsArea, fnd.olsArea_p);
p('<span class="kpi">Years to detect (n*)<br><b>%.0f yr</b> (phi=%.2f)</span>', fnd.olsArea_nStar, fnd.olsArea_phi);
p('<span class="kpi">Population<br><b>%.2f billion</b></span>', fnd.popTotal/1e9);
p('</div>\n');
p('<ul>\n');
p(['<li>Global land-area-weighted annual-mean MDA8 changed by <b>%+.2f ppb/decade</b> ' ...
   '(Mann-Kendall p=%.3f); the Sen-fitted level rose from ~%.1f ppb in %d to ~%.1f ppb in %d.</li>\n'], ...
   fnd.glAnnualArea, fnd.glAnnualArea_p, fnd.glStart, fnd.y0, fnd.glEnd, fnd.y1);
p(['<li>The <b>population-weighted</b> trend (%+.2f ppb/decade) %s the area-weighted trend, ' ...
   'indicating people on average experience a %s change than the unweighted land surface.</li>\n'], ...
   fnd.glAnnualPop, local_cmp(fnd.glAnnualPop, fnd.glAnnualArea), local_cmpword(fnd.glAnnualPop, fnd.glAnnualArea));
p('<li>%.0f%% of land cells show a rising annual-mean trend; %.0f%% are significant (p<0.05). Median per-cell slope %+.2f ppb/decade.</li>\n', ...
   fnd.cellsRising, fnd.cellsSig, fnd.medSlope);
for r = 1:numel(fnd.regNames)
    p('<li>%s: pop-weighted annual trend <b>%+.2f ppb/decade</b>.</li>\n', local_esc(fnd.regNames{r}), fnd.regTrend(r));
end
for ti = 1:numel(fnd.expThr)
    p('<li>Population above the WHO %d ug/m3 target (OSDMA8): %.1f%% in %d -> %.1f%% in %d.</li>\n', ...
        fnd.expThr(ti), fnd.expStart(ti), fnd.y0, fnd.expEnd(ti), fnd.y1);
end
p(['<li><b>OLS trend (DeLang/Becker-style):</b> global OSDMA8 %+.2f ppb/decade area-weighted ' ...
   '(%+.2f pop-weighted); Weatherhead AR(1)-adjusted p=%.3f, lag-1 phi=%.2f. The observed trend ' ...
   'would need ~%.0f years of data to detect at 90%% power / 5%% significance given the noise and ' ...
   'autocorrelation (n*).</li>\n'], fnd.olsArea, fnd.olsPop, fnd.olsArea_p, fnd.olsArea_phi, fnd.olsArea_nStar);
p('</ul>\n');

% ---- figures grouped by section
sections = {'Trends','Long-term trends'; ...
    'TrendStats','Trend statistics: OLS + AR(1) and two-period (DeLang/Becker-style)'; ...
    'Seasonality','Seasonality'; ...
    'PeakMonth','Peak ozone month'; 'Exposure','Population exposure (WHO targets)'; ...
    'Regional','Regional & country patterns'; 'Methods','Method performance'};
secNum = 2;
for sct = 1:size(sections,1)
    idx = find(strcmp({F.section}, sections{sct,1}));
    if isempty(idx), continue; end
    p('<h2>%d. %s</h2>\n', secNum, sections{sct,2}); secNum = secNum + 1;
    for k = idx
        p('<figure><img src="figs/%s" alt="%s"><figcaption><b>%s.</b> %s</figcaption></figure>\n', ...
            local_basename(F(k).file), local_esc(F(k).title), local_esc(F(k).title), local_esc(F(k).caption));
    end
end

% ---- detailed tables
p('<h2>%d. Detailed result tables</h2>\n', secNum); secNum = secNum + 1;
tbl = {'regional_trends.csv','Regional / global trends - Theil-Sen (all metrics & weightings)'; ...
       'trend_ols_regional.csv','Regional OLS trends + AR(1) significance & n* (Weatherhead 1998)'; ...
       'trend_twoperiod_regional.csv','Two-period (breakpoint) regional OLS trends'; ...
       'ref_published_trends.csv','Benchmark template (fill with DeLang/Becker published values)'; ...
       'seasonal_means_trends.csv','Seasonal series (per region/year)'; ...
       'exposure_by_threshold.csv','Population exposure by WHO threshold'; ...
       'exposure_trends.csv','Exposure trends'; ...
       'peak_month_trend.csv','Peak-month summary by region'; ...
       'country_trends.csv','Per-country levels & trends'; ...
       'best_method_by_year.csv','Best method by year (CBV)'; ...
       'method_year_skill.csv','Median CBV skill per method/year'};
for t = 1:size(tbl,1)
    T = local_readtable(fullfile(csvDir, tbl{t,1}));
    if isempty(T), continue; end
    p('<h3>%s <span style="font-weight:normal;color:#888">(%s, %d rows)</span></h3>\n', ...
        local_esc(tbl{t,2}), tbl{t,1}, height(T));
    p('<div class="scroll">%s</div>\n', local_table2html(T));
end

% ---- methods & caveats
p('<h2>%d. Methods & caveats</h2>\n<ul>\n', secNum);
p('<li>OSDMA8 = max over 6-month running-mean windows of monthly MDA8 (computeOSDMA8.m); used for the WHO peak-season targets.</li>\n');
p('<li>WHO targets applied: %s ug/m3 = %s ppb (factor %.2f ug/m3 per ppb).</li>\n', ...
    mat2str(opts.whoThresholdsUgm3), mat2str(opts.whoThresholdsUgm3/opts.ugPerPpb), opts.ugPerPpb);
p('<li>Trends: Theil-Sen slope + Mann-Kendall p (trendSenMK.m). Population: static 2019 (PopulationData2019).</li>\n');
p('<li>Grid: land cells common to every month (per-year station points excluded for consistency).</li>\n');
p('<li>1990-2004 is a partial-period test run; rerun for 1990-2022 (and once other methods have estimates) for the full per-year best-method composite.</li>\n');
p('</ul>\n');

p('</body></html>\n');
end

% ========================================================================
% Small helpers
% ========================================================================
function s = local_wser(vals, w)
w = w(:); valid = ~isnan(vals); V = vals; V(~valid) = 0;
num = sum(w.*V,1); den = sum(w.*valid,1); s = num./den; s(den==0)=NaN;
end
function s = local_wserMask(vals, w, mask)
s = local_wser(vals(mask,:), w(mask));
end
function regs = local_regionMasks(w)
regs = struct('name', {}, 'mask', {});
regs(end+1) = struct('name','Global','mask',true(w.nGrid,1));
for a = 1:numel(w.areaNames)
    regs(end+1) = struct('name', w.areaNames{a}, 'mask', w.areaMask(:,a)); %#ok<AGROW>
end
end
function f = local_fig()
f = figure('Visible','off','Position',[100 100 1000 520],'Color','w');
end
function s = local_save(f, figDir, name, opts, ttl, cap, section)
fn = fullfile(figDir, [name '.png']);
exportgraphics(f, fn, 'Resolution', opts.dpi); close(f);
s = struct('file', fn, 'title', ttl, 'caption', cap, 'section', section);
end
function s = local_emptyFig()
s = struct('file', {}, 'title', {}, 'caption', {}, 'section', {});
if isempty(s), s = struct('file','','title','','caption','','section',''); end
end
function local_trendline(x, y, col)
tr = trendSenMK(x, y);
if ~isnan(tr.slope)
    plot(x, tr.intercept + tr.slope*x, '--', 'Color', col, 'LineWidth', 1);
end
end
function cmap = local_div()
n = 256; h = n/2;
cmap = [[linspace(0,1,h) ones(1,h)]', [linspace(0,1,h) linspace(1,0,h)]', [ones(1,h) linspace(1,0,h)]'];
end
function m = local_robustMax(x)
x = abs(x(~isnan(x)));
if isempty(x), m = 0; else, m = prctile(x, 98); end
if ~isfinite(m) || m==0, m = max([x(:); eps]); end
end
function T = local_readtable(p)
if exist(p, 'file'), T = readtable(p, 'TextType','string'); else, T = table(); end
end
function h = local_table2html(T)
v = T.Properties.VariableNames;
h = '<table><tr>';
for j = 1:numel(v), h = [h '<th>' local_esc(v{j}) '</th>']; end %#ok<AGROW>
h = [h '</tr>'];
for i = 1:height(T)
    h = [h '<tr>']; %#ok<AGROW>
    for j = 1:numel(v)
        val = T{i, j};
        if isnumeric(val) || islogical(val)
            cell_ = local_num(double(val));
        else
            sv = string(val);
            if ismissing(sv), cell_ = ''; else, cell_ = local_esc(char(sv)); end
        end
        h = [h '<td>' cell_ '</td>']; %#ok<AGROW>
    end
    h = [h '</tr>']; %#ok<AGROW>
end
h = [h '</table>'];
end
function s = local_num(x)
if isnan(x), s = ''; elseif x==round(x) && abs(x)<1e6, s = sprintf('%d', x);
else, s = sprintf('%.4g', x); end
end
function s = local_esc(s)
s = strrep(char(s), '&', '&amp;'); s = strrep(s, '<', '&lt;'); s = strrep(s, '>', '&gt;');
end
function b = local_basename(p)
[~, n, e] = fileparts(p); b = [n e];
end
function w = local_cmp(a, b)
if a > b + 1e-9, w = 'exceeds'; elseif a < b - 1e-9, w = 'is below'; else, w = 'matches'; end
end
function w = local_cmpword(a, b)
if a > b + 1e-9, w = 'larger'; elseif a < b - 1e-9, w = 'smaller'; else, w = 'similar'; end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('outDir', '8postprocess', 'method', 'best-per-year', ...
    'yearRange', [1990 2004], 'whoThresholdsUgm3', [60 70 100], ...
    'ugPerPpb', 2.0, 'dpi', 150);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end
function cfg = local_cfgForLoad(opts)
cfg = struct('methodConfig', struct('goScenario',3,'logTransf',0,'areaCode',0, ...
    'mapResolution',1.0,'dataFormat','stug','keepOnlyLand',1), ...
    'fallbackMethod','13000313-02', 'srcDir','5BMEspatialPlots', ...
    'outDir', opts.outDir, 'yearRange', opts.yearRange);
end
