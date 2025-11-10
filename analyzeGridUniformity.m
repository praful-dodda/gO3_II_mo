function gridAnalysis = analyzeGridUniformity(source, sourceType)
% analyzeGridUniformity - Check if spatial grid is uniformly spaced
%
% This function determines whether a spatial grid is regular (uniformly spaced)
% or irregular (unstructured). This is critical for determining if simple
% spatial thinning (keeping every Nth point) is valid.
%
% SYNTAX:
%   gridAnalysis = analyzeGridUniformity(source, sourceType)
%
% INPUTS:
%   source     - Source data:
%                  For 'mat': path to spatial_grid.mat file
%                  For 'csv': path to CSV file with lon/lat in columns 1-2
%                  For 'struct': structure with .lon and .lat fields
%   sourceType - Type of source: 'mat', 'csv', or 'struct'
%
% OUTPUTS:
%   gridAnalysis - Structure with fields:
%                  .isUniform      - Boolean: true if grid is regular
%                  .gridType       - 'regular' or 'irregular'
%                  .nPoints        - Total number of grid points
%                  .lonRange       - [min max] longitude
%                  .latRange       - [min max] latitude
%                  .lonResolution  - Median spacing in longitude (if regular)
%                  .latResolution  - Median spacing in latitude (if regular)
%                  .lonUniformity  - Std dev of lon spacings / median
%                  .latUniformity  - Std dev of lat spacings / median
%                  .isStructured   - Boolean: organized in lat/lon matrix
%                  .structuredSize - [nLat nLon] if structured
%                  .recommendations - String with thinning recommendations
%
% EXAMPLES:
%   % Check a .mat file
%   analysis = analyzeGridUniformity('1data/CTM/model_output_data/spatial_grids/M3fusion_spatial_grid.mat', 'mat');
%
%   % Check a CSV file
%   analysis = analyzeGridUniformity('1data/CTM/model_output_data/M3fusion/M3fusion-monthly-mda8-2016.csv', 'csv');
%
%   % Check a structure (e.g., from loadRAMPdata)
%   softData = loadRAMPdata('M3fusion', 2016, ...);
%   analysis = analyzeGridUniformity(softData, 'struct');

%% Input validation
if nargin < 2
    sourceType = 'mat';
end

fprintf('\n========================================\n');
fprintf('  ANALYZING GRID UNIFORMITY\n');
fprintf('========================================\n');

%% Load data based on source type
switch lower(sourceType)
    case 'mat'
        fprintf('Loading from .mat file: %s\n', source);
        if ~exist(source, 'file')
            error('File not found: %s', source);
        end
        data = load(source);
        lon = data.lon(:);
        lat = data.lat(:);

    case 'csv'
        fprintf('Loading from CSV file: %s\n', source);
        if ~exist(source, 'file')
            error('File not found: %s', source);
        end
        data = readtable(source);
        lon = data{:, 1};
        lat = data{:, 2};

    case 'struct'
        fprintf('Analyzing structure...\n');
        if isfield(source, 'lon') && isfield(source, 'lat')
            lon = source.lon(:);
            lat = source.lat(:);
        elseif isfield(source, 'sMS')
            lon = source.sMS(:, 1);
            lat = source.sMS(:, 2);
        else
            error('Structure must have .lon/.lat or .sMS fields');
        end

    otherwise
        error('sourceType must be ''mat'', ''csv'', or ''struct''');
end

nPoints = length(lon);
fprintf('Grid points: %d\n', nPoints);
fprintf('Lon range: [%.4f, %.4f]\n', min(lon), max(lon));
fprintf('Lat range: [%.4f, %.4f]\n', min(lat), max(lat));

%% Check if grid is structured (organized in lat/lon matrix)
fprintf('\n--- Checking Grid Structure ---\n');

% Get unique lon and lat values
uniqueLon = unique(lon);
uniqueLat = unique(lat);
nUniqueLon = length(uniqueLon);
nUniqueLat = length(uniqueLat);

fprintf('Unique longitudes: %d\n', nUniqueLon);
fprintf('Unique latitudes: %d\n', nUniqueLat);

% Check if it's a structured grid (every lon/lat combination exists)
isStructured = (nUniqueLon * nUniqueLat == nPoints);

if isStructured
    fprintf('Grid type: STRUCTURED (regular lat/lon grid)\n');
    fprintf('Grid dimensions: %d lat × %d lon = %d points\n', ...
        nUniqueLat, nUniqueLon, nPoints);
else
    fprintf('Grid type: UNSTRUCTURED (irregular or sparse)\n');
    fprintf('Expected points (full grid): %d\n', nUniqueLon * nUniqueLat);
    fprintf('Actual points: %d (%.1f%% coverage)\n', ...
        nPoints, 100*nPoints/(nUniqueLon*nUniqueLat));
end

%% Check spacing uniformity for longitude
fprintf('\n--- Checking Longitude Spacing ---\n');

lonSpacings = diff(sort(uniqueLon));

if ~isempty(lonSpacings)
    lonMedianSpacing = median(lonSpacings);
    lonMinSpacing = min(lonSpacings);
    lonMaxSpacing = max(lonSpacings);
    lonStdSpacing = std(lonSpacings);
    lonUniformity = lonStdSpacing / lonMedianSpacing;  % Coefficient of variation

    fprintf('Median spacing: %.6f degrees\n', lonMedianSpacing);
    fprintf('Min spacing: %.6f degrees\n', lonMinSpacing);
    fprintf('Max spacing: %.6f degrees\n', lonMaxSpacing);
    fprintf('Std dev: %.6f degrees\n', lonStdSpacing);
    fprintf('Uniformity metric: %.6f (lower is better, <0.01 is uniform)\n', lonUniformity);

    isLonUniform = lonUniformity < 0.01;
    if isLonUniform
        fprintf('Result: UNIFORM longitude spacing ✓\n');
    else
        fprintf('Result: NON-UNIFORM longitude spacing ✗\n');
    end
else
    lonMedianSpacing = NaN;
    lonUniformity = NaN;
    isLonUniform = false;
    fprintf('Cannot determine spacing (single longitude)\n');
end

%% Check spacing uniformity for latitude
fprintf('\n--- Checking Latitude Spacing ---\n');

latSpacings = diff(sort(uniqueLat));

if ~isempty(latSpacings)
    latMedianSpacing = median(latSpacings);
    latMinSpacing = min(latSpacings);
    latMaxSpacing = max(latSpacings);
    latStdSpacing = std(latSpacings);
    latUniformity = latStdSpacing / latMedianSpacing;

    fprintf('Median spacing: %.6f degrees\n', latMedianSpacing);
    fprintf('Min spacing: %.6f degrees\n', latMinSpacing);
    fprintf('Max spacing: %.6f degrees\n', latMaxSpacing);
    fprintf('Std dev: %.6f degrees\n', latStdSpacing);
    fprintf('Uniformity metric: %.6f (lower is better, <0.01 is uniform)\n', latUniformity);

    isLatUniform = latUniformity < 0.01;
    if isLatUniform
        fprintf('Result: UNIFORM latitude spacing ✓\n');
    else
        fprintf('Result: NON-UNIFORM latitude spacing ✗\n');
    end
else
    latMedianSpacing = NaN;
    latUniformity = NaN;
    isLatUniform = false;
    fprintf('Cannot determine spacing (single latitude)\n');
end

%% Overall uniformity assessment
fprintf('\n========================================\n');
fprintf('  UNIFORMITY ASSESSMENT\n');
fprintf('========================================\n');

isUniform = isLonUniform && isLatUniform && isStructured;

if isUniform
    fprintf('Grid is REGULAR (uniform spacing) ✓\n');
    gridType = 'regular';
    fprintf('\nGrid specifications:\n');
    fprintf('  Resolution: %.4f° × %.4f° (lon × lat)\n', lonMedianSpacing, latMedianSpacing);
    fprintf('  Dimensions: %d × %d points\n', nUniqueLat, nUniqueLon);
    fprintf('  At equator: ~%.1f km × ~%.1f km\n', ...
        lonMedianSpacing * 111.32, latMedianSpacing * 111.32);
else
    fprintf('Grid is IRREGULAR (non-uniform or unstructured) ✗\n');
    gridType = 'irregular';
    if ~isStructured
        fprintf('  Reason: Unstructured grid (not full lat/lon matrix)\n');
    end
    if ~isLonUniform
        fprintf('  Reason: Non-uniform longitude spacing\n');
    end
    if ~isLatUniform
        fprintf('  Reason: Non-uniform latitude spacing\n');
    end
end

%% Generate recommendations
fprintf('\n========================================\n');
fprintf('  RECOMMENDATIONS\n');
fprintf('========================================\n');

if isUniform
    fprintf('✓ Simple thinning (every Nth point) is VALID\n');
    fprintf('  Recommended thinning factors based on resolution:\n');

    % Suggest thinning based on resolution
    if lonMedianSpacing < 0.3
        fprintf('    Factor 2: ~%.2f° grid (good for 0.5-1° estimation)\n', lonMedianSpacing*2);
        fprintf('    Factor 3: ~%.2f° grid (good for 1-2° estimation)\n', lonMedianSpacing*3);
        fprintf('    Factor 4: ~%.2f° grid (good for 2° estimation)\n', lonMedianSpacing*4);
    else
        fprintf('    Factor 1: Keep all points (already coarse grid)\n');
    end

    recommendations = 'Simple thinning is valid. Use thinningFactor=2-4 in subsetSoftData().';

else
    fprintf('✗ Simple thinning (every Nth point) is NOT RECOMMENDED\n');
    fprintf('  Alternative approaches:\n');
    fprintf('    1. Spatial averaging within target grid cells\n');
    fprintf('    2. Nearest neighbor selection on target grid\n');
    fprintf('    3. Spatial interpolation to regular grid first\n');
    fprintf('    4. Use all points and rely on BME neighbor selection\n');

    if ~isStructured
        recommendations = 'Unstructured grid - use spatial interpolation or all points.';
    else
        recommendations = 'Non-uniform spacing - use careful spatial averaging or interpolation.';
    end
end

%% Package output
gridAnalysis = struct();
gridAnalysis.isUniform = isUniform;
gridAnalysis.gridType = gridType;
gridAnalysis.nPoints = nPoints;
gridAnalysis.lonRange = [min(lon) max(lon)];
gridAnalysis.latRange = [min(lat) max(lat)];
gridAnalysis.lonResolution = lonMedianSpacing;
gridAnalysis.latResolution = latMedianSpacing;
gridAnalysis.lonUniformity = lonUniformity;
gridAnalysis.latUniformity = latUniformity;
gridAnalysis.isStructured = isStructured;
if isStructured
    gridAnalysis.structuredSize = [nUniqueLat nUniqueLon];
else
    gridAnalysis.structuredSize = [];
end
gridAnalysis.recommendations = recommendations;

% Store full data for further analysis
gridAnalysis.lon = lon;
gridAnalysis.lat = lat;
gridAnalysis.uniqueLon = uniqueLon;
gridAnalysis.uniqueLat = uniqueLat;

fprintf('\n========================================\n\n');

end
