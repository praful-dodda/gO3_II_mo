function fillPaperTables(varargin)
%FILLPAPERTABLES Fill the 9 paper-summary tables in SampleTablesPaper3.xlsx.
%   FILLPAPERTABLES() computes per-period CBV skill (R2, RMSE) from the cached
%   checker-board-validation results and writes the numbers into the existing
%   workbook paper-3-figures/SampleTablesPaper3.xlsx, preserving its styling and
%   merged headers. A 'Commands' sheet documenting the run is appended.
%
%   FILLPAPERTABLES('--selftest') runs unit checks on the computation helpers
%   against synthetic CBV files (no real data / no workbook needed).
%
%   Conventions (verified against the workbook's own seed values):
%     * Stats are PER-YEAR AVERAGED: each year = mean over its (<=2) CBV folds,
%       then averaged across the years of the period (NaN-safe).
%     * % improvement is RELATIVE to the ObsFlat base, as a fraction:
%         R2  :  (val - base)/base        (higher R2 is better)
%         RMSE:  (base - val)/base        (lower RMSE is better)
%     * Method families (all GO scenario 3 except the flat base):
%         ObsFlat (base)          = 10000133  go0
%         Obs+M3fusion            = 13000313-02
%         Obs+M3fusion+Satellite  = per period: 06=OMI-MLS, 0E=+IASI-GOME2,
%                                   42=+CrIS (1990-2004 has no satellite -> NAN).
%
%   See also SELECTBESTFUSIONBYPERIOD, SUMMARIZECBVFORPAPER.

    % ---- Parse first argument: '--selftest' | 'pooled' | 'averaged' | cfg struct
    mode = 'averaged'; cfgIn = struct();
    if nargin >= 1
        a = varargin{1};
        if ischar(a) && any(strcmpi(a, {'--selftest', 'selftest', 'test'}))
            local_selftest(); return;
        elseif ischar(a) && any(strcmpi(a, {'pooled', 'averaged'}))
            mode = lower(a);
        elseif isstruct(a)
            cfgIn = a;
            if isfield(cfgIn, 'statMode'), mode = lower(cfgIn.statMode); end
        else
            error('fillPaperTables:badArg', ...
                'First arg must be ''pooled'', ''averaged'', ''--selftest'', or a cfg struct.');
        end
    end

    cfg.cbvDir   = fullfile('.', '7validation', 'CBV');
    cfg.useExcel = true;     % Excel COM preserves fonts/borders; built-in writer drops them
    cfg.statMode = mode;     % 'averaged' (per-year stat, mean over years) | 'pooled' (pool raw pts)
    cfg.template = fullfile('.', 'paper-3-figures', 'SampleTablesPaper3.orig.xlsx');
    if strcmp(mode, 'pooled')
        cfg.xlsx = fullfile('.', 'paper-3-figures', 'SampleTablesPaper3_pooled.xlsx');
    else
        cfg.xlsx = fullfile('.', 'paper-3-figures', 'SampleTablesPaper3.xlsx');
    end
    fn = fieldnames(cfgIn);
    for i = 1:numel(fn), cfg.(fn{i}) = cfgIn.(fn{i}); end

    assert(exist(cfg.cbvDir, 'dir') == 7, 'CBV dir not found: %s', cfg.cbvDir);

    % Ensure the target workbook exists; create it from the pristine styled template.
    if exist(cfg.xlsx, 'file') ~= 2
        assert(exist(cfg.template, 'file') == 2, ...
            'Template not found: %s (build the averaged version first).', cfg.template);
        copyfile(cfg.template, cfg.xlsx);
        fprintf('Created %s from template.\n', cfg.xlsx);
    end

    % One-time backup of the pristine averaged template.
    if strcmp(cfg.statMode, 'averaged')
        [p, n, e] = fileparts(cfg.xlsx);
        bak = fullfile(p, [n '.orig' e]);
        if exist(bak, 'file') ~= 2
            copyfile(cfg.xlsx, bak);
            fprintf('Backed up template -> %s\n', bak);
        end
    end

    T = local_compute(cfg.cbvDir, cfg.statMode);
    local_writeWorkbook(cfg.xlsx, T, cfg.useExcel);
    local_report(T);
end

% ======================================================================
% COMPUTATION
% ======================================================================
function T = local_compute(cbvDir, mode)
% Build every table block as numeric matrices (NaN = missing).
% mode = 'averaged' (per-year stat, mean across years) | 'pooled' (pool raw points).

    T.statMode = mode;
    boxes = [5.0 20.0];

    % Period labels and the year windows they average over.
    T.periods = {'1990-2004', 1990:2004; ...
                 '2005-2016', 2005:2016; ...
                 '2017-2020', 2017:2020; ...
                 '2021',      2021; ...
                 '2022',      2022};
    nP = size(T.periods, 1);

    % Satellite (Obs+M3fusion+SAT) family code chosen per period & box.
    % 1990-2004 -> none; 2005-2016 & 2021 -> -06 (OMI); 2017-2020 -> -0E (+IASI);
    % 2022 -> -42 (CrIS) at 5deg, but CrIS was not run at 20deg -> fall back to -06.
    satCode = { '',            '' ; ...
                '13000313-06', '13000313-06' ; ...
                '13000313-0E', '13000313-0E' ; ...
                '13000313-06', '13000313-06' ; ...
                '13000313-42', '13000313-06' };   % {5deg, 20deg}

    % Per box, per period: base / m3 / sat  for R2 and RMSE.
    T.box = boxes;
    for b = 1:numel(boxes)
        box = boxes(b);
        for i = 1:nP
            yrs = T.periods{i, 2};
            [T.baseR2(i, b), T.baseRMSE(i, b)] = ...
                local_periodStat(cbvDir, '10000133', 0, box, yrs, mode);
            [T.m3R2(i, b),   T.m3RMSE(i, b)]   = ...
                local_periodStat(cbvDir, '13000313-02', 3, box, yrs, mode);
            sc = satCode{i, b};
            if isempty(sc)
                T.satR2(i, b) = NaN; T.satRMSE(i, b) = NaN;
            else
                [T.satR2(i, b), T.satRMSE(i, b)] = ...
                    local_periodStat(cbvDir, sc, 3, box, yrs, mode);
            end
        end
    end

    % Recommended (best-method-sheet) config name per period & box.
    T.recName = { 'Obs. + M3fusion', 'Obs. + M3fusion' ; ...
                  'Obs. + M3fusion + OMI-MLS', 'Obs. + M3fusion + OMI-MLS' ; ...
                  'Obs. + M3fusion + OMI-MLS + IASI-GOME2', ...
                      'Obs. + M3fusion + OMI-MLS + IASI-GOME2' ; ...
                  'Obs. + M3fusion + OMI-MLS', 'Obs. + M3fusion + OMI-MLS' ; ...
                  'Obs. + M3fusion + CrIS', 'Obs. + M3fusion + OMI-MLS' };
    % Recommended config skill = M3fusion for 1990-2004, else the satellite family.
    T.recR2   = T.satR2;   T.recR2(1, :)   = T.m3R2(1, :);
    T.recRMSE = T.satRMSE; T.recRMSE(1, :) = T.m3RMSE(1, :);

    % Ranking pool: canonical 11 methods minus -03.  {token, code, go}.
    pool = { '10000133go0', '10000133',    0 ; ...
             '10000133go3', '10000133',    3 ; ...
             '13000313-02', '13000313-02', 3 ; ...
             '13000313-04', '13000313-04', 3 ; ...
             '13000313-08', '13000313-08', 3 ; ...
             '13000313-40', '13000313-40', 3 ; ...
             '13000313-06', '13000313-06', 3 ; ...
             '13000313-0A', '13000313-0A', 3 ; ...
             '13000313-42', '13000313-42', 3 ; ...
             '13000313-0E', '13000313-0E', 3 };
    T.pool = pool;

    % Ranking covers all periods (the 3 multi-year eras + single years 2021, 2022),
    % written to rows 4..(3+nPeriods) of the ranking sheets.
    eras = T.periods;
    T.eras = eras;
    for i = 1:size(eras, 1)
        yrs = eras{i, 2};
        for b = 1:numel(boxes)
            box = boxes(b);
            np = size(pool, 1);
            r  = nan(np, 1); rm = nan(np, 1);
            for k = 1:np
                [r(k), rm(k)] = local_periodStat(cbvDir, pool{k, 2}, pool{k, 3}, box, yrs, mode);
            end
            ok = find(~isnan(r));
            % rank: R2 desc, tie-break RMSE asc
            [~, ord] = sortrows([-r(ok), rm(ok)]);
            ok = ok(ord);
            T.rank{i, b} = ok;        % indices into pool, best first
            T.rankR2{i, b}  = r;
            T.rankRMSE{i, b} = rm;
            % ObsFlat (column 4) is always pool row 1 (10000133go0)
        end
    end
end

function [r, rm] = local_periodStat(cbvDir, code, go, box, years, mode)
% Dispatch a period's [R2, RMSE] by mode: 'pooled' or 'averaged'.
    if strcmpi(mode, 'pooled')
        [r, rm] = local_periodPooled(cbvDir, code, go, box, years);
    else
        [r, rm] = local_periodAvg(cbvDir, code, go, box, years);
    end
end

function [r, rm] = local_periodPooled(cbvDir, code, go, box, years)
% Pool every year+fold's raw (obs,est) points over the period, then compute a
% single R2/RMSE via the project's calculateValidationStats. NaN if < 2 points.
    O = []; E = [];
    for y = years
        for f = 1:2
            fn = fullfile(cbvDir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                code, go, box, f, y));
            if exist(fn, 'file') ~= 2, continue; end
            try
                S = load(fn, 'annualResults');
                if ~isfield(S, 'annualResults'), continue; end
                ar = S.annualResults;
                if isfield(ar, 'Y_obs') && isfield(ar, 'Y_est')
                    O = [O; ar.Y_obs(:)]; %#ok<AGROW>
                    E = [E; ar.Y_est(:)]; %#ok<AGROW>
                end
            catch
                % skip unreadable file
            end
        end
    end
    ok = ~isnan(O) & ~isnan(E);
    if sum(ok) < 2
        r = NaN; rm = NaN; return;
    end
    st = calculateValidationStats(O(ok), E(ok));
    r  = st.R2; rm = st.RMSE;
end

function [r, rm] = local_periodAvg(cbvDir, code, go, box, years)
% Mean over YEARS of the fold-averaged annual R2 / RMSE. NaN if none.
    rv = []; tv = [];
    for y = years
        a = []; b = [];
        for f = 1:2
            fn = fullfile(cbvDir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                code, go, box, f, y));
            if exist(fn, 'file') ~= 2, continue; end
            try
                S = load(fn, 'annualStats');
                if ~isfield(S, 'annualStats'), continue; end
                if isfield(S.annualStats, 'R2'),   a(end+1) = S.annualStats.R2;   end %#ok<AGROW>
                if isfield(S.annualStats, 'RMSE'), b(end+1) = S.annualStats.RMSE; end %#ok<AGROW>
            catch
                % skip unreadable file
            end
        end
        if ~isempty(a), rv(end+1) = mean(a, 'omitnan'); end %#ok<AGROW>
        if ~isempty(b), tv(end+1) = mean(b, 'omitnan'); end %#ok<AGROW>
    end
    if isempty(rv), r = NaN; else, r = mean(rv, 'omitnan'); end
    if isempty(tv), rm = NaN; else, rm = mean(tv, 'omitnan'); end
end

% ======================================================================
% WORKBOOK WRITING  (sheet tab names, not the sheetN.xml indices)
% ======================================================================
function local_writeWorkbook(xlsx, T, useExcel)
    impR2   = @(v, base) (v - base) ./ base;       % R2 higher better
    impRMSE = @(v, base) (base - v) ./ base;       % RMSE lower better
    b5 = 1; b20 = 2;                               % box column indices
    wr = @(C, sheet, rng) writecell(C, xlsx, 'Sheet', sheet, 'Range', rng, ...
                                    'UseExcel', useExcel);

    % ---- Sheet 'Sheet10' : master R2 table (B3:I7) ----
    M = nan(5, 8);
    M(:, 1) = local_r(T.baseR2(:, b5), 3);
    M(:, 2) = local_r(T.baseR2(:, b20), 3);
    M(:, 3) = local_r(T.m3R2(:, b5), 3);
    M(:, 4) = local_r(T.m3R2(:, b20), 3);
    M(:, 5) = local_r(impR2(T.m3R2(:, b20),  T.baseR2(:, b20)), 3);
    M(:, 6) = local_r(T.satR2(:, b5), 3);
    M(:, 7) = local_r(T.satR2(:, b20), 3);
    M(:, 8) = local_r(impR2(T.satR2(:, b20), T.m3R2(:, b20)), 3);
    wr(local_numcell(M), 'Sheet10', 'B3:I7');

    % ---- Family sheets: {tab, box, metric} ----
    %  Sheet2=5deg R2, Sheet3=20deg R2, Sheet6=5deg RMSE, Sheet7=20deg RMSE
    fam = { 'Sheet2', b5,  'R2' ; ...
            'Sheet3', b20, 'R2' ; ...
            'Sheet6', b5,  'RMSE' ; ...
            'Sheet7', b20, 'RMSE' };
    for q = 1:size(fam, 1)
        bcol = fam{q, 2};
        if strcmp(fam{q, 3}, 'R2')
            base = T.baseR2(:, bcol); m3 = T.m3R2(:, bcol); sat = T.satR2(:, bcol);
            imp = impR2;  nd = 3;
        else
            base = T.baseRMSE(:, bcol); m3 = T.m3RMSE(:, bcol); sat = T.satRMSE(:, bcol);
            imp = impRMSE; nd = 2;
        end
        F = nan(5, 5);
        F(:, 1) = local_r(base, nd);
        F(:, 2) = local_r(m3, nd);
        F(:, 3) = local_r(imp(m3, base), 3);
        F(:, 4) = local_r(sat, nd);
        F(:, 5) = local_r(imp(sat, base), 3);
        wr(local_numcell(F), fam{q, 1}, 'B3:F7');
    end

    % ---- Best-method sheets: Sheet4=5deg, Sheet5=20deg (B3:F7) ----
    bm = { 'Sheet4', b5 ; 'Sheet5', b20 };
    for q = 1:size(bm, 1)
        bcol = bm{q, 2};
        C = cell(5, 5);
        for i = 1:5
            C{i, 1} = T.recName{i, bcol};
            C{i, 2} = local_r(T.recR2(i, bcol), 3);
            C{i, 3} = local_r(T.recRMSE(i, bcol), 2);
            C{i, 4} = local_r(impR2(T.recR2(i, bcol),   T.baseR2(i, bcol)), 3);
            C{i, 5} = local_r(impRMSE(T.recRMSE(i, bcol), T.baseRMSE(i, bcol)), 3);
        end
        C = local_nanstr(C);
        wr(C, bm{q, 1}, 'B3:F7');
    end

    % ---- Ranking sheets: Sheet8=5deg, Sheet9=20deg ----
    % 13-col layout: Period | {Method, R2, RMSE} x {Best, Second, Next, ObsFlat}.
    % The Method cell names the config behind each rank's stats.
    rk = { 'Sheet8', 1 ; 'Sheet9', 2 };
    nE = size(T.eras, 1);
    hdr2 = {'Time-Period', 'Best Method', '', '', 'Second Best', '', '', ...
            'Next Best', '', '', 'Using Obs Only (Flat)', '', ''};
    hdr3 = {'', 'Method', 'R2', 'RMSE', 'Method', 'R2', 'RMSE', ...
            'Method', 'R2', 'RMSE', 'Method', 'R2', 'RMSE'};
    for q = 1:size(rk, 1)
        bcol = rk{q, 2};
        D = cell(nE, 13);
        for i = 1:nE
            ord = T.rank{i, bcol};
            r   = T.rankR2{i, bcol};
            rm  = T.rankRMSE{i, bcol};
            D{i, 1} = T.eras{i, 1};

            % Gather the (<=3) best ranked methods + ObsFlat, then pick the
            % fewest decimals that keep the ranked methods visually distinct
            % so the user can see how the top three actually separate.
            r2vals = nan(4, 1); rmvals = nan(4, 1); names = cell(4, 1);
            for s = 1:3                         % best / second / next
                if numel(ord) >= s
                    names{s}  = local_name(T.pool{ord(s), 1});
                    r2vals(s) = r(ord(s));
                    rmvals(s) = rm(ord(s));
                else
                    names{s} = 'NAN';            % r2vals/rmvals stay NaN
                end
            end
            names{4}  = local_name(T.pool{1, 1});   % ObsFlat = pool row 1
            r2vals(4) = r(1);
            rmvals(4) = rm(1);

            r2str = local_fmtDistinct(r2vals, 3, 6);   % R2: >=3 dp, up to 6
            rmstr = local_fmtDistinct(rmvals, 2, 5);   % RMSE: >=2 dp, up to 5

            for s = 1:3
                cc = 2 + (s - 1) * 3;
                D{i, cc}     = names{s};
                D{i, cc + 1} = r2str{s};
                D{i, cc + 2} = rmstr{s};
            end
            D{i, 11} = names{4};
            D{i, 12} = r2str{4};
            D{i, 13} = rmstr{4};
        end
        D = local_nanstr(D);
        wr(hdr2, rk{q, 1}, 'A2:M2');                       % rank headers
        wr(hdr3, rk{q, 1}, 'A3:M3');                       % Method/R2/RMSE sub-labels
        wr(D,    rk{q, 1}, sprintf('A4:M%d', 3 + nE));     % data
    end

    % ---- Commands sheet ----
    cmds = local_commandLog(T.statMode);
    wr(cmds, 'Commands', 'A1');
end

% ======================================================================
% HELPERS
% ======================================================================
function y = local_r(x, n)
% Round, NaN-safe (round() already passes NaN through).
    y = round(x, n);
end

function s = local_fmtDistinct(vals, minD, maxD)
% Format the values as strings using the FEWEST decimals in [minD,maxD] that
% keep all non-NaN entries distinct, so closely-ranked methods stay visually
% separable in the workbook. NaN -> 'NAN'. Strings (not numbers) are returned
% so the displayed precision survives the cell's number format.
    v    = vals(:);
    good = v(~isnan(v));
    nd   = maxD;
    for d = minD:maxD
        if numel(unique(round(good, d))) == numel(good)
            nd = d; break;          % enough decimals to separate them
        end
    end
    s = cell(size(v));
    for i = 1:numel(v)
        if isnan(v(i)), s{i} = 'NAN';
        else,           s{i} = sprintf('%.*f', nd, v(i));
        end
    end
end

function C = local_numcell(M)
% Numeric matrix -> cell, NaN -> 'NAN' (matches the template's text sentinel).
    C = num2cell(M);
    C(isnan(M)) = {'NAN'};
end

function C = local_nanstr(C)
% In a mixed cell, replace numeric NaN entries with the string 'NAN'.
    for i = 1:numel(C)
        if isnumeric(C{i}) && isscalar(C{i}) && isnan(C{i})
            C{i} = 'NAN';
        end
    end
end

function name = local_name(token)
    map = { ...
        '10000133go0', 'Obs only (Flat GO)' ; ...
        '10000133go3', 'Obs only (GO3)' ; ...
        '13000313-02', 'Obs + M3fusion' ; ...
        '13000313-04', 'Obs + OMI-MLS' ; ...
        '13000313-08', 'Obs + IASI-GOME2' ; ...
        '13000313-40', 'Obs + CrIS' ; ...
        '13000313-06', 'Obs + M3fusion + OMI-MLS' ; ...
        '13000313-0A', 'Obs + M3fusion + IASI-GOME2' ; ...
        '13000313-42', 'Obs + M3fusion + CrIS' ; ...
        '13000313-0E', 'Obs + M3fusion + OMI-MLS + IASI-GOME2' };
    idx = find(strcmp(map(:, 1), token), 1);
    if isempty(idx), name = token; else, name = map{idx, 2}; end
end

function cmds = local_commandLog(statMode)
    if strcmpi(statMode, 'pooled')
        runCmd  = 'matlab -batch "fillPaperTables(''pooled'')"';
        srcLine = 'Source:        annualResults.Y_obs/.Y_est (raw validation points)';
        conv = {'Stat convention (POOLED): pool every year+fold raw (obs,est) point in the'; ...
                '  window into one set, then one calculateValidationStats per period'; ...
                '  (point-weighted; data-rich years dominate). R2 = Pearson corr^2.'};
    else
        runCmd  = 'matlab -batch "fillPaperTables"';
        srcLine = 'Source:        annualStats.R2 and annualStats.RMSE (pre-computed per year/fold)';
        conv = {'Stat convention (AVERAGED): per year = mean over folds 1..2; period = mean'; ...
                '  over the years in the window (equal weight per year, NaN-safe).'};
    end
    cmds = [ { ...
      ['Commands / provenance  (statMode = ' statMode ')']; ...
      ''; ...
      ['Generated by:  ' runCmd]; ...
      srcLine; ...
      '' }; ...
      conv(:); ...
      { ''; ...
      'Box sizes: 5.0 and 20.0 degrees.'; ...
      'Percent improvement (fraction, vs ObsFlat base):'; ...
      '  R2   : (val - base) / base      RMSE : (base - val) / base'; ...
      'Percent improvement (fraction, vs ObsFlat base):'; ...
      '  R2   : (val - base) / base      RMSE : (base - val) / base'; ...
      ''; ...
      'Method families:'; ...
      '  ObsFlat (Base)         = 10000133  go0'; ...
      '  Obs+M3fusion           = 13000313-02  go3'; ...
      '  Obs+M3fusion+Satellite = 13000313-06 (OMI-MLS, 2005-2016 & 2021),'; ...
      '                           13000313-0E (+IASI-GOME2, 2017-2020),'; ...
      '                           13000313-42 (+CrIS, 2022 @5deg; 20deg falls back to -06).'; ...
      '                           1990-2004 has no satellite -> NAN.'; ...
      ''; ...
      'Ranking sheets pool (canonical 11 minus -03), ranked by period R2'; ...
      '  (tie-break RMSE), best/second/next per period (rows 4-8):'; ...
      '  10000133go0, 10000133go3, 13000313-02, -04, -08, -40, -06, -0A, -42, -0E'; ...
      ''; ...
      'Sheet map (tab name -> content):'; ...
      '  Sheet10 = master R2 (both boxes)   Sheet2/3 = 5/20deg R2'; ...
      '  Sheet6/7 = 5/20deg RMSE            Sheet4/5 = best method 5/20deg'; ...
      '  Sheet8/9 = best/second/next ranking 5/20deg'; ...
      ''; ...
      ['Run timestamp: ' char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))] } ];
end

function local_report(T)
    fprintf('\nFilled tables (statMode = %s). Headline R2 numbers:\n', T.statMode);
    fprintf('%-10s | %-22s | %-22s | %-22s\n', 'Period', ...
        'ObsFlat R2(5/20)', 'M3fusion R2(5/20)', 'Satellite R2(5/20)');
    for i = 1:size(T.periods, 1)
        fprintf('%-10s | %6.3f / %-6.3f       | %6.3f / %-6.3f       | %6.3f / %-6.3f\n', ...
            T.periods{i, 1}, T.baseR2(i, 1), T.baseR2(i, 2), ...
            T.m3R2(i, 1), T.m3R2(i, 2), T.satR2(i, 1), T.satR2(i, 2));
    end
    fprintf('\nRanking winners (best/second/next) by era:\n');
    for b = 1:2
        bx = T.box(b);
        fprintf('  --- %g deg ---\n', bx);
        for i = 1:size(T.eras, 1)
            ord = T.rank{i, b};
            nm = arrayfun(@(k) local_name(T.pool{k, 1}), ord(1:min(3, numel(ord))), ...
                'UniformOutput', false);
            fprintf('    %-10s : %s\n', T.eras{i, 1}, strjoin(nm, '  >  '));
        end
    end
end

% ======================================================================
% SELF TEST
% ======================================================================
function local_selftest()
    fprintf('fillPaperTables --selftest\n');
    tmp = tempname; mkdir(tmp);
    cdir = fullfile(tmp, 'CBV'); mkdir(cdir);
    cleaner = onCleanup(@() rmdir(tmp, 's'));

    % helper to drop a synthetic annual file
    putfile = @(code, go, box, fold, yr, r2, rmse) local_putAnnual(cdir, code, go, box, fold, yr, r2, rmse);

    % Two folds for one method/year -> period avg must be the fold mean.
    putfile('10000133', 0, 5.0, 1, 2010, 0.60, 8.0);
    putfile('10000133', 0, 5.0, 2, 2010, 0.70, 6.0);   % fold mean: R2 .65, RMSE 7.0
    [r, rm] = local_periodAvg(cdir, '10000133', 0, 5.0, 2010);
    assert(abs(r - 0.65) < 1e-12 && abs(rm - 7.0) < 1e-12, 'fold avg');

    % Two years -> across-year mean.
    putfile('10000133', 0, 5.0, 1, 2011, 0.80, 4.0);
    putfile('10000133', 0, 5.0, 2, 2011, 0.80, 4.0);   % yr2: .80 / 4.0
    [r, rm] = local_periodAvg(cdir, '10000133', 0, 5.0, 2010:2011);
    assert(abs(r - mean([0.65 0.80])) < 1e-12 && abs(rm - mean([7.0 4.0])) < 1e-12, 'year avg');

    % Missing -> NaN.
    [r, rm] = local_periodAvg(cdir, '13000313-99', 3, 5.0, 2010);
    assert(isnan(r) && isnan(rm), 'missing -> NaN');

    % % improvement formulas.
    impR2   = @(v, base) (v - base) ./ base;
    impRMSE = @(v, base) (base - v) ./ base;
    assert(abs(impR2(0.769, 0.680) - 0.1309) < 1e-3, 'R2 imp');     % matches seed 0.131
    assert(abs(impRMSE(6.0, 8.0) - 0.25) < 1e-12, 'RMSE imp');

    % Ranking: best by R2, tie-break by lower RMSE.
    yr = 2012;
    putfile('13000313-02', 3, 5.0, 1, yr, 0.70, 7.0);
    putfile('13000313-02', 3, 5.0, 2, yr, 0.70, 7.0);
    putfile('13000313-06', 3, 5.0, 1, yr, 0.90, 5.0);   % clear best
    putfile('13000313-06', 3, 5.0, 2, yr, 0.90, 5.0);
    putfile('13000313-04', 3, 5.0, 1, yr, 0.90, 4.0);   % ties R2 with -06 but lower RMSE -> 1st
    putfile('13000313-04', 3, 5.0, 2, yr, 0.90, 4.0);
    pool = {'13000313-02', '13000313-02', 3; '13000313-04', '13000313-04', 3; ...
            '13000313-06', '13000313-06', 3};
    np = size(pool, 1); r = nan(np, 1); rm = nan(np, 1);
    for k = 1:np, [r(k), rm(k)] = local_periodAvg(cdir, pool{k, 2}, pool{k, 3}, 5.0, yr); end
    ok = find(~isnan(r)); [~, ord] = sortrows([-r(ok), rm(ok)]); ok = ok(ord);
    assert(isequal(ok(:)', [2 3 1]), 'ranking order');   % -04, then -06, then -02

    % local_numcell / local_nanstr NaN handling.
    C = local_numcell([1 NaN; 0.5 2]);
    assert(strcmp(C{1, 2}, 'NAN') && C{1, 1} == 1, 'numcell NAN');
    C2 = local_nanstr({'x', NaN, 3});
    assert(strcmp(C2{2}, 'NAN') && C2{3} == 3, 'nanstr NAN');

    % name map.
    assert(strcmp(local_name('13000313-0E'), 'Obs + M3fusion + OMI-MLS + IASI-GOME2'), 'name');

    % pooled: concatenate raw points across folds+years, one calculateValidationStats.
    o1 = [1;2;3;4;5;6]; e1 = [1.1;1.9;3.2;3.8;5.1;5.9];
    o2 = [2;3;4;5;6;7]; e2 = [2.2;2.7;4.1;5.3;5.8;7.2];
    local_putRaw(cdir, '13000313-77', 3, 5.0, 1, 2013, o1, e1);
    local_putRaw(cdir, '13000313-77', 3, 5.0, 2, 2013, o2, e2);
    [pr, prm] = local_periodPooled(cdir, '13000313-77', 3, 5.0, 2013);
    st = calculateValidationStats([o1; o2], [e1; e2]);
    assert(abs(pr - st.R2) < 1e-10 && abs(prm - st.RMSE) < 1e-10, 'pooled concat');
    % dispatcher routes by mode
    [dr, ~] = local_periodStat(cdir, '13000313-77', 3, 5.0, 2013, 'pooled');
    assert(abs(dr - st.R2) < 1e-10, 'dispatch pooled');
    [ar, ~] = local_periodStat(cdir, '10000133', 0, 5.0, 2010:2011, 'averaged');
    assert(abs(ar - mean([0.65 0.80])) < 1e-12, 'dispatch averaged');

    fprintf('ALL PASSED\n');
end

function local_putRaw(cdir, code, go, box, fold, yr, o, e)
    annualResults = struct('Y_obs', o, 'Y_est', e);
    annualStats   = struct('R2', 0, 'RMSE', 0, 'Year', yr, 'Fold', fold, 'BoxSize', box);
    fn = fullfile(cdir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
        code, go, box, fold, yr));
    save(fn, 'annualResults', 'annualStats');
end

function local_putAnnual(cdir, code, go, box, fold, yr, r2, rmse)
    annualStats = struct('R2', r2, 'RMSE', rmse, 'Year', yr, 'Fold', fold, ...
                         'BoxSize', box);
    fn = fullfile(cdir, sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
        code, go, box, fold, yr));
    save(fn, 'annualStats');
end
