function bestT = loadBestMethodCsv(csvPath, yearRange)
% loadBestMethodCsv - Read a user-authored year->BME-method CSV into a bestT table.
%
% Turns a hand-curated "which BME method is best for each year" CSV into the exact
% table shape the post-processing pipeline already consumes (composeBestMethodCube /
% loadCompositeCube): columns Year (numeric) and BestMethod (string method code).
%
% SYNTAX:
%   bestT = loadBestMethodCsv(csvPath)
%   bestT = loadBestMethodCsv(csvPath, yearRange)
%   loadBestMethodCsv('--selftest')      % run built-in unit checks
%
% INPUTS:
%   csvPath   - path to a CSV with one year column and one BME-method column.
%               Column headers are matched case-insensitively: the year column is
%               any header containing 'year'; the method column is any of
%               method / bmemethod / bestmethod / bme_method / bme method. If the
%               headers are unrecognized, the first numeric column is taken as Year
%               and the first text column as BestMethod.
%   yearRange - optional [y0 y1]; rows outside this range are dropped with a warning.
%
% OUTPUT:
%   bestT     - table with VariableNames {'Year','BestMethod'}, sorted by Year.
%               Year is numeric (rounded); BestMethod is a trimmed string with any
%               trailing GO suffix ('_go3' / 'go3') stripped so the bare code is used
%               for the estimate filenames. Empty/NaN rows are dropped; duplicate
%               years raise an error.
%
% All selected methods are assumed to share GO scenario 3 (the fusion default); a
% stripped GO suffix other than 3 raises a warning.
%
% SEE ALSO: runPostprocess, composeBestMethodCube, loadCompositeCube, bestMethodByYear

%% Self-test entry point
if nargin >= 1 && (ischar(csvPath) || isstring(csvPath)) && strcmp(csvPath, '--selftest')
    bestT = local_selftest();
    return;
end

if nargin < 2, yearRange = []; end
if ~exist(csvPath, 'file')
    error('loadBestMethodCsv:noFile', 'CSV not found: %s', csvPath);
end

T = readtable(csvPath, 'TextType', 'string');
if isempty(T) || width(T) < 2
    error('loadBestMethodCsv:badCsv', ...
        'CSV %s must have at least a year column and a method column.', csvPath);
end

vn = string(T.Properties.VariableNames);
vnl = lower(vn);

% ---- locate the year column ----
yi = find(contains(vnl, 'year'), 1);
% ---- locate the method column ----
methAliases = ["bestmethod","bmemethod","bme_method","bme method","method"];
mi = [];
for a = methAliases
    mi = find(vnl == a, 1);
    if ~isempty(mi), break; end
end
if isempty(mi)
    mi = find(contains(vnl, 'method'), 1);
end

% ---- fallback: infer by type (first numeric = year, first text = method) ----
if isempty(yi) || isempty(mi)
    isNum = varfun(@(c) isnumeric(c), T, 'OutputFormat', 'uniform');
    if isempty(yi), yi = find(isNum, 1); end
    if isempty(mi), mi = find(~isNum, 1); end
end
if isempty(yi) || isempty(mi) || yi == mi
    error('loadBestMethodCsv:cols', ...
        ['Could not identify distinct year and method columns in %s ' ...
         '(headers: %s). Expected a "year" column and a "method" column.'], ...
        csvPath, strjoin(vn, ', '));
end

yearsRaw = T.(vn(yi));
methRaw  = T.(vn(mi));

% ---- normalize Year -> numeric ----
if ~isnumeric(yearsRaw)
    yearsRaw = str2double(string(yearsRaw));
end
Year = round(double(yearsRaw(:)));

% ---- normalize BestMethod -> trimmed string, strip GO suffix ----
BestMethod = strtrim(string(methRaw(:)));
[BestMethod, goTok] = local_stripGo(BestMethod);

% ---- drop empty / NaN rows ----
keep = ~isnan(Year) & BestMethod ~= "" & ~ismissing(BestMethod);
dropped = sum(~keep);
if dropped > 0
    warning('loadBestMethodCsv:emptyRows', ...
        'Dropped %d row(s) with missing year or method.', dropped);
end
Year = Year(keep); BestMethod = BestMethod(keep); goTok = goTok(keep);

% ---- warn on non-go3 suffixes ----
badGo = goTok ~= "" & goTok ~= "3";
if any(badGo)
    warning('loadBestMethodCsv:goScenario', ...
        ['%d row(s) carry a GO suffix other than go3 (e.g. go%s); the pipeline ' ...
         'assumes GO scenario 3 for all methods. The suffix was stripped and ' ...
         'scenario 3 will be used.'], sum(badGo), goTok(find(badGo,1)));
end

% ---- range filter ----
if ~isempty(yearRange) && numel(yearRange) == 2
    inRange = Year >= yearRange(1) & Year <= yearRange(2);
    if any(~inRange)
        warning('loadBestMethodCsv:range', ...
            'Dropped %d row(s) with year outside [%d %d].', ...
            sum(~inRange), yearRange(1), yearRange(2));
    end
    Year = Year(inRange); BestMethod = BestMethod(inRange);
end

% ---- duplicate years are ambiguous ----
[uy, ~, g] = unique(Year);
if numel(uy) < numel(Year)
    cnt = accumarray(g, 1);
    dup = uy(cnt > 1);
    error('loadBestMethodCsv:dupYears', ...
        'Duplicate year(s) in %s: %s. Each year must map to one method.', ...
        csvPath, strjoin(string(dup), ', '));
end

if isempty(Year)
    error('loadBestMethodCsv:empty', 'No usable year/method rows in %s.', csvPath);
end

[Year, ord] = sort(Year);
BestMethod = BestMethod(ord);
bestT = table(Year, BestMethod, 'VariableNames', {'Year', 'BestMethod'});

end

% ========================================================================
function [code, goTok] = local_stripGo(s)
% Strip a trailing GO suffix ('_go3', 'go3', ' go3') and return the bare code
% plus the captured GO digits ('' if none). Vectorized over a string array.
s = string(s);
tok = regexp(s, '[_ ]?go(\d+)\s*$', 'tokens', 'once', 'ignorecase');
goTok = strings(size(s));
code = s;
for i = 1:numel(s)
    if ~isempty(tok{i})
        goTok(i) = string(tok{i});
        code(i) = strtrim(regexprep(s(i), '[_ ]?go\d+\s*$', '', 'ignorecase'));
    end
end
end

% ========================================================================
function ok = local_selftest()
ok = true;
tmp = [tempname '.csv'];
c = onCleanup(@() local_rm(tmp));

% Messy headers, a GO suffix, whitespace, out-of-order years, a blank row.
fid = fopen(tmp, 'w');
fprintf(fid, 'Year , BME_Method\n');
fprintf(fid, '2005, 13000313-06_go3\n');
fprintf(fid, '1995,  13000313-02 \n');
fprintf(fid, '2019, 13000313-0E\n');
fprintf(fid, ' , \n');                 % blank row -> dropped
fclose(fid);

bestT = loadBestMethodCsv(tmp, [1990 2022]);

assert(isequal(bestT.Properties.VariableNames, {'Year','BestMethod'}), 'colnames');
assert(isequal(bestT.Year, [1995; 2005; 2019]), 'years sorted/parsed');
assert(bestT.BestMethod(1) == "13000313-02", 'trim');
assert(bestT.BestMethod(2) == "13000313-06", 'go suffix stripped');
assert(bestT.BestMethod(3) == "13000313-0E", 'plain code');
assert(height(bestT) == 3, 'blank row dropped');

% Range filter drops out-of-range years.
b2 = loadBestMethodCsv(tmp, [2000 2022]);
assert(isequal(b2.Year, [2005; 2019]), 'range filter');

% Duplicate years must error.
tmp2 = [tempname '.csv'];
c2 = onCleanup(@() local_rm(tmp2));
fid = fopen(tmp2, 'w');
fprintf(fid, 'year,method\n2010,13000313-06\n2010,13000313-02\n');
fclose(fid);
threw = false;
try
    loadBestMethodCsv(tmp2);
catch
    threw = true;
end
assert(threw, 'duplicate years should error');

% Header-less type inference (numeric col -> Year, text col -> method).
tmp3 = [tempname '.csv'];
c3 = onCleanup(@() local_rm(tmp3));
fid = fopen(tmp3, 'w');
fprintf(fid, 'col1,col2\n2001,13000313-02\n2002,13000313-06\n');
fclose(fid);
b3 = loadBestMethodCsv(tmp3);
assert(isequal(b3.Year, [2001; 2002]) && b3.BestMethod(2) == "13000313-06", 'type inference');

fprintf('loadBestMethodCsv self-test: ALL PASSED.\n');
end

% ========================================================================
function local_rm(p)
if exist(p, 'file'), delete(p); end
end
