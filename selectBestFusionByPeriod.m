function [groups, ranking, annual] = selectBestFusionByPeriod(methods, yearRange, varargin)
% selectBestFusionByPeriod - Pick the best BME data-fusion method per time period
%
% For a list of candidate BME methods, this loads the existing checkerboard
% validation (CBV) annual files, AVERAGES each method's annual skill over the
% requested years (per-year stats averaged, not pooled), and partitions the
% study period into as FEW contiguous time-period groups as possible such that a
% single recommended method covers each group. Among near-tied methods it
% prefers configurations that include satellite soft data, so that satellite is
% used as often as possible whenever it is available. The result is the
% era-by-configuration table used in the ES&T paper (e.g. "2005-2021 ->
% Obs+M3fusion+OMI-MLS").
%
% Methods with no CBV files in the requested range/box are silently skipped.
%
% SYNTAX:
%   selectBestFusionByPeriod                       % all defaults (the paper run)
%   groups = selectBestFusionByPeriod(methods, [2005 2021])
%   [groups, ranking, annual] = selectBestFusionByPeriod(..., 'boxSizes', [5 20])
%   selectBestFusionByPeriod('--selftest')         % synthetic self-test
%
% INPUTS:
%   methods   - Cell array of method tokens (default: the 11-method ES&T list).
%               Accepted token forms:
%                 '10000133go0'  -> code '10000133', GO scenario 0
%                 '13000313-06'  -> code '13000313-06', GO scenario = defaultGO
%                 '13000313-06_go3' (underscore form) also accepted
%   yearRange - [startYear endYear] (default: [2005 2021])
%
% OPTIONAL PARAMETERS (Name-Value):
%   'boxSizes'        - CBV box sizes in degrees (default: [5 20])
%   'metric'          - Primary ranking metric (default: 'R2')
%   'tieMetric'       - Tie-break metric, lower-is-better (default: 'RMSE')
%   'cbvDir'          - CBV results directory (default: './7validation/CBV')
%   'epsTol'          - A method is "acceptable" for a year if its primary
%                       metric is within epsTol of the best method that year
%                       (default: 0.01, in R2 units). Larger -> fewer groups and
%                       more chances for satellite methods to span a period.
%   'preferSatellite' - Prefer satellite-containing configs among near-ties
%                       (default: true)
%   'eras'            - Optional vector of era START years that FIX the period
%                       boundaries instead of using the greedy grouping. Each
%                       era runs from one start year to the next start minus one
%                       (last era runs to yearRange(2)), and the best method is
%                       chosen WITHIN each fixed era (full-era coverage required
%                       when available; satellite-preferred among near-ties).
%                       Use this to surface an availability-driven table, e.g.
%                       'eras', [2005 2017 2021] -> 2005-2016 (OMI era),
%                       2017-2020 (IASI era), 2021. Default [] = greedy mode.
%   'defaultGO'       - GO scenario for tokens without an explicit go (default: 3)
%   'outDir'          - Where to write the CSV (default: cbvDir)
%   'csvName'         - Output CSV file name (default: best_fusion_by_period.csv)
%   'writeCsv'        - Write the CSV (default: true)
%   'verbose'         - Print tables to console (default: true)
%
% OUTPUTS:
%   groups  - Struct array (one row per period per box size) with fields:
%             BoxSize, StartYear, EndYear, Method, MethodName, Satellite,
%             MeanR2, MeanRMSE, nYears, nMethods
%   ranking - Struct array of the per-method period-averaged skill (one row per
%             method per box size): BoxSize, Method, MethodName, Satellite,
%             nYears, MeanR2, MeanRMSE
%   annual  - Struct with the raw annual matrices per box size (.box, .years,
%             .methods, .R2 [nMethod x nYear], .tie)
%
% Satellite membership is decided from the extended method code: the hex CTM
% bitmask after each '-' is OR-ed and tested against 04|08|40 (OMI-MLS,
% IASI-GOME2, CrIS). E.g. '13000313-06' (02|04) and '13000313-0A' (02|08) are
% satellite; '13000313-02' (M3fusion) and '13000313-03' (01|02) are not.
%
% SEE ALSO: summarizeCBVforPaper, getBMEmethodName, runCBV_toar, bestMethodByYear

%% Self-test entry point
if nargin >= 1 && (ischar(methods) || isstring(methods)) && ...
        strcmpi(string(methods), '--selftest')
    groups = local_selftest();
    return;
end

%% Defaults
if nargin < 1 || isempty(methods)
    methods = {'10000133go0', '10000133go3', '13000313-02', '13000313-04', ...
        '13000313-08', '13000313-40', '13000313-06', '13000313-0A', ...
        '13000313-42', '13000313-03', '13000313-0E'};
end
if nargin < 2 || isempty(yearRange), yearRange = [2005 2021]; end

p = inputParser;
addParameter(p, 'boxSizes', [5 20], @isnumeric);
addParameter(p, 'metric', 'R2', @ischar);
addParameter(p, 'tieMetric', 'RMSE', @ischar);
addParameter(p, 'cbvDir', './7validation/CBV', @ischar);
addParameter(p, 'epsTol', 0.01, @isnumeric);
addParameter(p, 'preferSatellite', true, @islogical);
addParameter(p, 'eras', [], @isnumeric);
addParameter(p, 'defaultGO', 3, @isnumeric);
addParameter(p, 'outDir', '', @ischar);
addParameter(p, 'csvName', 'best_fusion_by_period.csv', @ischar);
addParameter(p, 'writeCsv', true, @islogical);
addParameter(p, 'verbose', true, @islogical);
parse(p, varargin{:});
opts = p.Results;
if isempty(opts.outDir), opts.outDir = opts.cbvDir; end

allYears = yearRange(1):yearRange(2);
dirSign  = local_metricDir(opts.metric);   % +1 higher-better, -1 lower-better

groups  = local_emptyGroups();
ranking = local_emptyRanking();
annual  = struct('box', {}, 'years', {}, 'methods', {}, 'R2', {}, 'tie', {});

for bi = 1:numel(opts.boxSizes)
    box = opts.boxSizes(bi);
    if opts.verbose
        fprintf('\n========================================================\n');
        fprintf(' CBV box %.1f deg | %d-%d | metric %s (eps=%.3g)\n', ...
            box, yearRange(1), yearRange(2), opts.metric, opts.epsTol);
        fprintf('========================================================\n');
    end

    % ---- Load annual skill for every method (average folds) ----
    kept = {}; keptCode = {}; keptGO = []; keptSat = []; keptName = {};
    Rrows = []; Trows = [];
    for im = 1:numel(methods)
        tok = methods{im};
        [code, go] = local_parseToken(tok, opts.defaultGO);
        rvec = NaN(1, numel(allYears));
        tvec = NaN(1, numel(allYears));
        for iy = 1:numel(allYears)
            [rvec(iy), tvec(iy)] = local_loadAnnual(opts.cbvDir, code, go, ...
                box, allYears(iy), opts.metric, opts.tieMetric);
        end
        if ~any(~isnan(rvec))
            if opts.verbose
                fprintf('  skip %-14s : no CBV files for box %.1f in range\n', tok, box);
            end
            continue;
        end
        kept{end+1}     = tok;            %#ok<AGROW>
        keptCode{end+1} = code;           %#ok<AGROW>
        keptGO(end+1)   = go;             %#ok<AGROW>
        keptSat(end+1)  = local_hasSatellite(code); %#ok<AGROW>
        keptName{end+1} = local_methodName(code, go); %#ok<AGROW>
        Rrows = [Rrows; rvec]; %#ok<AGROW>
        Trows = [Trows; tvec]; %#ok<AGROW>
    end

    if isempty(kept)
        if opts.verbose, fprintf('  No methods with data at box %.1f.\n', box); end
        continue;
    end

    annual(end+1) = struct('box', box, 'years', allYears, ...
        'methods', {kept}, 'R2', Rrows, 'tie', Trows); %#ok<AGROW>

    % ---- Per-method period-averaged ranking ----
    if opts.verbose
        fprintf('\n  Per-method skill averaged over %d-%d:\n', yearRange(1), yearRange(2));
        fprintf('  %-14s %-26s %4s %6s %8s %8s\n', ...
            'Method', 'Name', 'Sat', 'nYrs', opts.metric, opts.tieMetric);
        fprintf('  %s\n', repmat('-', 1, 72));
    end
    meanR = NaN(1, numel(kept));
    for im = 1:numel(kept)
        meanR(im) = mean(Rrows(im, :), 'omitnan');
        meanT     = mean(Trows(im, :), 'omitnan');
        nY        = sum(~isnan(Rrows(im, :)));
        r = struct('BoxSize', box, 'Method', kept{im}, ...
            'MethodName', keptName{im}, 'Satellite', logical(keptSat(im)), ...
            'nYears', nY, 'MeanR2', meanR(im), 'MeanRMSE', meanT);
        ranking(end+1) = r; %#ok<AGROW>
    end
    [~, ord] = sort(meanR, 'descend');
    if opts.verbose
        for k = ord
            fprintf('  %-14s %-26s %4s %6d %8.3f %8.2f\n', kept{k}, ...
                local_trim(keptName{k}, 26), local_yn(keptSat(k)), ...
                sum(~isnan(Rrows(k, :))), meanR(k), mean(Trows(k, :), 'omitnan'));
        end
    end

    % ---- Segmentation: fixed eras (if requested) or greedy minimal grouping ----
    score = dirSign * Rrows;                  % higher-better orientation
    best  = max(score, [], 1, 'omitnan');     % best score each year
    if ~isempty(opts.eras)
        segs = local_eraGroups(opts.eras, allYears, score, Trows, keptSat, ...
            opts.epsTol, opts.preferSatellite);
        hdr = 'Era table (fixed availability boundaries, satellite-preferred):';
    else
        segs = local_greedyGroups(score, best, Trows, keptSat, opts.epsTol, ...
            opts.preferSatellite);
        hdr = 'Recommended era table (fewest groups, satellite-preferred):';
    end

    if opts.verbose
        fprintf('\n  %s\n', hdr);
        fprintf('  %-12s %-14s %-26s %4s %8s %8s\n', ...
            'Period', 'Method', 'Configuration', 'Sat', opts.metric, opts.tieMetric);
        fprintf('  %s\n', repmat('-', 1, 78));
    end
    for s = 1:numel(segs)
        rng = segs(s).i1:segs(s).i2;
        m   = segs(s).m;
        g = struct('BoxSize', box, ...
            'StartYear', allYears(segs(s).i1), 'EndYear', allYears(segs(s).i2), ...
            'Method', kept{m}, 'MethodName', keptName{m}, ...
            'Satellite', logical(keptSat(m)), ...
            'MeanR2', mean(Rrows(m, rng), 'omitnan'), ...
            'MeanRMSE', mean(Trows(m, rng), 'omitnan'), ...
            'nYears', numel(rng), 'nMethods', numel(kept));
        groups(end+1) = g; %#ok<AGROW>
        if opts.verbose
            if g.StartYear == g.EndYear
                per = sprintf('%d', g.StartYear);
            else
                per = sprintf('%d-%d', g.StartYear, g.EndYear);
            end
            fprintf('  %-12s %-14s %-26s %4s %8.3f %8.2f\n', per, kept{m}, ...
                local_trim(keptName{m}, 26), local_yn(keptSat(m)), ...
                g.MeanR2, g.MeanRMSE);
        end
    end
end

%% Write CSV
if opts.writeCsv && ~isempty(groups)
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    csvPath = fullfile(opts.outDir, opts.csvName);
    T = struct2table(groups);
    try
        writetable(T, csvPath);
        if opts.verbose, fprintf('\nWrote %s\n', csvPath); end
    catch ME
        warning('Could not write %s: %s', csvPath, ME.message);
    end
end

end

%% ========================================================================
%  LOCAL HELPERS
%  ========================================================================

function [code, go] = local_parseToken(tok, defaultGO)
% Map a method token to (code, GO scenario), handling 3 token forms.
    tok = char(tok);
    m = regexp(tok, '^(.+?)_go(\d+)$', 'tokens', 'once');   % underscore form
    if ~isempty(m), code = m{1}; go = str2double(m{2}); return; end
    m = regexp(tok, '^(.+?)go(\d+)$', 'tokens', 'once');    % e.g. 10000133go3
    if ~isempty(m), code = m{1}; go = str2double(m{2}); return; end
    code = tok; go = defaultGO;                             % bare code
end

function [rv, tv] = local_loadAnnual(cbvDir, code, go, box, year, metric, tieMetric)
% Average the requested metrics over the (up to) two CBV folds. NaN if absent.
    rvals = []; tvals = [];
    for f = 1:2
        fname = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
            code, go, box, f, year);
        fpath = fullfile(cbvDir, fname);
        if ~exist(fpath, 'file'), continue; end
        try
            S = load(fpath, 'annualStats');
            if ~isfield(S, 'annualStats'), continue; end
            a = S.annualStats;
            if isfield(a, metric),    rvals(end+1) = a.(metric);    end %#ok<AGROW>
            if isfield(a, tieMetric), tvals(end+1) = a.(tieMetric); end %#ok<AGROW>
        catch
            % ignore unreadable file
        end
    end
    if isempty(rvals), rv = NaN; else, rv = mean(rvals, 'omitnan'); end
    if isempty(tvals), tv = NaN; else, tv = mean(tvals, 'omitnan'); end
end

function tf = local_hasSatellite(code)
% True if the extended code's CTM bitmask includes OMI-MLS(04), IASI-GOME2(08),
% or CrIS(40). Bare codes (no '-') carry no soft data and are not satellite.
    parts = strsplit(char(code), '-');
    mask = 0;
    for i = 2:numel(parts)               % skip the base code in parts{1}
        v = hex2dec(parts{i});
        if ~isnan(v), mask = bitor(mask, v); end
    end
    tf = bitand(mask, hex2dec('4C')) ~= 0;   % 0x04 | 0x08 | 0x40
end

function name = local_methodName(code, go)
    try
        name = getBMEmethodName(code, go);
    catch
        name = sprintf('%s_go%d', code, go);
    end
end

function d = local_metricDir(metric)
    lower_is_better = {'RMSE', 'MAE', 'MSE', 'NME', 'NMB', 'ME', 'MBE'};
    if ismember(metric, lower_is_better), d = -1; else, d = 1; end
end

function segs = local_greedyGroups(score, best, tie, isSat, epsTol, preferSat)
% Greedy left-to-right longest-acceptable-run segmentation. A method is
% acceptable for a year if its score is within epsTol of the best that year.
% Among methods that reach the same (maximal) run length, prefer satellite,
% then higher mean score, then lower mean tie metric.
    nM = size(score, 1);
    nY = size(score, 2);
    segs = struct('i1', {}, 'i2', {}, 'm', {});
    i = 1;
    while i <= nY
        if isnan(best(i)), i = i + 1; continue; end   % no data this year
        L = zeros(nM, 1);
        for m = 1:nM
            for j = i:nY
                if isnan(best(j)), break; end
                v = score(m, j);
                if isnan(v) || (best(j) - v) > epsTol, break; end
                L(m) = L(m) + 1;
            end
        end
        maxL = max(L);
        cand = find(L == maxL & maxL > 0);
        bestC = cand(1);
        for c = cand(:)'
            if local_betterCand(c, bestC, i, maxL, score, tie, isSat, preferSat)
                bestC = c;
            end
        end
        segs(end+1) = struct('i1', i, 'i2', i + maxL - 1, 'm', bestC); %#ok<AGROW>
        i = i + maxL;
    end
end

function tf = local_betterCand(c, ref, i, L, score, tie, isSat, preferSat)
    rng = i:(i + L - 1);
    tf = local_betterOverRange(c, ref, rng, score, tie, isSat, preferSat);
end

function tf = local_betterOverRange(c, ref, rng, score, tie, isSat, preferSat)
% Is candidate c better than ref over the index range rng? Preference order:
% satellite (if enabled) > higher mean score > lower mean tie metric.
    if preferSat && isSat(c) ~= isSat(ref)
        tf = isSat(c) > isSat(ref); return;
    end
    sc = mean(score(c, rng), 'omitnan');
    sr = mean(score(ref, rng), 'omitnan');
    if abs(sc - sr) > 1e-12, tf = sc > sr; return; end
    tc = mean(tie(c, rng), 'omitnan');
    tr = mean(tie(ref, rng), 'omitnan');
    tf = tc < tr;            % lower tie metric (RMSE) wins
end

function segs = local_eraGroups(eras, years, score, tie, isSat, epsTol, preferSat)
% Fixed-era segmentation. eras = vector of era START years; each era spans to
% the next start minus one (last era to years(end)). Within each era the best
% method is the one with the highest mean score; among methods within epsTol of
% that best mean, satellite configs are preferred. Methods that fully cover the
% era are preferred; partially covering methods are used only if none cover it.
    nM   = size(score, 1);
    eras = sort(unique(eras(:)'));
    segs = struct('i1', {}, 'i2', {}, 'm', {});
    for k = 1:numel(eras)
        startY = eras(k);
        if k < numel(eras), endY = eras(k+1) - 1; else, endY = years(end); end
        idx = find(years >= startY & years <= endY);
        if isempty(idx), continue; end

        full = false(1, nM); part = false(1, nM);
        for m = 1:nM
            v = score(m, idx);
            if all(~isnan(v)),      full(m) = true; end
            if any(~isnan(v)),      part(m) = true; end
        end
        elig = find(full);
        if isempty(elig), elig = find(part); end   % fall back to partial
        if isempty(elig), continue; end

        % Among eligible methods within epsTol of the best mean score, prefer
        % satellite, then higher mean score, then lower tie metric.
        ms = arrayfun(@(m) mean(score(m, idx), 'omitnan'), elig);
        near = elig(ms >= max(ms) - epsTol);
        bestM = near(1);
        for m = near
            if local_betterOverRange(m, bestM, idx, score, tie, isSat, preferSat)
                bestM = m;
            end
        end
        segs(end+1) = struct('i1', idx(1), 'i2', idx(end), 'm', bestM); %#ok<AGROW>
    end
end

function s = local_trim(str, n)
    str = char(str);
    if numel(str) > n, s = [str(1:n-1) '~']; else, s = str; end
end

function s = local_yn(tf)
    if tf, s = 'yes'; else, s = 'no'; end
end

function g = local_emptyGroups()
    g = struct('BoxSize', {}, 'StartYear', {}, 'EndYear', {}, 'Method', {}, ...
        'MethodName', {}, 'Satellite', {}, 'MeanR2', {}, 'MeanRMSE', {}, ...
        'nYears', {}, 'nMethods', {});
end

function r = local_emptyRanking()
    r = struct('BoxSize', {}, 'Method', {}, 'MethodName', {}, ...
        'Satellite', {}, 'nYears', {}, 'MeanR2', {}, 'MeanRMSE', {});
end

%% ========================================================================
%  SELF-TEST
%  ========================================================================
function groups = local_selftest()
    fprintf('selectBestFusionByPeriod --selftest\n');
    tmp = tempname; mkdir(tmp);
    cleaner = onCleanup(@() rmdir(tmp, 's'));

    box = 5.0; go = 3;
    yrs = 2005:2008;
    % R2 designs (per year). -06 (sat) full coverage & >= -02 every year.
    R2.('m13000313_02') = [0.770 0.770 0.770 0.770];   % no sat, full
    R2.('m13000313_06') = [0.775 0.775 0.785 0.785];   % sat (02|04), full
    R2.('m13000313_0A') = [NaN   NaN   0.790 0.790];   % sat (02|08), 2007-08
    R2.('m10000133')    = [0.600 0.600 0.600 0.600];   % hard-only baseline
    codeMap = {'13000313-02','m13000313_02'; '13000313-06','m13000313_06'; ...
               '13000313-0A','m13000313_0A'; '10000133','m10000133'};
    for r = 1:size(codeMap, 1)
        code = codeMap{r, 1}; key = codeMap{r, 2};
        for iy = 1:numel(yrs)
            v = R2.(key)(iy);
            if isnan(v), continue; end
            for f = 1:2
                annualStats = struct('R2', v, 'RMSE', 30 * (1 - v));
                fn = fullfile(tmp, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                    code, go, box, f, yrs(iy)));
                save(fn, 'annualStats');
            end
        end
    end

    methods = {'13000313-02', '13000313-06', '13000313-0A', '10000133go3', ...
        '13000313-99'};   % -99 has no files -> must be skipped
    [groups, ranking, annual] = selectBestFusionByPeriod(methods, [2005 2008], ...
        'boxSizes', box, 'cbvDir', tmp, 'epsTol', 0.01, 'writeCsv', false, ...
        'verbose', true);

    assert(~isempty(groups), 'no groups produced');
    assert(isscalar(groups), 'expected a single group, got %d', numel(groups));
    assert(strcmp(groups(1).Method, '13000313-06'), ...
        'expected satellite method 13000313-06, got %s', groups(1).Method);
    assert(groups(1).Satellite, 'group method should be flagged satellite');
    assert(groups(1).StartYear == 2005 && groups(1).EndYear == 2008, ...
        'group should span 2005-2008');
    % skipped method must not appear in the ranking
    assert(~any(strcmp({ranking.Method}, '13000313-99')), ...
        'missing method 13000313-99 should have been skipped');
    % satellite detection sanity
    assert(local_hasSatellite('13000313-06'),  '06 should be satellite');
    assert(~local_hasSatellite('13000313-02'), '02 should not be satellite');
    assert(~local_hasSatellite('13000313-03'), '03 should not be satellite');
    assert(local_hasSatellite('13000313-42'),  '42 should be satellite (CrIS)');
    assert(~local_hasSatellite('10000133'),    'bare code is not satellite');
    assert(isscalar(annual) && isequal(annual.years, 2005:2008), 'annual years');

    fprintf('selectBestFusionByPeriod --selftest: ALL PASSED.\n');
end
