function R = peakMonthAnalysis(cube, opts)
% peakMonthAnalysis - Is the peak ozone month shifting over time? (analysis E)
%
% For each grid cell and year, the month of maximum MDA8 is found, then its
% drift over the record is estimated with circular-aware handling (phase
% unwrap + Theil-Sen slope) and reported in days/decade. Also computes the
% high-ozone "season length" (months per year above the cell's climatological
% annual mean) and its trend. Outputs a point NetCDF map and, if grid weights
% are supplied, a regional summary CSV.
%
% SYNTAX:
%   R = peakMonthAnalysis(cube)
%   R = peakMonthAnalysis(cube, opts)
%
% INPUTS:
%   cube - from assembleBMEcube
%   opts - (optional):
%       .weights   computeGridWeights struct (enables regional CSV; default [])
%       .outDir    (default fullfile('8postprocess'))   maps/ and csv/ underneath
%       .method    (default cube.method)
%       .writeNetCDF (default 1)   .writePNG (default 1)   .verbose (default 1)
%
% OUTPUT (struct 'R'):
%   .lon,.lat
%   .meanPeakMonth         nGrid x 1  circular-mean peak month (1-12)
%   .shiftDaysPerDecade    nGrid x 1  peak-timing drift (signed; +later)
%   .pValue                nGrid x 1  Mann-Kendall p on the unwrapped series
%   .seasonLenTrendPerDec  nGrid x 1  months/decade change in season length
%   .regionalT             table (if weights given): per-region summary
%
% Run peakMonthAnalysis('--selftest') to execute built-in unit checks.
%
% SEE ALSO: cubeAnnualMetrics, trendSenMK, computeGridWeights

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    R = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts, cube);

M = cubeAnnualMetrics(cube);
years = M.years(:);
pm = M.peakMonth;                 % nGrid x nY
nG = size(pm, 1);
daysPerMonth = 365.25 / 12;

%% Per-cell circular mean + drift
meanPeakMonth = nan(nG, 1);
shiftDaysPerDecade = nan(nG, 1);
pValue = nan(nG, 1);
for g = 1:nG
    seq = pm(g, :);
    meanPeakMonth(g) = local_circMeanMonth(seq);
    u = local_unwrapMonths(seq);
    tr = trendSenMK(years, u(:));
    shiftDaysPerDecade(g) = tr.slope * 10 * daysPerMonth;
    pValue(g) = tr.pValue;
end

%% Season length (months/year above the cell's climatological annual mean) + trend
M3 = local_reshapeMonthly(cube, years);          % nGrid x 12 x nY
climAnnual = mean(mean(M3, 2, 'omitnan'), 3, 'omitnan');   % nGrid x 1
nY = numel(years);
seasonLen = nan(nG, nY);
for yi = 1:nY
    seasonLen(:, yi) = sum(M3(:, :, yi) > climAnnual, 2);
end
seasonLenTrendPerDec = nan(nG, 1);
for g = 1:nG
    tr = trendSenMK(years, seasonLen(g, :));
    seasonLenTrendPerDec(g) = tr.slope * 10;
end

R = struct('lon', cube.lon, 'lat', cube.lat, ...
    'meanPeakMonth', meanPeakMonth, 'shiftDaysPerDecade', shiftDaysPerDecade, ...
    'pValue', pValue, 'seasonLenTrendPerDec', seasonLenTrendPerDec);

%% Regional summary (area-weighted) if weights provided
if ~isempty(opts.weights)
    R.regionalT = local_regionalSummary(R, opts.weights);
    if opts.save
        cdir = fullfile(opts.outDir, 'csv');
        if ~exist(cdir, 'dir'), mkdir(cdir); end
        writetable(R.regionalT, fullfile(cdir, 'peak_month_trend.csv'));
    end
end

%% NetCDF
tag = sprintf('%s_%d-%d', opts.method, years(1), years(end));
if opts.writeNetCDF
    mdir = fullfile(opts.outDir, 'maps');
    if ~exist(mdir, 'dir'), mkdir(mdir); end
    local_writeNetCDF(fullfile(mdir, sprintf('peak_month_%s.nc', tag)), R, years);
end
if opts.writePNG
    mdir = fullfile(opts.outDir, 'maps');
    if ~exist(mdir, 'dir'), mkdir(mdir); end
    local_writePNG(fullfile(mdir, sprintf('peak_month_shift_%s.png', tag)), R);
end
if opts.verbose
    fprintf('peakMonthAnalysis: median shift %.1f days/decade (%.0f%% cells p<0.05)\n', ...
        median(shiftDaysPerDecade, 'omitnan'), 100*mean(pValue < 0.05, 'omitnan'));
end

end

% ========================================================================
function m = local_circMeanMonth(seq)
seq = seq(~isnan(seq));
if isempty(seq), m = NaN; return; end
ang = 2*pi*(seq-1)/12;
mAng = atan2(mean(sin(ang)), mean(cos(ang)));
m = mod(mAng/(2*pi)*12, 12) + 1;
end

% ========================================================================
function u = local_unwrapMonths(seq)
% Phase-unwrap a 1..12 month series so a wrapping drift (e.g. Dec->Jan) reads
% as a continuous change. NaNs are preserved (skipped) in place.
u = nan(size(seq));
ref = NaN;
for i = 1:numel(seq)
    if isnan(seq(i)), continue; end
    if isnan(ref)
        u(i) = seq(i);
    else
        d = mod(seq(i) - ref + 6, 12) - 6;   % minimal signed step in [-6,6)
        u(i) = ref + d;
    end
    ref = u(i);
end
end

% ========================================================================
function M3 = local_reshapeMonthly(cube, years)
nG = cube.nGrid; nY = numel(years);
M3 = nan(nG, 12, nY);
for yi = 1:nY
    for m = 1:12
        col = find(cube.year == years(yi) & cube.month == m, 1);
        if ~isempty(col), M3(:, m, yi) = cube.ozone(:, col); end
    end
end
end

% ========================================================================
function T = local_regionalSummary(R, weights)
sets = {}; names = {}; mpm = []; shift = []; slen = [];
regList = local_regionList(weights);
for r = 1:numel(regList)
    mask = regList(r).mask;
    w = weights.w_area(mask);
    sets{end+1} = regList(r).set;   %#ok<AGROW>
    names{end+1} = regList(r).name; %#ok<AGROW>
    mpm(end+1)   = local_wCircMonth(R.meanPeakMonth(mask), w);   %#ok<AGROW>
    shift(end+1) = local_wmean(R.shiftDaysPerDecade(mask), w);   %#ok<AGROW>
    slen(end+1)  = local_wmean(R.seasonLenTrendPerDec(mask), w); %#ok<AGROW>
end
T = table(string(sets(:)), string(names(:)), mpm(:), shift(:), slen(:), ...
    'VariableNames', {'RegionSet','Region','MeanPeakMonth', ...
    'ShiftDaysPerDecade','SeasonLenTrendPerDecade'});
end

function v = local_wmean(x, w)
ok = ~isnan(x) & ~isnan(w);
if ~any(ok), v = NaN; else, v = sum(w(ok).*x(ok))/sum(w(ok)); end
end

function m = local_wCircMonth(months, w)
ok = ~isnan(months) & ~isnan(w);
if ~any(ok), m = NaN; return; end
ang = 2*pi*(months(ok)-1)/12;
mAng = atan2(sum(w(ok).*sin(ang)), sum(w(ok).*cos(ang)));
m = mod(mAng/(2*pi)*12, 12) + 1;
end

function regList = local_regionList(weights)
regList = struct('set', {}, 'name', {}, 'mask', {});
regList(end+1) = struct('set','Global','name','Global','mask',true(weights.nGrid,1));
for a = 1:numel(weights.areaNames)
    regList(end+1) = struct('set','areacode','name',weights.areaNames{a}, ...
        'mask', weights.areaMask(:,a)); %#ok<AGROW>
end
end

% ========================================================================
function local_writeNetCDF(path, R, years)
if exist(path, 'file'), delete(path); end
n = numel(R.lon);
nccreate(path, 'lon', 'Dimensions', {'cell', n}, 'Format', 'netcdf4');
nccreate(path, 'lat', 'Dimensions', {'cell', n});
nccreate(path, 'mean_peak_month', 'Dimensions', {'cell', n});
nccreate(path, 'shift_days_per_decade', 'Dimensions', {'cell', n});
nccreate(path, 'pvalue', 'Dimensions', {'cell', n});
nccreate(path, 'season_len_trend_months_per_decade', 'Dimensions', {'cell', n});
ncwrite(path, 'lon', R.lon);
ncwrite(path, 'lat', R.lat);
ncwrite(path, 'mean_peak_month', R.meanPeakMonth);
ncwrite(path, 'shift_days_per_decade', R.shiftDaysPerDecade);
ncwrite(path, 'pvalue', R.pValue);
ncwrite(path, 'season_len_trend_months_per_decade', R.seasonLenTrendPerDec);
ncwriteatt(path, '/', 'period', sprintf('%d-%d', years(1), years(end)));
end

function local_writePNG(path, R)
try
    f = figure('Visible', 'off', 'Position', [100 100 1000 500]);
    scatter(R.lon, R.lat, 8, R.shiftDaysPerDecade, 'filled');
    cb = colorbar; cb.Label.String = 'days / decade (+ = later)';
    cmax = max(abs(R.shiftDaysPerDecade), [], 'omitnan');
    if isfinite(cmax) && cmax > 0, clim([-cmax cmax]); end
    axis equal; xlim([-180 180]); ylim([-90 90]);
    title('Peak ozone month shift'); xlabel('Longitude'); ylabel('Latitude');
    exportgraphics(f, path, 'Resolution', 150); close(f);
catch ME
    warning('peakMonthAnalysis:png', 'PNG write failed: %s', ME.message);
end
end

% ========================================================================
function opts = local_defaults(opts, cube)
method = 'unknown';
if isstruct(cube) && isfield(cube, 'method'), method = cube.method; end
d = struct('weights', [], 'outDir', fullfile('8postprocess'), ...
    'method', method, 'writeNetCDF', 1, 'writePNG', 1, 'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;

% Build a cube where, per year, we directly control the peak month.
% Cell 1: peak month fixed at 6 every year -> shift ~0.
% Cell 2: peak month increments by 1/yr and wraps -> +1 month/yr drift.
yrs = 2000:2011;          % 12 years
nY = numel(yrs);
peakA = repmat(6, 1, nY);
peakB = mod((3:3+nY-1) - 1, 12) + 1;   % 3,4,...,12,1,2

nG = 2;
yr = []; mon = []; tk = [];
for y = yrs
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
oz = 20*ones(nG, numel(yr));
for yi = 1:nY
    base = (yr == yrs(yi));
    cols = find(base);
    oz(1, cols(peakA(yi))) = 80;   % plant the maximum in the chosen month
    oz(2, cols(peakB(yi))) = 80;
end
cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', [0 0; 10 0], 'lon', [0;10], 'lat', [0;0], 'method','TEST');

R = peakMonthAnalysis(cube, struct('writeNetCDF', 0, 'writePNG', 0, ...
    'save', 0, 'verbose', 0));

% Cell 1: no drift
assert(abs(R.shiftDaysPerDecade(1)) < 1, 'cell1 no shift');
assert(abs(R.meanPeakMonth(1) - 6) < 1e-6, 'cell1 mean peak month 6');
% Cell 2: +1 month/yr = +10 months/decade ~ +304 days/decade
expected = 10 * (365.25/12);
assert(abs(R.shiftDaysPerDecade(2) - expected) < 1, 'cell2 +~304 days/decade');

fprintf('peakMonthAnalysis self-test: ALL PASSED.\n');
end
