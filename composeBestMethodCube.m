function cube = composeBestMethodCube(cubes, bestByYear, opts)
% composeBestMethodCube - Stitch a per-year best-method cube (decision D2)
%
% Given per-method cubes and a table of the best method for each year, builds a
% composite cube whose every year's months are taken from that year's
% best-validating method.
%
% The per-method cubes need NOT share a grid or a time axis: they are reconciled
% onto (a) a UNION monthly time axis spanning the full min->max year across all
% cubes, and (b) a COMMON grid formed by intersecting the method grids by
% coordinate. When every cube already shares one grid/axis (the legacy case),
% both operations are no-ops and the output matches the original behavior. This
% lets disjoint-era methods (e.g. 13000313-02 for 1990-2004 and 10000133 for
% 2022) be composed into one 1990-2022 cube.
%
% SYNTAX:
%   cube = composeBestMethodCube(cubes, bestByYear)
%   cube = composeBestMethodCube(cubes, bestByYear, opts)
%
% INPUTS:
%   cubes      - containers.Map: method string -> cube (from assembleBMEcube)
%   bestByYear - table with columns Year and BestMethod (from bestMethodByYear)
%   opts       - (optional):
%                .fallbackMethod (method string used for years not in the table
%                    or whose best method is unavailable; default '' = NaN)
%                .gridTolDeg     (coordinate-match tolerance for grid
%                    intersection, default 1e-4)
%
% OUTPUT (struct 'cube'):
%   same fields as an assembleBMEcube cube, plus
%   .sourceMethod  1 x nMonths string (which method each month came from)
%   .method = 'best-per-year'
%
% Run composeBestMethodCube('--selftest') to execute built-in unit checks.
%
% SEE ALSO: assembleBMEcube, bestMethodByYear, runPostprocess

%% Self-test entry point
if nargin >= 1 && (ischar(cubes) || isstring(cubes)) && strcmp(cubes, '--selftest')
    cube = local_selftest();
    return;
end

if nargin < 3 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'fallbackMethod'), opts.fallbackMethod = ''; end
if ~isfield(opts, 'gridTolDeg') || isempty(opts.gridTolDeg), opts.gridTolDeg = 1e-4; end

methods = keys(cubes);
ref = cubes(methods{1});

% ---- Common grid = intersection of the method grids (by coordinate) ---------
% Legacy case (all grids identical) reduces to the shared grid unchanged.
scl = 1 / max(opts.gridTolDeg, eps);
refKey = unique(round(ref.grid * scl), 'rows');
for i = 2:numel(methods)
    c = cubes(methods{i});
    refKey = intersect(refKey, round(c.grid * scl), 'rows');
end
if isempty(refKey)
    error('composeBestMethodCube:noCommonGrid', ...
        ['Method cubes share no common grid cells (tol=%g deg). ' ...
         'Were they produced with the same grid config / offset?'], opts.gridTolDeg);
end
grid = refKey / scl;
nGrid = size(grid, 1);

% Per-method row map: composite grid cell -> that method's row index (NaN=absent)
rowMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(methods)
    c = cubes(methods{i});
    [tf, loc] = ismember(refKey, round(c.grid * scl), 'rows');
    idx = nan(nGrid, 1);
    idx(tf) = loc(tf);
    rowMap(methods{i}) = idx;
end

% ---- Union monthly time axis over min..max year across all cubes ------------
y0 = inf; y1 = -inf;
for i = 1:numel(methods)
    c = cubes(methods{i});
    y0 = min(y0, min(c.year));
    y1 = max(y1, max(c.year));
end
uYears = y0:y1;
time  = reshape((uYears' + (0:11)/12).', 1, []);   % [y+0/12 ... y+11/12] per year
time  = sort(time);
year  = floor(time + 1e-6);
month = round((time - year) * 12) + 1;
nMonths = numel(time);

% Per-method column map: composite month -> that method's column index (NaN=absent)
colMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
tKey = round(time * 12);
for i = 1:numel(methods)
    c = cubes(methods{i});
    [tf, loc] = ismember(tKey, round(c.time * 12));
    idx = nan(1, nMonths);
    idx(tf) = loc(tf);
    colMap(methods{i}) = idx;
end

% ---- Assemble composite -----------------------------------------------------
cube = ref;
cube.method   = 'best-per-year';
cube.grid     = grid;
cube.lon      = grid(:, 1);
cube.lat      = grid(:, 2);
cube.time     = time;
cube.year     = year;
cube.month    = month;
cube.nGrid    = nGrid;
cube.nMonths  = nMonths;
cube.ozone    = nan(nGrid, nMonths);
cube.ozoneVar = nan(nGrid, nMonths);
cube.sourceMethod = strings(1, nMonths);
if isfield(cube, 'files'), cube = rmfield(cube, 'files'); end

bestYears = bestByYear.Year;
bestMeth  = string(bestByYear.BestMethod);

for c = 1:nMonths
    y = year(c);
    chosen = "";
    k = find(bestYears == y, 1);
    if ~isempty(k) && isKey(cubes, char(bestMeth(k)))
        chosen = bestMeth(k);
    elseif ~isempty(opts.fallbackMethod) && isKey(cubes, opts.fallbackMethod)
        chosen = string(opts.fallbackMethod);
    end
    if chosen == "", continue; end

    src = cubes(char(chosen));
    ri  = rowMap(char(chosen));      % nGrid x 1 source rows (NaN where absent)
    ci  = colMap(char(chosen));      % 1 x nMonths source cols
    sc  = ci(c);
    if isnan(sc), continue; end      % this method has no file for this month

    have = ~isnan(ri);
    cube.ozone(have, c) = src.ozone(ri(have), sc);
    if isfield(src, 'ozoneVar')
        cube.ozoneVar(have, c) = src.ozoneVar(ri(have), sc);
    end
    cube.sourceMethod(c) = chosen;
end

end

% ========================================================================
function ok = local_selftest()
ok = true;

% Two methods, same grid/time (2 cells x 24 months over 2 years).
yr = []; mon = []; tk = [];
for y = 2000:2001
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
nG = 2; n = numel(tk);
mk = @(val) struct('grid',[0 0;1 1],'time',tk,'year',yr,'month',mon, ...
    'nGrid',nG,'lon',[0;1],'lat',[0;1],'ozone',val*ones(nG,n), ...
    'ozoneVar',ones(nG,n),'method','x');

cubes = containers.Map();
cubes('AAA') = mk(10);     % method AAA -> all 10
cubes('BBB') = mk(20);     % method BBB -> all 20

best = table([2000;2001], ["BBB";"AAA"], 'VariableNames', {'Year','BestMethod'});
cube = composeBestMethodCube(cubes, best);

% Year 2000 columns should come from BBB (=20), year 2001 from AAA (=10)
y2000 = cube.year == 2000;
y2001 = cube.year == 2001;
assert(all(cube.ozone(1, y2000) == 20), '2000 from BBB');
assert(all(cube.ozone(1, y2001) == 10), '2001 from AAA');
assert(all(cube.sourceMethod(y2000) == "BBB"), 'source 2000');
assert(all(cube.sourceMethod(y2001) == "AAA"), 'source 2001');

% Fallback: a year with no best entry -> NaN unless fallback given
best2 = table(2000, "BBB", 'VariableNames', {'Year','BestMethod'});
c2 = composeBestMethodCube(cubes, best2);
assert(all(isnan(c2.ozone(1, c2.year == 2001))), '2001 NaN without fallback');
c3 = composeBestMethodCube(cubes, best2, struct('fallbackMethod','AAA'));
assert(all(c3.ozone(1, c3.year == 2001) == 10), '2001 uses fallback AAA');

% ---- Disjoint eras: two methods on non-overlapping years, differing grids ---
% EARLY covers 1990 only; LATE covers 1992 only; grids overlap on cells [0 0;1 1]
% but each carries an extra cell the other lacks (mimics per-year site points).
mkYr = @(yrsSet, grid, val) local_mkcube(yrsSet, grid, val);
gE = [0 0; 1 1; 9 9];    % EARLY has extra cell [9 9]
gL = [0 0; 1 1; 8 8];    % LATE  has extra cell [8 8]
cubesD = containers.Map();
cubesD('EARLY') = mkYr(1990, gE, 11);
cubesD('LATE')  = mkYr(1992, gL, 22);   % note: gap year 1991 has no source

bestD = table([1990;1992], ["EARLY";"LATE"], 'VariableNames', {'Year','BestMethod'});
cD = composeBestMethodCube(cubesD, bestD);

assert(cD.nMonths == 36, 'union axis spans 1990-1992 (36 months)');
assert(isequal(unique(cD.year(:)'), 1990:1992), 'union years 1990..1992');
assert(cD.nGrid == 2, 'common grid = intersection [0 0;1 1]');
assert(all(cD.ozone(1, cD.year == 1990) == 11), '1990 from EARLY');
assert(all(cD.ozone(1, cD.year == 1992) == 22), '1992 from LATE');
assert(all(isnan(cD.ozone(1, cD.year == 1991))), '1991 gap -> NaN');
assert(all(cD.sourceMethod(cD.year == 1990) == "EARLY"), 'source 1990');
assert(all(cD.sourceMethod(cD.year == 1991) == ""), 'source 1991 empty');

fprintf('composeBestMethodCube self-test: ALL PASSED.\n');
end

% ========================================================================
function c = local_mkcube(yrsSet, grid, val)
% Minimal single-method cube spanning the given years (12 months each) on `grid`.
yr = []; mon = []; tk = [];
for y = yrsSet
    for m = 1:12, yr(end+1)=y; mon(end+1)=m; tk(end+1)=y+(m-1)/12; end %#ok<AGROW>
end
nG = size(grid, 1); n = numel(tk);
c = struct('grid', grid, 'time', tk, 'year', yr, 'month', mon, ...
    'nGrid', nG, 'lon', grid(:,1), 'lat', grid(:,2), ...
    'ozone', val*ones(nG, n), 'ozoneVar', ones(nG, n), 'method', 'x');
end
