function softData = getTOARSoftData(BMEmethod, analyzeParam, varargin)
% getTOARSoftData - Load and prepare soft data for BME estimation
%
% Intelligently loads RAMP-corrected CTM data based on BME method code,
% applies spatial and temporal subsetting, and prepares for BME kriging.
% Includes temporal padding to avoid edge effects at year boundaries.
%
% SYNTAX:
%   softData = getTOARSoftData(BMEmethod, analyzeParam)
%   softData = getTOARSoftData(BMEmethod, analyzeParam, 'Name', Value, ...)
%
% INPUTS:
%   BMEmethod    - 8-digit BME method code (e.g., '13000313-02-10')
%                  Automatically parses to extract CTM model names
%   analyzeParam - Analysis parameter structure with fields:
%                  .areaCode        - Area code for spatial bounds
%                  .tkVec           - Estimation time vector (decimal years)
%                  .timeRange       - [startYear, endYear] for observations
%
% OPTIONAL PARAMETERS:
%   'temporalPadding' - Years to pad before/after estimation period (default: 1)
%                       Ensures soft data coverage at temporal boundaries
%   'spatialBuffer'   - Degrees to extend beyond area bounds (default: 2)
%                       Ensures soft data coverage at spatial boundaries
%   'thinningFactor'  - Spatial thinning (0=none, 1=every 2nd, 2=every 4th)
%                       Reduces memory for very dense CTM grids (default: 0)
%   'dataDir'         - Directory containing parquet files
%                       (default: fullfile('1data', 'CTM'))
%   'forceReload'     - Force reload from parquet files (default: 0)
%   'verbose'         - Display progress (default: 1)
%
% OUTPUTS:
%   softData - Cell array of soft data structures (one per model)
%              [] if no soft data required (CTMtype = 0)
%              Each structure contains:
%              .modelName, .sMS, .tME, .Z, .Zv, .ctm (=1 flag)
%
% WORKFLOW:
%   1. Parse BME method code to extract CTM models
%   2. Calculate padded year range (estimation years ± padding)
%   3. Load each model with padded years
%   4. Apply spatial subsetting (estimation area + buffer)
%   5. Apply temporal subsetting (estimation period + padding)
%   6. Optional spatial thinning
%   7. Mark as CTM data (.ctm = 1)
%
% EXAMPLE 1: Load soft data for Continental USA, 2016 monthly
%   analyzeParam.areaCode = 10;  % Continental USA
%   analyzeParam.tkVec = 2016:1/12:2017;  % Monthly 2016
%   analyzeParam.timeRange = [2016, 2016];
%
%   % BME method with M3fusion + UKML
%   softData = getTOARSoftData('13000313-02-10', analyzeParam);
%   % Returns: {M3fusion_subset, UKML_subset}
%   % Spatial: CONUS + 2° buffer
%   % Temporal: 2015-2017 (includes ±1 year padding)
%
% EXAMPLE 2: Custom padding and thinning
%   softData = getTOARSoftData('13000313-02', analyzeParam, ...
%       'temporalPadding', 0.5, 'thinningFactor', 1, 'spatialBuffer', 5);
%
% See also: parseBMEcode, loadRAMPdata, subsetSoftData, analyzeTOAR

%% Parse inputs
p = inputParser;
addRequired(p, 'BMEmethod', @ischar);
addRequired(p, 'analyzeParam', @isstruct);
addParameter(p, 'temporalPadding', 1, @isnumeric);  % 1 year padding
addParameter(p, 'spatialBuffer', 2, @isnumeric);    % 2 degree buffer
addParameter(p, 'thinningFactor', 0, @isnumeric);   % No thinning
addParameter(p, 'dataDir', fullfile('d:\Users\praful\Documents\Data\ramp_data\'), @ischar);
addParameter(p, 'forceReload', 0, @isnumeric);
addParameter(p, 'verbose', 1, @isnumeric);

parse(p, BMEmethod, analyzeParam, varargin{:});
opts = p.Results;

%% Parse BME method code to determine soft data requirements

if opts.verbose
    fprintf('\n========================================\n');
    fprintf('  LOADING SOFT DATA FOR BME\n');
    fprintf('========================================\n');
    fprintf('BME Method: %s\n', BMEmethod);
end

% Parse BME method code
[obsType, CTMtype, ~, ~, ~, ~, ctm_models] = parseBMEcode(BMEmethod);

if opts.verbose
    fprintf('  Observation type: %d\n', obsType);
    fprintf('  CTM type: %d\n', CTMtype);
end

% Check if soft data required
if CTMtype == 0 || isempty(ctm_models)
    if opts.verbose
        fprintf('  No soft data required (CTMtype = 0)\n');
        fprintf('========================================\n\n');
    end
    softData = [];
    return;
end

if opts.verbose
    fprintf('  CTM models to load: %d\n', length(ctm_models));
    for i = 1:length(ctm_models)
        fprintf('    %d. %s\n', i, ctm_models{i});
    end
end

%% Calculate temporal range with padding

% Extract year range from tkVec and timeRange
if isfield(analyzeParam, 'tkVec') && ~isempty(analyzeParam.tkVec)
    minYear = floor(min(analyzeParam.tkVec));
    maxYear = floor(max(analyzeParam.tkVec));
else
    minYear = analyzeParam.timeRange(1);
    maxYear = analyzeParam.timeRange(end);
end

% Add temporal padding
paddedMinYear = minYear - opts.temporalPadding;
paddedMaxYear = maxYear + opts.temporalPadding;
yearsToLoad = paddedMinYear:paddedMaxYear;

if opts.verbose
    fprintf('\n--- Temporal Configuration ---\n');
    fprintf('  Estimation period: %d - %d\n', minYear, maxYear);
    fprintf('  Temporal padding: ±%.1f years\n', opts.temporalPadding);
    fprintf('  Years to load: %d - %d (%d years total)\n', ...
        paddedMinYear, paddedMaxYear, length(yearsToLoad));
end

%% Get spatial bounds with buffer

if opts.verbose
    fprintf('\n--- Spatial Configuration ---\n');
end

% Get area boundaries
try
    [areaBounds, ~] = getTOARareaBoundaries(analyzeParam.areaCode);

    % Add spatial buffer
    spatialBounds = [
        areaBounds(1) - opts.spatialBuffer, ...  % minLon
        areaBounds(2) + opts.spatialBuffer, ...  % maxLon
        areaBounds(3) - opts.spatialBuffer, ...  % minLat
        areaBounds(4) + opts.spatialBuffer % maxLat
    ];

    if opts.verbose
        fprintf('  Area code %d\n', analyzeParam.areaCode);
        fprintf('  Core bounds: [%.1f, %.1f] x [%.1f, %.1f]\n', areaBounds);
        fprintf('  Spatial buffer: ±%.1f degrees\n', opts.spatialBuffer);
        fprintf('  Extended bounds: [%.1f, %.1f] x [%.1f, %.1f]\n', spatialBounds);
    end
catch ME
    warning('Could not get area boundaries: %s. Using global extent.', ME.message);
    spatialBounds = [];
end

% Calculate temporal bounds for subsetting (estimation period + padding)
if isfield(analyzeParam, 'tkVec') && ~isempty(analyzeParam.tkVec)
    temporalBounds = [paddedMinYear, paddedMaxYear+1];
else
    temporalBounds = [minYear, maxYear + 1];  % Full year coverage
end

if opts.verbose
    fprintf('  Temporal bounds: %.2f - %.2f\n', temporalBounds);
end

%% Load soft data for each model

if opts.verbose
    fprintf('\n--- Loading Soft Data ---\n');
end

softData = cell(length(ctm_models), 1);

for iModel = 1:length(ctm_models)
    modelName = ctm_models{iModel};

    if opts.verbose
        fprintf('\n[%d/%d] Model: %s\n', iModel, length(ctm_models), modelName);
    end

    try
        % Load RAMP data for padded years
        if opts.verbose
            fprintf('  Loading years %s...\n', mat2str(yearsToLoad));
        end

        softDataModel = loadRAMPdata(modelName, yearsToLoad, ...
            opts.dataDir, opts.forceReload);

        % Store original size
        nOrigGrid = size(softDataModel.sMS, 1);
        nOrigTime = length(softDataModel.tME);

        if opts.verbose
            fprintf('  Loaded: %d grid points, %d time periods\n', nOrigGrid, nOrigTime);
        end

        % Apply subsetting
        if ~isempty(spatialBounds) || ~isempty(temporalBounds)
            if opts.verbose
                fprintf('  Applying spatial/temporal subsetting...\n');
            end

            subsetOptions = struct();
            subsetOptions.spatialBounds = spatialBounds;
            subsetOptions.temporalBounds = temporalBounds;
            subsetOptions.thinningFactor = opts.thinningFactor;
            subsetOptions.minVariance = 0;  % Keep all variance levels
            subsetOptions.verbose = 0;  % Suppress detailed subsetting output

            softDataModel = subsetSoftData(softDataModel, subsetOptions);

            nSubsetGrid = size(softDataModel.sMS, 1);
            nSubsetTime = length(softDataModel.tME);

            if opts.verbose
                fprintf('  After subsetting: %d grid points (%.1f%%), %d time periods\n', ...
                    nSubsetGrid, 100*nSubsetGrid/nOrigGrid, nSubsetTime);
                fprintf('  Spatial extent: [%.1f, %.1f] x [%.1f, %.1f]\n', ...
                    min(softDataModel.sMS(:,1)), max(softDataModel.sMS(:,1)), ...
                    min(softDataModel.sMS(:,2)), max(softDataModel.sMS(:,2)));
                fprintf('  Temporal extent: %.2f - %.2f\n', ...
                    min(softDataModel.tME), max(softDataModel.tME));
            end
        end

        % Mark as CTM data (required by getTOARknowledgeBase)
        softDataModel.ctm = 1;

        % Store in cell array
        softData{iModel} = softDataModel;

        if opts.verbose
            fprintf('  ✓ Model loaded successfully\n');
        end

    catch ME
        warning('Failed to load soft data for model %s: %s', modelName, ME.message);
        fprintf('  Stack: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        softData{iModel} = [];
    end
end

% Remove empty entries
softData = softData(~cellfun(@isempty, softData));

%% Summary

if opts.verbose
    fprintf('\n========================================\n');
    fprintf('  SOFT DATA LOADING COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Models loaded: %d\n', length(softData));

    if ~isempty(softData)
        totalPoints = 0;
        totalTimes = 0;
        for i = 1:length(softData)
            totalPoints = totalPoints + size(softData{i}.sMS, 1);
            totalTimes = max(totalTimes, length(softData{i}.tME));
        end
        fprintf('Total grid points: %d\n', totalPoints);
        fprintf('Time periods: %d\n', totalTimes);
        fprintf('Memory estimate: ~%.1f MB\n', totalPoints * totalTimes * 2 * 8 / 1e6);
    else
        fprintf('WARNING: No soft data loaded (will run with hard data only)\n');
    end

    fprintf('========================================\n\n');
end

% Convert single model to non-cell for backwards compatibility
if length(softData) == 1
    softData = softData{1};
end

end
