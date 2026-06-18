function [bestT, skillT] = bestMethodByYear(opts)
% bestMethodByYear - Pick the best-validating BME method for each year (analysis A)
%
% Reads every CBV summary CSV (one per method) in the validation folder,
% aggregates the skill per (method, year) by taking the median across folds and
% box sizes, then ranks methods within each year by R2 (tie-break: lower RMSE).
%
% SYNTAX:
%   [bestT, skillT] = bestMethodByYear()
%   [bestT, skillT] = bestMethodByYear(opts)
%
% opts (optional):
%   .cbvDir   (default fullfile('7validation','CBV'))
%   .pattern  (default 'CBV_summary_BME*.csv')
%   .outDir   (default fullfile('8postprocess','csv'))
%   .save     (default 1)
%   .verbose  (default 1)
%
% OUTPUTS:
%   bestT  - table: Year, BestMethod, R2, RMSE, RunnerUpMethod, R2_margin, nMethods
%            -> written to csv/best_method_by_year.csv
%   skillT - long table: Method, Year, R2, RMSE, MAE, NMB, nFolds (the medians)
%            -> written to csv/method_year_skill.csv
%
% NOTE: the CBV summary has no region column, so best-per-region is not produced
% here; rerun CBV with region-tagged folds to enable that.
%
% Run bestMethodByYear('--selftest') to execute built-in unit checks.
%
% SEE ALSO: runCBV_toar, runPostprocess

%% Self-test entry point
if nargin >= 1 && ischar(opts) && strcmp(opts, '--selftest')
    bestT = local_selftest();
    return;
end

if nargin < 1 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);

files = dir(fullfile(opts.cbvDir, opts.pattern));
if isempty(files)
    error('bestMethodByYear:noFiles', 'No CBV summaries match %s', ...
        fullfile(opts.cbvDir, opts.pattern));
end

%% Build the long (Method, Year) median-skill table
skillT = table();
for i = 1:numel(files)
    method = local_methodFromName(files(i).name);
    T = readtable(fullfile(files(i).folder, files(i).name));
    if ~all(ismember({'Year','R2','RMSE'}, T.Properties.VariableNames))
        warning('bestMethodByYear:cols', 'Skipping %s (missing columns).', files(i).name);
        continue;
    end
    metricVars = intersect({'R2','RMSE','MAE','NMB'}, T.Properties.VariableNames);
    g = groupsummary(T, 'Year', 'median', metricVars);
    out = table();
    out.Method = repmat(string(method), height(g), 1);
    out.Year   = g.Year;
    for v = 1:numel(metricVars)
        out.(metricVars{v}) = g.(sprintf('median_%s', metricVars{v}));
    end
    out.nFolds = g.GroupCount;
    skillT = [skillT; out]; %#ok<AGROW>
end
if isempty(skillT)
    error('bestMethodByYear:empty', 'No usable CBV summaries found.');
end

%% Rank within each year: R2 desc, RMSE asc
years = unique(skillT.Year);
nY = numel(years);
Year = years(:);
BestMethod     = strings(nY, 1);
R2             = nan(nY, 1);
RMSE           = nan(nY, 1);
RunnerUpMethod = strings(nY, 1);
R2_margin      = nan(nY, 1);
nMethods       = zeros(nY, 1);

for k = 1:nY
    rows = skillT(skillT.Year == years(k), :);
    % sort by R2 desc, then RMSE asc
    rows = sortrows(rows, {'R2','RMSE'}, {'descend','ascend'});
    nMethods(k) = height(rows);
    BestMethod(k) = rows.Method(1);
    R2(k)   = rows.R2(1);
    RMSE(k) = rows.RMSE(1);
    if height(rows) >= 2
        RunnerUpMethod(k) = rows.Method(2);
        R2_margin(k) = rows.R2(1) - rows.R2(2);
    end
end

bestT = table(Year, BestMethod, R2, RMSE, RunnerUpMethod, R2_margin, nMethods);

%% Save
if opts.save
    if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end
    writetable(bestT, fullfile(opts.outDir, 'best_method_by_year.csv'));
    writetable(skillT, fullfile(opts.outDir, 'method_year_skill.csv'));
    if opts.verbose
        fprintf('Wrote best_method_by_year.csv (%d years) and method_year_skill.csv\n', nY);
    end
end
if opts.verbose
    disp(bestT);
end

end

% ========================================================================
function method = local_methodFromName(fname)
% Extract the method token from CBV_summary_BME<method>_go<scen>...csv
tok = regexp(fname, '^CBV_summary_BME(.+?)_go\d+', 'tokens', 'once');
if isempty(tok)
    % fallback: strip prefix/suffix
    method = regexprep(fname, '^CBV_summary_BME|\.csv$', '');
else
    method = tok{1};
end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('cbvDir', fullfile('7validation','CBV'), ...
    'pattern', 'CBV_summary_BME*.csv', ...
    'outDir', fullfile('8postprocess','csv'), 'save', 1, 'verbose', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
tmp = tempname; mkdir(tmp);
cleaner = onCleanup(@() rmdir(tmp, 's'));

% Method AAA: R2 = 0.8 (2000), 0.6 (2001)
% Method BBB: R2 = 0.7 (2000), 0.6 (2001) but lower RMSE in 2001 -> wins tie
mk = @(method, year, boxsize, fold, r2, rmse) table( ...
    boxsize, fold, year, 100, r2, rmse, rmse*0.8, 1.0, ...
    'VariableNames', {'BoxSize','Fold','Year','N','R2','RMSE','MAE','NMB'});

A = [mk('AAA',2000,5,1,0.82,3.0); mk('AAA',2000,5,2,0.78,3.2); ...
     mk('AAA',2001,5,1,0.60,4.0)];
B = [mk('BBB',2000,5,1,0.70,2.5); ...
     mk('BBB',2001,5,1,0.60,3.0); mk('BBB',2001,5,2,0.60,3.0)];
writetable(A, fullfile(tmp, 'CBV_summary_BMEAAA_go3_lt0_x.csv'));
writetable(B, fullfile(tmp, 'CBV_summary_BMEBBB_go3_lt0_x.csv'));

[bestT, skillT] = bestMethodByYear(struct('cbvDir', tmp, 'outDir', tmp, ...
    'save', 0, 'verbose', 0));

% 2000: AAA median R2 = median(0.82,0.78)=0.80 > BBB 0.70 -> AAA wins
r2000 = bestT(bestT.Year == 2000, :);
assert(r2000.BestMethod == "AAA", '2000 best is AAA');
assert(abs(r2000.R2 - 0.80) < 1e-9, '2000 median R2');
assert(abs(r2000.R2_margin - 0.10) < 1e-9, '2000 margin');

% 2001: both R2=0.60 tie; AAA RMSE=4.0, BBB RMSE=3.0 -> BBB wins on lower RMSE
r2001 = bestT(bestT.Year == 2001, :);
assert(r2001.BestMethod == "BBB", '2001 tie-break by RMSE -> BBB');

% skill long table has both methods
assert(numel(unique(skillT.Method)) == 2, 'two methods in skillT');

fprintf('bestMethodByYear self-test: ALL PASSED.\n');
end
