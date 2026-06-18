function weights = computeGridWeights(grid, opts)
% computeGridWeights - Area/population weights + region labels for the BME grid
%
% Builds, ONCE, everything needed to take area-weighted and population-weighted
% spatial averages and to split the grid into regions. Shared by every
% post-processing analysis (trends, seasonal, peak-month, exposure).
%
% SYNTAX:
%   weights = computeGridWeights(cube)            % cube from assembleBMEcube
%   weights = computeGridWeights(grid)            % grid = nGrid x 2 [lon lat]
%   weights = computeGridWeights(grid, opts)
%
% opts (optional):
%   .popCsv      (default fullfile('Population-Data','PopulationData2019.csv'))
%   .outDir      (default fullfile('8postprocess','cubes'))
%   .areaNames   (default {'CONUS','Europe','EastAsia'})
%   .areaCodes   (default [5 2 3])   getTOARareaBoundaries codes
%   .save        (default 1)         write 8postprocess/cubes/grid_weights.mat
%   .verbose     (default 1)
%
% OUTPUT (struct 'weights'):
%   .grid,.lon,.lat,.nGrid
%   .w_area      nGrid x 1   cos(lat) area weight (unnormalized; scale-invariant)
%   .w_pop       nGrid x 1   population summed onto each grid node (persons)
%   .popAssigned scalar      total population mapped onto the grid
%   .GBDRegion,.WHORegion,.CountryName,.ISO3   nGrid x 1 string (nearest pop cell)
%   .areaMask    nGrid x nArea logical (columns = .areaNames)
%   .areaNames,.areaCodes
%   .builtOn
%
% Run computeGridWeights('--selftest') to execute built-in unit checks.
%
% SEE ALSO: assembleBMEcube, getTOARareaBoundaries, annualSeasonalSeries

%% Self-test entry point
if nargin >= 1 && ischar(grid) && strcmp(grid, '--selftest')
    weights = local_selftest();
    return;
end

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

% Accept a cube struct or a raw grid matrix
if isstruct(grid)
    G = grid.grid;
else
    G = grid;
end
lon = G(:, 1);
lat = G(:, 2);
nGrid = size(G, 1);

%% Area weight
w_area = cosd(lat);
w_area(w_area < 0) = 0;

%% Population weight + region labels (from the population CSV)
w_pop = zeros(nGrid, 1);
GBDRegion   = strings(nGrid, 1);
WHORegion   = strings(nGrid, 1);
CountryName = strings(nGrid, 1);
ISO3        = strings(nGrid, 1);
popAssigned = 0;

if exist(opts.popCsv, 'file')
    io = detectImportOptions(opts.popCsv);
    want = {'Longitude','Latitude','POP','GBDRegion','WHORegion','CountryName','ISO3'};
    io.SelectedVariableNames = want(ismember(want, io.VariableNames));
    P = readtable(opts.popCsv, io);
    popXY = [P.Longitude, P.Latitude];
    good = all(~isnan(popXY), 2);
    P = P(good, :);
    popXY = popXY(good, :);

    % (1) population onto nodes: each pop cell -> nearest grid node, sum POP
    nodeOfCell = knnsearch(G, popXY);
    if ismember('POP', P.Properties.VariableNames)
        pop = P.POP;
        pop(isnan(pop)) = 0;
        w_pop = accumarray(nodeOfCell, pop, [nGrid 1]);
        popAssigned = sum(w_pop);
    end

    % (2) labels onto nodes: each grid node -> nearest pop cell, copy labels
    cellOfNode = knnsearch(popXY, G);
    GBDRegion   = local_label(P, 'GBDRegion',   cellOfNode, nGrid);
    WHORegion   = local_label(P, 'WHORegion',   cellOfNode, nGrid);
    CountryName = local_label(P, 'CountryName', cellOfNode, nGrid);
    ISO3        = local_label(P, 'ISO3',        cellOfNode, nGrid);
else
    warning('computeGridWeights:noPop', ...
        'Population CSV not found (%s); w_pop=0 and labels empty.', opts.popCsv);
end

%% Area-code region masks
nArea = numel(opts.areaCodes);
areaMask = false(nGrid, nArea);
for a = 1:nArea
    b = [-180 180 -90 90];   % init; overwritten inside evalc (prints suppressed)
    txt = evalc('b = getTOARareaBoundaries(opts.areaCodes(a));'); %#ok<NASGU>
    areaMask(:, a) = lon >= b(1) & lon <= b(2) & lat >= b(3) & lat <= b(4);
end

%% DeLang-style world-region labels (one exclusive label per cell, priority order)
wr = getWorldRegions();
worldNames = {wr.name};
worldRegion = strings(nGrid, 1);
for i = 1:numel(wr)
    b = wr(i).box;
    inBox = worldRegion == "" & lon >= b(1) & lon <= b(2) & lat >= b(3) & lat <= b(4);
    worldRegion(inBox) = wr(i).name;
end

%% Assemble
weights = struct();
weights.grid        = G;
weights.lon         = lon;
weights.lat         = lat;
weights.nGrid       = nGrid;
weights.w_area      = w_area;
weights.w_pop       = w_pop;
weights.popAssigned = popAssigned;
weights.GBDRegion   = GBDRegion;
weights.WHORegion   = WHORegion;
weights.CountryName = CountryName;
weights.ISO3        = ISO3;
weights.areaMask    = areaMask;
weights.areaNames   = opts.areaNames;
weights.areaCodes   = opts.areaCodes;
weights.worldRegion = worldRegion;
weights.worldNames  = worldNames;
weights.builtOn     = datestr(now); %#ok<TNOW1,DATST>

if opts.verbose
    fprintf('Grid weights: %d cells | population assigned: %.3g persons\n', ...
        nGrid, popAssigned);
    for a = 1:nArea
        fprintf('  %-10s mask: %d cells\n', opts.areaNames{a}, sum(areaMask(:, a)));
    end
end

if opts.save
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    p = fullfile(opts.outDir, 'grid_weights.mat');
    save(p, 'weights', '-v7.3');
    if opts.verbose, fprintf('  Saved weights to %s\n', p); end
end

end

% ========================================================================
function lab = local_label(P, var, idx, nGrid)
% Pull a label column as a string vector indexed by nearest-cell idx.
if ~ismember(var, P.Properties.VariableNames)
    lab = strings(nGrid, 1);
    return;
end
lab = string(P.(var));
lab = lab(idx);
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('popCsv', fullfile('Population-Data','PopulationData2019.csv'), ...
    'outDir', fullfile('8postprocess','cubes'), ...
    'areaNames', {{'CONUS','Europe','EastAsia'}}, 'areaCodes', [5 2 3], ...
    'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
        opts.(f{i}) = d.(f{i});
    end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));

% grid: four nodes
G = [0 0; 10 0; 0 60; 10 60];

% synthetic population CSV: cluster near node (10,0) and one near (0,60)
lonP = [9.9; 10.1; 10.0; 0.1];
latP = [0.1; -0.1; 0.2; 59.9];
POP  = [100;  200;  300;  50];
GBDRegion   = ["A";"A";"A";"B"];
WHORegion   = ["W1";"W1";"W1";"W2"];
CountryName = ["X";"X";"X";"Y"];
ISO3        = ["XXX";"XXX";"XXX";"YYY"];
T = table(lonP, latP, POP, GBDRegion, WHORegion, CountryName, ISO3, ...
    'VariableNames', {'Longitude','Latitude','POP','GBDRegion','WHORegion','CountryName','ISO3'});
csv = fullfile(tmp, 'pop.csv');
writetable(T, csv);

w = computeGridWeights(G, struct('popCsv', csv, 'outDir', tmp, ...
    'save', 0, 'verbose', 0));

% area weight: cos(0)=1 at equator, cos(60)=0.5
assert(abs(w.w_area(1) - 1) < 1e-9 && abs(w.w_area(3) - 0.5) < 1e-9, 'w_area');

% population: 600 persons onto node 2 (10,0); the (0.1,59.9) cell is nearest
% node 3 (0,60) -> 50 there; node 4 (10,60) gets none.
assert(abs(w.w_pop(2) - 600) < 1e-6, 'pop onto node 2');
assert(abs(w.w_pop(3) - 50)  < 1e-6, 'pop onto node 3');
assert(w.w_pop(4) == 0, 'no pop on node 4');
assert(abs(w.popAssigned - 650) < 1e-6, 'total pop');

% labels: node 2 nearest pop cells are region A / country X; node 3 is region B
assert(w.GBDRegion(2) == "A" && w.CountryName(2) == "X", 'labels node 2');
assert(w.GBDRegion(3) == "B" && w.ISO3(3) == "YYY", 'labels node 3');

% area masks exist with right shape
assert(isequal(size(w.areaMask), [4 3]), 'areaMask shape');

% world-region labels present; node 3 at (0,60) -> Europe, nodes at (10,0)/(0,0) -> Africa
assert(numel(w.worldNames) == 8, 'eight world names');
assert(w.worldRegion(3) == "Europe", 'node3 Europe');
assert(w.worldRegion(1) == "Africa" && w.worldRegion(2) == "Africa", 'equator nodes Africa');

fprintf('computeGridWeights self-test: ALL PASSED.\n');
end
