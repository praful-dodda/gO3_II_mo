function obs = getTOARobservationalData(stationTypes, timeRange, dataDir)
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
% dataDir       string path to directory containing TOAR-II data files
%               default: './1data/TOAR'
%
% OUTPUT :
%
% obs   structure containing the observational data:
%       obs.stationID      nMS x 1    unique station identifiers
%       obs.stationName    nMS x 1    cell array of station names
%       obs.stationType    nMS x 1    cell array of station types
%       obs.sMS           nMS x 2    Longitude-Latitude coordinates
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
if nargin < 2, timeRange = [2010 2020]; end
if nargin < 3, dataDir = fullfile('.', '1data', 'TOAR'); end

% Check if data directory exists
if ~exist(dataDir, 'dir')
    error('TOAR data directory %s does not exist. Please create and populate with TOAR-II data files.', dataDir);
end

% Set output structure parameters
obs.Zname = 'OZONE_TOAR';
obs.Zunit = 'ppb';
obs.Zlabel = [obs.Zname ' (' obs.Zunit ')'];
obs.spaceUnit = 'deg';
obs.timeUnit = 'year';
obs.logTransf = 0; % No log transform for ozone following AP convention

% Create time vector (monthly resolution for TOAR data)
startYear = timeRange(1);
endYear = timeRange(2);
tME = startYear:1/12:endYear; % Monthly time steps
obs.tME = tME;
nME = length(tME);

% Read TOAR-II data files
% This assumes TOAR data is provided in CSV format with specific structure
toarFiles = dir(fullfile(dataDir, '*.csv'));
if isempty(toarFiles)
    error('No TOAR CSV files found in %s', dataDir);
end

% Initialize data containers
allStationData = {};
stationCounter = 0;

fprintf('Reading TOAR-II data files...\n');
for iFile = 1:length(toarFiles)
    filename = fullfile(dataDir, toarFiles(iFile).name);
    fprintf('  Processing file: %s\n', toarFiles(iFile).name);
    
    try
        % Read the CSV file
        data = readtable(filename);
        
        % Extract station information (adjust column names as needed)
        if ismember('station_id', data.Properties.VariableNames)
            stationIDs = data.station_id;
        else
            warning('station_id column not found in %s', toarFiles(iFile).name);
            continue;
        end
        
        % Get unique stations from this file
        uniqueStations = unique(stationIDs);
        
        for iStation = 1:length(uniqueStations)
            stationCounter = stationCounter + 1;
            stationID = uniqueStations(iStation);
            
            % Extract data for this station
            stationIdx = stationIDs == stationID;
            stationData = data(stationIdx, :);
            
            % Store station metadata
            allStationData{stationCounter}.stationID = stationID;
            
            % Extract coordinates (adjust column names as needed)
            if ismember('longitude', stationData.Properties.VariableNames)
                allStationData{stationCounter}.longitude = stationData.longitude(1);
            else
                allStationData{stationCounter}.longitude = NaN;
            end
            
            if ismember('latitude', stationData.Properties.VariableNames)
                allStationData{stationCounter}.latitude = stationData.latitude(1);
            else
                allStationData{stationCounter}.latitude = NaN;
            end
            
            % Extract other metadata
            if ismember('station_name', stationData.Properties.VariableNames)
                allStationData{stationCounter}.stationName = stationData.station_name{1};
            else
                allStationData{stationCounter}.stationName = sprintf('Station_%d', stationID);
            end
            
            if ismember('station_type', stationData.Properties.VariableNames)
                allStationData{stationCounter}.stationType = stationData.station_type{1};
            else
                allStationData{stationCounter}.stationType = 'unknown';
            end
            
            if ismember('elevation', stationData.Properties.VariableNames)
                allStationData{stationCounter}.elevation = stationData.elevation(1);
            else
                allStationData{stationCounter}.elevation = NaN;
            end
            
            % Extract time series data
            % Initialize data arrays
            ozoneData = NaN(1, nME);
            qualityData = NaN(1, nME);
            countData = zeros(1, nME);
            
            % Process ozone measurements (adjust column names as needed)
            if ismember('datetime', stationData.Properties.VariableNames) && ...
               ismember('ozone', stationData.Properties.VariableNames)
                
                % Convert datetime to decimal years
                if iscell(stationData.datetime)
                    stationDates = datenum(stationData.datetime);
                else
                    stationDates = stationData.datetime;
                end
                stationTimes = datenum2decyear(stationDates);
                
                % Map data to time grid
                for iTime = 1:length(stationTimes)
                    [~, timeIdx] = min(abs(tME - stationTimes(iTime)));
                    if abs(tME(timeIdx) - stationTimes(iTime)) < 1/24 % Within 1 month
                        if ~isnan(stationData.ozone(iTime))
                            ozoneData(timeIdx) = stationData.ozone(iTime);
                            countData(timeIdx) = countData(timeIdx) + 1;
                            
                            % Extract quality flag if available
                            if ismember('quality_flag', stationData.Properties.VariableNames)
                                qualityData(timeIdx) = stationData.quality_flag(iTime);
                            end
                        end
                    end
                end
            end
            
            allStationData{stationCounter}.ozoneData = ozoneData;
            allStationData{stationCounter}.qualityData = qualityData;
            allStationData{stationCounter}.countData = countData;
        end
        
    catch ME
        warning('Error processing file %s: %s', toarFiles(iFile).name, ME.message);
    end
end

if stationCounter == 0
    error('No valid station data found in TOAR files');
end

% Filter stations by type if specified
if ~strcmp(stationTypes, 'all')
    if ischar(stationTypes)
        stationTypes = {stationTypes};
    end
    
    validStations = false(stationCounter, 1);
    for iStation = 1:stationCounter
        if any(strcmpi(allStationData{iStation}.stationType, stationTypes))
            validStations(iStation) = true;
        end
    end
    
    allStationData = allStationData(validStations);
    stationCounter = sum(validStations);
end

% Compile final data structure
nMS = stationCounter;
obs.stationID = zeros(nMS, 1);
obs.stationName = cell(nMS, 1);
obs.stationType = cell(nMS, 1);
obs.sMS = NaN(nMS, 2);
obs.elevation = NaN(nMS, 1);
obs.Z = NaN(nMS, nME);
obs.dataQuality = NaN(nMS, nME);
obs.measurementCount = zeros(nMS, nME);

for iStation = 1:nMS
    obs.stationID(iStation) = allStationData{iStation}.stationID;
    obs.stationName{iStation} = allStationData{iStation}.stationName;
    obs.stationType{iStation} = allStationData{iStation}.stationType;
    obs.sMS(iStation, :) = [allStationData{iStation}.longitude, allStationData{iStation}.latitude];
    obs.elevation(iStation) = allStationData{iStation}.elevation;
    obs.Z(iStation, :) = allStationData{iStation}.ozoneData;
    obs.dataQuality(iStation, :) = allStationData{iStation}.qualityData;
    obs.measurementCount(iStation, :) = allStationData{iStation}.countData;
end

% Set Y variable (no log transform for ozone)
obs.Y = obs.Z;
obs.Yname = obs.Zname;
obs.Yunit = obs.Zunit;
obs.Ylabel = obs.Zlabel;

fprintf('Successfully loaded data for %d stations over %d time periods\n', nMS, nME);
fprintf('Time range: %.2f to %.2f %s\n', min(obs.tME), max(obs.tME), obs.timeUnit);

end