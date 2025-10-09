function obs = getTOARobservationalData(stationTypes, timeRange, logTransf, dataDir)
% getTOARobservationalData - Reads TOAR-II observational data
%
% Reads observational data from TOAR-II database for ozone measurements
% following similar structure to getAPobservationalData.m
%
% SYNTAX
%
% obs = getTOARobservationalData(stationTypes, timeRange, dataDir);
%
% INPUT :
%
% stationTypes  cell array or string specifying station types to include:
%               'all' - all station types
%               {'urban', 'rural', 'background'} - specific types
%               default: 'all'
% timeRange     1x2 vector [startYear endYear] for data extraction
%               default: [2010 2020]
% logTransf     scalar indicating if log transform is applied to Z
%               0 - no log transform (default for ozone)
%               1 - log transform (not typical for ozone)
% dataDir       string path to directory containing TOAR-II data files
%               default: './1data/TOAR'
%
% OUTPUT :
%
% obs   structure containing the observational data:
%       obs.stationID      nMS x 1    unique station identifiers
%       obs.stationName    nMS x 1    cell array of station names
%       obs.stationType    nMS x 1    cell array of station types
%       obs.sMS           nMS x 2    lon-lat coordinates
%       obs.elevation     nMS x 1    station elevations (m)
%       obs.tME           1 x nME    time vector (decimal years)
%       obs.Z             nMS x nME  ozone concentrations (ppb)
%       obs.logTransf     scalar     log transform indicator (0 for ozone)
%       obs.Y             nMS x nME  analysis variable (same as Z for ozone)
%       obs.Zname         string     'OZONE_TOAR'
%       obs.Zunit         string     'ppb'
%       obs.spaceUnit     string     'deg'
%       obs.timeUnit      string     'year'
%       obs.dataQuality   nMS x nME  data quality flags
%       obs.measurementCount nMS x nME number of measurements per time period

if nargin < 1, stationTypes = 'all'; end
if nargin < 2, timeRange = [2015 2020]; end
if nargin < 3, logTransf = 0; end
if nargin < 4, dataDir = fullfile('.', '1data', 'TOAR-II'); end

% Check directory exists
if ~exist(dataDir, 'dir')
    error('TOAR data directory does not exist: %s', dataDir);
end

% Initialize output structure metadata
obs.Zname = 'OZONE-TOAR';
obs.Zunit = 'ppb';
obs.Zlabel = 'OZONE TOAR-II (ppb)';
obs.spaceUnit = 'deg';
obs.timeUnit = 'year';
obs.logTransf = 0;

% Create monthly time vector
startYear = timeRange(1);
endYear = timeRange(2);

% if length(timeRange) == 1
%     endYear = startYear;
% elseif length(timeRange) == 2
%     endYear = timeRange(2);
% end

nYears = endYear - startYear + 1;
nMonths = nYears * 12;
obs.tME = linspace(startYear, endYear + 11/12, nMonths);

% Find and read CSV files for requested years
fprintf('Reading TOAR-II data files...\n');
allData = [];

for year = startYear:endYear
    filename = fullfile(dataDir, sprintf('TOAR-II-monthly-mda8-%d.csv', year));
    
    if ~exist(filename, 'file')
        warning('File not found: %s', filename);
        continue;
    end
    
    fprintf('  Reading: %s\n', filename);
    yearData = readtable(filename);
    
    % Add year column to track which year this data is from
    yearData.year = repmat(year, height(yearData), 1);
    
    % Append to combined data
    if isempty(allData)
        allData = yearData;
    else
        allData = [allData; yearData]; %#ok<AGROW>
    end
end

if isempty(allData)
    error('No data files found for years %d-%d', startYear, endYear);
end

% Get unique stations
[uniqueIDs, ~, ic] = unique(allData.id, 'stable');
nStations = length(uniqueIDs);

fprintf('Found %d unique stations\n', nStations);

% Initialize output arrays
obs.stationID = cell(nStations, 1);
% obs.stationName = cell(nStations, 1);
obs.stationType = cell(nStations, 1);
% obs.country = cell(nStations, 1);
obs.sMS = NaN(nStations, 2);
obs.Z = NaN(nStations, nMonths);

% Process each station
for iStation = 1:nStations
    stationRows = find(ic == iStation);
    
    % Extract metadata from first occurrence
    firstRow = stationRows(1);
    obs.stationID{iStation} = allData.id(firstRow);
    % obs.stationName{iStation} = char(allData.id(firstRow));
    obs.stationType{iStation} = char(allData.type(firstRow));
    % obs.country{iStation} = char(allData.country(firstRow));
    obs.sMS(iStation, :) = [allData.lon(firstRow), allData.lat(firstRow)];
    
    % Extract ozone data for all years this station appears
    for iRow = stationRows'
        year = allData.year(iRow);
        yearOffset = (year - startYear) * 12;
        
        % Extract 12 monthly values (DMA8_1 through DMA8_12)
        for month = 1:12
            colName = sprintf('DMA8_%d', month);
            if ismember(colName, allData.Properties.VariableNames)
                timeIdx = yearOffset + month;
                obs.Z(iStation, timeIdx) = allData.(colName)(iRow);
            end
        end
    end
end

% Filter by station type if requested
if ~strcmp(stationTypes, 'all')
    if ischar(stationTypes), stationTypes = {stationTypes}; end
    
    keepStation = false(nStations, 1);
    for i = 1:nStations
        keepStation(i) = any(strcmpi(obs.stationType{i}, stationTypes));
    end
    
    obs.stationID = obs.stationID(keepStation);
    % obs.stationName = obs.stationName(keepStation);
    obs.stationType = obs.stationType(keepStation);
    % obs.country = obs.country(keepStation);
    obs.sMS = obs.sMS(keepStation, :);
    obs.Z = obs.Z(keepStation, :);
    
    fprintf('Filtered to %d stations matching types: %s\n', ...
        sum(keepStation), strjoin(stationTypes, ', '));
end

% Set Y variable (same as Z, no log transform)
obs.Y = obs.Z;
obs.Yname = obs.Zname;
obs.Yunit = obs.Zunit;
obs.Ylabel = obs.Zlabel;

% Summary
nMS = size(obs.Z, 1);
validData = sum(~isnan(obs.Z(:)));
totalData = numel(obs.Z);
fprintf('\nSummary:\n');
fprintf('  Stations: %d\n', nMS);
fprintf('  Time periods: %d months (%.1f - %.1f)\n', ...
    nMonths, min(obs.tME), max(obs.tME));
fprintf('  Valid data points: %d / %d (%.1f%%)\n', ...
    validData, totalData, 100*validData/totalData);

end