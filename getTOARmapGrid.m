function ck = getTOARmapGrid(resolution, keepOnlyLand , includeAntarctica)
% getTOARmapGrid - Generates estimation grid on land for TOAR mapping
%
% Creates and caches a regular grid of estimation points covering land areas
%
% SYNTAX:
%   ck = getTOARmapGrid(resolution, includeAntarctica)
%
% INPUTS:
%   resolution         - Grid resolution in degrees (e.g., 0.5, 1.0)
%                        default: 1.0
%   keepOnlyLand    - Include only land points in grid (true/false)
%                        default: true
%   includeAntarctica  - Include Antarctica in grid (true/false)
%                        default: false
%
% OUTPUT:
%   ck - [nPoints x 2] matrix of estimation points [lon, lat]
%
% EXAMPLE:
%   ck = getTOARmapGrid(0.5, true, false);  % 0.5° grid, no Antarctica
%   ck = getTOARmapGrid(1.0, true, true);   % 1.0° grid, with Antarctica

if nargin < 1, resolution = 1.0; end
if nargin < 2, keepOnlyLand = true; end
if nargin < 3, includeAntarctica = false; end

% Setup directories
dataDir = '1data';
gridSubdir = fullfile(dataDir, 'grids');
if ~exist(gridSubdir, 'dir'), mkdir(gridSubdir); end

% Filename based on parameters
gridFile = sprintf('map_grid_res%.2f_onlyLand%d_antarctica%d.mat', resolution, keepOnlyLand, includeAntarctica);
gridPath = fullfile(gridSubdir, gridFile);

% Load from cache if exists
if exist(gridPath, 'file')
    fprintf('Loading existing map grid: %s\n', gridFile);
    load(gridPath, 'ck');
    fprintf('  %d grid points loaded\n', size(ck, 1));
    return;
end

fprintf('Generating map grid (%.2f° resolution)...\n', resolution);

% Generate global grid
[lon_grid, lat_grid] = meshgrid(-180:resolution:180, -90:resolution:90);
grid_all = [lon_grid(:), lat_grid(:)];

% Filter Antarctica if requested
if ~includeAntarctica
    grid_all = grid_all(grid_all(:, 2) > -60, :);
end

% Keep only land points
if keepOnlyLand
    fprintf('  Filtering to land points only...\n');

    % Load coastline data if only land points are needed
    coastFile = fullfile(dataDir, 'coastlines.mat');
    if ~exist(coastFile, 'file') 
        error('Coastline file not found: %s', coastFile);
    end
    coast = load(coastFile, 'coastlon', 'coastlat');

    on_land = inpolygon(grid_all(:, 1), grid_all(:, 2), ...
    coast.coastlon, coast.coastlat);
    ck = grid_all(on_land, :);
else
    ck = grid_all;
end

% Save to cache
fprintf('  Generated %d land points\n', size(ck, 1));
fprintf('  Saving to: %s\n', gridPath);
save(gridPath, 'ck', '-v7.3');

end