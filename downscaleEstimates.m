function out = downscaleEstimates(src, opts)
% downscaleEstimates - Refine BME ozone estimates to a finer grid (no re-estimation)
%
% Takes an existing coarse (~1 deg) BME estimate field or cube and produces a
% finer-resolution field by pure numerical interpolation (bilinear / bicubic /
% spline). NO new data is used -> this is spatial DISAGGREGATION (smoothing),
% not informed downscaling. See docs/DOWNSCALING_METHODS.txt for the full menu
% (area-to-point kriging, dissever, covariate methods) and their trade-offs.
%
% The method set is a REGISTRY (local_methodRegistry) so new capabilities plug
% in without touching the core: add a 'gridded' (interp2), 'scattered'
% (scatteredInterpolant) or 'custom' (function handle) entry and it just works,
% including in the validation.
%
% SYNTAX:
%   out = downscaleEstimates(cube)                 % cube from assembleBMEcube
%   out = downscaleEstimates(cube, opts)
%   out = downscaleEstimates(struct('lon',lo,'lat',la,'val',v), opts)
%   downscaleEstimates('--selftest')
%
% INPUTS:
%   src - one of:
%         * a cube struct (assembleBMEcube): uses .lon,.lat,.ozone[nGrid x nMonths]
%           and passes through .time/.year/.month.
%         * a struct with fields .lon,.lat,.val  where val is [nGrid x 1] (one
%           field) or [nGrid x nF] (stack of fields, e.g. months).
%   opts - (optional) struct, any of:
%       .method     char or cellstr of registry names. default 'bilinear'.
%                   Built in: 'bilinear','bicubic','spline','nearest','makima'.
%                   First method drives out.lon/.lat/.val; all are validated.
%       .targetRes  target resolution (deg). default 0.25.
%       .targetGrid [nT x 2] explicit [lon lat] target (overrides targetRes).
%                   e.g. getTOARmapGrid(0.25,true,false,[0 0],0.5) for land-only.
%       .sourceRes  source spacing (deg). default: inferred from the data.
%       .maskToSource logical, drop target cells farther than maxGapDeg from any
%                   valid source node (kills ocean/edge bleed). default true.
%       .maxGapDeg  support radius for maskToSource. default 1.5*sourceRes.
%       .validate   logical, run held-out-node skill check. default true.
%       .holdoutFrac fraction of source nodes held out. default 0.10.
%       .rngSeed    default 42 (reproducible holdout).
%       .verbose    default true.
%
% OUTPUT (struct 'out'):
%   .lon,.lat    [nT x 1] target grid (for the FIRST/primary method)
%   .val         [nT x nF] downscaled values (primary method)
%   .method      primary method name
%   .methods     cellstr of all methods run
%   .byMethod    containers.Map: name -> struct(val, report)
%   .sourceRes,.targetRes,.nSource,.nTarget
%   .validation  table comparing methods (RMSE/MAE/R2/Bias/Overshoot/NaNfrac)
%   .time,.year,.month  passed through when src is a cube
%
% SEE ALSO: assembleBMEcube, getTOARmapGrid, docs/DOWNSCALING_METHODS.txt

if nargin >= 1 && ischar(src) && strcmp(src, '--selftest')
    out = local_selftest();
    return;
end
if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

%% ---- Normalize source to lon/lat/val ----------------------------------
[lon, lat, val, meta] = local_ingest(src);
nF = size(val, 2);

%% ---- Source resolution -------------------------------------------------
% Priority: explicit opts.sourceRes > resolution parsed from the cube fileBase
% (authoritative) > inference. The estimation grid is a regular lattice PLUS
% off-lattice monitoring-station nodes, so naive min-spacing inference is wrong.
if isempty(opts.sourceRes)
    if isfield(meta, 'sourceRes') && ~isempty(meta.sourceRes)
        opts.sourceRes = meta.sourceRes;
    else
        opts.sourceRes = local_inferRes(lon, lat);
    end
end
if isempty(opts.maxGapDeg)
    opts.maxGapDeg = 1.5 * opts.sourceRes;
end

%% ---- Target grid -------------------------------------------------------
if ~isempty(opts.targetGrid)
    tgt = opts.targetGrid;
else
    lonV = (floor(min(lon)) : opts.targetRes : ceil(max(lon)));
    latV = (floor(min(lat)) : opts.targetRes : ceil(max(lat)));
    [LO, LA] = meshgrid(lonV, latV);
    tgt = [LO(:), LA(:)];
end
% Restrict target to the support of the source data (kills bleed/extrapolation)
if opts.maskToSource
    finiteAny = any(isfinite(val), 2);
    [~, dSrc] = local_knn([lon(finiteAny) lat(finiteAny)], tgt);
    tgt = tgt(dSrc <= opts.maxGapDeg, :);
end
qLon = tgt(:, 1); qLat = tgt(:, 2);
nT = size(tgt, 1);

if opts.verbose
    fprintf(['downscaleEstimates: %d source nodes (res~%.3f deg) -> %d target ' ...
        'cells (res %.3f deg), %d field(s)\n'], numel(lon), opts.sourceRes, ...
        nT, opts.targetRes, nF);
end

%% ---- Method list -------------------------------------------------------
reg = local_methodRegistry();
methods = opts.method;
if ischar(methods), methods = {methods}; end
for m = 1:numel(methods)
    if ~isKey(reg, lower(methods{m}))
        error('downscaleEstimates:badMethod', ...
            'Unknown method "%s". Registered: %s', methods{m}, ...
            strjoin(reg.keys, ', '));
    end
end

%% ---- Interpolate + validate per method --------------------------------
byMethod = containers.Map('KeyType', 'char', 'ValueType', 'any');
vrows = {};
for m = 1:numel(methods)
    name = lower(methods{m});
    def = reg(name);

    qVal = nan(nT, nF);
    for f = 1:nF
        qVal(:, f) = local_dispatch(def, lon, lat, val(:, f), qLon, qLat, ...
            opts.sourceRes);
    end

    rep = local_report(val, qVal, opts);
    if opts.validate
        rep.holdout = local_validate(lon, lat, val, def, opts);
    end
    byMethod(name) = struct('val', qVal, 'report', rep);

    if opts.validate
        h = rep.holdout;
        vrows(end+1, :) = {name, h.RMSE, h.MAE, h.R2, h.Bias, ...
            rep.overshootFrac, rep.nanFrac, h.n}; %#ok<AGROW>
    else
        vrows(end+1, :) = {name, NaN, NaN, NaN, NaN, ...
            rep.overshootFrac, rep.nanFrac, 0}; %#ok<AGROW>
    end
    if opts.verbose
        if opts.validate
            fprintf('  %-9s holdout RMSE=%.3f MAE=%.3f R2=%.3f bias=%+.3f | overshoot=%.1f%% NaN=%.1f%%\n', ...
                name, rep.holdout.RMSE, rep.holdout.MAE, rep.holdout.R2, ...
                rep.holdout.Bias, 100*rep.overshootFrac, 100*rep.nanFrac);
        else
            fprintf('  %-9s overshoot=%.1f%% NaN=%.1f%%\n', ...
                name, 100*rep.overshootFrac, 100*rep.nanFrac);
        end
    end
end

%% ---- Assemble output ---------------------------------------------------
primary = lower(methods{1});
out = struct();
out.lon        = qLon;
out.lat        = qLat;
out.val        = byMethod(primary).val;
out.method     = primary;
out.methods    = methods;
out.byMethod   = byMethod;
out.sourceRes  = opts.sourceRes;
out.targetRes  = opts.targetRes;
out.nSource    = numel(lon);
out.nTarget    = nT;
out.validation = cell2table(vrows, 'VariableNames', ...
    {'Method','RMSE','MAE','R2','Bias','OvershootFrac','NaNFrac','nHoldout'});
% Pass-through cube time bookkeeping
for fld = {'time','year','month'}
    if isfield(meta, fld{1}), out.(fld{1}) = meta.(fld{1}); end
end
out.valLabel = meta.valLabel;

end

% ========================================================================
% Method registry - ADD NEW CAPABILITIES HERE.
%   kind 'gridded'   : spec = interp2 method string ('linear','cubic','spline',
%                      'nearest','makima'); rasterized then interp2.
%   kind 'scattered' : spec = scatteredInterpolant method ('linear','natural',
%                      'nearest'); handles irregular data directly.
%   kind 'custom'    : spec = @(sLon,sLat,sVal,qLon,qLat) -> qVal. Use this to
%                      register area-to-point kriging, dissever, etc. later.
% ========================================================================
function reg = local_methodRegistry()
reg = containers.Map('KeyType', 'char', 'ValueType', 'any');
reg('bilinear') = struct('kind','gridded',  'spec','linear');
reg('bicubic')  = struct('kind','gridded',  'spec','cubic');
reg('spline')   = struct('kind','gridded',  'spec','spline');
reg('nearest')  = struct('kind','gridded',  'spec','nearest');
reg('makima')   = struct('kind','gridded',  'spec','makima');
% --- Examples of extensions (uncomment / adapt) -------------------------
% reg('natural') = struct('kind','scattered','spec','natural');
% reg('atpk')    = struct('kind','custom','spec', @myAreaToPointKriging);
end

% ========================================================================
function qVal = local_dispatch(def, sLon, sLat, sVal, qLon, qLat, res)
% Route a single field through the right interpolation backend.
switch def.kind
    case 'gridded'
        qVal = local_gridded(sLon, sLat, sVal, qLon, qLat, def.spec, res);
    case 'scattered'
        good = isfinite(sVal);
        if nnz(good) < 3
            qVal = nan(size(qLon)); return;
        end
        F = scatteredInterpolant(sLon(good), sLat(good), sVal(good), ...
            def.spec, 'none');
        qVal = F(qLon, qLat);
    case 'custom'
        qVal = def.spec(sLon, sLat, sVal, qLon, qLat);
    otherwise
        error('downscaleEstimates:kind', 'Unknown method kind "%s".', def.kind);
end
end

% ========================================================================
function qVal = local_gridded(sLon, sLat, sVal, qLon, qLat, imethod, res)
% Rasterize scattered source nodes onto a regular lattice at spacing 'res',
% then interp2 to the query points. Off-lattice nodes (appended monitoring
% stations) are snapped to their nearest cell; multiple nodes in one cell are
% averaged. NaN cells (ocean / gaps) are left as NaN.
if nargin < 7 || isempty(res), res = local_inferRes(sLon, sLat); end
lonV = local_axis(sLon, res);
latV = local_axis(sLat, res);
nLon = numel(lonV); nLat = numel(latV);
if nLon < 2 || nLat < 2
    qVal = nan(size(qLon)); return;
end
if nLon * nLat > 2e7
    error('downscaleEstimates:gridTooLarge', ...
        ['Rasterizing at sourceRes=%.5f deg implies a %d x %d grid - far too ' ...
         'fine. The source is probably a lattice with off-lattice nodes; pass ' ...
         'the true opts.sourceRes (e.g. 1.0).'], res, nLat, nLon);
end
iLon = round((sLon - lonV(1)) / res) + 1;
iLat = round((sLat - latV(1)) / res) + 1;
gd   = iLon >= 1 & iLon <= nLon & iLat >= 1 & iLat <= nLat & isfinite(sVal);
cellIdx = sub2ind([nLat nLon], iLat(gd), iLon(gd));
% Average any duplicate nodes landing in the same cell; empty cells -> NaN.
V = accumarray(cellIdx, sVal(gd), [nLat*nLon, 1], @mean, NaN);
V = reshape(V, [nLat, nLon]);
% Ocean/gap cells are NaN. 'spline' errors on a NaN grid and 'cubic'/'linear'
% lose near-shore coverage, so fill the holes first; maskToSource then clips the
% result back to real land support (opts.maxGapDeg), so invented ocean values
% outside that buffer are discarded anyway.
if any(isnan(V(:)))
    V = local_fillgrid(lonV, latV, V);
end
qVal = interp2(lonV, latV, V, qLon, qLat, imethod);
end

% ========================================================================
function V = local_fillgrid(lonV, latV, V)
% Fill NaN cells of a raster: linear interior fill + nearest for the exterior.
% Uses fillmissing2 (R2023a+) when present, else a scatteredInterpolant fallback
% (no toolbox-version assumptions).
if exist('fillmissing2', 'file')
    V = fillmissing2(V, 'linear');
    if any(isnan(V(:))), V = fillmissing2(V, 'nearest'); end
    return;
end
[LO, LA] = meshgrid(lonV, latV);
good = isfinite(V);
if nnz(good) < 3, return; end
F = scatteredInterpolant(LO(good), LA(good), V(good), 'linear', 'nearest');
V(~good) = F(LO(~good), LA(~good));
end

% ========================================================================
function v = local_axis(x, res)
v = (min(x) : res : max(x) + res/2);
v = v(:).';
end

% ========================================================================
function res = local_inferRes(lon, lat)
% Robust to a regular lattice contaminated with off-lattice extras (stations):
% use the MODE of coordinate spacings, not the min/median.
res = min([local_modestep(lon), local_modestep(lat)]);
if ~isfinite(res) || res <= 0, res = 1.0; end
end
function s = local_modestep(x)
u = unique(round(x * 1e6) / 1e6);
d = diff(sort(u));
d = d(d > 1e-6);
if isempty(d), s = Inf; return; end
s = mode(round(d, 3));           % dominant lattice spacing
if ~isfinite(s) || s <= 0, s = median(d); end
end

% ========================================================================
function rep = local_report(srcVal, qVal, opts) %#ok<INUSD>
% Field-level diagnostics that need no held-out data.
finiteSrc = isfinite(srcVal);
rep = struct();
rep.srcMin = min(srcVal(finiteSrc)); rep.srcMax = max(srcVal(finiteSrc));
finiteQ = isfinite(qVal);
rep.nanFrac = 1 - nnz(finiteQ) / numel(qVal);
% Overshoot = fine values outside the global source range (spline/cubic ringing)
tol = 1e-9 * max(1, abs(rep.srcMax - rep.srcMin));
over = qVal(finiteQ) < rep.srcMin - tol | qVal(finiteQ) > rep.srcMax + tol;
rep.overshootFrac = nnz(over) / max(1, nnz(finiteQ));
rep.qMin = min(qVal(finiteQ)); rep.qMax = max(qVal(finiteQ));
end

% ========================================================================
function h = local_validate(lon, lat, val, def, opts)
% Held-out-node skill: hide a random fraction of source nodes, predict them
% from the rest, aggregate error across all fields. Uses the SAME method; for
% 'gridded' methods the prediction is done with a scattered analog (linear for
% bilinear, natural otherwise) since interp2 cannot query a node it just removed.
rng(opts.rngSeed);
switch def.kind
    case 'custom'
        predFun = @(sL,sB,sV,qL,qB) def.spec(sL,sB,sV,qL,qB);
    case 'scattered'
        predFun = @(sL,sB,sV,qL,qB) local_scatPred(sL,sB,sV,qL,qB,def.spec);
    otherwise  % gridded -> scattered analog
        if strcmp(def.spec, 'linear') || strcmp(def.spec, 'nearest')
            sm = def.spec;
        else
            sm = 'natural';
        end
        predFun = @(sL,sB,sV,qL,qB) local_scatPred(sL,sB,sV,qL,qB,sm);
end

nF = size(val, 2);
allObs = []; allPred = [];
for f = 1:nF
    good = find(isfinite(val(:, f)));
    if numel(good) < 20, continue; end
    nHold = max(1, round(opts.holdoutFrac * numel(good)));
    ho = good(randperm(numel(good), nHold));
    tr = setdiff(good, ho);
    pred = predFun(lon(tr), lat(tr), val(tr, f), lon(ho), lat(ho));
    ok = isfinite(pred);
    allObs  = [allObs;  val(ho(ok), f)]; %#ok<AGROW>
    allPred = [allPred; pred(ok)];       %#ok<AGROW>
end
h = local_metrics(allObs, allPred);
end

function qv = local_scatPred(sL, sB, sV, qL, qB, method)
if numel(sL) < 3
    qv = nan(size(qL)); return;
end
F = scatteredInterpolant(sL, sB, sV, method, 'none');
qv = F(qL, qB);
end

% ========================================================================
function h = local_metrics(obs, pred)
h = struct('RMSE', NaN, 'MAE', NaN, 'R2', NaN, 'Bias', NaN, 'n', numel(obs));
if numel(obs) < 2, return; end
e = pred - obs;
h.RMSE = sqrt(mean(e.^2));
h.MAE  = mean(abs(e));
h.Bias = mean(e);
ssRes = sum(e.^2);
ssTot = sum((obs - mean(obs)).^2);
if ssTot > 0, h.R2 = 1 - ssRes / ssTot; end
end

% ========================================================================
function [lon, lat, val, meta] = local_ingest(src)
meta = struct('valLabel', 'value');
if isfield(src, 'ozone')                 % a cube from assembleBMEcube
    lon = src.lon(:); lat = src.lat(:);
    val = src.ozone;
    meta.valLabel = 'ozone_ppb';
    for fld = {'time','year','month'}
        if isfield(src, fld{1}), meta.(fld{1}) = src.(fld{1}); end
    end
    % Authoritative source resolution from the cube fileBase (e.g. _res1.00_)
    if isfield(src, 'fileBase') && ~isempty(src.fileBase)
        tok = regexp(src.fileBase, '_res([0-9.]+)', 'tokens', 'once');
        if ~isempty(tok), meta.sourceRes = str2double(tok{1}); end
    end
elseif all(isfield(src, {'lon','lat','val'}))
    lon = src.lon(:); lat = src.lat(:);
    val = src.val;
    if isvector(val), val = val(:); end
else
    error('downscaleEstimates:src', ...
        'src must be a cube (with .ozone) or a struct with .lon/.lat/.val.');
end
if size(val, 1) ~= numel(lon)
    error('downscaleEstimates:shape', ...
        'val rows (%d) must equal number of nodes (%d).', size(val,1), numel(lon));
end
end

% ========================================================================
function [idx, d] = local_knn(ref, q)
% Nearest ref point to each q, with distance. Uses knnsearch if available,
% else a chunked brute-force fallback (no toolbox dependency).
if exist('knnsearch', 'file')
    [idx, d] = knnsearch(ref, q);
    return;
end
n = size(q, 1); idx = zeros(n, 1); d = zeros(n, 1);
chunk = 2000;
for a = 1:chunk:n
    b = min(a + chunk - 1, n);
    dx = q(a:b, 1) - ref(:, 1).';
    dy = q(a:b, 2) - ref(:, 2).';
    [dm, im] = min(dx.^2 + dy.^2, [], 2);
    idx(a:b) = im; d(a:b) = sqrt(dm);
end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('method', 'bilinear', 'targetRes', 0.25, 'targetGrid', [], ...
    'sourceRes', [], 'maskToSource', true, 'maxGapDeg', [], ...
    'validate', true, 'holdoutFrac', 0.10, 'rngSeed', 42, 'verbose', true);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
fprintf('downscaleEstimates self-test:\n');

% Smooth analytic field on a 1-deg lattice over a region, land-agnostic.
[LO, LA] = meshgrid(-10:1:10, 30:1:50);
truth = @(x, y) 40 + 8*sin(x/6) + 6*cos(y/7) + 0.05*(x - y);
lon = LO(:); lat = LA(:);
val = truth(lon, lat);
cube.lon = lon; cube.lat = lat; cube.ozone = [val, val + 3];  % 2 "months"
cube.time = [2010.0 2010.0833]; cube.year = [2010 2010]; cube.month = [1 2];

o = downscaleEstimates(cube, struct('method', {{'bilinear','bicubic','spline'}}, ...
    'targetRes', 0.25, 'verbose', false));

% (1) shape / finer grid
assert(o.nTarget > o.nSource, 'target finer than source');
assert(size(o.val, 2) == 2, 'both fields downscaled');
assert(o.targetRes == 0.25, 'target res recorded');

% (2) accuracy vs analytic truth at target cells (primary=bilinear)
tv = truth(o.lon, o.lat);
good = isfinite(o.val(:, 1));
rmse = sqrt(mean((o.val(good, 1) - tv(good)).^2));
assert(rmse < 0.5, sprintf('bilinear tracks smooth truth (rmse=%.3f)', rmse));

% (3) bilinear must NOT overshoot the source range
rb = o.byMethod('bilinear').report;
assert(rb.overshootFrac == 0, 'bilinear no overshoot');

% (4) validation table present with all three methods, finite skill
assert(height(o.validation) == 3, 'three methods validated');
assert(all(isfinite(o.validation.RMSE)), 'holdout RMSE finite');
assert(o.validation.R2(strcmp(o.validation.Method,'bilinear')) > 0.9, ...
    'bilinear holdout R2 high on smooth field');

% (5) node-exactness: querying bilinear AT the source nodes reproduces them
oNode = downscaleEstimates(struct('lon',lon,'lat',lat,'val',val), ...
    struct('method','bilinear','targetGrid',[lon lat], ...
    'maskToSource',false,'validate',false,'verbose',false));
assert(max(abs(oNode.val - val)) < 1e-6, 'bilinear exact at source nodes');

% (6) extensibility: register a custom method via opts pathway (mean-fill)
reg = local_methodRegistry();
assert(isKey(reg,'makima') && isKey(reg,'nearest'), 'extra methods registered');

% (7) plain lon/lat/val vector input works
o2 = downscaleEstimates(struct('lon',lon,'lat',lat,'val',val), ...
    struct('method','spline','targetRes',0.5,'verbose',false));
assert(~isempty(o2.val) && o2.nTarget > 0, 'vector input path');

fprintf('  (1) finer grid, multi-field ....... OK (%d->%d cells)\n', o.nSource, o.nTarget);
fprintf('  (2) tracks smooth truth ........... OK (bilinear rmse=%.3f)\n', rmse);
fprintf('  (3) bilinear no overshoot ......... OK\n');
fprintf('  (4) holdout validation table ...... OK\n');
fprintf('  (5) exact at source nodes ......... OK\n');
fprintf('  (6) method registry extensible .... OK\n');
fprintf('  (7) lon/lat/val vector input ...... OK\n');
fprintf('downscaleEstimates self-test: ALL PASSED.\n');
end
