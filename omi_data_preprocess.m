%% Standardize Satellite Data to Theoretical 1-degree Grid
% Creates spatially uniform datasets by filling missing coordinates with NaN

clear; clc;

%% Configuration
dataFolder = 'BME corrected satellite data 2005-2022/';
outputFolder = 'BME corrected satellite data uniform/';
filePattern = 'OMI_MLS*.csv';  % Adjust pattern as needed

% Create output folder
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% Step 1: Define theoretical 1-degree grid
% Adjust these ranges based on your data coverage
latRange = (-85:1:85)';      % 171 latitudes
lonRange = (-180:1:179)';    % 360 longitudes
months = (1:12)';            % 12 months

nLat = length(latRange);
nLon = length(lonRange);
nMonths = 12;

% Create full grid for one year (lat, lon, month combinations)
[LON, LAT, MONTH] = ndgrid(lonRange, latRange, months);
masterLat = LAT(:);
masterLon = LON(:);
masterMonth = MONTH(:);

nGridPoints = length(masterLat);  % Should be 171 * 360 * 12 = 738,720

fprintf('Theoretical grid:\n');
fprintf('  Latitude:  %d to %d (%d points)\n', min(latRange), max(latRange), nLat);
fprintf('  Longitude: %d to %d (%d points)\n', min(lonRange), max(lonRange), nLon);
fprintf('  Months:    1 to 12\n');
fprintf('  Total grid points per year: %d\n\n', nGridPoints);

%% Step 2: Create lookup table for fast coordinate matching
% Key: "lat_lon_month" -> index in master grid
fprintf('Building coordinate lookup table...\n');
coordMap = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:nGridPoints
    key = sprintf('%d_%d_%d', masterLat(i), masterLon(i), masterMonth(i));
    coordMap(key) = i;
end

%% Step 3: Process each file
files = dir(fullfile(dataFolder, filePattern));
nFiles = length(files);

fprintf('Processing %d files...\n\n', nFiles);

for f = 1:nFiles
    filepath = fullfile(dataFolder, files(f).name);
    fprintf('[%d/%d] Processing %s...\n', f, nFiles, files(f).name);
    
    % Read data
    data = readtable(filepath);
    nOriginal = height(data);
    
    % Get the year from the data
    yearVal = data.year(1);
    
    % Initialize uniform output arrays with NaN
    uniformLat = masterLat;
    uniformLon = masterLon;
    uniformMonth = masterMonth;
    uniformYear = repmat(yearVal, nGridPoints, 1);
    uniformOmi = NaN(nGridPoints, 1);
    uniformVar = NaN(nGridPoints, 1);
    uniformSurf = NaN(nGridPoints, 1);
    
    % Fill in values from original data
    matchCount = 0;
    unmatchedCount = 0;
    
    for i = 1:nOriginal
        lat = data.lat(i);
        lon = data.lon(i);
        mon = data.month(i);
        
        key = sprintf('%d_%d_%d', lat, lon, mon);
        
        if isKey(coordMap, key)
            idx = coordMap(key);
            matchCount = matchCount + 1;
            
            uniformOmi(idx) = data.omi_tcol(i);
            uniformVar(idx) = data.variance_tcol_sur(i);
            uniformSurf(idx) = data.surface_ozone_bme_tcol(i);
        else
            unmatchedCount = unmatchedCount + 1;
            if unmatchedCount <= 5
                fprintf('  WARNING: Coord (%d, %d, month=%d) outside theoretical grid\n', ...
                    lat, lon, mon);
            end
        end
    end
    
    if unmatchedCount > 5
        fprintf('  ... and %d more unmatched coordinates\n', unmatchedCount - 5);
    end
    
    % Create output table
    uniformData = table(uniformLat, uniformLon, uniformMonth, uniformOmi, ...
        uniformYear, uniformVar, uniformSurf, ...
        'VariableNames', {'lat', 'lon', 'month', 'omi_tcol', 'year', ...
        'variance_tcol_sur', 'surface_ozone_bme_tcol'});
    
    % Count NaNs added
    nNaNs = sum(isnan(uniformOmi));
    
    % Save
    [~, fname, ext] = fileparts(files(f).name);
    outputPath = fullfile(outputFolder, [fname '_uniform' ext]);
    writetable(uniformData, outputPath);
    
    fprintf('  Original: %d rows -> Uniform: %d rows\n', nOriginal, nGridPoints);
    fprintf('  Matched: %d, NaN-filled: %d, Outside grid: %d\n\n', ...
        matchCount, nNaNs, unmatchedCount);
end

%% Step 4: Save master grid template
masterGridTable = table(masterLat, masterLon, masterMonth, ...
    'VariableNames', {'lat', 'lon', 'month'});
writetable(masterGridTable, fullfile(outputFolder, 'master_grid_template.csv'));

fprintf('========================================\n');
fprintf('Done! All files standardized to %d rows.\n', nGridPoints);
fprintf('Master grid saved to: %s\n', fullfile(outputFolder, 'master_grid_template.csv'));
fprintf('========================================\n');

%% Optional: Verify output
fprintf('\nVerification - checking output files:\n');
outFiles = dir(fullfile(outputFolder, '*_uniform.csv'));
for f = 1:length(outFiles)
    data = readtable(fullfile(outputFolder, outFiles(f).name));
    fprintf('  %s: %d rows\n', outFiles(f).name, height(data));
end