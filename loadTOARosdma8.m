function osd = loadTOARosdma8(years, varargin)
% loadTOARosdma8 - Read official TOAR per-station annual OSDMA8 CSVs
%
% Direct reader for the authoritative OSDMA8 metric exported per year as
% 1data/TOAR-OSDMA8/toar-OSDAM8-YYYY.csv with columns:
%   id, lat, lon, osdam8, country, type
% Unlike getTOARobservationalData_Yearly (which RECOMPUTES OSDMA8 from monthly
% MDA8), this returns the official value as-is, for use as validation truth.
%
% SYNTAX:
%   osd = loadTOARosdma8(2017)
%   osd = loadTOARosdma8([2016 2017 2018], 'stationTypes', 'urban')
%   osd = loadTOARosdma8(2017, 'dataDir', 'D:\alt\TOAR-OSDMA8')
%
% INPUTS:
%   years - target year(s) (scalar -> struct; vector -> 1xN struct array)
%
% OPTIONAL (name/value):
%   'dataDir'      - folder holding toar-OSDAM8-YYYY.csv
%                    (default: ./1data/TOAR-OSDMA8)
%   'stationTypes' - filter on the 'type' column:
%                    'all' (default) | 'urban' | 'rural' | {cell of types}
%
% OUTPUT (per year):
%   osd.year     - the year
%   osd.coords   - [n x 2] [lon lat]
%   osd.osdma8   - [n x 1] OSDMA8 (ppb)
%   osd.id       - {n x 1} station id (char)
%   osd.country  - {n x 1} country
%   osd.type     - {n x 1} station type
%   osd.dataDir  - folder used
% A missing year file yields an empty entry (n = 0) with a warning.
%
% SEE ALSO: runOSDMA8validation, getTOARobservationalData, computeOSDMA8

%% Parse options
p = inputParser;
addParameter(p, 'dataDir', fullfile('.', '1data', 'TOAR-OSDMA8'), @ischar);
addParameter(p, 'stationTypes', 'all');
parse(p, varargin{:});
opt = p.Results;

% Self-test path
if ischar(years) && strcmpi(years, '--selftest')
    osd = local_selftest();
    return;
end

years = years(:).';
nY = numel(years);

% Normalize requested station types to a lower-case set (or 'all').
typeFilter = local_normalizeTypes(opt.stationTypes);

tmpl = struct('year', [], 'coords', zeros(0,2), 'osdma8', zeros(0,1), ...
    'id', {{}}, 'country', {{}}, 'type', {{}}, 'dataDir', opt.dataDir);
osd = repmat(tmpl, 1, nY);

for iy = 1:nY
    Y = years(iy);
    osd(iy).year = Y;

    fname = fullfile(opt.dataDir, sprintf('toar-OSDAM8-%d.csv', Y));
    if ~exist(fname, 'file')
        warning('loadTOARosdma8:missing', 'File not found: %s', fname);
        continue;
    end

    T = readtable(fname);
    T.Properties.VariableNames = lower(T.Properties.VariableNames);

    % OSDMA8 value column: tolerate 'osdam8' (file header) or 'osdma8'.
    valCol = '';
    for cand = {'osdam8', 'osdma8'}
        if ismember(cand{1}, T.Properties.VariableNames)
            valCol = cand{1}; break;
        end
    end
    if isempty(valCol)
        warning('loadTOARosdma8:noValueCol', ...
            'No osdam8/osdma8 column in %s; skipping.', fname);
        continue;
    end

    % Required coordinate columns.
    if ~all(ismember({'lon','lat'}, T.Properties.VariableNames))
        warning('loadTOARosdma8:noCoords', ...
            'Missing lon/lat columns in %s; skipping.', fname);
        continue;
    end

    lon = T.lon;  lat = T.lat;  val = T.(valCol);

    % Optional columns
    id      = local_toCharCol(T, 'id', height(T));
    country = local_toCharCol(T, 'country', height(T));
    type    = local_toCharCol(T, 'type', height(T));

    % Station-type filter
    if ~isempty(typeFilter)
        keep = ismember(lower(type), typeFilter);
        lon = lon(keep); lat = lat(keep); val = val(keep);
        id = id(keep); country = country(keep); type = type(keep);
    end

    osd(iy).coords  = [lon(:), lat(:)];
    osd(iy).osdma8  = val(:);
    osd(iy).id      = id(:);
    osd(iy).country = country(:);
    osd(iy).type    = type(:);

    fprintf('loadTOARosdma8: %d -> %d stations (%s).\n', ...
        Y, numel(val), local_typeLabel(opt.stationTypes));
end

end

% ------------------------------------------------------------------------
function tf = local_normalizeTypes(stationTypes)
% Return a lower-case cellstr of accepted types, or [] meaning 'all'.
if (ischar(stationTypes) && strcmpi(stationTypes, 'all'))
    tf = [];
elseif ischar(stationTypes)
    tf = {lower(stationTypes)};
elseif iscell(stationTypes)
    tf = lower(stationTypes(:).');
else
    tf = [];
end
end

% ------------------------------------------------------------------------
function s = local_typeLabel(stationTypes)
if ischar(stationTypes)
    s = stationTypes;
elseif iscell(stationTypes)
    s = strjoin(stationTypes, '+');
else
    s = 'all';
end
end

% ------------------------------------------------------------------------
function c = local_toCharCol(T, name, n)
% Return column `name` as an n x 1 cellstr; empty strings if absent.
if ismember(name, T.Properties.VariableNames)
    v = T.(name);
    if isnumeric(v)
        c = cellstr(num2str(v(:)));
    elseif iscell(v)
        c = cellfun(@(x) char(string(x)), v(:), 'UniformOutput', false);
    elseif isstring(v) || iscategorical(v)
        c = cellstr(v(:));
    else
        c = cellstr(string(v(:)));
    end
else
    c = repmat({''}, n, 1);
end
end

% ------------------------------------------------------------------------
function osd = local_selftest()
% Minimal structural self-test (no file IO): exercises the normalize/label
% helpers and the empty-template shape.
assert(isempty(local_normalizeTypes('all')));
assert(isequal(local_normalizeTypes('Urban'), {'urban'}));
assert(isequal(local_normalizeTypes({'Urban','Rural'}), {'urban','rural'}));
assert(strcmp(local_typeLabel({'urban','rural'}), 'urban+rural'));
osd = struct('year', 2000, 'coords', zeros(0,2), 'osdma8', zeros(0,1), ...
    'id', {{}}, 'country', {{}}, 'type', {{}}, 'dataDir', 'n/a');
fprintf('loadTOARosdma8 self-test passed.\n');
end
