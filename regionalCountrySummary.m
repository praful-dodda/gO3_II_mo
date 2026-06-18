function T = regionalCountrySummary(cube, weights, opts)
% regionalCountrySummary - Per-country ozone level & trend roll-up (analysis F)
%
% Aggregates per-cell annual-mean and OSDMA8 levels and their Theil-Sen trends
% up to country level (via the ISO3 label attached to each grid cell), producing
% a ready-to-use table for a paper or dashboard.
%
% SYNTAX:
%   T = regionalCountrySummary(cube, weights)
%   T = regionalCountrySummary(cube, weights, opts)
%
% INPUTS:
%   cube    - from assembleBMEcube
%   weights - from computeGridWeights (provides ISO3, CountryName, w_pop, w_area)
%   opts    - (optional):
%       .recentYears (default 10)  number of trailing years for "recent" means
%       .minCells    (default 1)   drop countries with fewer cells
%       .outDir (default fullfile('8postprocess','csv'))  .save (1) .verbose (1)
%
% OUTPUT (also csv/country_trends.csv when .save):
%   T - ISO3, CountryName, nCells, Pop,
%       MeanAnnual_recent, MeanOSDMA8_recent (population-weighted, ppb),
%       SlopeAnnual_ppb_per_decade, SlopeOSDMA8_ppb_per_decade (pop-weighted),
%       pAnnual (fraction of cells with p<0.05 on annual trend)
%
% Run regionalCountrySummary('--selftest') to execute built-in unit checks.
%
% SEE ALSO: cubeAnnualMetrics, trendSenMK, exposureMetrics

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    T = local_selftest();
    return;
end

if nargin < 3 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

M = cubeAnnualMetrics(cube);
years = M.years(:);
recentMask = years >= years(end) - opts.recentYears + 1;

% per-cell recent means and trends
annualRecent = mean(M.annualMean(:, recentMask), 2, 'omitnan');
osdmaRecent  = mean(M.osdma8(:, recentMask), 2, 'omitnan');
[slopeAnnual, pAnnual] = local_cellTrends(years, M.annualMean);
slopeOSDMA = local_cellTrends(years, M.osdma8);

iso = string(weights.ISO3);
country = string(weights.CountryName);
wPop = weights.w_pop(:);

u = unique(iso);
u = u(u ~= "" & ~ismissing(u));

ISO3 = strings(0,1); CountryName = strings(0,1);
nCells = []; Pop = [];
MeanAnnual_recent = []; MeanOSDMA8_recent = [];
SlopeAnnual = []; SlopeOSDMA8 = []; pSig = [];

for i = 1:numel(u)
    m = iso == u(i);
    if sum(m) < opts.minCells, continue; end
    w = wPop(m);
    if sum(w) == 0, w = ones(sum(m),1); end   % fall back to equal weights
    ISO3(end+1,1) = u(i); %#ok<AGROW>
    cn = country(m);
    CountryName(end+1,1) = cn(1); %#ok<AGROW>
    nCells(end+1,1) = sum(m); %#ok<AGROW>
    Pop(end+1,1) = sum(wPop(m)); %#ok<AGROW>
    MeanAnnual_recent(end+1,1) = local_wmean(annualRecent(m), w); %#ok<AGROW>
    MeanOSDMA8_recent(end+1,1) = local_wmean(osdmaRecent(m), w); %#ok<AGROW>
    SlopeAnnual(end+1,1) = local_wmean(slopeAnnual(m), w) * 10; %#ok<AGROW>
    SlopeOSDMA8(end+1,1) = local_wmean(slopeOSDMA(m), w) * 10; %#ok<AGROW>
    pSig(end+1,1) = mean(pAnnual(m) < 0.05, 'omitnan'); %#ok<AGROW>
end

T = table(ISO3, CountryName, nCells, Pop, MeanAnnual_recent, MeanOSDMA8_recent, ...
    SlopeAnnual, SlopeOSDMA8, pSig, 'VariableNames', ...
    {'ISO3','CountryName','nCells','Pop','MeanAnnual_recent','MeanOSDMA8_recent', ...
     'SlopeAnnual_ppb_per_decade','SlopeOSDMA8_ppb_per_decade','FracCellsSignif'});
T = sortrows(T, 'SlopeAnnual_ppb_per_decade', 'descend');

if opts.save
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    writetable(T, fullfile(opts.outDir, 'country_trends.csv'));
    if opts.verbose
        fprintf('regionalCountrySummary: %d countries -> country_trends.csv\n', height(T));
    end
end

end

% ========================================================================
function [slopePerYr, pValue] = local_cellTrends(years, A)
nG = size(A, 1);
slopePerYr = nan(nG, 1); pValue = nan(nG, 1);
for g = 1:nG
    tr = trendSenMK(years, A(g, :));
    slopePerYr(g) = tr.slope;
    pValue(g) = tr.pValue;
end
end

function v = local_wmean(x, w)
ok = ~isnan(x) & ~isnan(w);
if ~any(ok), v = NaN; else, v = sum(w(ok).*x(ok)) / sum(w(ok)); end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('recentYears', 10, 'minCells', 1, ...
    'outDir', fullfile('8postprocess','csv'), 'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;

% 3 cells: 2 in country AAA (rising), 1 in BBB (flat).
yrs = 2000:2009;
nG = 3;
yr = []; mon = []; tk = [];
for y = yrs
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
oz = nan(nG, numel(yr));
for c = 1:numel(yr)
    yy = yr(c) - 2000;
    oz(1, c) = 30 + 2*yy;   % AAA cell, +2 ppb/yr
    oz(2, c) = 32 + 2*yy;   % AAA cell, +2 ppb/yr
    oz(3, c) = 25;          % BBB cell, flat
end
cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', zeros(nG,2));
weights = struct('ISO3', ["AAA";"AAA";"BBB"], ...
    'CountryName', ["Aland";"Aland";"Bland"], 'w_pop', [1;1;1], 'w_area', [1;1;1]);

T = regionalCountrySummary(cube, weights, struct('save', 0, 'verbose', 0));

assert(height(T) == 2, 'two countries');
A = T(T.ISO3 == "AAA", :);
B = T(T.ISO3 == "BBB", :);
assert(abs(A.SlopeAnnual_ppb_per_decade - 20) < 1e-6, 'AAA +20 ppb/decade');
assert(abs(B.SlopeAnnual_ppb_per_decade - 0) < 1e-6, 'BBB flat');
assert(A.nCells == 2 && B.nCells == 1, 'cell counts');

fprintf('regionalCountrySummary self-test: ALL PASSED.\n');
end
