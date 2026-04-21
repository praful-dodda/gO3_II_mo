function repSites = selectRepresentativeSites(obs, areaCode, varargin)
% selectRepresentativeSites - Select one representative site per region for temporal analysis
%
% Automatically selects one observation station per geographic region based on
% data completeness and spatial representativeness criteria
%
% SYNTAX:
%   repSites = selectRepresentativeSites(obs, areaCode)
%   repSites = selectRepresentativeSites(obs, areaCode, 'Name', Value, ...)
%
% INPUTS:
%   obs       - Observation structure from getTOARobservationalData
%   areaCode  - Area code for domain (see getTOARareaBoundaries)
%               Used to filter regions relevant to the study area
%
% OPTIONAL PARAMETERS:
%   'years'            - Year range to filter [minYear maxYear] or single year (default: [] = all years)
%   'minCompleteness'  - Minimum data completeness (0-1, default: 0.40)
%   'maxCompleteness'  - Maximum data completeness (0-1, default: 1.0)
%   'minObservations'  - Minimum number of observations (default: 100)
%   'selectionMethod'  - Selection criterion (default: 'centroid')
%                        'centroid': Closest to regional centroid
%                        'completeness': Highest data completeness
%                        'density': Highest temporal density
%   'saveResults'      - Save to CSV file (default: true)
%
% OUTPUTS:
%   repSites - Structure with one field per region, each containing:
%              .siteID         - Station identifier
%              .lon, lat       - Coordinates (degrees)
%              .region         - Region name
%              .nObs           - Number of observations
%              .completeness   - Data completeness (0-1)
%              .timeRange      - [minTime, maxTime] in decimal years
%              .meanValue      - Mean ozone concentration (ppb)
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2015 2020]);
%   repSites = selectRepresentativeSites(obs, 10);  % Continental USA
%
% See also: assignRegions, plotBME_TemporalSeries

%% Parse inputs
p = inputParser;
addRequired(p, 'obs', @isstruct);
addRequired(p, 'areaCode', @isnumeric);
addParameter(p, 'years', [], @isnumeric);
addParameter(p, 'minCompleteness', 0.40, @isnumeric);
addParameter(p, 'maxCompleteness', 1.0, @isnumeric);
addParameter(p, 'minObservations', 2, @isnumeric);
addParameter(p, 'selectionMethod', 'centroid', @(x) ismember(x, {'centroid', 'completeness', 'density'}));
addParameter(p, 'saveResults', true, @islogical);
addParameter(p, 'forYear', [], @isnumeric);  % Optional: filter by specific year

parse(p, obs, areaCode, varargin{:});
opts = p.Results;

% Filter observations by year if specified
if ~isempty(opts.years)
    if isscalar(opts.years)
        yearRange = [opts.years, opts.years];
    else
        yearRange = [min(opts.years), max(opts.years)];
    end

    % Filter time indices within year range
    timeInRange = (obs.tME >= yearRange(1)) & (obs.tME < (yearRange(2) + 1));

    % Create filtered obs structure
    obs_filtered = obs;
    obs_filtered.tME = obs.tME(timeInRange);
    obs_filtered.Y = obs.Y(:, timeInRange);

    fprintf('=== Selecting Representative Sites ===\n');
    fprintf('  Year filter: %d-%d (%.1f%% of data retained)\n', ...
        yearRange(1), yearRange(2), 100*sum(timeInRange)/length(obs.tME));

    % Use filtered observations for selection
    obs = obs_filtered;
else
    fprintf('=== Selecting Representative Sites ===\n');
    fprintf('  Year filter: None (using all years)\n');
end

fprintf('  Selection method: %s\n', opts.selectionMethod);
fprintf('  Min completeness: %.0f%%\n', opts.minCompleteness * 100);
fprintf('  Max completeness: %.0f%%\n', opts.maxCompleteness * 100);
fprintf('  Min observations: %d\n\n', opts.minObservations);

%% Get area boundaries
[axMS, areaName] = getTOARareaBoundaries(areaCode);

fprintf('  Study area: %s (code %d)\n', areaName, areaCode);
fprintf('  Bounds: [%.1f, %.1f] x [%.1f, %.1f]\n\n', ...
    axMS(1), axMS(2), axMS(3), axMS(4));

%% Assign regions to all observation stations

% Get unique station locations
[uniqueLocs, ~, locIdx] = unique(obs.sMS, 'rows');
nStations = size(uniqueLocs, 1);

fprintf('  Total unique stations: %d\n', nStations);

% Assign regions
regionLabels = assignRegions(uniqueLocs(:, 1), uniqueLocs(:, 2));

% Get unique regions in study area
uniqueRegions = unique(regionLabels);
fprintf('  Regions found: %s\n', strjoin(uniqueRegions, ', '));

%% Calculate statistics for each station

stationStats = struct();
for iStation = 1:nStations

    % Get all observations at this station
    stationMask = (locIdx == iStation);
    stationObs = obs.Y(stationMask,:);
    stationTimes = obs.tME;

    % Calculate statistics (count non-NaN observations only)
    nObs = sum(~isnan(stationObs), 'all');
    timeRange = [min(stationTimes), max(stationTimes)];
    timeDuration = timeRange(2) - timeRange(1);

    % Calculate completeness: actual obs / expected obs (assuming monthly)
    expectedObs = max(1, round(timeDuration * 12));  % Monthly sampling
    completeness = min(1.0, nObs / expectedObs);

    % Store statistics
    stationStats(iStation).siteID = iStation;
    stationStats(iStation).lon = uniqueLocs(iStation, 1);
    stationStats(iStation).lat = uniqueLocs(iStation, 2);
    stationStats(iStation).region = regionLabels{iStation};
    stationStats(iStation).nObs = nObs;
    stationStats(iStation).completeness = completeness;
    stationStats(iStation).timeRange = timeRange;
    stationStats(iStation).meanValue = mean(stationObs, 'omitnan');
    stationStats(iStation).stdValue = std(stationObs, 'omitnan');
    stationStats(iStation).timeDensity = nObs / max(1, timeDuration);
end

%% Select one representative site per region

repSites = struct();

for iReg = 1:length(uniqueRegions)
    regionName = uniqueRegions{iReg};

    fprintf('\n  Region: %s\n', regionName);

    % Get all stations in this region
    regionMask = strcmp({stationStats.region}, regionName);
    regionStations = stationStats(regionMask);

    if isempty(regionStations)
        fprintf('    No stations found\n');
        continue;
    end

    fprintf('    Total stations: %d\n', length(regionStations));

    % Filter by minimum criteria
    validMask = ([regionStations.nObs] >= opts.minObservations) & ...
                ([regionStations.completeness] >= opts.minCompleteness) & ...
                ([regionStations.completeness] <= opts.maxCompleteness);

    validStations = regionStations(validMask);

    if isempty(validStations)
        fprintf('    No stations meet minimum criteria\n');
        fprintf('      Relaxing criteria...\n');

        % Relax criteria: try 50% completeness or 50 observations
        validMask = ([regionStations.nObs] >= opts.minObservations/2) | ...
                    ([regionStations.completeness] >= opts.minCompleteness/2) | ...
                    ([regionStations.completeness] <= opts.maxCompleteness*1.5);
        validStations = regionStations(validMask);

        if isempty(validStations)
            fprintf('      Still no valid stations, skipping region\n');
            continue;
        end
    end

    fprintf('    Candidate stations: %d\n', length(validStations));

    % Select representative station based on method
    switch opts.selectionMethod
        case 'centroid'
            % Select station closest to regional centroid
            regionLons = [validStations.lon];
            regionLats = [validStations.lat];
            centroidLon = mean(regionLons);
            centroidLat = mean(regionLats);

            % Calculate distances to centroid
            distances = sqrt((regionLons - centroidLon).^2 + (regionLats - centroidLat).^2);
            [~, bestIdx] = min(distances);

        case 'completeness'
            % Select station with highest completeness
            [~, bestIdx] = max([validStations.completeness]);

        case 'density'
            % Select station with highest temporal density
            [~, bestIdx] = max([validStations.timeDensity]);
    end

    selectedSite = validStations(bestIdx);

    % Create field name (replace spaces with underscores)
    fieldName = strrep(regionName, ' ', '_');

    % Store selected site
    repSites.(fieldName) = selectedSite;

    fprintf('    Selected: Site %d at [%.2f, %.2f]\n', ...
        selectedSite.siteID, selectedSite.lon, selectedSite.lat);
    fprintf('      Observations: %d (%.1f%% complete)\n', ...
        selectedSite.nObs, selectedSite.completeness * 100);
    fprintf('      Time range: %.2f - %.2f\n', ...
        selectedSite.timeRange(1), selectedSite.timeRange(2));
    fprintf('      Mean value: %.1f ± %.1f ppb\n', ...
        selectedSite.meanValue, selectedSite.stdValue);
end

%% Save results to CSV

if opts.saveResults
    fprintf('\n  Saving results...\n');

    % Create table
    regions = fieldnames(repSites);
    nSites = length(regions);

    T = table();
    for i = 1:nSites
        site = repSites.(regions{i});
        T.Region{i} = site.region;
        T.SiteID(i) = site.siteID;
        T.Longitude(i) = site.lon;
        T.Latitude(i) = site.lat;
        T.NumObservations(i) = site.nObs;
        T.Completeness(i) = site.completeness;
        T.TimeStart(i) = site.timeRange(1);
        T.TimeEnd(i) = site.timeRange(2);
        T.MeanOzone_ppb(i) = site.meanValue;
        T.StdOzone_ppb(i) = site.stdValue;
    end

    % Save to CSV
    csvFile = fullfile('5BMEspatialPlots', 'representative_sites.csv');
    writetable(T, csvFile);
    fprintf('    Saved to: %s\n', csvFile);
end

%% Summary

fprintf('\n  Summary:\n');
fprintf('    Total regions: %d\n', length(fieldnames(repSites)));
fprintf('    Selection method: %s\n', opts.selectionMethod);
fprintf('    Sites selected from %d total stations\n', nStations);

end
