function ck = getTOARmapGrid(resolution, includeAntarctica)
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
%   includeAntarctica  - Include Antarctica in grid (true/false)
%                        default: false
%
% OUTPUT:
%   ck - [nPoints x 2] matrix of estimation points [lon, lat]
%
% EXAMPLE:
%   ck = getTOARmapGrid(0.5, false);  % 0.5° grid, no Antarctica
%   ck = getTOARmapGrid(1.0, true);   % 1.0° grid, with Antarctica

if nargin < 1, resolution = 1.0; end
if nargin < 2, includeAntarctica = false; end

% Setup directories
dataDir = '1data';
gridSubdir = fullfile(dataDir, 'grids');
if ~exist(gridSubdir, 'dir'), mkdir(gridSubdir); end

% Filename based on parameters
gridFile = sprintf('map_grid_res%.2f_antarctica%d.mat', resolution, includeAntarctica);
gridPath = fullfile(gridSubdir, gridFile);

% Load from cache if exists
if exist(gridPath, 'file')
    fprintf('Loading existing map grid: %s\n', gridFile);
    load(gridPath, 'ck');
    fprintf('  %d grid points loaded\n', size(ck, 1));
    return;
end

fprintf('Generating map grid (%.2f° resolution)...\n', resolution);

% Load coastline data
coastFile = fullfile(dataDir, 'coastlines.mat');
if ~exist(coastFile, 'file')
    error('Coastline file not found: %s', coastFile);
end
coast = load(coastFile, 'coastlon', 'coastlat');

% Generate global grid
[lon_grid, lat_grid] = meshgrid(-180:resolution:180, -90:resolution:90);
grid_all = [lon_grid(:), lat_grid(:)];

% Filter Antarctica if requested
if ~includeAntarctica
    grid_all = grid_all(grid_all(:, 2) > -60, :);
end

% Keep only land points
on_land = inpolygon(grid_all(:, 1), grid_all(:, 2), ...
    coast.coastlon, coast.coastlat);
ck = grid_all(on_land, :);

% Save to cache
fprintf('  Generated %d land points\n', size(ck, 1));
fprintf('  Saving to: %s\n', gridPath);
save(gridPath, 'ck', '-v7.3');

end