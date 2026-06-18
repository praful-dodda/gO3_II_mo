function [seriesT, trendsT] = annualSeasonalSeries(cube, weights, opts)
% annualSeasonalSeries - Regional area- & population-weighted series + trends
%                        (post-processing analyses C and D)
%
% Collapses the per-cell/per-year metrics (annual mean, OSDMA8, seasonal means,
% seasonal amplitude) into global and regional time series using BOTH area and
% population weights, then fits a robust Sen/Mann-Kendall trend to each series.
% Regions cover all three definitions: area-code (CONUS/Europe/EastAsia), GBD
% regions, and WHO regions, plus Global.
%
% SYNTAX:
%   [seriesT, trendsT] = annualSeasonalSeries(cube, weights)
%   [seriesT, trendsT] = annualSeasonalSeries(cube, weights, opts)
%
% INPUTS:
%   cube    - from assembleBMEcube
%   weights - from computeGridWeights (same grid as cube)
%   opts    - (optional):
%       .outDir   (default fullfile('8postprocess','csv'))
%       .metrics  (default {'AnnualMean','OSDMA8','DJF','MAM','JJA','SON','SeasonAmp'})
%       .weightings (default {'area','pop'})
%       .regionSets (default {'Global','areacode','GBD','WHO'})
%       .save     (default 1)   .verbose (default 1)
%
% OUTPUTS (also written to csv/ when .save):
%   seriesT - long table: RegionSet, Region, Metric, Weighting, Year, Value, Ncells
%   trendsT - long table: RegionSet, Region, Metric, Weighting,
%             SlopePerDecade, pValue, StartVal, EndVal, nYears
%   Files: regional_series.csv, regional_trends.csv,
%          annual_means_global_regional.csv, seasonal_means_trends.csv,
%          popweighted_annual.csv
%
% Run annualSeasonalSeries('--selftest') to execute built-in unit checks.
%
% SEE ALSO: cubeAnnualMetrics, computeGridWeights, trendSenMK

%% Self-test entry point
if nargin >= 1 && (ischar(cube) || isstring(cube)) && strcmp(cube, '--selftest')
    seriesT = local_selftest();
    return;
end

if nargin < 3 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

M = cubeAnnualMetrics(cube);
years = M.years(:);
nY = numel(years);

metricField = struct('AnnualMean','annualMean', 'OSDMA8','osdma8', ...
    'DJF','DJF', 'MAM','MAM', 'JJA','JJA', 'SON','SON', 'SeasonAmp','seasonAmp');

regions = local_buildRegions(weights, opts.regionSets);   % struct array

%% Reduce to series + trends
sBlocks = {};
tRows = {};
for r = 1:numel(regions)
    mask = regions(r).mask;
    for mi = 1:numel(opts.metrics)
        mName = opts.metrics{mi};
        vals = M.(metricField.(mName))(mask, :);     % nCells x nY
        for wi = 1:numel(opts.weightings)
            wName = opts.weightings{wi};
            if strcmp(wName, 'area')
                w = weights.w_area(mask);
            else
                w = weights.w_pop(mask);
            end
            series = local_wYearMean(vals, w);        % 1 x nY

            blk = table();
            blk.RegionSet = repmat(string(regions(r).set), nY, 1);
            blk.Region    = repmat(string(regions(r).name), nY, 1);
            blk.Metric    = repmat(string(mName), nY, 1);
            blk.Weighting = repmat(string(wName), nY, 1);
            blk.Year      = years;
            blk.Value     = series(:);
            blk.Ncells    = repmat(sum(mask), nY, 1);
            sBlocks{end+1} = blk; %#ok<AGROW>

            tr = trendSenMK(years, series(:));
            valid = ~isnan(series(:));
            sv = NaN; ev = NaN;
            if any(valid)
                idx = find(valid);
                sv = series(idx(1)); ev = series(idx(end));
            end
            tRows{end+1} = {string(regions(r).set), string(regions(r).name), ...
                string(mName), string(wName), tr.slope*10, tr.pValue, ...
                sv, ev, sum(valid)}; %#ok<AGROW>
        end
    end
end

seriesT = vertcat(sBlocks{:});
trendsT = cell2table(vertcat(tRows{:}), 'VariableNames', ...
    {'RegionSet','Region','Metric','Weighting','SlopePerDecade','pValue', ...
     'StartVal','EndVal','nYears'});

%% Save
if opts.save
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    writetable(seriesT, fullfile(opts.outDir, 'regional_series.csv'));
    writetable(trendsT, fullfile(opts.outDir, 'regional_trends.csv'));

    isAnnual  = ismember(seriesT.Metric, {'AnnualMean','OSDMA8'});
    isSeason  = ismember(seriesT.Metric, {'DJF','MAM','JJA','SON','SeasonAmp'});
    writetable(seriesT(isAnnual, :), ...
        fullfile(opts.outDir, 'annual_means_global_regional.csv'));
    writetable(seriesT(isSeason, :), ...
        fullfile(opts.outDir, 'seasonal_means_trends.csv'));
    writetable(seriesT(isAnnual & seriesT.Weighting == "pop", :), ...
        fullfile(opts.outDir, 'popweighted_annual.csv'));
    if opts.verbose
        fprintf('annualSeasonalSeries: %d series rows, %d trend rows -> %s\n', ...
            height(seriesT), height(trendsT), opts.outDir);
    end
end

end

% ========================================================================
function series = local_wYearMean(vals, w)
% Weighted mean over cells for each year, NaN-safe (NaN cells excluded).
w = w(:);
valid = ~isnan(vals);
V = vals; V(~valid) = 0;
num = sum(w .* V, 1);
den = sum(w .* valid, 1);
series = num ./ den;
series(den == 0) = NaN;
end

% ========================================================================
function regions = local_buildRegions(weights, regionSets)
% Build a struct array of regions: .set, .name, .mask (nGrid x 1 logical).
nGrid = weights.nGrid;
regions = struct('set', {}, 'name', {}, 'mask', {});
for s = 1:numel(regionSets)
    switch lower(regionSets{s})
        case 'global'
            regions(end+1) = struct('set','Global','name','Global', ...
                'mask', true(nGrid,1)); %#ok<AGROW>
        case 'areacode'
            for a = 1:numel(weights.areaNames)
                regions(end+1) = struct('set','areacode', ...
                    'name', weights.areaNames{a}, ...
                    'mask', weights.areaMask(:,a)); %#ok<AGROW>
            end
        case 'gbd'
            regions = local_labelRegions(regions, 'GBD', weights.GBDRegion, nGrid);
        case 'who'
            regions = local_labelRegions(regions, 'WHO', weights.WHORegion, nGrid);
        case 'world'
            if isfield(weights, 'worldRegion')
                regions = local_labelRegions(regions, 'world', weights.worldRegion, nGrid);
            end
        otherwise
            warning('annualSeasonalSeries:region', 'Unknown region set %s', regionSets{s});
    end
end
end

function regions = local_labelRegions(regions, setName, labels, ~)
labels = string(labels);
u = unique(labels);
u = u(u ~= "" & ~ismissing(u));
for i = 1:numel(u)
    regions(end+1) = struct('set', setName, 'name', char(u(i)), ...
        'mask', labels == u(i)); %#ok<AGROW>
end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('outDir', fullfile('8postprocess','csv'), ...
    'metrics', {{'AnnualMean','OSDMA8','DJF','MAM','JJA','SON','SeasonAmp'}}, ...
    'weightings', {{'area','pop'}}, ...
    'regionSets', {{'Global','world','areacode','GBD','WHO'}}, ...
    'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;

% 2 cells, 3 years. Build a cube with a known rising annual mean.
nG = 2;
yrs = 2000:2002;
yr = []; mon = []; tk = [];
for y = yrs
    for m = 1:12
        yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; %#ok<AGROW>
    end
end
% cell 1 annual mean = year-2000 (0,1,2); cell 2 = 10 + that
base = repmat(reshape(yrs-2000, 1, 1, 3), nG, 12, 1);
base(2,:,:) = base(2,:,:) + 10;
oz = reshape(base, nG, 36);
cube = struct('ozone', oz, 'year', yr, 'month', mon, 'time', tk, ...
    'nGrid', nG, 'grid', [0 0; 0 0]);

% weights: area equal, pop weights [1 3]; both cells Global only.
weights = struct('nGrid', nG, 'w_area', [1;1], 'w_pop', [1;3], ...
    'GBDRegion', ["";""], 'WHORegion', ["";""], ...
    'areaNames', {{}}, 'areaMask', false(nG,0));

[seriesT, trendsT] = annualSeasonalSeries(cube, weights, ...
    struct('regionSets', {{'Global'}}, 'metrics', {{'AnnualMean'}}, ...
           'save', 0, 'verbose', 0));

% area-weighted global annual mean year 2000 = mean(0,10)=5
a2000 = seriesT(seriesT.Weighting=="area" & seriesT.Year==2000, :);
assert(abs(a2000.Value - 5) < 1e-9, 'area-weighted 2000 = 5');
% pop-weighted year 2000 = (1*0 + 3*10)/4 = 7.5
p2000 = seriesT(seriesT.Weighting=="pop" & seriesT.Year==2000, :);
assert(abs(p2000.Value - 7.5) < 1e-9, 'pop-weighted 2000 = 7.5');
% trend: rising 1 ppb/yr -> 10 ppb/decade, significant-ish slope
tr = trendsT(trendsT.Weighting=="area", :);
assert(abs(tr.SlopePerDecade - 10) < 1e-9, 'slope 10/decade');

fprintf('annualSeasonalSeries self-test: ALL PASSED.\n');
end
