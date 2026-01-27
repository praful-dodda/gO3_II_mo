function regionLabels = assignRegions(lon, lat)
% assignRegions - Assign geographic regions based on lon/lat coordinates
%
% SYNTAX:
%   regionLabels = assignRegions(lon, lat)
%
% INPUTS:
%   lon - Longitude values (degrees East, -180 to 180)
%   lat - Latitude values (degrees North, -90 to 90)
%
% OUTPUTS:
%   regionLabels - Cell array of region names for each point
%
% REGIONS:
%   North America, Europe, East Asia, South Asia, South America,
%   Africa, Australia, Other
%
% EXAMPLE:
%   lon = [-120, 10, 120];
%   lat = [40, 50, 30];
%   regions = assignRegions(lon, lat);

% Ensure column vectors
lon = lon(:);
lat = lat(:);

n = length(lon);
regionLabels = cell(n, 1);

% Define regions with lon/lat bounds
regions = struct();
regions(1).name = 'North America';
regions(1).bounds = [-130, -60, 25, 60];  % [min_lon, max_lon, min_lat, max_lat]

regions(2).name = 'Europe';
regions(2).bounds = [-10, 40, 35, 70];

regions(3).name = 'East Asia';
regions(3).bounds = [100, 145, 20, 50];

regions(4).name = 'South Asia';
regions(4).bounds = [60, 100, 5, 35];

regions(5).name = 'South America';
regions(5).bounds = [-80, -30, -60, 15];

regions(6).name = 'Africa';
regions(6).bounds = [-20, 50, -35, 40];

regions(7).name = 'Australia';
regions(7).bounds = [110, 160, -45, -10];

% Assign regions
for i = 1:n
    assigned = false;
    for r = 1:length(regions)
        bounds = regions(r).bounds;
        if lon(i) >= bounds(1) && lon(i) <= bounds(2) && ...
           lat(i) >= bounds(3) && lat(i) <= bounds(4)
            regionLabels{i} = regions(r).name;
            assigned = true;
            break;
        end
    end

    % If not assigned to any region, label as 'Other'
    if ~assigned
        regionLabels{i} = 'Other';
    end
end

end
