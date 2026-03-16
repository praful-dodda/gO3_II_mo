function ck = getTOARmapGrid(resolution, keepOnlyLand , includeAntarctica, gridOffset)
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
%   gridOffset        - Optional [lonOffset, latOffset] to shift grid points (default: [0, 0])
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
if nargin < 4, gridOffset = [0, 0]; end

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

% Apply grid offset if specified
if any(gridOffset ~= 0)
    fprintf('Applying grid offset: [%.2f, %.2f] degrees\n', gridOffset(1), gridOffset(2));
    grid_all(:, 1) = grid_all(:, 1) + gridOffset(1);
    grid_all(:, 2) = grid_all(:, 2) + gridOffset(2);
end

% Filter Antarctica if requested
if ~includeAntarctica
    grid_all = grid_all(grid_all(:, 2) > -60, :);
end

% Keep only land points
if keepOnlyLand
    fprintf('  Filtering to land points only using coastlines.mat...\n');

    % Try coastlines.mat first (produces better quality results)
    coastFile = fullfile(dataDir, 'coastlines.mat');
    if exist(coastFile, 'file')
        try
            coast = load(coastFile, 'coastlon', 'coastlat');
            on_land = inpolygon(grid_all(:, 1), grid_all(:, 2), ...
                coast.coastlon, coast.coastlat);
            ck = grid_all(on_land, :);

            nPoints = size(grid_all, 1);
            fprintf('    Land filtering complete: %d/%d points on land (%.1f%% reduction)\n', ...
                sum(on_land), nPoints, 100*(1 - sum(on_land)/nPoints));

        catch ME
            warning('Could not load coastlines.mat: %s', ME.message);
            fprintf('  Attempting fallback to landareas.shp...\n');

            % Fallback to landareas.shp
            try
                % Use MATLAB's built-in landareas.shp (from Mapping Toolbox)
                landShapefile = 'landareas.shp';
                landAreas = shaperead(landShapefile);

                fprintf('    Loaded %d land polygons from landareas.shp\n', length(landAreas));

                % Pre-allocate logical array
                on_land = false(size(grid_all, 1), 1);

                % Check each point against all land polygons
                % Use a more efficient approach: check batches of points
                nPoints = size(grid_all, 1);
                nPolygons = length(landAreas);

                fprintf('    Checking %d grid points against %d land polygons...\n', nPoints, nPolygons);

                % For each land polygon, check which points are inside
                for iPoly = 1:nPolygons
                    if mod(iPoly, 100) == 0
                        fprintf('      Processing polygon %d/%d (%.1f%%)...\n', ...
                            iPoly, nPolygons, 100*iPoly/nPolygons);
                    end

                    % Get polygon coordinates
                    polyLon = landAreas(iPoly).X(:);
                    polyLat = landAreas(iPoly).Y(:);

                    % Remove NaN separators
                    validIdx = ~isnan(polyLon) & ~isnan(polyLat);
                    polyLon = polyLon(validIdx);
                    polyLat = polyLat(validIdx);

                    % Skip if polygon is empty
                    if isempty(polyLon)
                        continue;
                    end

                    % Check which points (not yet marked as land) are in this polygon
                    % This optimization skips points already identified as land
                    pointsToCheck = ~on_land;
                    if any(pointsToCheck)
                        in_this_poly = inpolygon(grid_all(pointsToCheck, 1), ...
                                                grid_all(pointsToCheck, 2), ...
                                                polyLon, polyLat);

                        % Update the land mask
                        temp = find(pointsToCheck);
                        on_land(temp(in_this_poly)) = true;
                    end
                end

                ck = grid_all(on_land, :);

                fprintf('    Land filtering complete: %d/%d points on land (%.1f%% reduction)\n', ...
                    sum(on_land), nPoints, 100*(1 - sum(on_land)/nPoints));

            catch ME2
                warning('Could not load landareas.shp: %s', ME2.message);
                warning('No land filtering available. Using all grid points.');
                ck = grid_all;
            end
        end
    else
        % coastlines.mat doesn't exist, try landareas.shp
        fprintf('  coastlines.mat not found. Attempting landareas.shp...\n');

        try
            % Use MATLAB's built-in landareas.shp (from Mapping Toolbox)
            landShapefile = 'landareas.shp';
            landAreas = shaperead(landShapefile);

            fprintf('    Loaded %d land polygons from landareas.shp\n', length(landAreas));

            % Pre-allocate logical array
            on_land = false(size(grid_all, 1), 1);

            % Check each point against all land polygons
            % Use a more efficient approach: check batches of points
            nPoints = size(grid_all, 1);
            nPolygons = length(landAreas);

            fprintf('    Checking %d grid points against %d land polygons...\n', nPoints, nPolygons);

            % For each land polygon, check which points are inside
            for iPoly = 1:nPolygons
                if mod(iPoly, 100) == 0
                    fprintf('      Processing polygon %d/%d (%.1f%%)...\n', ...
                        iPoly, nPolygons, 100*iPoly/nPolygons);
                end

                % Get polygon coordinates
                polyLon = landAreas(iPoly).X(:);
                polyLat = landAreas(iPoly).Y(:);

                % Remove NaN separators
                validIdx = ~isnan(polyLon) & ~isnan(polyLat);
                polyLon = polyLon(validIdx);
                polyLat = polyLat(validIdx);

                % Skip if polygon is empty
                if isempty(polyLon)
                    continue;
                end

                % Check which points (not yet marked as land) are in this polygon
                % This optimization skips points already identified as land
                pointsToCheck = ~on_land;
                if any(pointsToCheck)
                    in_this_poly = inpolygon(grid_all(pointsToCheck, 1), ...
                                            grid_all(pointsToCheck, 2), ...
                                            polyLon, polyLat);

                    % Update the land mask
                    temp = find(pointsToCheck);
                    on_land(temp(in_this_poly)) = true;
                end
            end

            ck = grid_all(on_land, :);

            fprintf('    Land filtering complete: %d/%d points on land (%.1f%% reduction)\n', ...
                sum(on_land), nPoints, 100*(1 - sum(on_land)/nPoints));

        catch ME
            warning('Could not load landareas.shp: %s', ME.message);
            warning('No land filtering available. Using all grid points.');
            ck = grid_all;
        end
    end
else
    ck = grid_all;
end

% Save to cache
fprintf('  Generated %d land points\n', size(ck, 1));
fprintf('  Saving to: %s\n', gridPath);
save(gridPath, 'ck', '-v7.3');

end