function cube = composeBestMethodCube(cubes, bestByYear, opts)
% composeBestMethodCube - Stitch a per-year best-method cube (decision D2)
%
% Given per-method cubes (all on the SAME grid and time axis) and a table of the
% best method for each year, builds a composite cube whose every year's months
% are taken from that year's best-validating method.
%
% SYNTAX:
%   cube = composeBestMethodCube(cubes, bestByYear)
%   cube = composeBestMethodCube(cubes, bestByYear, opts)
%
% INPUTS:
%   cubes      - containers.Map: method string -> cube (from assembleBMEcube)
%   bestByYear - table with columns Year and BestMethod (from bestMethodByYear)
%   opts       - (optional): .fallbackMethod (method string used for years not in
%                the table or whose best method is unavailable; default '' = NaN)
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

methods = keys(cubes);
ref = cubes(methods{1});

% Validate shared grid + time across all method cubes
for i = 2:numel(methods)
    c = cubes(methods{i});
    if ~isequal(size(c.grid), size(ref.grid)) || max(abs(c.grid(:)-ref.grid(:))) > 1e-6
        error('composeBestMethodCube:grid', 'Method %s grid differs.', methods{i});
    end
    if numel(c.time) ~= numel(ref.time) || max(abs(c.time - ref.time)) > 1e-6
        error('composeBestMethodCube:time', 'Method %s time axis differs.', methods{i});
    end
end

nMonths = numel(ref.time);
cube = ref;
cube.method = 'best-per-year';
cube.ozone = nan(ref.nGrid, nMonths);
cube.ozoneVar = nan(ref.nGrid, nMonths);
cube.sourceMethod = strings(1, nMonths);

bestYears = bestByYear.Year;
bestMeth  = string(bestByYear.BestMethod);

for c = 1:nMonths
    y = ref.year(c);
    chosen = "";
    k = find(bestYears == y, 1);
    if ~isempty(k) && isKey(cubes, char(bestMeth(k)))
        chosen = bestMeth(k);
    elseif ~isempty(opts.fallbackMethod) && isKey(cubes, opts.fallbackMethod)
        chosen = string(opts.fallbackMethod);
    end
    if chosen ~= ""
        src = cubes(char(chosen));
        cube.ozone(:, c) = src.ozone(:, c);
        if isfield(src, 'ozoneVar'), cube.ozoneVar(:, c) = src.ozoneVar(:, c); end
        cube.sourceMethod(c) = chosen;
    end
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

fprintf('composeBestMethodCube self-test: ALL PASSED.\n');
end
