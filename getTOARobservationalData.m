function obs = getTOARobservationalData(stationTypes, timeRange, logTransf, dataDir)
% getTOARobservationalData - Reads TOAR-II observational data
%
% Reads observational data from TOAR-II database for ozone measurements
% with caching and quality control checks. Creates synthetic station IDs
% based on unique coordinates.

if nargin < 1, stationTypes = 'all'; end
if nargin < 2, timeRange = [2015 2020]; end
if nargin < 3, logTransf = 0; end
if nargin < 4, dataDir = fullfile('.', '1data', 'TOAR-II'); end

%% Setup Cache
cacheDir = fullfile(dataDir, 'cache');
if ~exist(cacheDir, 'dir')
    mkdir(cacheDir);
end

startYear = timeRange(1);
endYear = timeRange(2);

if ischar(stationTypes)
    typeStr = stationTypes;
else
    typeStr = strjoin(sort(stationTypes), '_');
end

cacheFile = sprintf('TOAR_obs_%s_y%d_%d_lt%d_QC.mat', ...
    typeStr, startYear, endYear, logTransf);
cachePath = fullfile(cacheDir, cacheFile);

%% Check Cache
if exist(cachePath, 'file')
    fprintf('Loading cached TOAR data from: %s\n', cacheFile);
    load(cachePath, 'obs');
    fprintf('  Loaded %d stations, %d time periods (%.1f%% valid data)\n', ...
        size(obs.Z, 1), size(obs.Z, 2), ...
        100*sum(~isnan(obs.Z(:)))/numel(obs.Z));
    return;
end

fprintf('Cache not found. Processing TOAR-II data files...\n');

%% Check Data Directory
if ~exist(dataDir, 'dir')
    error('TOAR data directory does not exist: %s', dataDir);
end

%% Initialize Metadata
obs.Zname = 'OZONE-TOAR';
obs.Zunit = 'ppb';
obs.Zlabel = 'OZONE TOAR-II (ppb)';
obs.spaceUnit = 'deg';
obs.timeUnit = 'year';
obs.logTransf = logTransf;

%% Create Time Vector
nYears = endYear - startYear + 1;
nMonths = nYears * 12;
obs.tME = linspace(startYear, endYear + 11/12, nMonths);

%% Read CSV Files
fprintf('  Reading data files for years %d-%d...\n', startYear, endYear);
allData = [];

for year = startYear:endYear
    filename = fullfile(dataDir, sprintf('TOAR-II-monthly-mda8-%d.csv', year));
    
    if ~exist(filename, 'file')
        warning('File not found: %s', filename);
        continue;
    end
    
    fprintf('    %d...', year);
    yearData = readtable(filename);
    yearData.year = repmat(year, height(yearData), 1);
    
    if isempty(allData)
        allData = yearData;
    else
        allData = [allData; yearData]; %#ok<AGROW>
    end
end
fprintf(' Done.\n');

if isempty(allData)
    error('No data files found for years %d-%d', startYear, endYear);
end

%% Create Initial Data Structure
nRecords = height(allData);
fprintf('  Building initial data structure (%d records)...\n', nRecords);

% Preallocate arrays for all records
coords_all = NaN(nRecords * 12, 2);
times_all = NaN(nRecords * 12, 1);
values_all = NaN(nRecords * 12, 1);
types_all = cell(nRecords * 12, 1);
originalIDs_all = cell(nRecords * 12, 1);  % Keep original for reference

recordIdx = 0;
for iRow = 1:nRecords
    year = allData.year(iRow);
    lon = allData.lon(iRow);
    lat = allData.lat(iRow);
    stationType = char(allData.type(iRow));
    originalID = char(string(allData.id(iRow)));  % Convert whatever format to char
    
    yearOffset = (year - startYear) * 12;
    
    % Extract all 12 months for this station-year
    for month = 1:12
        colName = sprintf('DMA8_%d', month);
        if ismember(colName, allData.Properties.VariableNames)
            value = allData.(colName)(iRow);
            
            % Only store valid values
            if ~isnan(value) && value > 0
                recordIdx = recordIdx + 1;
                coords_all(recordIdx, :) = [lon, lat];
                times_all(recordIdx) = obs.tME(yearOffset + month);
                values_all(recordIdx) = value;
                types_all{recordIdx} = stationType;
                originalIDs_all{recordIdx} = originalID;
            end
        end
    end
end

% Trim to actual size
coords_all = coords_all(1:recordIdx, :);
times_all = times_all(1:recordIdx);
values_all = values_all(1:recordIdx);
types_all = types_all(1:recordIdx);
originalIDs_all = originalIDs_all(1:recordIdx);

fprintf('    Total valid records: %d\n', recordIdx);

%% QUALITY CONTROL: Create Synthetic IDs Based on Unique Coordinates
fprintf('\n--- Creating Synthetic Station IDs ---\n');

% Round coordinates to 4 decimal places (~11 meters precision)
coords_rounded = round(coords_all * 10000) / 10000;

% Find unique locations
[uniqueCoords, ~, coordIC] = unique(coords_rounded, 'rows');
nUniqueLocations = size(uniqueCoords, 1);

fprintf('  Found %d unique coordinate pairs\n', nUniqueLocations);

% Create synthetic station IDs: TOAR_XXXX
syntheticIDs = cell(recordIdx, 1);
for i = 1:recordIdx
    locationIdx = coordIC(i);
    syntheticIDs{i} = sprintf('TOAR_%04d', locationIdx);
end

fprintf('  Generated IDs from TOAR_0001 to TOAR_%04d\n', nUniqueLocations);

% Report on consolidation from original IDs
fprintf('  Original unique IDs: %d\n', length(unique(originalIDs_all)));
fprintf('  Consolidated to: %d coordinate-based IDs\n', nUniqueLocations);

%% QUALITY CONTROL CHECK: Duplicate Measurements at Same Space-Time
fprintf('\n--- QC Check: Duplicate Measurements at Same Space-Time ---\n');

% Create unique space-time key
times_rounded = round(times_all * 10000) / 10000;
spaceTimeKeys = [coords_rounded, times_rounded];

% Find unique space-time combinations
[uniqueST, ia, ic] = unique(spaceTimeKeys, 'rows');
nDuplicates = length(times_all) - length(ia);

if nDuplicates > 0
    fprintf('  Found %d duplicate space-time records\n', nDuplicates);
    
    % Average duplicate values
    syntheticIDs_unique = syntheticIDs(ia);
    coords_unique = coords_all(ia, :);
    times_unique = times_all(ia);
    types_unique = types_all(ia);
    values_unique = NaN(length(ia), 1);
    
    nAveraged = 0;
    for iST = 1:length(ia)
        % Find all records at this space-time location
        idxDuplicates = (ic == iST);
        duplicateValues = values_all(idxDuplicates);
        
        % Average the values
        values_unique(iST) = mean(duplicateValues, 'omitnan');
        
        if sum(idxDuplicates) > 1
            nAveraged = nAveraged + 1;
            if nAveraged <= 5  % Show first 5 examples
                fprintf('    [%.4f, %.4f] at %.2f: %d values (%.1f → %.1f ppb)\n', ...
                    coords_unique(iST, 1), coords_unique(iST, 2), times_unique(iST), ...
                    sum(idxDuplicates), duplicateValues(1), values_unique(iST));
            end
        end
    end
    
    if nAveraged > 5
        fprintf('    ... and %d more averaged\n', nAveraged - 5);
    end
    
    % Replace with deduplicated data
    syntheticIDs = syntheticIDs_unique;
    coords_all = coords_unique;
    times_all = times_unique;
    values_all = values_unique;
    types_all = types_unique;
    
    fprintf('  After deduplication: %d unique space-time records\n', length(values_unique));
else
    fprintf('  No duplicates found.\n');
end

%% Build Final Station-Based Structure
fprintf('\n  Building final station-time grid...\n');

% Get unique stations (based on synthetic IDs)
[uniqueStations, ~, stationIC] = unique(syntheticIDs);
nStations = length(uniqueStations);

fprintf('    Final number of stations: %d\n', nStations);

% Initialize output arrays
obs.stationID = uniqueStations;
obs.stationType = cell(nStations, 1);
obs.sMS = NaN(nStations, 2);
obs.Z = NaN(nStations, nMonths);

% Fill in station information
for iStation = 1:nStations
    idxThisStation = (stationIC == iStation);
    
    % Station coordinates (should all be same after QC)
    obs.sMS(iStation, :) = coords_all(find(idxThisStation, 1), :);
    
    % Station type (pick most common type if multiple)
    % stationTypes_this = types_all(idxThisStation);
    obs.stationType{iStation} = "Unknown-Dup";
    
    % Fill in time series
    stationTimes = times_all(idxThisStation);
    stationValues = values_all(idxThisStation);
    
    for iRecord = 1:length(stationTimes)
        % Find time index
        [~, timeIdx] = min(abs(obs.tME - stationTimes(iRecord)));
        obs.Z(iStation, timeIdx) = stationValues(iRecord);
    end
end

%% Filter by Station Type
if ~strcmp(stationTypes, 'all')
    if ischar(stationTypes), stationTypes = {stationTypes}; end
    
    keepStation = false(nStations, 1);
    for i = 1:nStations
        keepStation(i) = any(strcmpi(obs.stationType{i}, stationTypes));
    end
    
    obs.stationID = obs.stationID(keepStation);
    obs.stationType = obs.stationType(keepStation);
    obs.sMS = obs.sMS(keepStation, :);
    obs.Z = obs.Z(keepStation, :);
    
    fprintf('  Filtered to %d stations (types: %s)\n', ...
        sum(keepStation), strjoin(stationTypes, ', '));
    
    nStations = sum(keepStation);
end

%% Set Y Variable
if logTransf == 1
    obs.Z(obs.Z <= 0) = NaN;
    obs.Y = log(obs.Z);
    obs.Yname = sprintf('log(%s)', obs.Zname);
    obs.Yunit = sprintf('log(%s)', obs.Zunit);
    obs.Ylabel = sprintf('log %s', obs.Zlabel);
else
    obs.Y = obs.Z;
    obs.Yname = obs.Zname;
    obs.Yunit = obs.Zunit;
    obs.Ylabel = obs.Zlabel;
end

%% Final Quality Check
fprintf('\n--- Final Verification ---\n');

% Check for duplicate coordinates
coords_rounded = round(obs.sMS * 10000) / 10000;
[~, ia, ~] = unique(coords_rounded, 'rows');
if length(ia) < size(obs.sMS, 1)
    warning('Duplicate coordinates still exist after QC!');
    fprintf('  Found %d duplicate coordinate pairs\n', size(obs.sMS,1) - length(ia));
else
    fprintf('  ✓ All station coordinates are unique\n');
end

% Check for duplicate IDs
if length(unique(obs.stationID)) < length(obs.stationID)
    warning('Duplicate station IDs still exist after QC!');
else
    fprintf('  ✓ All station IDs are unique\n');
end

% Check for duplicate measurements at same space-time
duplicateCount = 0;
for iStation = 1:nStations
    for iTime = 1:nMonths
        % Count how many stations have data at this time and same location
        sameCoord = all(abs(obs.sMS - obs.sMS(iStation,:)) < 0.0001, 2);
        sameTime = ~isnan(obs.Z(:, iTime));
        if sum(sameCoord & sameTime) > 1
            duplicateCount = duplicateCount + 1;
        end
    end
end

if duplicateCount > 0
    warning('Found %d potential space-time duplicates', duplicateCount);
else
    fprintf('  ✓ No space-time duplicates\n');
end

%% Summary Statistics
validData = sum(~isnan(obs.Z(:)));
totalData = numel(obs.Z);

fprintf('\n=== FINAL SUMMARY ===\n');
fprintf('  Stations: %d\n', nStations);
fprintf('  Time: %d months (%.2f - %.2f)\n', nMonths, min(obs.tME), max(obs.tME));
fprintf('  Valid data: %d / %d (%.1f%%)\n', validData, totalData, 100*validData/totalData);
fprintf('  Concentration range: [%.1f, %.1f] %s\n', ...
    min(obs.Z(:)), max(obs.Z(:)), obs.Zunit);
fprintf('  Mean concentration: %.1f ± %.1f %s\n', ...
    mean(obs.Z(:), 'omitnan'), std(obs.Z(:), 'omitnan'), obs.Zunit);

fprintf('\n  Quality Control Summary:\n');
fprintf('    Unique coordinates consolidated: %d locations\n', nUniqueLocations);
fprintf('    Space-time duplicates averaged: %d\n', nDuplicates);
fprintf('    Final stations: %d\n', nStations);

%% Save to Cache
fprintf('\n  Saving to cache: %s\n', cacheFile);
save(cachePath, 'obs', '-v7.3');
fprintf('Data processing complete.\n\n');

end