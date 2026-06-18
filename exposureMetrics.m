function [expT, trendT] = exposureMetrics(cube, weights, opts)
% exposureMetrics - Population exposure to WHO ozone targets over time (analysis F)
%
% Uses OSDMA8 (the 6-month running-mean peak-season metric, which matches the
% WHO ozone guideline definition) and counts, for each year and each WHO target,
% how much population and land area lives where the peak-season ozone exceeds it.
%
% WHO 2021 ozone peak-season targets (applied to OSDMA8):
%   AQG = 60 ug/m3, interim target 2 = 70 ug/m3, interim target 1 = 100 ug/m3.
% Converted to ppb with .ugPerPpb (default 2.0 ug/m3 per ppb) -> 30 / 35 / 50 ppb.
%
% SYNTAX:
%   [expT, trendT] = exposureMetrics(cube, weights)
%   [expT, trendT] = exposureMetrics(cube, weights, opts)
%
% opts (optional):
%   .thresholdsUgm3 (default [60 70 100])  .ugPerPpb (default 2.0)
%   .metric ('osdma8'|'annualMean', default 'osdma8')
%   .outDir (default fullfile('8postprocess','csv'))  .save (1) .verbose (1)
%
% OUTPUTS (also written to csv/ when .save):
%   expT   - Year, Threshold_ugm3, Threshold_ppb, PopAbove, PctPopAbove, PctAreaAbove
%   trendT - Threshold_ugm3, SlopePctPop_per_decade, pValue, StartPct, EndPct
%   Files: exposure_by_threshold.csv, exposure_trends.csv
%
% Run exposureMetrics('--selftest') to execute built-in unit checks.
%
% SEE ALSO: cubeAnnualMetrics, computeGridWeights, regionalCountrySummary

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    expT = local_selftest();
    return;
end

if nargin < 3 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

M = cubeAnnualMetrics(cube);
years = M.years(:);
if strcmpi(opts.metric, 'annualMean'), A = M.annualMean; else, A = M.osdma8; end

thrPpb = opts.thresholdsUgm3 / opts.ugPerPpb;
wPop = weights.w_pop(:);
wArea = weights.w_area(:);
totalPop = sum(wPop);
totalArea = sum(wArea);

%% Per year x threshold
nY = numel(years); nT = numel(thrPpb);
rows = {};
pctPopMat = nan(nY, nT);
for ti = 1:nT
    for yi = 1:nY
        above = A(:, yi) > thrPpb(ti);     % NaN -> false
        popAbove = sum(wPop(above));
        pctPop = 100 * popAbove / totalPop;
        pctArea = 100 * sum(wArea(above)) / totalArea;
        pctPopMat(yi, ti) = pctPop;
        rows{end+1} = {years(yi), opts.thresholdsUgm3(ti), thrPpb(ti), ...
            popAbove, pctPop, pctArea}; %#ok<AGROW>
    end
end
expT = cell2table(vertcat(rows{:}), 'VariableNames', ...
    {'Year','Threshold_ugm3','Threshold_ppb','PopAbove','PctPopAbove','PctAreaAbove'});

%% Trend of % population exposed, per threshold
tr_thr = opts.thresholdsUgm3(:);
slopePctPop = nan(nT, 1); pv = nan(nT, 1); sp = nan(nT, 1); ep = nan(nT, 1);
for ti = 1:nT
    tr = trendSenMK(years, pctPopMat(:, ti));
    slopePctPop(ti) = tr.slope * 10;
    pv(ti) = tr.pValue;
    v = pctPopMat(:, ti); idx = find(~isnan(v));
    if ~isempty(idx), sp(ti) = v(idx(1)); ep(ti) = v(idx(end)); end
end
trendT = table(tr_thr, slopePctPop, pv, sp, ep, 'VariableNames', ...
    {'Threshold_ugm3','SlopePctPop_per_decade','pValue','StartPct','EndPct'});

%% Save
if opts.save
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    writetable(expT, fullfile(opts.outDir, 'exposure_by_threshold.csv'));
    writetable(trendT, fullfile(opts.outDir, 'exposure_trends.csv'));
    if opts.verbose
        fprintf('exposureMetrics: %d thresholds x %d years -> exposure_by_threshold.csv\n', nT, nY);
    end
end

end

% ========================================================================
function opts = local_defaults(opts)
d = struct('thresholdsUgm3', [60 70 100], 'ugPerPpb', 2.0, ...
    'metric', 'osdma8', 'outDir', fullfile('8postprocess','csv'), ...
    'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;

% 2 cells, pop [10 90]. OSDMA8: cell2 crosses 35 ppb (=70 ug/m3) in later years.
yrs = 2000:2009; nY = numel(yrs);
nG = 2;
yr = []; mon = []; tk = [];
for y = yrs
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
% Build monthly so that OSDMA8 (max 6-mo running mean) equals a target per year.
% Set every month of a year to a constant value -> OSDMA8 = that value.
oz = nan(nG, numel(yr));
valCell1 = 20;                       % always below all thresholds (20 ppb)
valCell2 = linspace(25, 45, nY);     % rises through 30,35 ppb thresholds
for yi = 1:nY
    cols = find(yr == yrs(yi));
    oz(1, cols) = valCell1;
    oz(2, cols) = valCell2(yi);
end
cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', [0 0; 10 0], 'lon', [0;10], 'lat', [0;0]);
weights = struct('w_pop', [10;90], 'w_area', [1;1]);

% Use annualMean so the metric equals the planted value exactly (OSDMA8 would
% mix in adjacent-year months); the exposure logic is identical either way.
[expT, trendT] = exposureMetrics(cube, weights, ...
    struct('metric', 'annualMean', 'save', 0, 'verbose', 0));

% threshold 60 ug/m3 = 30 ppb. cell2 value exceeds 30 once linspace>30.
thr30 = expT(expT.Threshold_ugm3 == 60, :);
% Year 2000: cell2=25 < 30 -> 0% pop above. Last year cell2=45>30 -> 90% pop.
assert(abs(thr30.PctPopAbove(1) - 0) < 1e-9, 'year1 0% above 30ppb');
assert(abs(thr30.PctPopAbove(end) - 90) < 1e-9, 'last year 90% above 30ppb');

% exposure to 30 ppb rose over the record (Sen slope of a step can be ~0,
% so compare endpoints rather than the slope sign).
t30 = trendT(trendT.Threshold_ugm3 == 60, :);
assert(t30.EndPct > t30.StartPct, 'exposure rose end vs start');
assert(t30.SlopePctPop_per_decade >= 0, 'exposure slope non-negative');

fprintf('exposureMetrics self-test: ALL PASSED.\n');
end
