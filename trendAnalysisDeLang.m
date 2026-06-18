function [olsT, twoT] = trendAnalysisDeLang(cube, opts)
% trendAnalysisDeLang - OLS + AR(1) and two-period regional ozone trends
%
% Adds the DeLang/Becker (Serre/West, UNC) style time-series trend analysis on
% top of the post-processing outputs:
%   (1) Full-period OLS linear trends with Weatherhead-1998 AR(1)-adjusted
%       significance (and years-to-detect n*), per region/metric/weighting;
%   (2) Two-period (breakpoint) OLS trends to capture changing rates;
%   (3) Per-cell OLS trend maps (NetCDF/PNG);
%   (4) A benchmark template to compare modeled vs published regional trends.
%
% It fits to the regional series already written by annualSeasonalSeries
% (csv/regional_series.csv), so weighting/regions stay consistent.
%
% SYNTAX:
%   [olsT, twoT] = trendAnalysisDeLang(cube)
%   [olsT, twoT] = trendAnalysisDeLang(cube, opts)
%
% INPUTS:
%   cube - composite cube (for the per-cell maps). May be [] to skip maps.
%   opts - (optional):
%       .outDir      (default '8postprocess')
%       .metrics     (default {'OSDMA8','AnnualMean'})
%       .breakpoints (default [] -> single midpoint split) e.g. [2000]
%       .writeNetCDF (default true) .writePNG (default true)
%       .makeMaps    (default ~isempty(cube))
%       .verbose     (default true)
%
% OUTPUTS (also written to csv/):
%   olsT - trend_ols_regional.csv : RegionSet, Region, Metric, Weighting, Period,
%          SlopePerDecade, SE, phi, pValue, nStar, StartFit, EndFit, nYears
%   twoT - trend_twoperiod_regional.csv : RegionSet, Region, Metric, Weighting,
%          P1, P1Slope, P1p, P2, P2Slope, P2p, DeltaSlope
%   Also: ref_published_trends.csv (template), maps/trend_ols_<metric>_<period>.nc/.png
%
% Run trendAnalysisDeLang('--selftest') to execute built-in unit checks.
%
% SEE ALSO: annualSeasonalSeries, trendOLSweatherhead, trendSenMK, makePaperReport

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    olsT = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts, cube);
csvDir = fullfile(opts.outDir, 'csv');
if ~exist(csvDir, 'dir'), mkdir(csvDir); end

%% Load the regional series produced by annualSeasonalSeries
seriesPath = fullfile(csvDir, 'regional_series.csv');
if ~exist(seriesPath, 'file')
    error('trendAnalysisDeLang:noSeries', ...
        'Missing %s - run annualSeasonalSeries first.', seriesPath);
end
S = readtable(seriesPath, 'TextType', 'string');
S = S(ismember(S.Metric, string(opts.metrics)), :);

% group key: RegionSet|Region|Metric|Weighting
key = S.RegionSet + "|" + S.Region + "|" + S.Metric + "|" + S.Weighting;
[uk, ia] = unique(key, 'stable');

olsRows = {}; twoRows = {};
for g = 1:numel(uk)
    rows = S(key == uk(g), :);
    rows = sortrows(rows, 'Year');
    yr = rows.Year; val = rows.Value;
    meta = S(ia(g), :);

    % ---- full-period OLS + AR(1) ----
    tr = trendOLSweatherhead(yr, val);
    sf = tr.intercept + tr.slope*yr(1);
    ef = tr.intercept + tr.slope*yr(end);
    olsRows{end+1} = {meta.RegionSet, meta.Region, meta.Metric, meta.Weighting, ...
        sprintf('%d-%d', yr(1), yr(end)), tr.slopePerDecade, tr.se*10, tr.phi, ...
        tr.pValue, tr.nStar, sf, ef, sum(~isnan(val))}; %#ok<AGROW>

    % ---- two-period split ----
    bp = opts.breakpoints;
    if isempty(bp), bp = floor((yr(1)+yr(end))/2); end
    edges = [yr(1)-0.5, bp(:)'+0.5, yr(end)+0.5];
    seg = cell(1, numel(edges)-1);
    for s = 1:numel(edges)-1
        m = yr > edges(s) & yr < edges(s+1);
        seg{s} = trendOLSweatherhead(yr(m), val(m));
    end
    % report first vs last segment (P1 vs P2)
    p1 = seg{1}; p2 = seg{end};
    lab = @(s) sprintf('%d-%d', floor(edges(s)+0.5), floor(edges(s+1)-0.5));
    twoRows{end+1} = {meta.RegionSet, meta.Region, meta.Metric, meta.Weighting, ...
        lab(1), p1.slopePerDecade, p1.pValue, lab(numel(seg)), p2.slopePerDecade, ...
        p2.pValue, p2.slopePerDecade - p1.slopePerDecade}; %#ok<AGROW>
end

olsT = cell2table(vertcat(olsRows{:}), 'VariableNames', ...
    {'RegionSet','Region','Metric','Weighting','Period','SlopePerDecade','SE', ...
     'phi','pValue','nStar','StartFit','EndFit','nYears'});
twoT = cell2table(vertcat(twoRows{:}), 'VariableNames', ...
    {'RegionSet','Region','Metric','Weighting','P1','P1Slope','P1p', ...
     'P2','P2Slope','P2p','DeltaSlope'});

writetable(olsT, fullfile(csvDir, 'trend_ols_regional.csv'));
writetable(twoT, fullfile(csvDir, 'trend_twoperiod_regional.csv'));

% benchmark template (do not overwrite if the user has filled it)
local_writeRefTemplate(fullfile(opts.outDir, 'ref_published_trends.csv'), olsT);

%% Per-cell OLS maps
if opts.makeMaps && ~isempty(cube)
    M = cubeAnnualMetrics(cube);
    years = M.years(:);
    mapDir = fullfile(opts.outDir, 'maps');
    if ~exist(mapDir, 'dir'), mkdir(mapDir); end
    mf = struct('OSDMA8','osdma8','AnnualMean','annualMean');
    for mi = 1:numel(opts.metrics)
        mName = opts.metrics{mi};
        if ~isfield(mf, mName), continue; end
        A = M.(mf.(mName));
        nG = size(A,1); slope = nan(nG,1); pv = nan(nG,1);
        for c = 1:nG
            tr = trendOLSweatherhead(years, A(c,:));
            slope(c) = tr.slopePerDecade; pv(c) = tr.pValue;
        end
        tag = sprintf('%s_%d-%d', mName, years(1), years(end));
        if opts.writeNetCDF
            local_writeNC(fullfile(mapDir, sprintf('trend_ols_%s.nc', tag)), ...
                cube.lon, cube.lat, slope, pv, mName, years);
        end
        if opts.writePNG
            local_writePNG(fullfile(mapDir, sprintf('trend_ols_%s.png', tag)), ...
                cube.lon, cube.lat, slope, pv, mName);
        end
    end
end

if opts.verbose
    gi = find(olsT.RegionSet=="Global" & olsT.Metric=="OSDMA8" & olsT.Weighting=="area", 1);
    if ~isempty(gi)
        fprintf('trendAnalysisDeLang: global OSDMA8 OLS %.2f ppb/decade (p=%.3f, phi=%.2f, n*=%.0f yr)\n', ...
            olsT.SlopePerDecade(gi), olsT.pValue(gi), olsT.phi(gi), olsT.nStar(gi));
    end
end

end

% ========================================================================
function local_writeRefTemplate(path, olsT)
if exist(path, 'file'), return; end   % keep user-filled values
sub = olsT(ismember(olsT.RegionSet, {'Global','world'}) & olsT.Weighting=="pop", :);
T = table(sub.RegionSet, sub.Region, sub.Metric, ...
    repmat("", height(sub), 1), nan(height(sub),1), repmat("", height(sub),1), ...
    'VariableNames', {'RegionSet','Region','Metric','Source','RefSlopePerDecade','RefPeriod'});
writetable(T, path);
end

% ========================================================================
function local_writeNC(path, lon, lat, slope, pv, mName, years)
if exist(path, 'file'), delete(path); end
n = numel(lon);
nccreate(path, 'lon', 'Dimensions', {'cell', n}, 'Format', 'netcdf4');
nccreate(path, 'lat', 'Dimensions', {'cell', n});
nccreate(path, 'ols_slope_ppb_per_decade', 'Dimensions', {'cell', n});
nccreate(path, 'pvalue_ar1', 'Dimensions', {'cell', n});
ncwrite(path, 'lon', lon); ncwrite(path, 'lat', lat);
ncwrite(path, 'ols_slope_ppb_per_decade', slope); ncwrite(path, 'pvalue_ar1', pv);
ncwriteatt(path, '/', 'metric', mName);
ncwriteatt(path, '/', 'period', sprintf('%d-%d', years(1), years(end)));
ncwriteatt(path, '/', 'method', 'OLS slope, Weatherhead-1998 AR(1)-adjusted p');
end

function local_writePNG(path, lon, lat, slope, pv, mName)
try
    f = figure('Visible','off','Position',[100 100 1000 500],'Color','w');
    scatter(lon, lat, 6, slope, 'filled'); hold on;
    sig = pv < 0.05; plot(lon(sig), lat(sig), 'k.', 'MarkerSize', 1);
    n = 256; h = n/2;
    colormap(gca, [[linspace(0,1,h) ones(1,h)]', [linspace(0,1,h) linspace(1,0,h)]', [ones(1,h) linspace(1,0,h)]']);
    cb = colorbar; cb.Label.String = 'ppb / decade';
    cmax = prctile(abs(slope(~isnan(slope))), 98); if cmax>0, clim([-cmax cmax]); end
    axis equal; xlim([-180 180]); ylim([-60 85]);
    xlabel('Longitude'); ylabel('Latitude');
    title([mName ' OLS trend (dots: AR(1) p<0.05)']);
    exportgraphics(f, path, 'Resolution', 150); close(f);
catch ME
    warning('trendAnalysisDeLang:png', 'PNG write failed: %s', ME.message);
end
end

% ========================================================================
function opts = local_defaults(opts, cube)
d = struct('outDir', '8postprocess', 'metrics', {{'OSDMA8','AnnualMean'}}, ...
    'breakpoints', [], 'writeNetCDF', true, 'writePNG', true, ...
    'makeMaps', ~isempty(cube), 'verbose', true);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));
csvDir = fullfile(tmp, 'csv'); mkdir(csvDir);

% Synthetic regional_series.csv: Global OSDMA8 area-weighted, rising 1 ppb/yr,
% steeper in the second half (breakpoint behaviour).
yrs = (2000:2014)';
val = 30 + 1.0*(yrs-2000);
val(yrs>=2007) = val(yrs>=2007) + 2.0*(val(yrs>=2007)~=0).*(yrs(yrs>=2007)-2007); % extra slope late
T = table(repmat("Global",numel(yrs),1), repmat("Global",numel(yrs),1), ...
    repmat("OSDMA8",numel(yrs),1), repmat("area",numel(yrs),1), yrs, val, ...
    repmat(100,numel(yrs),1), 'VariableNames', ...
    {'RegionSet','Region','Metric','Weighting','Year','Value','Ncells'});
writetable(T, fullfile(csvDir, 'regional_series.csv'));

[olsT, twoT] = trendAnalysisDeLang([], struct('outDir', tmp, 'breakpoints', 2007, ...
    'makeMaps', false, 'verbose', false));

assert(height(olsT)==1 && height(twoT)==1, 'one series row each');
assert(olsT.SlopePerDecade > 9, 'full-period slope ~10+/decade');
assert(olsT.pValue < 0.05, 'significant');
assert(isfinite(olsT.nStar) && olsT.nStar > 0, 'finite n*');
% second period steeper than first
assert(twoT.P2Slope > twoT.P1Slope, 'second period steeper');
assert(abs(twoT.DeltaSlope - (twoT.P2Slope - twoT.P1Slope)) < 1e-9, 'delta consistent');
assert(exist(fullfile(csvDir,'trend_ols_regional.csv'),'file')>0, 'ols csv written');
assert(exist(fullfile(csvDir,'trend_twoperiod_regional.csv'),'file')>0, 'twoperiod csv written');
assert(exist(fullfile(tmp,'ref_published_trends.csv'),'file')>0, 'ref template written');

fprintf('trendAnalysisDeLang self-test: ALL PASSED.\n');
end
