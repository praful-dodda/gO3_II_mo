function [osdma8Stats, results] = runOSDMA8validation(cfg)
% runOSDMA8validation - Validate BME estimates of OSDMA8 from CBV monthly files
%
% Aggregates the monthly MDA8 values stored by the CBV pipeline
% (7validation/CBV/monthly/CBV_BME*.mat) into the annual OSDMA8 metric and
% compares an estimated series against a reference series per validation
% station. Produces CBV-style summary CSV/MAT and diagnostic plots.
%
% This script is READ-ONLY with respect to the CBV pipeline: it never edits
% or writes CBV files, and tolerates monthly files that are missing or being
% written by a live run.
%
% USAGE:
%   runOSDMA8validation                 % edit defaults below, press Run
%   runOSDMA8validation(cfg)            % pass a config struct
%   [stats, results] = runOSDMA8validation(cfg)
%
% Each series source can be selected independently:
%   'toar_osdma8' - OFFICIAL annual OSDMA8 from loadTOARosdma8 (truth; read
%                   from cfg.osdma8RefDir, matched to CBV coords)
%   'cbv_obs'     - observed monthly MDA8 (Y_obs) from the monthly CBV files,
%                   aggregated to OSDMA8 via computeOSDMA8
%   'cbv_est'     - BME-estimated monthly MDA8 (Y_est) from the monthly files
%   'yearly_file' - OSDMA8 from getTOARobservationalData_Yearly (a possibly
%                   DIFFERENT obs file set via cfg.customObsDir)
%
% By default this validates BME (cbv_est) against the official OSDMA8
% (toar_osdma8) and, when cfg.crossCheck is true, also reports the official
% metric vs OSDMA8 recomputed from observed monthly MDA8 (cbv_obs) as a QA of
% the monthly->OSDMA8 aggregation.
%
% SEE ALSO: loadTOARosdma8, computeOSDMA8, getTOARobservationalData_Yearly,
%           calculateValidationStats

%% ===================== CONFIGURATION (edit & Run) =====================
if nargin < 1, cfg = struct(); end
def = struct( ...
    'BMEmethod',    '10000133', ...
    'goScenario',   3, ...
    'boxSizes',     5.0, ...
    'valYears',     2017, ...
    'folds',        [1 2], ...
    'monthlyDir',   fullfile('7validation', 'CBV', 'monthly'), ...
    'refSource',    'toar_osdma8', ... % reference / "truth" series (official OSDMA8)
    'testSource',   'cbv_est', ...     % series being validated (BME)
    'completeness', 'strict', ...      % 'strict' | 'partial' | 'any'
    'minMonths',    4, ...
    'stationTypes', 'all', ...         % filter for 'toar_osdma8' / 'yearly_file'
    'customObsDir', fullfile('1data', 'TOAR-II'), ... % alt file set for 'yearly_file'
    'osdma8RefDir', fullfile('1data', 'TOAR-OSDMA8'), ... % official OSDMA8 CSVs
    'crossCheck',   true, ...          % also report toar_osdma8 vs cbv_obs (QA)
    'matchDecimals',4, ...             % coord-key precision (drop to 3 if pairs are few)
    'outDir',       fullfile('7validation', 'OSDMA8'), ...
    'makePlots',    true);
cfg = local_fillDefaults(cfg, def);
%% =====================================================================

cOpts = struct('completeness', cfg.completeness, 'minMonths', cfg.minMonths);
if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end

% Accumulators across all (box, fold, year) for plotting & summary
statsRows = {};
pooled = struct('ref', [], 'test', [], 'lon', [], 'lat', [], ...
                'box', [], 'fold', [], 'year', []);
results = struct('byCase', {{}}, 'pooled', pooled, 'cfg', cfg);

fprintf('\n=== OSDMA8 validation: ref=%s vs test=%s (%s) ===\n', ...
    cfg.refSource, cfg.testSource, cfg.completeness);

for boxSize = cfg.boxSizes(:).'
    for iFold = cfg.folds(:).'
        for valYear = cfg.valYears(:).'

            % Assemble per-station 15-month matrices from the monthly files.
            [coords, obsMat, estMat, nFiles] = local_assembleMonthly( ...
                cfg, boxSize, iFold, valYear);

            if isempty(coords)
                fprintf('  [box %.1f fold %d %d] no monthly files found - skipped.\n', ...
                    boxSize, iFold, valYear);
                continue;
            end

            % Resolve each side to an OSDMA8 vector at the validation coords.
            osRef  = local_sourceToOSDMA8(cfg.refSource,  coords, obsMat, estMat, cfg, valYear, cOpts);
            osTest = local_sourceToOSDMA8(cfg.testSource, coords, obsMat, estMat, cfg, valYear, cOpts);

            keep = ~isnan(osRef) & ~isnan(osTest);
            nPair = sum(keep);
            fprintf('  [box %.1f fold %d %d] %d files, %d stations, %d OSDMA8 pairs.\n', ...
                boxSize, iFold, valYear, nFiles, size(coords,1), nPair);
            if nPair < 2, continue; end

            osRefK = osRef(keep); osTestK = osTest(keep);
            cK = coords(keep, :);

            stats = calculateValidationStats(osRefK, osTestK);
            if isempty(fieldnames(stats)), continue; end
            stats.BoxSize = boxSize;
            stats.Fold    = iFold;
            stats.Year    = valYear;

            % Cross-check: official OSDMA8 (ref) vs OSDMA8 recomputed from
            % observed monthly MDA8 (cbv_obs). Isolates aggregation error from
            % BME error. Only meaningful when the reference is the official set.
            xc = struct();
            if cfg.crossCheck && strcmpi(cfg.refSource, 'toar_osdma8')
                osObs = computeOSDMA8(obsMat, cOpts);
                kxc = ~isnan(osRef) & ~isnan(osObs);
                if sum(kxc) >= 2
                    xc = calculateValidationStats(osRef(kxc), osObs(kxc));
                    stats.R2_xc   = local_get(xc, 'R2');
                    stats.RMSE_xc = local_get(xc, 'RMSE');
                    stats.NMB_xc  = local_get(xc, 'NMB');
                    stats.N_xc    = local_get(xc, 'N');
                end
            end

            % Per-case result file (under OSDMA8 output dir, not CBV dirs).
            caseRes = struct('osRef', osRefK, 'osTest', osTestK, 'coords', cK, ...
                'stats', stats, 'crossCheck', xc, 'boxSize', boxSize, ...
                'fold', iFold, 'year', valYear, 'cfg', cfg);
            caseName = sprintf('OSDMA8_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                cfg.BMEmethod, cfg.goScenario, boxSize, iFold, valYear);
            save(fullfile(cfg.outDir, caseName), 'caseRes', '-v7.3');

            results.byCase{end+1} = caseRes;
            statsRows{end+1} = stats; %#ok<AGROW>

            pooled.ref  = [pooled.ref;  osRefK];
            pooled.test = [pooled.test; osTestK];
            pooled.lon  = [pooled.lon;  cK(:,1)];
            pooled.lat  = [pooled.lat;  cK(:,2)];
            pooled.box  = [pooled.box;  repmat(boxSize, nPair, 1)];
            pooled.fold = [pooled.fold; repmat(iFold,  nPair, 1)];
            pooled.year = [pooled.year; repmat(valYear, nPair, 1)];
        end
    end
end

results.pooled = pooled;

if isempty(statsRows)
    warning('runOSDMA8validation:noResults', ...
        'No OSDMA8 pairs produced. Check monthlyDir/method/years and completeness.');
    osdma8Stats = table();
    return;
end

%% Summary table + CSV/MAT (parallels CBV_summary_*)
osdma8Stats = local_statsTable(statsRows);
summaryBase = sprintf('OSDMA8_summary_BME%s_go%d', cfg.BMEmethod, cfg.goScenario);
writetable(osdma8Stats, fullfile(cfg.outDir, [summaryBase '.csv']));
save(fullfile(cfg.outDir, [summaryBase '.mat']), 'osdma8Stats', 'pooled', 'cfg', '-v7.3');
fprintf('\nWrote %s.csv / .mat to %s\n', summaryBase, cfg.outDir);
disp(osdma8Stats(:, intersect({'BoxSize','Fold','Year','N','R2','RMSE','MAE','NMB', ...
    'R2_xc','RMSE_xc'}, osdma8Stats.Properties.VariableNames, 'stable')));

%% Plots
if cfg.makePlots
    try
        plotOSDMA8results(pooled, osdma8Stats, cfg);
    catch ME
        warning('runOSDMA8validation:plot', 'Plotting failed: %s', ME.message);
    end
end

end

% ========================================================================
function [coords, obsMat, estMat, nFiles] = local_assembleMonthly(cfg, boxSize, iFold, valYear)
% Load the 15 monthly CBV files (Y m1-12, Y+1 m1-3) and build per-station
% [nStations x 15] matrices of Y_obs and Y_est, matched by rounded lon/lat.
keys = containers.Map('KeyType', 'char', 'ValueType', 'double');  % key -> row index
coordsList = zeros(0, 2);
obsMat = zeros(0, 15);
estMat = zeros(0, 15);
nFiles = 0;

% (year, month, slot) triples to read.
spec = [repmat(valYear, 12, 1), (1:12).', (1:12).'; ...
        repmat(valYear+1, 3, 1), (1:3).', (13:15).'];

for i = 1:size(spec, 1)
    fy = spec(i,1); fm = spec(i,2); slot = spec(i,3);
    fn = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d_%02d.mat', ...
        cfg.BMEmethod, cfg.goScenario, boxSize, iFold, fy, fm);
    fp = fullfile(cfg.monthlyDir, fn);
    if ~exist(fp, 'file'), continue; end

    try
        S = load(fp, 'monthResults');
    catch
        continue;   % file may be mid-write by the live pipeline
    end
    if ~isfield(S, 'monthResults') || ~isfield(S.monthResults, 'sk'), continue; end
    mr = S.monthResults;
    nFiles = nFiles + 1;

    sk = mr.sk;
    yo = local_col(mr, 'Y_obs', size(sk,1));
    ye = local_col(mr, 'Y_est', size(sk,1));

    nd = cfg.matchDecimals; scale = 10^nd;
    for r = 1:size(sk, 1)
        lon = round(sk(r,1)*scale)/scale;
        lat = round(sk(r,2)*scale)/scale;
        k = sprintf('%.*f_%.*f', nd, lon, nd, lat);
        if isKey(keys, k)
            idx = keys(k);
        else
            idx = size(coordsList, 1) + 1;
            keys(k) = idx;
            coordsList(idx, :) = [lon, lat]; %#ok<AGROW>
            obsMat(idx, :) = nan(1, 15);     %#ok<AGROW>
            estMat(idx, :) = nan(1, 15);     %#ok<AGROW>
        end
        obsMat(idx, slot) = yo(r);
        estMat(idx, slot) = ye(r);
    end
end

coords = coordsList;
end

% ------------------------------------------------------------------------
function v = local_col(mr, name, n)
% Return monthResults.(name) as an n x 1 column, or NaNs if absent.
if isfield(mr, name) && ~isempty(mr.(name))
    v = mr.(name);
    v = v(:);
    if numel(v) ~= n, v = nan(n, 1); end
else
    v = nan(n, 1);
end
end

% ------------------------------------------------------------------------
function os = local_sourceToOSDMA8(src, coords, obsMat, estMat, cfg, valYear, cOpts)
% Resolve a series source to an OSDMA8 vector aligned to `coords`.
switch lower(src)
    case 'toar_osdma8'
        osd = loadTOARosdma8(valYear, 'dataDir', cfg.osdma8RefDir, ...
            'stationTypes', cfg.stationTypes);
        os = local_matchByCoord(coords, osd.coords, osd.osdma8, cfg.matchDecimals);
    case 'cbv_obs'
        os = computeOSDMA8(obsMat, cOpts);
    case 'cbv_est'
        os = computeOSDMA8(estMat, cOpts);
    case 'yearly_file'
        obsY = getTOARobservationalData_Yearly(cfg.stationTypes, valYear, ...
            'dataDir', cfg.customObsDir, 'completeness', cfg.completeness, ...
            'minMonths', cfg.minMonths);
        os = local_matchByCoord(coords, obsY.sMS, obsY.Z(:,1), cfg.matchDecimals);
    otherwise
        error('runOSDMA8validation:src', 'Unknown source: %s', src);
end
os = os(:);
end

% ------------------------------------------------------------------------
function vals = local_matchByCoord(coords, srcCoords, srcVals, nd)
% Match each row of coords to srcCoords by rounded lon/lat; NaN if no match.
% nd = number of decimals for the coordinate key (default 4).
if nargin < 4 || isempty(nd), nd = 4; end
scale = 10^nd;
m = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:size(srcCoords, 1)
    k = sprintf('%.*f_%.*f', nd, round(srcCoords(i,1)*scale)/scale, ...
                            nd, round(srcCoords(i,2)*scale)/scale);
    m(k) = srcVals(i);   % last one wins (coords are unique after QC)
end
vals = nan(size(coords, 1), 1);
for i = 1:size(coords, 1)
    k = sprintf('%.*f_%.*f', nd, round(coords(i,1)*scale)/scale, ...
                            nd, round(coords(i,2)*scale)/scale);
    if isKey(m, k), vals(i) = m(k); end
end
end

% ------------------------------------------------------------------------
function T = local_statsTable(statsRows)
% Stack per-case stats structs into a table, leading with key columns.
allFields = {};
for i = 1:numel(statsRows)
    allFields = union(allFields, fieldnames(statsRows{i}), 'stable');
end
lead = intersect({'BoxSize','Fold','Year','N','R2','RMSE','MAE','NMB','IOA','FAC2', ...
    'R2_xc','RMSE_xc','NMB_xc','N_xc'}, allFields, 'stable');
tail = setdiff(allFields, lead, 'stable');
ordered = [lead(:).', tail(:).'];   % force row vectors for horzcat

C = cell(numel(statsRows), numel(ordered));
for i = 1:numel(statsRows)
    s = statsRows{i};
    for j = 1:numel(ordered)
        f = ordered{j};
        if isfield(s, f), C{i,j} = s.(f); else, C{i,j} = NaN; end
    end
end
T = cell2table(C, 'VariableNames', ordered);
end

% ------------------------------------------------------------------------
function v = local_get(s, f)
% Safe struct field fetch (NaN if absent).
if isstruct(s) && isfield(s, f), v = s.(f); else, v = NaN; end
end

% ------------------------------------------------------------------------
function cfg = local_fillDefaults(cfg, def)
f = fieldnames(def);
for i = 1:numel(f)
    if ~isfield(cfg, f{i}) || isempty(cfg.(f{i}))
        cfg.(f{i}) = def.(f{i});
    end
end
end
