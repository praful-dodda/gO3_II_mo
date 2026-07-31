function Priority = inventoryBMEestimates(cfg)
% inventoryBMEestimates - Audit monthly BME spatial-estimate completeness -> Excel
%
% Scans the monthly BME estimate .mat files in 5BMEspatialPlots/ (by FILENAME
% only - the .mat contents are never read) and reports, for every configuration
% and every year, whether all 12 months are present.
%
% A "configuration" is the full base filename before the _time field, i.e.
%   BME<method>_go<G>_lt<L>_area<A>_res<R>[_<fmt>][_land<F>]
% so the same BME method run at different area/resolution/land settings is
% tracked as separate configurations.
%
% USAGE:
%   inventoryBMEestimates            % uses the defaults below
%   inventoryBMEestimates(cfg)       % override any default field via struct cfg
%
% OUTPUT: estimate_inventory.xlsx with two sheets
%   Matrix  - rows = years, one column per config, cells = Done / Partial (N/12)
%   Detail  - one row per (config, year): method/go/area/res/.../months/missing
%
% Month encoding: file time = Y + (m-1)/12 (m = 1..12), formatted %.2f, so the
% 12 monthly fractions are {.00 .08 .17 .25 .33 .42 .50 .58 .67 .75 .83 .92}.

%% ===================== CONFIG (edit or override via cfg) ================
d = struct();
d.srcDir    = '5BMEspatialPlots';
d.yearRange = [1990 2022];
d.outFile   = 'estimate_inventory.xlsx';

% Production config that the required methods are expected to have been run at
% (matches runBME_estimation / runPostprocess methodConfig).
d.methodConfig = struct('goScenario', 3, 'logTransf', 0, 'areaCode', 0, ...
    'mapResolution', 1.0, 'dataFormat', 'stug', 'keepOnlyLand', 1);

% Required per-period methods (the selected best fusion per era). Columns:
%   {startYear, endYear, BMEcode, description}.  Only the code drives the check.
d.required = { ...
    1990, 2004, '13000313-02', 'Obs + M3fusion'; ...
    2005, 2016, '13000313-06', 'Obs + M3fusion + OMI-MLS'; ...
    2017, 2020, '13000313-0E', 'Obs + M3fusion + OMI-MLS + IASI+GOME2'; ...
    2021, 2021, '13000313-06', 'Obs + M3fusion + OMI-MLS'; ...
    2022, 2022, '10000133',    'Observations only (obs-only, best for 2022)'};

if nargin < 1 || isempty(cfg), cfg = struct(); end
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(cfg, f{i}), cfg.(f{i}) = d.(f{i}); end
end

years = cfg.yearRange(1):cfg.yearRange(2);
nYears = numel(years);

%% ---- Scan directory ----------------------------------------------------
listing = dir(fullfile(cfg.srcDir, 'BME*.mat'));
if isempty(listing)
    error('inventoryBMEestimates:noFiles', ...
        'No BME*.mat files found in %s', cfg.srcDir);
end

% Tolerant pattern: optional _<fmt>, optional _land<F>, optional _lc<R> leak tag.
pat = ['^BME(?<method>[0-9]{8}(?:-[0-9A-Za-z]+)?)' ...
       '_go(?<go>\d+)_lt(?<lt>\d+)_area(?<area>\d+)_res(?<res>[0-9.]+)' ...
       '(?:_(?<fmt>st[uvg]+))?(?:_land(?<land>[01]))?' ...
       '_time(?<time>\d{4}\.\d{2})(?:_lc[0-9.]+)?\.mat$'];

% Map: config string -> struct(meta, monthsByYear [nYears x 12 logical])
configs = containers.Map('KeyType', 'char', 'ValueType', 'any');

nMatched = 0; nSkipped = 0;
for k = 1:numel(listing)
    name = listing(k).name;
    t = regexp(name, pat, 'names', 'once');
    if isempty(t)
        nSkipped = nSkipped + 1;
        continue
    end
    nMatched = nMatched + 1;

    tnum  = str2double(t.time);
    yr    = floor(tnum + 1e-6);              % integer year (Jan = .00 belongs to yr)
    frac  = tnum - yr;
    month = round(frac * 12) + 1;            % 1..12
    if month < 1 || month > 12, continue, end

    yi = find(years == yr, 1);
    if isempty(yi), continue, end            % outside requested year range

    % config key = full base name before the _time field
    cfgKey = regexprep(name, '_time\d{4}\.\d{2}(?:_lc[0-9.]+)?\.mat$', '');

    if isKey(configs, cfgKey)
        S = configs(cfgKey);
    else
        S = struct();
        S.method = t.method;
        S.go     = t.go;
        S.lt     = t.lt;
        S.area   = t.area;
        S.res    = t.res;
        if isfield(t,'fmt')  && ~isempty(t.fmt),  S.fmt  = t.fmt;  else, S.fmt  = ''; end
        if isfield(t,'land') && ~isempty(t.land), S.land = t.land; else, S.land = ''; end
        S.months = false(nYears, 12);
    end
    S.months(yi, month) = true;
    configs(cfgKey) = S;
end

cfgKeys = sort(configs.keys);
nCfg = numel(cfgKeys);

%% ---- Build Matrix sheet (years x configs) ------------------------------
% Layout: row 1 = header ['Year', config1, config2, ...]; one row per year.
M = cell(nYears + 1, nCfg + 1);
M{1,1} = 'Year';
for c = 1:nCfg, M{1, c+1} = cfgKeys{c}; end
for yi = 1:nYears
    M{yi+1, 1} = years(yi);
    for c = 1:nCfg
        S = configs(cfgKeys{c});
        n = nnz(S.months(yi, :));
        M{yi+1, c+1} = local_status(n);      % '' if 0
    end
end

%% ---- Build Detail sheet (long format) ----------------------------------
rows = {};   % accumulate cell rows
for c = 1:nCfg
    key = cfgKeys{c};
    S = configs(key);
    for yi = 1:nYears
        present = S.months(yi, :);
        n = nnz(present);
        if n == 0, continue, end
        missing = find(~present);
        missStr = strjoin(arrayfun(@(x) sprintf('%d', x), missing, ...
            'UniformOutput', false), ',');
        rows(end+1, :) = { key, S.method, str2double(S.go), str2double(S.area), ...
            str2double(S.res), S.fmt, S.land, years(yi), n, ...
            local_status(n), missStr }; %#ok<AGROW>
    end
end
detailVars = {'Config','BMEmethod','GO','Area','Res','Format','Land', ...
    'Year','MonthsPresent','Status','MissingMonths'};
if isempty(rows)
    Detail = cell2table(cell(0, numel(detailVars)), 'VariableNames', detailVars);
else
    Detail = cell2table(rows, 'VariableNames', detailVars);
    Detail = sortrows(Detail, {'Config','Year'});
end

%% ---- Required-vs-done + priority to run --------------------------------
% For each required (period, code), build the expected config key at the
% production settings and tally month coverage per year. Rank what to run by
% how many months are still missing (most missing first).
mc = cfg.methodConfig;
req = cfg.required;
nReq = size(req, 1);
prows = cell(nReq, 12);
for r = 1:nReq
    y0 = req{r,1}; y1 = req{r,2}; code = req{r,3}; desc = req{r,4};
    key = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', code, ...
        mc.goScenario, mc.logTransf, mc.areaCode, mc.mapResolution, ...
        mc.dataFormat, mc.keepOnlyLand);
    reqYears = y0:y1;
    monthsReq = 12 * numel(reqYears);
    monthsDone = 0;
    missingYears = {};
    present = isKey(configs, key);
    if present, S = configs(key); end
    for y = reqYears
        yi = find(years == y, 1);
        n = 0;
        if present && ~isempty(yi), n = nnz(S.months(yi, :)); end
        monthsDone = monthsDone + n;
        if n < 12, missingYears{end+1} = sprintf('%d', y); end %#ok<AGROW>
    end
    if monthsDone >= monthsReq
        status = 'Done';
    elseif monthsDone == 0
        status = 'Missing';
    else
        status = 'Partial';
    end
    prows(r, :) = { 0, sprintf('%d-%d', y0, y1), desc, code, key, ...
        present, numel(reqYears), monthsReq, monthsDone, ...
        round(100 * monthsDone / monthsReq), status, ...
        strjoin(missingYears, ',') };
end
priVars = {'Priority','Period','Method','Code','ConfigKey','ConfigPresent', ...
    'YearsReq','MonthsReq','MonthsDone','PctDone','Status','MissingYears'};
Priority = cell2table(prows, 'VariableNames', priVars);
% Priority rank: incomplete blocks first, most-missing first; Done -> 0.
missCnt = Priority.MonthsReq - Priority.MonthsDone;
[~, ord] = sortrows([missCnt, (1:nReq)'], [-1 1]);
Priority = Priority(ord, :);
rank = zeros(nReq, 1);
incompl = Priority.MonthsDone < Priority.MonthsReq;
rank(incompl) = (1:nnz(incompl))';
Priority.Priority = rank;

%% ---- Write Excel -------------------------------------------------------
try
    if exist(cfg.outFile, 'file'), delete(cfg.outFile); end
    writetable(Priority, cfg.outFile, 'Sheet', 'Priority');
    writecell(M, cfg.outFile, 'Sheet', 'Matrix');
    writetable(Detail, cfg.outFile, 'Sheet', 'Detail');
catch ME
    [p, b, e] = fileparts(cfg.outFile);
    cfg.outFile = fullfile(p, sprintf('%s_%s%s', b, ...
        datestr(now,'yyyymmdd_HHMMSS'), e)); %#ok<TNOW1,DATST>
    warning('inventoryBMEestimates:locked', ...
        ['Could not write %s%s (%s) - it may be open in Excel. ' ...
         'Writing to %s instead.'], b, e, ME.message, cfg.outFile);
    writetable(Priority, cfg.outFile, 'Sheet', 'Priority');
    writecell(M, cfg.outFile, 'Sheet', 'Matrix');
    writetable(Detail, cfg.outFile, 'Sheet', 'Detail');
end

%% ---- Console summary ---------------------------------------------------
fprintf('\n=== BME estimate inventory ===\n');
fprintf('Scanned %s : %d files (%d matched, %d skipped)\n', ...
    cfg.srcDir, numel(listing), nMatched, nSkipped);
fprintf('Configurations: %d   Years: %d-%d\n', nCfg, years(1), years(end));
fprintf('%-52s %8s %8s\n', 'Config', 'Complete', 'Partial');
for c = 1:nCfg
    S = configs(cfgKeys{c});
    cnt = sum(S.months, 2);
    fprintf('%-52s %8d %8d\n', cfgKeys{c}, nnz(cnt == 12), nnz(cnt >= 1 & cnt < 12));
end
fprintf('\nWrote %s (sheets: Priority, Matrix, Detail)\n', cfg.outFile);

%% ---- Required-methods / priority-to-run report -------------------------
fprintf('\n=== Required methods: estimate completeness ===\n');
fprintf('%-4s %-10s %-13s %-8s %-7s %-6s %s\n', ...
    'Pri', 'Period', 'Code', 'Status', 'Done', 'Pct', 'MissingYears');
for r = 1:height(Priority)
    fprintf('%-4d %-10s %-13s %-8s %4d/%-2d %5d%% %s\n', ...
        Priority.Priority(r), Priority.Period{r}, Priority.Code{r}, ...
        Priority.Status{r}, Priority.MonthsDone(r), Priority.MonthsReq(r), ...
        Priority.PctDone(r), Priority.MissingYears{r});
end
nIncomplete = nnz(~strcmp(Priority.Status, 'Done'));
if nIncomplete == 0
    fprintf('\nALL REQUIRED ESTIMATES COMPLETE - ready for post-processing.\n\n');
else
    fprintf(['\n%d required method-period block(s) INCOMPLETE - run these ' ...
        '(priority order above) before post-processing.\n\n'], nIncomplete);
end

end

% ========================================================================
function s = local_status(n)
if n == 0
    s = '';
elseif n >= 12
    s = 'Done';
else
    s = sprintf('Partial (%d/12)', n);
end
end
