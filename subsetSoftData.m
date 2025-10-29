function softData = subsetSoftData(softData, options)
% subsetSoftData - Subset and optimize soft data for BME estimation
%
% This function performs spatial and temporal subsetting, along with optional
% spatial thinning, to optimize soft data for BME kriging estimation.
%
% SYNTAX:
%   softData = subsetSoftData(softData, options)
%
% INPUTS:
%   softData - Structure from loadRAMPdata with fields:
%              .sMS   - Spatial coordinates [nPoints × 2] as [lon, lat]
%              .tME   - Time vector [1 × nTimes]
%              .Z     - Mean values [nPoints × nTimes]
%              .Zv    - Variance values [nPoints × nTimes]
%
%   options  - Structure with fields:
%              .spatialBounds   - [minLon maxLon minLat maxLat] or areaCode
%              .temporalBounds  - [minTime maxTime] in decimal years
%              .thinningFactor  - Spatial thinning (1=none, 2=every 2nd, etc.)
%              .minVariance     - Minimum variance threshold (default: 0.01)
%              .verbose         - Display progress (default: 1)
%
% OUTPUTS:
%   softData - Subsetted soft data structure (modified in place)
%
% EXAMPLE:
%   % Subset to Continental US, monthly 2016, thin by 2
%   options.spatialBounds = [-126 -66 24 50];  % CONUS
%   options.temporalBounds = [2016 2017];       % Year 2016
%   options.thinningFactor = 2;                 % Every 2nd point
%   softData = subsetSoftData(softData, options);
%
%   % Using area code
%   options.spatialBounds = 5;  % Continental US (uses getTOARareaBoundaries)
%   options.temporalBounds = [2016 2016.9167];
%   options.thinningFactor = 1;
%   softData = subsetSoftData(softData, options);

%% Input Validation
if nargin < 2
    error('Both softData and options are required');
end

% Set defaults
if ~isfield(options, 'spatialBounds'), options.spatialBounds = []; end
if ~isfield(options, 'temporalBounds'), options.temporalBounds = []; end
if ~isfield(options, 'thinningFactor'), options.thinningFactor = 1; end
if ~isfield(options, 'minVariance'), options.minVariance = 0.01; end
if ~isfield(options, 'verbose'), options.verbose = 1; end

if options.verbose
    fprintf('\n========================================\n');
    fprintf('  SUBSETTING SOFT DATA\n');
    fprintf('========================================\n');
    fprintf('Original size:\n');
    fprintf('  Grid points: %d\n', size(softData.sMS, 1));
    fprintf('  Time periods: %d\n', length(softData.tME));
    fprintf('  Total elements: %d\n', numel(softData.Z));
end

% Store original size for reporting
nOrigGrid = size(softData.sMS, 1);
nOrigTime = length(softData.tME);

%% Step 1: Spatial Subsetting
if ~isempty(options.spatialBounds)
    if options.verbose
        fprintf('\n--- Spatial Subsetting ---\n');
    end

    % Get bounds (either direct or from area code)
    if isscalar(options.spatialBounds)
        % Area code provided - get boundaries
        areaCode = options.spatialBounds;
        if options.verbose
            fprintf('  Using area code: %d\n', areaCode);
        end

        try
            boundaries = getTOARareaBoundaries(areaCode);
            bounds = [boundaries.lonMin boundaries.lonMax ...
                     boundaries.latMin boundaries.latMax];
        catch
            warning('Could not get boundaries for area code %d. Skipping spatial subsetting.', areaCode);
            bounds = [];
        end
    else
        % Direct bounds provided
        bounds = options.spatialBounds;
    end

    if ~isempty(bounds)
        if options.verbose
            fprintf('  Bounds: [%.1f %.1f %.1f %.1f] (lon/lat)\n', bounds);
        end

        % Find points within bounds
        inBounds = (softData.sMS(:,1) >= bounds(1)) & ...
                   (softData.sMS(:,1) <= bounds(2)) & ...
                   (softData.sMS(:,2) >= bounds(3)) & ...
                   (softData.sMS(:,2) <= bounds(4));

        nInBounds = sum(inBounds);

        if nInBounds == 0
            warning('No soft data points within spatial bounds! Keeping all points.');
        else
            % Apply spatial subset
            softData.sMS = softData.sMS(inBounds, :);
            softData.Z = softData.Z(inBounds, :);
            softData.Zv = softData.Zv(inBounds, :);

            if isfield(softData, 'lon')
                softData.lon = softData.lon(inBounds);
                softData.lat = softData.lat(inBounds);
            end

            if options.verbose
                fprintf('  Points after bounds: %d (%.1f%% of original)\n', ...
                    nInBounds, 100*nInBounds/nOrigGrid);
            end
        end
    end
end

%% Step 2: Spatial Thinning
if options.thinningFactor > 1
    if options.verbose
        fprintf('\n--- Spatial Thinning ---\n');
        fprintf('  Thinning factor: %d (keep every %dth point)\n', ...
            options.thinningFactor, options.thinningFactor);
    end

    nBeforeThin = size(softData.sMS, 1);

    % Keep every Nth point
    keepIdx = 1:options.thinningFactor:nBeforeThin;

    softData.sMS = softData.sMS(keepIdx, :);
    softData.Z = softData.Z(keepIdx, :);
    softData.Zv = softData.Zv(keepIdx, :);

    if isfield(softData, 'lon')
        softData.lon = softData.lon(keepIdx);
        softData.lat = softData.lat(keepIdx);
    end

    if options.verbose
        fprintf('  Points after thinning: %d (%.1f%% of bounded)\n', ...
            length(keepIdx), 100*length(keepIdx)/nBeforeThin);
    end
end

%% Step 3: Temporal Subsetting
if ~isempty(options.temporalBounds)
    if options.verbose
        fprintf('\n--- Temporal Subsetting ---\n');
        fprintf('  Original time range: %.4f - %.4f\n', ...
            min(softData.tME), max(softData.tME));
        fprintf('  Requested bounds: %.4f - %.4f\n', ...
            options.temporalBounds(1), options.temporalBounds(2));
    end

    % Find times within bounds
    inBounds = (softData.tME >= options.temporalBounds(1)) & ...
               (softData.tME <= options.temporalBounds(2));

    nInBounds = sum(inBounds);

    if nInBounds == 0
        warning('No soft data time periods within temporal bounds! Keeping all times.');
    else
        % Apply temporal subset
        softData.tME = softData.tME(inBounds);
        softData.Z = softData.Z(:, inBounds);
        softData.Zv = softData.Zv(:, inBounds);

        if options.verbose
            fprintf('  Time periods after bounds: %d (%.1f%% of original)\n', ...
                nInBounds, 100*nInBounds/nOrigTime);
            fprintf('  New time range: %.4f - %.4f\n', ...
                min(softData.tME), max(softData.tME));
        end
    end
end

%% Step 4: Quality Control
if options.verbose
    fprintf('\n--- Quality Control ---\n');
end

nBefore = numel(softData.Z);

% Enforce minimum variance
lowVar = softData.Zv < options.minVariance;
if sum(lowVar(:)) > 0
    if options.verbose
        fprintf('  Setting %d low variance values (< %.3f) to %.3f\n', ...
            sum(lowVar(:)), options.minVariance, options.minVariance);
    end
    softData.Zv(lowVar) = options.minVariance;
end

% Remove infinite or NaN values
badMean = isinf(softData.Z) | isnan(softData.Z);
badVar = isinf(softData.Zv) | isnan(softData.Zv) | (softData.Zv < 0);
badData = badMean | badVar;

if sum(badData(:)) > 0
    if options.verbose
        fprintf('  Flagging %d bad values (%.2f%%) as NaN\n', ...
            sum(badData(:)), 100*sum(badData(:))/nBefore);
    end
    softData.Z(badData) = NaN;
    softData.Zv(badData) = NaN;
end

% Report completeness
nValid = sum(~isnan(softData.Z(:)));
nTotal = numel(softData.Z);

if options.verbose
    fprintf('  Valid data: %d / %d (%.1f%%)\n', nValid, nTotal, 100*nValid/nTotal);
end

%% Summary
nFinalGrid = size(softData.sMS, 1);
nFinalTime = length(softData.tME);
nFinalTotal = nFinalGrid * nFinalTime;

reductionGrid = 100 * (1 - nFinalGrid/nOrigGrid);
reductionTime = 100 * (1 - nFinalTime/nOrigTime);
reductionTotal = 100 * (1 - nFinalTotal/(nOrigGrid*nOrigTime));

if options.verbose
    fprintf('\n========================================\n');
    fprintf('  SUBSETTING COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Final size:\n');
    fprintf('  Grid points: %d (%.1f%% reduction)\n', nFinalGrid, reductionGrid);
    fprintf('  Time periods: %d (%.1f%% reduction)\n', nFinalTime, reductionTime);
    fprintf('  Total elements: %d (%.1f%% reduction)\n', nFinalTotal, reductionTotal);
    fprintf('  Spatial extent: [%.2f, %.2f] × [%.2f, %.2f]\n', ...
        min(softData.sMS(:,1)), max(softData.sMS(:,1)), ...
        min(softData.sMS(:,2)), max(softData.sMS(:,2)));
    fprintf('  Temporal extent: %.4f - %.4f\n', ...
        min(softData.tME), max(softData.tME));
    fprintf('\nEstimated speedup: %.1fx faster\n', ...
        (nOrigGrid*nOrigTime) / nFinalTotal);
    fprintf('========================================\n\n');
end

end
