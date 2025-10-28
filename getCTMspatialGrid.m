function gridInfo = getCTMspatialGrid(modelName, dataDir)
% getCTMspatialGrid - Read spatial grid from CTM NetCDF files
%
% Reads longitude and latitude coordinates from NetCDF files containing
% CTM model outputs. Handles different file naming conventions.
%
% SYNTAX:
%   gridInfo = getCTMspatialGrid(modelName, dataDir)
%
% INPUTS:
%   modelName - Model identifier (e.g., 'UKML', 'M3fusion')
%   dataDir   - Directory containing NetCDF files (default: '1data/CTM')
%
% OUTPUTS:
%   gridInfo - Structure with fields:
%              .modelName  - Model identifier
%              .lon        - Longitude grid [nLon × 1] or [nLat × nLon]
%              .lat        - Latitude grid [nLat × 1] or [nLat × nLon]
%              .nLat       - Number of latitude points
%              .nLon       - Number of longitude points
%              .nGrid      - Total grid points (nLat × nLon)
%              .ncFile     - NetCDF file used
%              .gridType   - 'vector' or 'meshgrid'
%
% FILE NAMING CONVENTION:
%   Most models: {modelName}_MDA8_combined.nc (e.g., UKML_MDA8_combined.nc)
%   M3fusion:    M3fusion_MDA8_{year}.nc (uses first available year)
%
% EXAMPLE:
%   grid = getCTMspatialGrid('UKML', '1data/CTM');
%   grid = getCTMspatialGrid('M3fusion');

%% Input Validation
if nargin < 1 || isempty(modelName)
    error('modelName is required');
end
if nargin < 2 || isempty(dataDir)
    dataDir = fullfile('1data', 'CTM');
end

fprintf('\n========================================\n');
fprintf('  READ CTM SPATIAL GRID\n');
fprintf('========================================\n');
fprintf('Model: %s\n', modelName);
fprintf('Data directory: %s\n', dataDir);

%% Find NetCDF File
if strcmpi(modelName, 'M3fusion')
    % M3fusion has yearly files - find first available
    fprintf('  Searching for M3fusion yearly files...\n');
    ncFiles = dir(fullfile(dataDir, 'M3fusion_MDA8_*.nc'));

    if isempty(ncFiles)
        error('No M3fusion NetCDF files found in %s', dataDir);
    end

    % Use first file found
    ncFile = ncFiles(1).name;
    fprintf('  Using: %s\n', ncFile);
else
    % Standard combined file
    ncFile = sprintf('%s_MDA8_combined.nc', modelName);
    fprintf('  Looking for: %s\n', ncFile);
end

ncPath = fullfile(dataDir, ncFile);

if ~exist(ncPath, 'file')
    error('NetCDF file not found: %s', ncPath);
end

%% Read NetCDF File Information
fprintf('\n--- Reading NetCDF Structure ---\n');
ncInfo = ncinfo(ncPath);

% Display dimensions
fprintf('  Dimensions:\n');
for i = 1:length(ncInfo.Dimensions)
    fprintf('    %s: %d\n', ncInfo.Dimensions(i).Name, ncInfo.Dimensions(i).Length);
end

% Display variables
fprintf('  Variables:\n');
for i = 1:length(ncInfo.Variables)
    fprintf('    %s: [%s]\n', ncInfo.Variables(i).Name, ...
        strjoin(arrayfun(@num2str, ncInfo.Variables(i).Size, 'UniformOutput', false), ' × '));
end

%% Read Spatial Coordinates
fprintf('\n--- Reading Coordinates ---\n');

% Read longitude
if any(strcmp({ncInfo.Variables.Name}, 'lon'))
    lon = ncread(ncPath, 'lon');
    fprintf('  Longitude: ');
elseif any(strcmp({ncInfo.Variables.Name}, 'longitude'))
    lon = ncread(ncPath, 'longitude');
    fprintf('  Longitude: ');
else
    error('Longitude variable not found (expected ''lon'' or ''longitude'')');
end

% Read latitude
if any(strcmp({ncInfo.Variables.Name}, 'lat'))
    lat = ncread(ncPath, 'lat');
    fprintf('Latitude: ');
elseif any(strcmp({ncInfo.Variables.Name}, 'latitude'))
    lat = ncread(ncPath, 'latitude');
    fprintf('Latitude: ');
else
    error('Latitude variable not found (expected ''lat'' or ''latitude'')');
end

%% Determine Grid Type and Reshape if Needed
if isvector(lon) && isvector(lat)
    gridType = 'vector';
    lon = lon(:);  % Column vector
    lat = lat(:);  % Column vector
    nLon = length(lon);
    nLat = length(lat);

    fprintf('Grid type: 1D vectors\n');
    fprintf('    Longitude: [%d × 1] range [%.2f, %.2f]\n', nLon, min(lon), max(lon));
    fprintf('    Latitude:  [%d × 1] range [%.2f, %.2f]\n', nLat, min(lat), max(lat));

    % Create meshgrid for flattened representation
    [lonGrid, latGrid] = meshgrid(lon, lat);
    lon_flat = lonGrid(:);
    lat_flat = latGrid(:);
    nGrid = nLat * nLon;

elseif ismatrix(lon) && ismatrix(lat) && isequal(size(lon), size(lat))
    gridType = 'meshgrid';

    fprintf('Grid type: 2D meshgrid\n');
    fprintf('    Longitude: [%s] range [%.2f, %.2f]\n', ...
        mat2str(size(lon)), min(lon(:)), max(lon(:)));
    fprintf('    Latitude:  [%s] range [%.2f, %.2f]\n', ...
        mat2str(size(lat)), min(lat(:)), max(lat(:)));

    % Flatten for point-wise representation
    lon_flat = lon(:);
    lat_flat = lat(:);
    nLat = size(lat, 1);
    nLon = size(lon, 2);
    nGrid = length(lon_flat);

else
    error('Unexpected coordinate array dimensions');
end

fprintf('    Total grid points: %d\n', nGrid);

%% Package Output Structure
gridInfo = struct();
gridInfo.modelName = modelName;
gridInfo.lon = lon_flat;  % Flattened [nGrid × 1]
gridInfo.lat = lat_flat;  % Flattened [nGrid × 1]
gridInfo.nLat = nLat;
gridInfo.nLon = nLon;
gridInfo.nGrid = nGrid;
gridInfo.ncFile = ncFile;
gridInfo.gridType = gridType;

% Store original grid structure for reference
if strcmp(gridType, 'vector')
    gridInfo.lon_1d = lon;
    gridInfo.lat_1d = lat;
else
    gridInfo.lon_2d = lon;
    gridInfo.lat_2d = lat;
end

fprintf('========================================\n\n');

end
