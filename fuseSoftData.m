function fusedData = fuseSoftData(softDataCell, method, varargin)
% FUSESOFTDATA Fuse multiple RAMP-corrected soft datasets for BME
%
% Takes multiple soft data structures (from RAMP) and combines them into
% a single "Super Dataset" for input into krigingME_stg.
%
% SYNTAX:
%   fusedData = fuseSoftData(softDataCell, method)
%   fusedData = fuseSoftData(softDataCell, method, 'Name', Value, ...)
%
% INPUT:
%   softDataCell  - Cell array of soft data structs, each with fields:
%                   .sMS  (nGrid x 2) spatial coordinates [lat, lon]
%                   .tME  (1 x nMonths) time events (decimal years)
%                   .Z    (nGrid x nMonths) bias-corrected means
%                   .Zv   (nGrid x nMonths) error variances
%                   .modelName, .Zname, .Zunit, .Zlabel (metadata)
%
%   method        - Fusion method string:
%                   'selection' : Spatially Varying Selection (champion)
%                   'bma'       : Bayesian Model Averaging with moment matching
%                   'concat'    : Simple concatenation (keeps all points)
%
% OPTIONAL NAME-VALUE PAIRS:
%   'SpatialTolerance'  - Tolerance for matching locations across grids (default: 0.001°)
%                         Used for selection/bma when grids differ
%   'MinVariance'       - Floor for variances to prevent div/0 (default: 1e-10)
%   'VarianceTolerance' - Tolerance for tie detection in selection (default: 1e-6)
%   'SortOutput'        - Sort output by (lat, lon) ascending (default: true)
%   'Verbose'           - Print diagnostics (default: true)
%
% OUTPUT:
%   fusedData     - Struct with same format as input, plus:
%                   .fusionMethod     - Method used
%                   .sourceModels     - Cell array of source model names
%                   .modelSelected    - (selection only) Index of selected model
%                   .weights          - (bma only) Struct with weight arrays
%                   .nModelsAvailable - Number of models with data at each point
%
% METHODS:
%
%   1. SELECTION ('selection')
%      At each (s,t), selects the model with minimum RAMP variance.
%      Handles different spatial grids via union grid approach.
%
%   2. BMA ('bma')
%      Bayesian Model Averaging with moment matching.
%      Models without data at a location contribute zero weight.
%
%   3. CONCATENATION ('concat')
%      Stacks all soft data points. Output sorted by (lat, lon) ascending.
%
% Author: Praful Dodda
% Date: November 2025

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'softDataCell', @iscell);
    addRequired(p, 'method', @(x) ismember(lower(x), {'selection', 'bma', 'concat'}));
    addParameter(p, 'SpatialTolerance', 0.001, @isnumeric);  % ~100m
    addParameter(p, 'MinVariance', 1e-10, @isnumeric);
    addParameter(p, 'VarianceTolerance', 1e-6, @isnumeric);
    addParameter(p, 'SortOutput', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, softDataCell, method, varargin{:});
    
    opts = p.Results;
    method = lower(method);
    K = numel(softDataCell);
    
    if K < 2
        error('fuseSoftData:NotEnoughModels', 'Need at least 2 models for fusion');
    end
    
    %% Print header
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('SOFT DATA FUSION\n');
        fprintf('========================================\n');
        fprintf('Method: %s\n', upper(method));
        fprintf('Number of models: %d\n', K);
        fprintf('Spatial tolerance: %.4f°\n', opts.SpatialTolerance);
    end
    
    %% Validate temporal alignment
    ref = softDataCell{1};
    modelNames = cell(K, 1);
    
    for k = 1:K
        sd = softDataCell{k};
        modelNames{k} = sd.modelName;
        
        nGrid_k = size(sd.Z, 1);
        nMonths_k = size(sd.Z, 2);
        
        if opts.Verbose
            fprintf('  Model %d: %s (%d locations x %d times)\n', ...
                k, sd.modelName, nGrid_k, nMonths_k);
        end
        
        % Check temporal alignment
        if ~isequal(sd.tME, ref.tME)
            error('fuseSoftData:TemporalMismatch', ...
                'Model %s has different time events than %s. All models must share the same tME.', ...
                sd.modelName, ref.modelName);
        end
    end
    
    %% Dispatch to appropriate method
    switch method
        case 'selection'
            fusedData = fuseSelectionUnion(softDataCell, opts);
        case 'bma'
            fusedData = fuseBMAUnion(softDataCell, opts);
        case 'concat'
            fusedData = fuseConcatSorted(softDataCell, opts);
    end
    
    % Add common metadata
    fusedData.fusionMethod = method;
    fusedData.sourceModels = modelNames;
    fusedData.version = 4;
    fusedData.loadedAt = datestr(now);
    
    %% Print diagnostics
    if opts.Verbose
        printDiagnostics(softDataCell, fusedData, method);
    end
end


%% ========================================================================
%  UNION GRID CONSTRUCTION
%  ========================================================================

function [unionSMS, alignedZ, alignedZv, nModelsAvailable] = buildUnionGrid(softDataCell, opts)
% BUILDUNIONGRID Create union of all spatial grids and align model data
%
% For models with different spatial resolutions, this:
%   1. Collects all unique (lat, lon) locations across models
%   2. Creates aligned arrays with NaN where a model has no data
%
% Uses coordinate rounding for efficient unique-finding on large grids.

    K = numel(softDataCell);
    nMonths = size(softDataCell{1}.Z, 2);
    tol = opts.SpatialTolerance;
    
    % Precision for rounding (digits after decimal)
    precision = -floor(log10(tol));
    
    if opts.Verbose
        fprintf('\nBuilding union grid...\n');
    end
    
    %% Step 1: Collect all coordinates
    totalPoints = 0;
    for k = 1:K
        totalPoints = totalPoints + size(softDataCell{k}.sMS, 1);
    end
    
    allCoords = zeros(totalPoints, 2);
    allCoordsRounded = zeros(totalPoints, 2);
    modelSource = zeros(totalPoints, 1);  % Track which model each point came from
    localIdx = zeros(totalPoints, 1);     % Track original index within model
    
    idx = 1;
    for k = 1:K
        sMS_k = softDataCell{k}.sMS;
        nk = size(sMS_k, 1);
        rows = idx:(idx + nk - 1);
        
        allCoords(rows, :) = sMS_k;
        allCoordsRounded(rows, :) = round(sMS_k, precision);
        modelSource(rows) = k;
        localIdx(rows) = (1:nk)';
        
        idx = idx + nk;
    end
    
    %% Step 2: Find unique locations via sorting
    % Create compound key for sorting: lat * 1e9 + lon (handles negative lons)
    keys = allCoordsRounded(:,1) * 1e9 + allCoordsRounded(:,2);
    [keysSorted, sortIdx] = sort(keys);
    
    % Find first occurrence of each unique key
    isFirst = [true; diff(keysSorted) ~= 0];
    uniqueMask = false(totalPoints, 1);
    uniqueMask(sortIdx(isFirst)) = true;
    
    % Extract unique coordinates (use original unrounded for precision)
    uniqueIdx = find(uniqueMask);
    unionSMS = allCoords(uniqueIdx, :);
    nUnion = size(unionSMS, 1);
    
    if opts.Verbose
        fprintf('  Total input locations: %d\n', totalPoints);
        fprintf('  Unique union locations: %d\n', nUnion);
    end
    
    %% Step 3: Build mapping from rounded coords to union index
    unionRounded = round(unionSMS, precision);
    unionKeys = unionRounded(:,1) * 1e9 + unionRounded(:,2);
    
    % Create lookup table using containers.Map
    keyToUnionIdx = containers.Map(unionKeys, 1:nUnion);
    
    %% Step 4: Align each model to union grid
    alignedZ = NaN(nUnion, nMonths, K, 'single');
    alignedZv = NaN(nUnion, nMonths, K, 'single');
    
    for k = 1:K
        sMS_k = softDataCell{k}.sMS;
        Z_k = single(softDataCell{k}.Z);
        Zv_k = single(softDataCell{k}.Zv);
        nGrid_k = size(sMS_k, 1);
        
        % Round and create keys
        sMS_k_rounded = round(sMS_k, precision);
        modelKeys = sMS_k_rounded(:,1) * 1e9 + sMS_k_rounded(:,2);
        
        % Vectorized lookup using arrayfun
        for i = 1:nGrid_k
            key = modelKeys(i);
            if isKey(keyToUnionIdx, key)
                uIdx = keyToUnionIdx(key);
                alignedZ(uIdx, :, k) = Z_k(i, :);
                alignedZv(uIdx, :, k) = Zv_k(i, :);
            end
        end
        
        nMapped = sum(~isnan(alignedZ(:, 1, k)));
        if opts.Verbose
            fprintf('  %s: %d/%d locations mapped (%.1f%%)\n', ...
                softDataCell{k}.modelName, nMapped, nGrid_k, 100*nMapped/nGrid_k);
        end
    end
    
    %% Step 5: Count models available at each location
    nModelsAvailable = sum(~isnan(alignedZ(:, 1, :)), 3);
    
    if opts.Verbose
        fprintf('  All %d models available: %d locations (%.1f%%)\n', ...
            K, sum(nModelsAvailable == K), 100*sum(nModelsAvailable == K)/nUnion);
        fprintf('  Only 1 model available: %d locations (%.1f%%)\n', ...
            sum(nModelsAvailable == 1), 100*sum(nModelsAvailable == 1)/nUnion);
    end
end


%% ========================================================================
%  FUSION METHODS
%  ========================================================================

function fusedData = fuseSelectionUnion(softDataCell, opts)
% FUSESELECTIONUNION Spatially Varying Selection with union grid support

    K = numel(softDataCell);
    ref = softDataCell{1};
    nMonths = size(ref.Z, 2);
    
    % Build union grid
    [unionSMS, alignedZ, alignedZv, nModelsAvailable] = buildUnionGrid(softDataCell, opts);
    nUnion = size(unionSMS, 1);
    
    % Set NaN variances to Inf so they're never selected
    alignedZv_masked = alignedZv;
    alignedZv_masked(isnan(alignedZv)) = Inf;
    
    % Find model with minimum variance at each point
    [~, modelSelected] = min(alignedZv_masked, [], 3);
    
    % Extract fused values
    Z_fused = NaN(nUnion, nMonths, 'single');
    Zv_fused = NaN(nUnion, nMonths, 'single');
    
    for j = 1:nMonths
        for i = 1:nUnion
            k = modelSelected(i, j);
            if ~isinf(alignedZv_masked(i, j, k))
                Z_fused(i, j) = alignedZ(i, j, k);
                Zv_fused(i, j) = alignedZv(i, j, k);
            end
        end
    end
    
    % Sort output
    if opts.SortOutput
        [unionSMS, sortIdx] = sortrows(unionSMS, [1, 2]);
        Z_fused = Z_fused(sortIdx, :);
        Zv_fused = Zv_fused(sortIdx, :);
        modelSelected = modelSelected(sortIdx, :);
        nModelsAvailable = nModelsAvailable(sortIdx);
    end
    
    % Build output
    fusedData = buildOutputStruct(ref, unionSMS, Z_fused, Zv_fused, 'selection');
    fusedData.modelSelected = modelSelected;
    fusedData.nModelsAvailable = nModelsAvailable;
end


function fusedData = fuseBMAUnion(softDataCell, opts)
% FUSEBMAUNION Bayesian Model Averaging with union grid support

    K = numel(softDataCell);
    ref = softDataCell{1};
    nMonths = size(ref.Z, 2);
    
    % Build union grid
    [unionSMS, alignedZ, alignedZv, nModelsAvailable] = buildUnionGrid(softDataCell, opts);
    nUnion = size(unionSMS, 1);
    
    % Apply variance floor
    alignedZv_safe = max(alignedZv, opts.MinVariance);
    
    % Compute precisions (1/variance), NaN -> 0 precision
    precisions = 1 ./ alignedZv_safe;
    precisions(isnan(alignedZv)) = 0;
    
    % Normalize to get weights
    precisionSum = sum(precisions, 3);
    precisionSum(precisionSum == 0) = 1;  % Avoid div by 0
    weights = precisions ./ precisionSum;
    
    % Fused mean
    alignedZ_safe = alignedZ;
    alignedZ_safe(isnan(alignedZ)) = 0;
    Z_fused = sum(weights .* alignedZ_safe, 3);
    
    % Fused variance: within + between
    withinVar = sum(weights .* alignedZv_safe, 3);
    deviations = alignedZ_safe - Z_fused;
    betweenVar = sum(weights .* (deviations.^2), 3);
    Zv_fused = single(withinVar + betweenVar);
    Z_fused = single(Z_fused);
    
    % Handle all-NaN locations
    allNaN = all(isnan(alignedZ), 3);
    Z_fused(allNaN) = NaN;
    Zv_fused(allNaN) = NaN;
    
    % Sort output
    if opts.SortOutput
        [unionSMS, sortIdx] = sortrows(unionSMS, [1, 2]);
        Z_fused = Z_fused(sortIdx, :);
        Zv_fused = Zv_fused(sortIdx, :);
        nModelsAvailable = nModelsAvailable(sortIdx);
        weights = weights(sortIdx, :, :);
    end
    
    % Build output
    fusedData = buildOutputStruct(ref, unionSMS, Z_fused, Zv_fused, 'bma');
    fusedData.nModelsAvailable = nModelsAvailable;
    
    fusedData.weights = struct();
    for k = 1:K
        fieldName = matlab.lang.makeValidName(softDataCell{k}.modelName);
        fusedData.weights.(fieldName) = squeeze(weights(:, :, k));
    end
end


function fusedData = fuseConcatSorted(softDataCell, opts)
% FUSECONCATSORTED Concatenation with sorted output

    K = numel(softDataCell);
    ref = softDataCell{1};
    nMonths = size(ref.Z, 2);
    
    % Count total points
    totalGrid = 0;
    for k = 1:K
        totalGrid = totalGrid + size(softDataCell{k}.Z, 1);
    end
    
    % Pre-allocate
    sMS_cat = zeros(totalGrid, 2);
    Z_cat = zeros(totalGrid, nMonths, 'single');
    Zv_cat = zeros(totalGrid, nMonths, 'single');
    modelIndex = zeros(totalGrid, 1);
    
    % Concatenate
    idx = 1;
    for k = 1:K
        sd = softDataCell{k};
        nk = size(sd.Z, 1);
        rows = idx:(idx + nk - 1);
        
        sMS_cat(rows, :) = sd.sMS;
        Z_cat(rows, :) = single(sd.Z);
        Zv_cat(rows, :) = single(sd.Zv);
        modelIndex(rows) = k;
        
        idx = idx + nk;
    end
    
    % Sort by (lat, lon)
    if opts.SortOutput
        [sMS_cat, sortIdx] = sortrows(sMS_cat, [1, 2]);
        Z_cat = Z_cat(sortIdx, :);
        Zv_cat = Zv_cat(sortIdx, :);
        modelIndex = modelIndex(sortIdx);
        
        if opts.Verbose
            fprintf('\nOutput sorted by (lat, lon) ascending.\n');
        end
    end
    
    % Build output
    fusedData = struct();
    fusedData.modelName = 'ConcatFusion';
    fusedData.years = ref.years;
    fusedData.lat = sMS_cat(:, 1);
    fusedData.lon = sMS_cat(:, 2);
    fusedData.sMS = sMS_cat;
    fusedData.tME = ref.tME;
    fusedData.Z = Z_cat;
    fusedData.Zv = Zv_cat;
    fusedData.Zname = 'Concatenated-RAMP';
    fusedData.Zunit = ref.Zunit;
    fusedData.Zlabel = 'Concatenated RAMP-corrected MDA8 Ozone';
    fusedData.nGrid = totalGrid;
    fusedData.nMonths = nMonths;
    fusedData.modelIndex = modelIndex;
    
    if isfield(ref, 'gridInfo')
        fusedData.gridInfo = ref.gridInfo;
        fusedData.gridInfo.note = 'Contains multiple grids stacked';
    end
end


%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function fusedData = buildOutputStruct(ref, sMS, Z_fused, Zv_fused, method)
% BUILDOUTPUTSTRUCT Create output struct matching input format

    fusedData = struct();
    fusedData.modelName = sprintf('%sFusion', upper(method(1)));
    fusedData.years = ref.years;
    fusedData.lat = sMS(:, 1);
    fusedData.lon = sMS(:, 2);
    fusedData.sMS = sMS;
    fusedData.tME = ref.tME;
    fusedData.Z = Z_fused;
    fusedData.Zv = Zv_fused;
    fusedData.Zname = sprintf('%s-Fused-RAMP', upper(method));
    fusedData.Zunit = ref.Zunit;
    fusedData.Zlabel = sprintf('%s-Fused RAMP-corrected MDA8 Ozone', upper(method));
    fusedData.nGrid = size(Z_fused, 1);
    fusedData.nMonths = size(Z_fused, 2);
    
    if isfield(ref, 'gridInfo')
        fusedData.gridInfo = ref.gridInfo;
    end
end


function printDiagnostics(softDataCell, fusedData, method)
% PRINTDIAGNOSTICS Print fusion diagnostics

    K = numel(softDataCell);
    
    fprintf('\n--- Diagnostics ---\n');
    
    % Output dimensions
    fprintf('Output: %d locations x %d times\n', fusedData.nGrid, fusedData.nMonths);
    
    % Verify sorting
    sMS = fusedData.sMS;
    if size(sMS, 1) > 1
        latSorted = all(diff(sMS(:,1)) >= 0);
        fprintf('Sorted by lat: %s\n', mat2str(latSorted));
    end
    
    % Model coverage
    if isfield(fusedData, 'nModelsAvailable')
        nma = fusedData.nModelsAvailable;
        fprintf('\nCoverage:\n');
        for n = K:-1:1
            fprintf('  %d model(s): %d pts (%.1f%%)\n', n, sum(nma == n), 100*sum(nma == n)/numel(nma));
        end
    end
    
    % Variance analysis
    inputVarMean = 0;
    for k = 1:K
        inputVarMean = inputVarMean + nanmean(softDataCell{k}.Zv(:));
    end
    inputVarMean = inputVarMean / K;
    fusedVarMean = nanmean(fusedData.Zv(:));
    
    fprintf('\nVariance:\n');
    fprintf('  Input mean: %.2f\n', inputVarMean);
    fprintf('  Fused mean: %.2f\n', fusedVarMean);
    fprintf('  Ratio: %.3f', fusedVarMean / inputVarMean);
    if fusedVarMean / inputVarMean > 1.5
        fprintf(' (high disagreement)\n');
    elseif fusedVarMean / inputVarMean < 0.8
        fprintf(' (consistent models)\n');
    else
        fprintf('\n');
    end
    
    % Selection fractions
    if strcmp(method, 'selection') && isfield(fusedData, 'modelSelected')
        fprintf('\nSelection:\n');
        for k = 1:K
            frac = mean(fusedData.modelSelected(:) == k);
            fprintf('  %s: %.1f%%\n', softDataCell{k}.modelName, frac * 100);
        end
    end
    
    % Concat info
    if strcmp(method, 'concat')
        fprintf('\nConcat:\n');
        for k = 1:K
            nk = sum(fusedData.modelIndex == k);
            fprintf('  %s: %d pts\n', softDataCell{k}.modelName, nk);
        end
    end
    
    fprintf('\n========================================\n\n');
end
