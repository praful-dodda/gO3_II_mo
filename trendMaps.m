function R = trendMaps(cube, opts)
% trendMaps - Per-cell robust trend maps + decadal-difference (analysis B)
%
% For each requested metric (annual mean, OSDMA8) fits a Theil-Sen slope and a
% Mann-Kendall p-value at every grid cell over the full period, and computes a
% decadal-difference map (late-decade mean minus early-decade mean). Results are
% written as point NetCDF (cell-indexed) plus an optional PNG scatter map.
%
% SYNTAX:
%   R = trendMaps(cube)
%   R = trendMaps(cube, opts)
%
% INPUTS:
%   cube - from assembleBMEcube
%   opts - (optional):
%       .metrics     (default {'AnnualMean','OSDMA8'})
%       .earlyDecade (default [1990 1999])
%       .lateDecade  (default [2013 2022])
%       .outDir      (default fullfile('8postprocess','maps'))
%       .method      (label embedded in filenames; default cube.method)
%       .writeNetCDF (default 1)   .writePNG (default 1)
%       .verbose     (default 1)
%
% OUTPUT (struct 'R'), one field per metric, each with:
%   .lon,.lat, .slopePerDecade, .pValue, .decadalDiff, .signif (p<0.05)
%
% Files: maps/trend_sen_<metric>_<method>_<y0>-<y1>.nc (+ .png)
%
% Run trendMaps('--selftest') to execute built-in unit checks.
%
% SEE ALSO: cubeAnnualMetrics, trendSenMK, peakMonthAnalysis

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    R = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts, cube);

M = cubeAnnualMetrics(cube);
years = M.years(:);
lon = cube.lon; lat = cube.lat;
metricField = struct('AnnualMean','annualMean','OSDMA8','osdma8');

R = struct();
for mi = 1:numel(opts.metrics)
    mName = opts.metrics{mi};
    A = M.(metricField.(mName));            % nGrid x nY

    [slopePerDecade, pValue] = local_cellTrends(years, A);
    decadalDiff = local_decadalDiff(years, A, opts.earlyDecade, opts.lateDecade);

    res = struct('lon', lon, 'lat', lat, ...
        'slopePerDecade', slopePerDecade, 'pValue', pValue, ...
        'decadalDiff', decadalDiff, 'signif', pValue < 0.05);
    R.(mName) = res;

    tag = sprintf('%s_%s_%d-%d', mName, opts.method, years(1), years(end));
    if opts.writeNetCDF
        local_writePointNetCDF(fullfile(opts.outDir, ...
            sprintf('trend_sen_%s.nc', tag)), res, mName, years);
    end
    if opts.writePNG
        local_writeTrendPNG(fullfile(opts.outDir, ...
            sprintf('trend_sen_%s.png', tag)), res, mName);
    end
    if opts.verbose
        fprintf('trendMaps %-10s: median slope %.3f ppb/decade, %.0f%% cells significant\n', ...
            mName, median(slopePerDecade,'omitnan'), ...
            100*mean(res.signif,'omitnan'));
    end
end

end

% ========================================================================
function [slopePerDecade, pValue] = local_cellTrends(years, A)
nG = size(A, 1);
slopePerDecade = nan(nG, 1);
pValue = nan(nG, 1);
for g = 1:nG
    tr = trendSenMK(years, A(g, :));
    slopePerDecade(g) = tr.slope * 10;
    pValue(g) = tr.pValue;
end
end

% ========================================================================
function d = local_decadalDiff(years, A, early, late)
eMask = years >= early(1) & years <= early(2);
lMask = years >= late(1)  & years <= late(2);
d = mean(A(:, lMask), 2, 'omitnan') - mean(A(:, eMask), 2, 'omitnan');
end

% ========================================================================
function local_writePointNetCDF(path, res, mName, years)
if exist(path, 'file'), delete(path); end
n = numel(res.lon);
nccreate(path, 'lon', 'Dimensions', {'cell', n}, 'Format', 'netcdf4');
nccreate(path, 'lat', 'Dimensions', {'cell', n});
nccreate(path, 'slope_ppb_per_decade', 'Dimensions', {'cell', n});
nccreate(path, 'pvalue', 'Dimensions', {'cell', n});
nccreate(path, 'decadal_diff_ppb', 'Dimensions', {'cell', n});
ncwrite(path, 'lon', res.lon);
ncwrite(path, 'lat', res.lat);
ncwrite(path, 'slope_ppb_per_decade', res.slopePerDecade);
ncwrite(path, 'pvalue', res.pValue);
ncwrite(path, 'decadal_diff_ppb', res.decadalDiff);
ncwriteatt(path, '/', 'metric', mName);
ncwriteatt(path, '/', 'period', sprintf('%d-%d', years(1), years(end)));
ncwriteatt(path, '/', 'trend_method', 'Theil-Sen slope, Mann-Kendall p-value');
end

% ========================================================================
function local_writeTrendPNG(path, res, mName)
try
    f = figure('Visible', 'off', 'Position', [100 100 1000 500]);
    scatter(res.lon, res.lat, 8, res.slopePerDecade, 'filled');
    hold on;
    sig = res.signif;
    plot(res.lon(sig), res.lat(sig), 'k.', 'MarkerSize', 1);
    colormap(local_divergingMap());
    cb = colorbar; cb.Label.String = 'ppb / decade';
    cmax = max(abs(res.slopePerDecade), [], 'omitnan');
    if isfinite(cmax) && cmax > 0, clim([-cmax cmax]); end
    axis equal; xlim([-180 180]); ylim([-90 90]);
    title(sprintf('%s trend (Sen slope; dots = p<0.05)', mName));
    xlabel('Longitude'); ylabel('Latitude');
    exportgraphics(f, path, 'Resolution', 150);
    close(f);
catch ME
    warning('trendMaps:png', 'PNG write failed: %s', ME.message);
end
end

function cmap = local_divergingMap()
% simple blue-white-red diverging colormap (no toolbox dependency)
n = 256; half = n/2;
r = [linspace(0,1,half) ones(1,half)];
g = [linspace(0,1,half) linspace(1,0,half)];
b = [ones(1,half) linspace(1,0,half)];
cmap = [r' g' b'];
end

% ========================================================================
function opts = local_defaults(opts, cube)
method = 'unknown';
if isstruct(cube) && isfield(cube, 'method'), method = cube.method; end
d = struct('metrics', {{'AnnualMean','OSDMA8'}}, ...
    'earlyDecade', [1990 1999], 'lateDecade', [2013 2022], ...
    'outDir', fullfile('8postprocess','maps'), 'method', method, ...
    'writeNetCDF', 1, 'writePNG', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
if (opts.writeNetCDF || opts.writePNG) && ~exist(opts.outDir, 'dir')
    mkdir(opts.outDir);
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));

% 3 cells, 10 years; cell g rises at g ppb/yr -> g*10 ppb/decade.
nG = 3; yrs = 2000:2009;
yr = []; mon = []; tk = [];
for y = yrs
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
oz = nan(nG, numel(yr));
for g = 1:nG
    for c = 1:numel(yr)
        oz(g,c) = 20 + g*(yr(c)-2000);    % linear in year, slope g/yr
    end
end
cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', [0 0; 10 10; 20 20], 'lon', [0;10;20], ...
    'lat', [0;10;20], 'method', 'TEST');

R = trendMaps(cube, struct('metrics', {{'AnnualMean'}}, 'outDir', tmp, ...
    'writeNetCDF', 1, 'writePNG', 0, 'verbose', 0));

assert(abs(R.AnnualMean.slopePerDecade(1) - 10) < 1e-6, 'cell1 slope 10/dec');
assert(abs(R.AnnualMean.slopePerDecade(3) - 30) < 1e-6, 'cell3 slope 30/dec');

% NetCDF round-trip
ncf = fullfile(tmp, 'trend_sen_AnnualMean_TEST_2000-2009.nc');
assert(exist(ncf, 'file') > 0, 'netcdf written');
slp = ncread(ncf, 'slope_ppb_per_decade');
assert(abs(slp(2) - 20) < 1e-6, 'netcdf slope roundtrip');

fprintf('trendMaps self-test: ALL PASSED.\n');
end
