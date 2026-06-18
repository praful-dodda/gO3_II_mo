function cube = assembleBMEcube(method, opts)
% assembleBMEcube - Consolidate monthly BME estimate files into one data cube
%
% Loads every monthly 5BMEspatialPlots/BME<method>..._time<tk>.mat file for a
% given method/config and stacks the MDA8 estimates (and variance) into a
% [nGrid x nMonths] cube on a single shared grid. This cube is the foundation
% for all the post-processing analyses (trends, seasonal, peak-month, exposure).
%
% SYNTAX:
%   cube = assembleBMEcube(method)
%   cube = assembleBMEcube(method, opts)
%
% INPUTS:
%   method - BME method string as it appears in the filename, e.g. '13000313-02'
%   opts   - (optional) struct with any of:
%       .goScenario    (default 3)      .logTransf    (default 0)
%       .areaCode      (default 0)      .mapResolution(default 1.0)
%       .dataFormat    (default 'stug') .keepOnlyLand (default 1)
%       .srcDir        (default '5BMEspatialPlots')
%       .outDir        (default fullfile('8postprocess','cubes'))
%       .yearRange     (default [] = all years found)  e.g. [1990 2022]
%       .forceReload   (default 0)   1 = rebuild even if cache exists
%       .saveCache     (default 1)   0 = do not write the cache .mat
%       .verbose       (default 1)
%       .gridMode      ('intersect' (default) | 'strict')
%                      Per-year estimation grids differ because monitoring-site
%                      locations are appended to the lattice; 'intersect' stacks
%                      onto the common cells across months. 'strict' errors on any
%                      grid difference.
%       .gridTolDeg    (default 1e-4) coordinate-match tolerance for the grid
%
% OUTPUT (struct 'cube'):
%   .method, .fileBase
%   .grid      nGrid x 2   [lon lat] (from BMEs.sk; asserted identical across files)
%   .lon,.lat  nGrid x 1
%   .time      1 x nMonths decimal years (sorted)
%   .year      1 x nMonths integer year
%   .month     1 x nMonths integer month (1-12)
%   .ozone     nGrid x nMonths   MDA8 estimate (ppb)   <-- main variable (YkBMEm)
%   .ozoneVar  nGrid x nMonths   estimation variance (XkBMEv)
%   .nGrid, .nMonths, .builtOn, .files
%
% Run assembleBMEcube('--selftest') to execute built-in unit checks.
%
% SEE ALSO: computeGridWeights, computeOSDMA8, trendSenMK

%% Self-test entry point
if nargin >= 1 && ischar(method) && strcmp(method, '--selftest')
    cube = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

%% Build file base + cache path
fileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', ...
    method, opts.goScenario, opts.logTransf, opts.areaCode, ...
    opts.mapResolution, opts.dataFormat, opts.keepOnlyLand);

cacheName = sprintf('cube_%s.mat', regexprep(fileBase, '[^a-zA-Z0-9]', '_'));
cachePath = fullfile(opts.outDir, cacheName);

if exist(cachePath, 'file') && ~opts.forceReload
    if opts.verbose, fprintf('Loading cached cube: %s\n', cachePath); end
    S = load(cachePath, 'cube');
    cube = S.cube;
    return;
end

%% Glob monthly files
pattern = fullfile(opts.srcDir, sprintf('%s_time*.mat', fileBase));
files = dir(pattern);
if isempty(files)
    error('assembleBMEcube:noFiles', 'No files match: %s', pattern);
end
if opts.verbose
    fprintf('Found %d monthly files for %s\n', numel(files), fileBase);
end

%% Single pass: load each file once (tk, grid coordinate keys, values)
% The estimation grid appends per-year monitoring-site locations to the stable
% map lattice (estTOARsBMEoptim.m), so grids differ month to month. We therefore
% stack onto the COMMON grid across months (the stable lattice) rather than
% requiring identical grids.
nF = numel(files);
tkAll = nan(nF, 1);
keyCell = cell(nF, 1);   % integer coordinate keys per file (nCells x 2)
yCell   = cell(nF, 1);   % YkBMEm per file
vCell   = cell(nF, 1);   % XkBMEv per file
scl = 1 / max(opts.gridTolDeg, eps);
for i = 1:nF
    S = load(fullfile(files(i).folder, files(i).name), 'BMEs');
    B = S.BMEs;
    tkAll(i)   = B.tk;
    keyCell{i} = round(B.sk * scl);
    yCell{i}   = B.YkBMEm(:);
    if isfield(B, 'XkBMEv')
        vCell{i} = B.XkBMEv(:);
    else
        vCell{i} = nan(numel(B.YkBMEm), 1);
    end
end
[tkSorted, order] = sort(tkAll);
keyCell = keyCell(order); yCell = yCell(order); vCell = vCell(order);
files = files(order);

% Optional year filtering
if ~isempty(opts.yearRange)
    yrs = floor(tkSorted + 1e-6);
    keep = yrs >= opts.yearRange(1) & yrs <= opts.yearRange(2);
    files = files(keep); tkSorted = tkSorted(keep);
    keyCell = keyCell(keep); yCell = yCell(keep); vCell = vCell(keep);
end
nMonths = numel(tkSorted);
if nMonths == 0
    error('assembleBMEcube:noFilesInRange', 'No files within year range.');
end

% Duplicate-time check
if numel(unique(round(tkSorted*12))) < nMonths
    warning('assembleBMEcube:dupTime', 'Duplicate time slices detected; keeping all.');
end

%% Reference grid = common cells across all months (robust to per-year sites)
if strcmpi(opts.gridMode, 'strict')
    refKey = keyCell{1};
    for i = 2:nMonths
        if ~isequal(keyCell{i}, refKey)
            error('assembleBMEcube:gridMismatch', ...
                'Grid in %s differs (gridMode=strict).', files(i).name);
        end
    end
else   % 'intersect' (default)
    refKey = unique(keyCell{1}, 'rows');
    for i = 2:nMonths
        refKey = intersect(refKey, keyCell{i}, 'rows');
    end
end
if isempty(refKey)
    error('assembleBMEcube:noCommonGrid', ...
        ['Monthly grids share no common cells (tol=%g deg). ' ...
         'Were they produced with the same grid config / offset?'], opts.gridTolDeg);
end
nGrid = size(refKey, 1);
refGrid = refKey / scl;

%% Stack values onto the reference grid
ozone = nan(nGrid, nMonths);
ozoneVar = nan(nGrid, nMonths);
for i = 1:nMonths
    [tf, loc] = ismember(refKey, keyCell{i}, 'rows');
    ozone(tf, i)    = yCell{i}(loc(tf));
    ozoneVar(tf, i) = vCell{i}(loc(tf));
end
if opts.verbose
    n1 = size(keyCell{1}, 1);
    fprintf('  Common grid: %d cells (first month had %d; %d non-common dropped)\n', ...
        nGrid, n1, n1 - nGrid);
end

%% Build time bookkeeping + assemble output
year = floor(tkSorted(:).' + 1e-6);
month = round((tkSorted(:).' - year) * 12) + 1;

cube = struct();
cube.method     = method;
cube.fileBase   = fileBase;
cube.grid       = refGrid;
cube.lon        = refGrid(:, 1);
cube.lat        = refGrid(:, 2);
cube.time       = tkSorted(:).';
cube.year       = year;
cube.month      = month;
cube.ozone      = ozone;
cube.ozoneVar   = ozoneVar;
cube.nGrid      = size(refGrid, 1);
cube.nMonths    = nMonths;
cube.builtOn    = datestr(now); %#ok<TNOW1,DATST>
cube.files      = {files.name};

%% Sanity report
if opts.verbose
    nanPerMonth = sum(isnan(ozone), 1);
    fprintf('  Cube: %d grid cells x %d months (%.2f - %.2f)\n', ...
        cube.nGrid, nMonths, cube.time(1), cube.time(end));
    fprintf('  Months fully NaN: %d ; max NaN in a month: %d/%d\n', ...
        sum(nanPerMonth == cube.nGrid), max(nanPerMonth), cube.nGrid);
    expMonths = round((cube.time(end) - cube.time(1)) * 12) + 1;
    if expMonths ~= nMonths
        fprintf('  NOTE: %d months present but span implies %d (gaps exist).\n', ...
            nMonths, expMonths);
    end
end

%% Cache
if opts.saveCache
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    save(cachePath, 'cube', '-v7.3');
    if opts.verbose, fprintf('  Saved cube to %s\n', cachePath); end
end

end

% ========================================================================
function opts = local_defaults(opts)
d = struct('goScenario', 3, 'logTransf', 0, 'areaCode', 0, ...
    'mapResolution', 1.0, 'dataFormat', 'stug', 'keepOnlyLand', 1, ...
    'srcDir', '5BMEspatialPlots', 'outDir', fullfile('8postprocess', 'cubes'), ...
    'yearRange', [], 'forceReload', 0, 'saveCache', 1, 'verbose', 1, ...
    'gridMode', 'intersect', 'gridTolDeg', 1e-4);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
        if ~(strcmp(f{i}, 'yearRange'))   % yearRange may legitimately be []
            opts.(f{i}) = d.(f{i});
        elseif ~isfield(opts, f{i})
            opts.(f{i}) = d.(f{i});
        end
    end
end
end

% ========================================================================
function ok = local_selftest()
% Build synthetic monthly files in a temp dir and verify the stacking.
ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));

method = '13000313-02';
fileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', ...
    method, 3, 0, 0, 1.0, 'stug', 1);

% small 4-cell grid, 3 years x 12 months = 36 files, written out of order
sk = [0 0; 10 0; 0 10; 10 10];
nGrid = size(sk, 1);
yrs = 1990:1992;
tks = [];
for y = yrs
    for m = 1:12
        tks(end+1) = y + (m-1)/12; %#ok<AGROW>
    end
end
tks = tks(randperm(numel(tks)));     % scramble write order
for k = 1:numel(tks)
    tk = tks(k);
    BMEs = struct();
    BMEs.sk = sk;
    BMEs.tk = tk;
    BMEs.YkBMEm = (40 + 5*sin(2*pi*tk) + (1:nGrid)')';  % deterministic-ish
    BMEs.YkBMEm = BMEs.YkBMEm(:);
    BMEs.XkBMEv = ones(nGrid, 1);
    fn = fullfile(tmp, sprintf('%s_time%.2f.mat', fileBase, tk));
    save(fn, 'BMEs');
end

cube = assembleBMEcube(method, struct('srcDir', tmp, 'outDir', tmp, ...
    'saveCache', 0, 'verbose', 0));

assert(cube.nGrid == nGrid, 'nGrid');
assert(cube.nMonths == 36, 'nMonths');
assert(issorted(cube.time), 'time sorted');
assert(isequal(cube.year(1:12), repmat(1990, 1, 12)), 'year mapping');
assert(isequal(cube.month(1:12), 1:12), 'month mapping');
assert(cube.month(1) == 1 && cube.month(12) == 12, 'jan..dec');
assert(isequal(size(cube.ozone), [nGrid 36]), 'ozone shape');
assert(~any(isnan(cube.ozone(:))), 'no NaNs in synthetic cube');

% year-range filtering
cube2 = assembleBMEcube(method, struct('srcDir', tmp, 'outDir', tmp, ...
    'saveCache', 0, 'verbose', 0, 'yearRange', [1991 1991]));
assert(cube2.nMonths == 12 && all(cube2.year == 1991), 'year range filter');

% Heterogeneous grids: each month carries the common 4-cell lattice PLUS a
% different appended "station" point (mimics estTOARsBMEoptim's [sk; obs.sMS]).
% Intersection must recover the common 4 cells with no error and no NaN.
tmp2 = tempname; mkdir(tmp2);
cleaner2 = onCleanup(@() rmdir(tmp2, 's'));
for y = 1990:1991
    for m = 1:12
        tk = y + (m-1)/12;
        extra = [100 + m + 12*(y-1990), 50];   % a unique station point per month
        skH = [sk; extra];
        BMEs = struct('sk', skH, 'tk', tk, ...
            'YkBMEm', (1:size(skH,1))', 'XkBMEv', ones(size(skH,1),1));
        save(fullfile(tmp2, sprintf('%s_time%.2f.mat', fileBase, tk)), 'BMEs');
    end
end
cubeH = assembleBMEcube(method, struct('srcDir', tmp2, 'outDir', tmp2, ...
    'saveCache', 0, 'verbose', 0));
assert(cubeH.nGrid == nGrid, 'intersection recovers common lattice');
assert(cubeH.nMonths == 24, 'heterogeneous nMonths');
assert(~any(isnan(cubeH.ozone(:))), 'common cells fully populated');

% strict mode must reject heterogeneous grids
threw = false;
try
    assembleBMEcube(method, struct('srcDir', tmp2, 'outDir', tmp2, ...
        'saveCache', 0, 'verbose', 0, 'gridMode', 'strict'));
catch
    threw = true;
end
assert(threw, 'strict mode errors on differing grids');

fprintf('assembleBMEcube self-test: ALL PASSED.\n');
end
