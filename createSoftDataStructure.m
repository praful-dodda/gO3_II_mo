function softData = createSoftDataStructure(ctmData, obs, options)
% createSoftDataStructure - Format CTM data for BME soft data
%
% Converts RAMP-corrected CTM data into soft data structure compatible with
% getTOARknowledgeBase and BME estimation/validation.
%
% SYNTAX:
%   softData = createSoftDataStructure(ctmData, obs, options)
%
% INPUTS:
%   ctmData - Structure from loadRAMPdata
%   obs     - Observational data structure (for time alignment)
%   options - Optional structure with fields:
%             .spatialBounds   - [minLon maxLon minLat maxLat] for subsetting
%             .thinningFactor  - Spatial thinning (e.g., 2 = every 2nd point)
%             .minVariance     - Minimum variance threshold (default: 0.01)
%             .removeHardData  - Remove soft where hard exists (1/0, default: 0)
%
% OUTPUTS:
%   softData - Structure compatible with getTOARknowledgeBase:
%              .sMS   - Spatial coordinates [nPoints × 2] (Mercator)
%              .lon   - Longitude for reference [nPoints × 1] (degrees)
%              .lat   - Latitude for reference [nPoints × 1] (degrees)
%              .tME   - Temporal coordinates [1 × nTimes] (decimal years)
%              .Z     - Mean values [nPoints × nTimes]
%              .Zv    - Variance values [nPoints × nTimes]
%              .Zname, .Zunit, .Zlabel - Metadata
%              .original - Reference to original ctmData
%
% EXAMPLE:
%   % Basic usage
%   softData = createSoftDataStructure(ctm, obs);
%
%   % With spatial bounds (e.g., Continental US)
%   options.spatialBounds = [-125 -65 24 50];
%   softData = createSoftDataStructure(ctm, obs, options);
%
%   % With spatial thinning (every 2nd grid point)
%   options.thinningFactor = 2;
%   softData = createSoftDataStructure(ctm, obs, options);

%% Input Validation
if nargin < 2
    error('Both ctmData and obs are required');
end

if nargin < 3
    options = struct();
end

% Set defaults
if ~isfield(options, 'spatialBounds'), options.spatialBounds = []; end
if ~isfield(options, 'thinningFactor'), options.thinningFactor = 1; end
if ~isfield(options, 'minVariance'), options.minVariance = 0.01; end
if ~isfield(options, 'removeHardData'), options.removeHardData = 0; end

fprintf('\n========================================\n');
fprintf('  CREATE SOFT DATA STRUCTURE\n');
fprintf('========================================\n');
fprintf('Model: %s\n', ctmData.modelName);
fprintf('Original grid: %d points × %d months\n', ctmData.nGrid, ctmData.nMonths);

%% Step 1: Spatial Subsetting
lon_subset = ctmData.lon;
lat_subset = ctmData.lat;
sMS_subset = ctmData.sMS;  % Mercator coordinates
Z_subset = ctmData.Z;
Zv_subset = ctmData.Zv;

if ~isempty(options.spatialBounds)
    bounds = options.spatialBounds;
    fprintf('\nApplying spatial bounds: [%.1f %.1f %.1f %.1f]\n', bounds);

    inBounds = (ctmData.lon >= bounds(1)) & (ctmData.lon <= bounds(2)) & ...
               (ctmData.lat >= bounds(3)) & (ctmData.lat <= bounds(4));

    lon_subset = ctmData.lon(inBounds);
    lat_subset = ctmData.lat(inBounds);
    sMS_subset = ctmData.sMS(inBounds, :);
    Z_subset = ctmData.Z(inBounds, :);
    Zv_subset = ctmData.Zv(inBounds, :);

    fprintf('  Points after bounds: %d (%.1f%% of original)\n', ...
        length(lon_subset), 100*length(lon_subset)/ctmData.nGrid);
end

%% Step 2: Spatial Thinning
if options.thinningFactor > 1
    fprintf('\nApplying spatial thinning (factor %d)...\n', options.thinningFactor);

    % Keep every Nth point
    keepIdx = 1:options.thinningFactor:length(lon_subset);

    lon_subset = lon_subset(keepIdx);
    lat_subset = lat_subset(keepIdx);
    sMS_subset = sMS_subset(keepIdx, :);
    Z_subset = Z_subset(keepIdx, :);
    Zv_subset = Zv_subset(keepIdx, :);

    fprintf('  Points after thinning: %d (%.1f%% of bounded)\n', ...
        length(lon_subset), 100*length(keepIdx)/length(lon_subset));
end

%% Step 3: Temporal Alignment
% Match CTM temporal coverage to obs
fprintf('\nAligning temporal coverage...\n');
fprintf('  Obs time range: %.4f - %.4f\n', min(obs.tME), max(obs.tME));
fprintf('  CTM time range: %.4f - %.4f\n', min(ctmData.tME), max(ctmData.tME));

% Find overlapping times
[~, ia, ib] = intersect(obs.tME, ctmData.tME);

if isempty(ia)
    error('No temporal overlap between obs and CTM data!');
end

tME_aligned = obs.tME(ia);
Z_aligned = Z_subset(:, ib);
Zv_aligned = Zv_subset(:, ib);

fprintf('  Overlapping months: %d\n', length(tME_aligned));
fprintf('  Aligned time range: %.4f - %.4f\n', min(tME_aligned), max(tME_aligned));

%% Step 4: Quality Control
fprintf('\nApplying quality control...\n');

nBefore = numel(Z_aligned);

% Enforce minimum variance
lowVar = Zv_aligned < options.minVariance;
if sum(lowVar(:)) > 0
    fprintf('  Setting %d low variance values (< %.3f) to %.3f\n', ...
        sum(lowVar(:)), options.minVariance, options.minVariance);
    Zv_aligned(lowVar) = options.minVariance;
end

% Remove infinite or negative values
badMean = isinf(Z_aligned) | isnan(Z_aligned);
badVar = isinf(Zv_aligned) | isnan(Zv_aligned) | (Zv_aligned < 0);
badData = badMean | badVar;

if sum(badData(:)) > 0
    fprintf('  Removing %d bad values (%.2f%%)\n', ...
        sum(badData(:)), 100*sum(badData(:))/nBefore);
    Z_aligned(badData) = NaN;
    Zv_aligned(badData) = NaN;
end

% Report completeness
nValid = sum(~isnan(Z_aligned(:)));
nTotal = numel(Z_aligned);
fprintf('  Valid data: %d / %d (%.1f%%)\n', nValid, nTotal, 100*nValid/nTotal);

%% Step 5: Remove Hard Data Locations (Optional)
if options.removeHardData
    fprintf('\nRemoving soft data at hard data locations...\n');

    nRemoved = 0;
    for iTime = 1:length(tME_aligned)
        % Find hard data at this time
        obsAtTime = ~isnan(obs.Z(:, ia(iTime)));
        if sum(obsAtTime) == 0
            continue;
        end

        obsMercX = obs.sMS(obsAtTime, 1);
        obsMercY = obs.sMS(obsAtTime, 2);

        % Remove soft data at same locations (within tolerance)
        % Compare in Mercator space for consistency
        for iObs = 1:length(obsMercX)
            dist = sqrt((sMS_subset(:,1) - obsMercX(iObs)).^2 + (sMS_subset(:,2) - obsMercY(iObs)).^2);
            nearObs = dist < 1.0;  % Within ~1 km in Mercator units

            if sum(nearObs) > 0
                Z_aligned(nearObs, iTime) = NaN;
                Zv_aligned(nearObs, iTime) = NaN;
                nRemoved = nRemoved + sum(nearObs);
            end
        end
    end

    fprintf('  Removed %d soft data points at hard locations\n', nRemoved);
end

%% Package Output Structure
softData.sMS = sMS_subset;  % Mercator coordinates [nPoints × 2]
softData.lon = lon_subset;  % Also keep lon/lat for reference
softData.lat = lat_subset;
softData.tME = tME_aligned;
softData.Z = Z_aligned;
softData.Zv = Zv_aligned;

% Metadata
softData.Zname = ctmData.Zname;
softData.Zunit = ctmData.Zunit;
softData.Zlabel = ctmData.Zlabel;
softData.spaceUnit = 'mercator';
softData.timeUnit = 'year';
softData.modelName = ctmData.modelName;
softData.version = ctmData.version;

% Store options used
softData.options = options;

% Keep reference to original
softData.original = struct('modelName', ctmData.modelName, ...
                          'years', ctmData.years, ...
                          'originalGrid', ctmData.nGrid);

%% Summary Statistics
fprintf('\n========================================\n');
fprintf('  SOFT DATA STRUCTURE CREATED\n');
fprintf('========================================\n');
fprintf('Grid:\n');
fprintf('  Spatial points: %d\n', size(softData.sMS, 1));
fprintf('  Temporal points: %d\n', length(softData.tME));
fprintf('  Total elements: %d\n', numel(softData.Z));
fprintf('\nSpatial extent:\n');
fprintf('  Longitude: [%.2f, %.2f] deg\n', min(softData.lon), max(softData.lon));
fprintf('  Latitude:  [%.2f, %.2f] deg\n', min(softData.lat), max(softData.lat));
fprintf('  Mercator X: [%.1f, %.1f] km\n', min(softData.sMS(:,1)), max(softData.sMS(:,1)));
fprintf('  Mercator Y: [%.1f, %.1f] km\n', min(softData.sMS(:,2)), max(softData.sMS(:,2)));
fprintf('\nTemporal extent:\n');
fprintf('  Time: [%.4f, %.4f]\n', min(softData.tME), max(softData.tME));
fprintf('  Months: %d\n', length(softData.tME));
fprintf('\nData ranges:\n');
fprintf('  Mean: [%.2f, %.2f] %s\n', ...
    min(softData.Z(:), [], 'omitnan'), max(softData.Z(:), [], 'omitnan'), softData.Zunit);
fprintf('  Variance: [%.4f, %.2f] %s²\n', ...
    min(softData.Zv(:), [], 'omitnan'), max(softData.Zv(:), [], 'omitnan'), softData.Zunit);
fprintf('\nCompleteness:\n');
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(softData.Z(:)))/numel(softData.Z));
fprintf('\nMemory:\n');
fprintf('  Structure size: ~%.1f MB\n', ...
    (numel(softData.Z)*4 + numel(softData.Zv)*4 + numel(softData.sMS)*8) / 1024^2);
fprintf('========================================\n\n');

end
