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

function decimalYear = datenum2decyear(datenumValue)
% Convert MATLAB datenum to decimal year
    dateVector = datevec(datenumValue);
    year = dateVector(:, 1);
    dayOfYear = datenumValue - datenum(year, 1, 1) + 1;
    daysInYear = datenum(year + 1, 1, 1) - datenum(year, 1, 1);
    decimalYear = year + (dayOfYear - 1) ./ daysInYear;
end

% =========================================================================

function go = getTOARglobalOffset(obs, goScenario, goPlot)
% getTOARglobalOffset - Estimates global offset for TOAR ozone data
%
% Models the space/time global offset for TOAR-II ozone data following
% the same methodology as getAPglobalOffset.m
%
% SYNTAX:
%  
% go = getTOARglobalOffset(obs, goScenario, goPlot);
%
% INPUT :
%
% obs         structure containing TOAR observational data from getTOARobservationalData
% goScenario  scalar specifying global offset scenario 
%             0 zero, 1 flat, 2 domain wide, 3 regional, 4 local
%             default: 3
% goPlot      scalar indicating plotting level
%             0 no plots, 1 basic plots, 2 detailed plots, 3 comprehensive plots
%             default: 1
%
% OUTPUT :
% go   structure containing global offset:
%      go.logTransf      scalar   0 (no log transform for ozone)
%      go.scenario       scalar   global offset scenario
%      go.sMSraw         nMS x 2  original station coordinates
%      go.tMEraw         1 x nME  original time vector
%      go.msRaw          nMS x 1  raw spatial means
%      go.mtRaw          1 x nME  raw temporal means
%      go.sMS            nMSd x 2 densified spatial coordinates
%      go.tME            1 x nMEd densified time vector
%      go.ms             nMSd x 1 smoothed spatial means
%      go.mt             1 x nMEd smoothed temporal means
%      go.goParam        1 x 5    global offset parameters
%      go.densParam      1 x 6    densification parameters

if nargin < 1, error('obs structure required'); end
if nargin < 2, goScenario = 3; end
if nargin < 3, goPlot = 1; end

if isnumeric(obs), error('obs must be a structure from getTOARobservationalData'); end

% Create global offset directory
goDir = '2globalOffset';
if ~exist(goDir, 'dir')
    mkdir(goDir);
    fid = fopen(fullfile(goDir, '0readme.txt'), 'w');
    fprintf(fid, 'Global offset files for TOAR-II data analysis.\n');
    fprintf(fid, 'Generated by getTOARglobalOffset.m\n');
    fclose(fid);
end

% Set filename for saved results
goFile = sprintf('%s_go_%d.mat', obs.Zname, goScenario);

% Force re-estimation (set to 0 to use saved results)
forceGOestimation = 1;

if exist(fullfile(goDir, goFile), 'file') && ~forceGOestimation
    load(fullfile(goDir, goFile), 'go');
    fprintf('Loaded existing global offset from %s\n', fullfile(goDir, goFile));
else
    fprintf('Computing global offset for TOAR data (scenario %d)...\n', goScenario);
    
    % Set global offset parameters based on scenario
    switch goScenario
        case 0, goParam = [NaN NaN NaN NaN 0];  % Zero offset
        case 1, goParam = [10000 10000 10000 10000 0];  % Flat
        case 2, goParam = [180 5 50 20 0];      % Domain wide (global scale)
        case 3, goParam = [90 2 20 5 0];        % Regional
        case 4, goParam = [45 0.5 10 2 0];      % Local
    end
    
    % Set densification parameters
    inclvoronoi = 1;      % Include Voronoi vertices
    inclgrid = 1;         % Include regular grid
    nxpix = 40;           % X-direction pixels
    nypix = 25;           % Y-direction pixels
    densifytME = 1;       % Densify time
    tMEtimeStep = 1/12;   % Monthly time step
    densParam = [inclvoronoi inclgrid nxpix nypix densifytME tMEtimeStep];
    
    % Set spatial domain (global extent for TOAR data)
    axMS = [-180 180 -90 90];  % Global longitude/latitude range
    
    % Remove stations with insufficient data
    validStations = sum(~isnan(obs.Y), 2) >= 12; % At least 12 valid observations
    fprintf('Using %d stations with sufficient data (out of %d total)\n', ...
            sum(validStations), length(validStations));
    
    Y_filtered = obs.Y(validStations, :);
    sMS_filtered = obs.sMS(validStations, :);
    stationID_filtered = obs.stationID(validStations);
    
    % Calculate space/time mean using stmeanDensified
    [msRaw, mssd, mtRaw, mtsd, sMSd, tMEd] = stmeanDensified(...
        Y_filtered, sMS_filtered, stationID_filtered, obs.tME, goParam, densParam, axMS);
    
    % Handle zero scenario
    if goScenario == 0
        mssd = zeros(size(mssd));
        mtsd = zeros(size(mtsd));
    end
    
    % Build output structure
    go.logTransf = obs.logTransf;
    go.scenario = goScenario;
    go.sMSraw = sMS_filtered;
    go.tMEraw = obs.tME;
    go.msRaw = msRaw;
    go.mtRaw = mtRaw;
    go.sMS = sMSd;
    go.tME = tMEd;
    go.ms = mssd;
    go.mt = mtsd;
    go.goParam = goParam;
    go.densParam = densParam;
    
    % Save results
    save(fullfile(goDir, goFile), 'go');
    fprintf('Global offset saved to %s\n', fullfile(goDir, goFile));
end

% Generate plots if requested
if goPlot >= 1
    plotTOARglobalOffset(obs, go, goPlot);
end

end

% =========================================================================

function cov = getTOARcovariance(obs, go, covPlot)
% getTOARcovariance - Estimates space/time covariance for TOAR ozone data
%
% Models the space/time covariance of offset-removed TOAR ozone data
% following the methodology from getAPcov.m
%
% SYNTAX:
%  
% cov = getTOARcovariance(obs, go, covPlot)
%
% INPUT :
% 
% obs     structure from getTOARobservationalData
% go      structure from getTOARglobalOffset or scalar scenario number
% covPlot scalar for plotting: 0-no plot, 1-2D plots, 2-2D and 3D plots
%         default: 1
%
% OUTPUT :
% cov     structure containing experimental covariance and model:
%         cov.Zname       string  'OZONE_TOAR'
%         cov.Yname       string  variable name
%         cov.rLag        vector  spatial lags
%         cov.Cr          vector  experimental spatial covariance
%         cov.npr         vector  number of pairs for spatial covariance
%         cov.tLag        vector  temporal lags
%         cov.Ct          vector  experimental temporal covariance
%         cov.npt         vector  number of pairs for temporal covariance
%         cov.var         scalar  experimental variance
%         cov.covmodel    cell    covariance model specification
%         cov.covparam    cell    covariance parameters

if nargin < 1, error('obs structure required'); end
if nargin < 2, go = 3; end
if nargin < 3, covPlot = 1; end

if isnumeric(obs), error('obs must be structure from getTOARobservationalData'); end
if isnumeric(go), go = getTOARglobalOffset(obs, go, 0); end

% Create covariance directory
covDir = '3covariance';
if ~exist(covDir, 'dir')
    mkdir(covDir);
    fid = fopen(fullfile(covDir, '0readme.txt'), 'w');
    fprintf(fid, 'Covariance files for TOAR-II data analysis.\n');
    fprintf(fid, 'Generated by getTOARcovariance.m\n');
    fclose(fid);
end

% Set filename
covFile = sprintf('%s_cov_go%d.mat', obs.Zname, go.scenario);

% Force re-estimation (set to 0 to use saved results)
forceCOVestimation = 1;

if exist(fullfile(covDir, covFile), 'file') && ~forceCOVestimation
    load(fullfile(covDir, covFile), 'cov');
    fprintf('Loaded existing covariance from %s\n', fullfile(covDir, covFile));
else
    fprintf('Computing covariance for TOAR data...\n');
    
    % Remove global offset from data
    X = obs.Y - stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
    
    % Set up spatial and temporal lags for global data
    % Spatial lags in degrees (global scale)
    rLag = [0 0.5 1.0 2.0 5.0 10.0:5.0:30.0 40.0:10.0:90.0];
    rLagTol = [0 0.25 0.5 1.0 2.0 2.5*ones(1,5) 5.0*ones(1,6)];
    
    % Temporal lags in years
    tLag = [0:1/12:2 3:1:10];  % Monthly for first 2 years, then yearly
    tLagTol = [0.05*ones(1,25) 0.5*ones(1,8)];
    
    % Calculate experimental covariance
    fprintf('  Calculating spatial covariance...\n');
    [Cr, npr] = stcov(X, obs.sMS, obs.tME, X, obs.sMS, obs.tME, ...
                      rLag, rLagTol, 0, 0.1, {'coord2dist'}, 'kron');
    
    fprintf('  Calculating temporal covariance...\n');
    [Ct, npt] = stcov(X, obs.sMS, obs.tME, X, obs.sMS, obs.tME, ...
                      0, 0.001, tLag, tLagTol, {'coord2dist'}, 'kron');
    
    % Calculate variance
    v = var(X(~isnan(X)));
    
    % Set covariance model parameters for ozone (global scale)
    switch go.scenario
        case {0, 1}  % Zero or flat
            c01 = v * 0.6; ar1 = 50; at1 = 2;
            c02 = v * 0.4; ar2 = 5; at2 = 10;
        case 2       % Domain wide
            c01 = v * 0.5; ar1 = 30; at1 = 1;
            c02 = v * 0.5; ar2 = 3; at2 = 5;
        case 3       % Regional
            c01 = v * 0.4; ar1 = 20; at1 = 0.5;
            c02 = v * 0.6; ar2 = 2; at2 = 3;
        case 4       % Local
            c01 = v * 0.3; ar1 = 10; at1 = 0.25;
            c02 = v * 0.7; ar2 = 1; at2 = 1.5;
    end
    
    % Build covariance structure
    cov.Zname = obs.Zname;
    cov.Yname = obs.Yname;
    cov.rLag = rLag;
    cov.Cr = Cr;
    cov.npr = npr;
    cov.tLag = tLag;
    cov.Ct = Ct;
    cov.npt = npt;
    cov.var = v;
    cov.covmodel = {'exponentialC/exponentialC', 'exponentialC/exponentialC'};
    cov.covparam = {[c01 ar1 at1], [c02 ar2 at2]};
    
    % Save results
    save(fullfile(covDir, covFile), 'cov');
    fprintf('Covariance saved to %s\n', fullfile(covDir, covFile));
end

% Generate plots if requested
if covPlot >= 1
    plotTOARcovariance(cov, covPlot);
end

end

% =========================================================================

function analyzeTOARscenario(obs, goScenario, covPlot, timePoints)
% analyzeTOARscenario - Complete analysis workflow for TOAR data
%
% Performs comprehensive analysis of TOAR ozone data including:
% 1. Global offset estimation and de-trending
% 2. Covariance analysis of residuals
% 3. Summary statistics and diagnostics
%
% SYNTAX:
%
% analyzeTOARscenario(obs, goScenario, covPlot, timePoints)
%
% INPUT:
%
% obs         structure from getTOARobservationalData
% goScenario  scalar specifying global offset scenario (0-4)
%             default: 3 (regional)
% covPlot     scalar for covariance plotting (0-2)
%             default: 1
% timePoints  vector of specific time points for detailed analysis
%             default: [2012 2015 2018] (if available in data)

if nargin < 1, error('obs structure required'); end
if nargin < 2, goScenario = 3; end
if nargin < 3, covPlot = 1; end
if nargin < 4
    % Select representative time points from available data
    availableYears = floor(obs.tME);
    uniqueYears = unique(availableYears);
    if length(uniqueYears) >= 3
        timePoints = uniqueYears([1 round(end/2) end]);
    else
        timePoints = uniqueYears;
    end
end

fprintf('\n=== TOAR-II Data Analysis Summary ===\n');
fprintf('Dataset: %s\n', obs.Zname);
fprintf('Number of stations: %d\n', size(obs.Y, 1));
fprintf('Time period: %.2f - %.2f %s\n', min(obs.tME), max(obs.tME), obs.timeUnit);
fprintf('Global offset scenario: %d\n', goScenario);

% Step 1: Global offset estimation
fprintf('\n--- Step 1: Global Offset Estimation ---\n');
go = getTOARglobalOffset(obs, goScenario, 1);

% Step 2: Covariance analysis
fprintf('\n--- Step 2: Covariance Analysis ---\n');
cov = getTOARcovariance(obs, go, covPlot);

% Step 3: Data quality assessment
fprintf('\n--- Step 3: Data Quality Assessment ---\n');
assessTOARdataQuality(obs, go, timePoints);

fprintf('\n=== Analysis Complete ===\n');

end

% =========================================================================

function assessTOARdataQuality(obs, go, timePoints)
% assessTOARdataQuality - Assess data quality and provide summary statistics
%
% SYNTAX:
%
% assessTOARdataQuality(obs, go, timePoints)

% Remove global offset
X = obs.Y - stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);

% Calculate summary statistics
validData = ~isnan(obs.Y);
nTotalObs = numel(obs.Y);
nValidObs = sum(validData(:));
dataCompleteness = nValidObs / nTotalObs * 100;

fprintf('Data completeness: %.1f%% (%d/%d observations)\n', ...
        dataCompleteness, nValidObs, nTotalObs);

% Station-wise completeness
stationCompleteness = sum(validData, 2) / size(obs.Y, 2) * 100;
fprintf('Station completeness - Mean: %.1f%%, Min: %.1f%%, Max: %.1f%%\n', ...
        mean(stationCompleteness), min(stationCompleteness), max(stationCompleteness));

% Temporal completeness
temporalCompleteness = sum(validData, 1) / size(obs.Y, 1) * 100;
fprintf('Temporal completeness - Mean: %.1f%%, Min: %.1f%%, Max: %.1f%%\n', ...
        mean(temporalCompleteness), min(temporalCompleteness), max(temporalCompleteness));

% Summary statistics of raw data
validObs = obs.Y(validData);
validResiduals = X(~isnan(X));

fprintf('\nOzone concentration statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validObs), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validObs), obs.Zunit);
fprintf('  Min:  %.2f %s\n', min(validObs), obs.Zunit);
fprintf('  Max:  %.2f %s\n', max(validObs), obs.Zunit);

fprintf('\nResidual (offset-removed) statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validResiduals), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validResiduals), obs.Zunit);
fprintf('  Min:  %.2f %s\n', min(validResiduals), obs.Zunit);
fprintf('  Max:  %.2f %s\n', max(validResiduals), obs.Zunit);

% Global offset contribution
globalOffsetValues = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
validGO = globalOffsetValues(validData);

fprintf('\nGlobal offset statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validGO), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validGO), obs.Zunit);
fprintf('  Range: %.2f to %.2f %s\n', min(validGO), max(validGO), obs.Zunit);

% Variance decomposition
totalVar = var(validObs);
offsetVar = var(validGO);
residualVar = var(validResiduals);
varianceExplained = offsetVar / totalVar * 100;

fprintf('\nVariance decomposition:\n');
fprintf('  Total variance: %.3f %s^2\n', totalVar, obs.Zunit);
fprintf('  Global offset variance: %.3f %s^2 (%.1f%%)\n', offsetVar, obs.Zunit, varianceExplained);
fprintf('  Residual variance: %.3f %s^2 (%.1f%%)\n', residualVar, obs.Zunit, (100-varianceExplained));

end

% =========================================================================