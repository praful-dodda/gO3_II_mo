function regions = getWorldRegions(mode)
% getWorldRegions - DeLang-style world regions for regional ozone trend analysis
%
% Returns an ORDERED list of world regions defined by lon/lat bounding boxes,
% matching the regional breakdown used in the Serre/West (UNC) global ozone
% papers (DeLang et al. 2021; Becker et al. 2023). The order is a priority order
% so that each grid cell is assigned to a single region (first containing box
% wins) - see computeGridWeights.m.
%
% SYNTAX:
%   regions = getWorldRegions()
%   getWorldRegions('--selftest')
%
% OUTPUT:
%   regions - struct array with fields:
%       .name  char    region name
%       .box   1x4     [lonMin lonMax latMin latMax] (degrees)
%
% NOTE: boxes are approximate continental/sub-continental extents; the priority
% ordering resolves the small overlaps (e.g. Russia vs Europe/East Asia) so the
% per-cell labels are mutually exclusive. "Global" is handled separately by the
% callers (all cells).
%
% SEE ALSO: computeGridWeights, annualSeasonalSeries, trendAnalysisDeLang

if nargin >= 1 && (ischar(mode) || isstring(mode)) && strcmp(mode, '--selftest')
    regions = local_selftest();
    return;
end

names = { ...
    'NorthAmerica',     [-170  -52   15   84]; ...
    'SouthAmerica',     [ -82  -34  -56   13]; ...
    'Europe',           [ -12   40   35   72]; ...
    'Russia',           [  30  180   50   78]; ...
    'SouthCentralAsia', [  46   98    5   45]; ...
    'EastAsia',         [  98  150   18   54]; ...
    'Africa',           [ -20   52  -36   38]; ...
    'Oceania',          [ 110  180  -50    0]};

regions = struct('name', {}, 'box', {});
for i = 1:size(names, 1)
    regions(i) = struct('name', names{i,1}, 'box', names{i,2});
end

end

% ========================================================================
function ok = local_selftest()
ok = true;
r = getWorldRegions();
assert(numel(r) == 8, 'eight regions');
assert(all(arrayfun(@(x) numel(x.box) == 4, r)), 'box is 1x4');
assert(all(arrayfun(@(x) x.box(1) < x.box(2) && x.box(3) < x.box(4), r)), 'valid boxes');

% spot-check a few representative points land in the expected region
chk = @(lon, lat, name) assert(strcmp(local_assign(r, lon, lat), name), ...
    sprintf('%s should contain (%g,%g)', name, lon, lat));
chk(-95, 40, 'NorthAmerica');     % USA
chk(-60, -15, 'SouthAmerica');    % Brazil
chk(10, 50, 'Europe');            % Germany
chk(100, 62, 'Russia');           % Siberia (priority over EastAsia/SCAsia)
chk(78, 22, 'SouthCentralAsia');  % India
chk(116, 39, 'EastAsia');         % Beijing
chk(20, 5, 'Africa');             % central Africa
chk(145, -35, 'Oceania');         % SE Australia

% a remote ocean point matches nothing
assert(isempty(local_assign(r, -150, -40)), 'open ocean unassigned');

fprintf('getWorldRegions self-test: ALL PASSED.\n');
end

function nm = local_assign(r, lon, lat)
nm = '';
for i = 1:numel(r)
    b = r(i).box;
    if lon >= b(1) && lon <= b(2) && lat >= b(3) && lat <= b(4)
        nm = r(i).name; return;
    end
end
end
