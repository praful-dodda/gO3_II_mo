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
%   'DisagreementThreshold' - For hybrid extension (default: 2.0)
%   'MinVariance'           - Floor for variances to prevent div/0 (default: 1e-10)
%   'VarianceTolerance'     - Tolerance for tie detection in selection (default: 1e-6)
%   'Verbose'               - Print diagnostics (default: true)
%
% OUTPUT:
%   fusedData     - Struct with same format as input, plus:
%                   .fusionMethod   - Method used
%                   .sourceModels   - Cell array of source model names
%                   .modelSelected  - (selection only) Index of selected model at each point
%                   .weights        - (bma only) Struct with weight arrays per model
%
% METHODS:
%
%   1. SELECTION ('selection')
%      At each (s,t), selects the model with minimum RAMP variance.
%      Z_fused = Z_k*,  Zv_fused = Zv_k*  where k* = argmin(Zv_k)
%      Best when models have distinct geographic strengths.
%
%   2. BMA ('bma')
%      Bayesian Model Averaging with moment matching (Law of Total Variance).
%      w_k = (1/Zv_k) / sum(1/Zv_k)
%      Z_fused = sum(w_k * Z_k)
%      Zv_fused = sum(w_k * Zv_k) + sum(w_k * (Z_k - Z_fused)^2)
%               = within-model var  + between-model var (disagreement penalty)
%      Best for rigorous uncertainty quantification.
%
%   3. CONCATENATION ('concat')
%      Simply stacks all soft data points, even if co-located.
%      Useful when you want BME to handle the weighting internally.
%      Output will have nGrid * nModels rows.
%
% EXAMPLE:
%   softData1 = load('RAMP_MERRA2-GMI.mat');
%   softData2 = load('RAMP_M3fusion.mat');
%   fused = fuseSoftData({softData1, softData2}, 'bma');
%
% Author: Praful Dodda
% Date: November 2025

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'softDataCell', @iscell);
    addRequired(p, 'method', @(x) ismember(lower(x), {'selection', 'bma', 'concat'}));
    addParameter(p, 'DisagreementThreshold', 2.0, @isnumeric);
    addParameter(p, 'MinVariance', 1e-10, @isnumeric);
    addParameter(p, 'VarianceTolerance', 1e-6, @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, softDataCell, method, varargin{:});
    
    opts = p.Results;
    method = lower(method);
    K = numel(softDataCell);
    
    if K < 2
        error('fuseSoftData:NotEnoughModels', 'Need at least 2 models for fusion');
    end
    
    %% Validate inputs
    if opts.Verbose
        fprintf('\n========================================\n');
        fprintf('SOFT DATA FUSION\n');
        fprintf('========================================\n');
        fprintf('Method: %s\n', upper(method));
        fprintf('Number of models: %d\n', K);
    end
    
    % Get reference dimensions
    ref = softDataCell{1};
    [nGrid, nMonths] = size(ref.Z);
    
    modelNames = cell(K, 1);
    for k = 1:K
        sd = softDataCell{k};
        modelNames{k} = sd.modelName;
        
        if opts.Verbose
            fprintf('  Model %d: %s (%d x %d)\n', k, sd.modelName, size(sd.Z, 1), size(sd.Z, 2));
        end
        
        % Validate dimensions (except for concat which allows different grids)
        if ~strcmp(method, 'concat')
            if size(sd.Z, 1) ~= nGrid || size(sd.Z, 2) ~= nMonths
                error('fuseSoftData:DimensionMismatch', ...
                    'Model %s has size [%d, %d], expected [%d, %d]', ...
                    sd.modelName, size(sd.Z, 1), size(sd.Z, 2), nGrid, nMonths);
            end
            
            % Check spatial alignment
            if ~isequal(size(sd.sMS), size(ref.sMS)) || max(abs(sd.sMS(:) - ref.sMS(:))) > 1e-6
                error('fuseSoftData:SpatialMismatch', ...
                    'Model %s has different spatial coordinates than %s', ...
                    sd.modelName, ref.modelName);
            end
            
            % Check temporal alignment
            if ~isequal(sd.tME, ref.tME)
                error('fuseSoftData:TemporalMismatch', ...
                    'Model %s has different time events than %s', ...
                    sd.modelName, ref.modelName);
            end
        end
    end
    
    %% Dispatch to appropriate method
    switch method
        case 'selection'
            fusedData = fuseSelection(softDataCell, opts);
        case 'bma'
            fusedData = fuseBMA(softDataCell, opts);
        case 'concat'
            fusedData = fuseConcat(softDataCell, opts);
    end
    
    % Add common metadata
    fusedData.fusionMethod = method;
    fusedData.sourceModels = modelNames;
    fusedData.version = 4;  % Increment version for fused data
    fusedData.loadedAt = datetime("now", 'Format', 'yyyy-MM-dd HH:mm:ss');
    
    %% Print diagnostics
    if opts.Verbose
        printDiagnostics(softDataCell, fusedData, method);
    end
end


%% ========================================================================
%  FUSION METHODS
%  ========================================================================

function fusedData = fuseSelection(softDataCell, opts)
% FUSESELECTION Spatially Varying Selection (Champion Method)
%
% At each (s,t), select the model with minimum variance.

    K = numel(softDataCell);
    ref = softDataCell{1};
    [nGrid, nMonths] = size(ref.Z);
    
    % Stack all Z and Zv into 3D arrays: (nGrid x nMonths x K)
    allZ = zeros(nGrid, nMonths, K, 'single');
    allZv = zeros(nGrid, nMonths, K, 'single');
    
    for k = 1:K
        allZ(:,:,k) = single(softDataCell{k}.Z);
        allZv(:,:,k) = single(softDataCell{k}.Zv);
    end
    
    % Handle NaN variances by setting to Inf
    allZv_masked = allZv;
    allZv_masked(isnan(allZv)) = Inf;
    
    % Find model with minimum variance at each point
    [minZv, modelSelected] = min(allZv_masked, [], 3);  % (nGrid x nMonths)
    
    % Extract fused values using linear indexing
    Z_fused = zeros(nGrid, nMonths, 'single');
    Zv_fused = zeros(nGrid, nMonths, 'single');
    
    for i = 1:nGrid
        for j = 1:nMonths
            k = modelSelected(i, j);
            Z_fused(i, j) = allZ(i, j, k);
            Zv_fused(i, j) = allZv(i, j, k);
        end
    end
    
    % Check for ties
    nTies = 0;
    for k = 1:K
        nearTie = abs(allZv_masked(:,:,k) - minZv) < opts.VarianceTolerance;
        nTies = nTies + sum(nearTie(:));
    end
    nTies = nTies - numel(minZv);  % Subtract the winners themselves
    tieFraction = nTies / numel(minZv);
    if tieFraction > 0.1
        warning('fuseSoftData:ManyTies', ...
            '%.1f%% of points have near-tied variances. First model wins ties.', ...
            tieFraction * 100);
    end
    
    % Build output struct
    fusedData = buildOutputStruct(ref, Z_fused, Zv_fused, 'selection');
    fusedData.modelSelected = modelSelected;
end


function fusedData = fuseBMA(softDataCell, opts)
% FUSEBMA Bayesian Model Averaging with Moment Matching
%
% Uses precision (inverse-variance) weighting.
% Fused variance = within-model + between-model (Law of Total Variance)

    K = numel(softDataCell);
    ref = softDataCell{1};
    [nGrid, nMonths] = size(ref.Z);
    
    % Stack all Z and Zv into 3D arrays: (nGrid x nMonths x K)
    allZ = zeros(nGrid, nMonths, K, 'single');
    allZv = zeros(nGrid, nMonths, K, 'single');
    
    for k = 1:K
        allZ(:,:,k) = single(softDataCell{k}.Z);
        allZv(:,:,k) = single(softDataCell{k}.Zv);
    end
    
    % Apply variance floor
    allZv_safe = max(allZv, opts.MinVariance);
    
    % Compute precisions (1/variance), setting NaN variances to 0 precision
    precisions = zeros(nGrid, nMonths, K, 'single');
    for k = 1:K
        prec = 1 ./ allZv_safe(:,:,k);
        prec(isnan(allZv(:,:,k))) = 0;  % NaN variance -> 0 contribution
        precisions(:,:,k) = prec;
    end
    
    % Normalize to get weights
    precisionSum = sum(precisions, 3);  % (nGrid x nMonths)
    precisionSum(precisionSum == 0) = 1;  % Avoid div by 0
    
    weights = zeros(nGrid, nMonths, K, 'single');
    for k = 1:K
        weights(:,:,k) = precisions(:,:,k) ./ precisionSum;
    end
    
    % Fused mean: weighted average
    % Handle NaN in Z: treat as 0 contribution (weight already 0)
    allZ_safe = allZ;
    allZ_safe(isnan(allZ)) = 0;
    
    Z_fused = zeros(nGrid, nMonths, 'single');
    for k = 1:K
        Z_fused = Z_fused + weights(:,:,k) .* allZ_safe(:,:,k);
    end
    
    % Fused variance: Law of Total Variance
    % Term 1: Within-model variance (average internal uncertainty)
    withinVar = zeros(nGrid, nMonths, 'single');
    for k = 1:K
        withinVar = withinVar + weights(:,:,k) .* allZv_safe(:,:,k);
    end
    
    % Term 2: Between-model variance (disagreement penalty)
    betweenVar = zeros(nGrid, nMonths, 'single');
    for k = 1:K
        deviation = allZ_safe(:,:,k) - Z_fused;
        betweenVar = betweenVar + weights(:,:,k) .* (deviation.^2);
    end
    
    Zv_fused = withinVar + betweenVar;
    
    % Where all models were NaN, result should be NaN
    allNanMask = all(isnan(allZ), 3);
    Z_fused(allNanMask) = NaN;
    Zv_fused(allNanMask) = NaN;
    
    % Build output struct
    fusedData = buildOutputStruct(ref, Z_fused, Zv_fused, 'bma');
    
    % Store weights
    fusedData.weights = struct();
    for k = 1:K
        fieldName = matlab.lang.makeValidName(softDataCell{k}.modelName);
        fusedData.weights.(fieldName) = weights(:,:,k);
    end
end


function fusedData = fuseConcat(softDataCell, ~)
% FUSECONCAT Simple concatenation of soft datasets
%
% Stacks all soft data points vertically, even if co-located.
% BME will handle the weighting internally during kriging.

    K = numel(softDataCell);
    
    % Count total grid points
    totalGrid = 0;
    for k = 1:K
        totalGrid = totalGrid + size(softDataCell{k}.Z, 1);
    end
    
    % Get time dimension from first model (assume all have same tME)
    ref = softDataCell{1};
    nMonths = size(ref.Z, 2);
    
    % Pre-allocate
    sMS_cat = zeros(totalGrid, 2);
    lat_cat = zeros(totalGrid, 1);
    lon_cat = zeros(totalGrid, 1);
    Z_cat = zeros(totalGrid, nMonths, 'single');
    Zv_cat = zeros(totalGrid, nMonths, 'single');
    modelIndex = zeros(totalGrid, 1);  % Track which model each row came from
    
    % Concatenate
    idx = 1;
    for k = 1:K
        sd = softDataCell{k};
        nk = size(sd.Z, 1);
        
        rows = idx:(idx + nk - 1);
        sMS_cat(rows, :) = sd.sMS;
        if isfield(sd, 'lat')
            lat_cat(rows) = sd.lat;
        else
            lat_cat(rows) = sd.sMS(:, 1);
        end
        if isfield(sd, 'lon')
            lon_cat(rows) = sd.lon;
        else
            lon_cat(rows) = sd.sMS(:, 2);
        end
        Z_cat(rows, :) = single(sd.Z);
        Zv_cat(rows, :) = single(sd.Zv);
        modelIndex(rows) = k;
        
        idx = idx + nk;
    end
    
    % Build output struct
    fusedData = struct();
    fusedData.modelName = 'ConcatFusion';
    fusedData.years = ref.years;
    fusedData.lon = lon_cat;
    fusedData.lat = lat_cat;
    fusedData.sMS = sMS_cat;
    fusedData.tME = ref.tME;
    fusedData.Z = Z_cat;
    fusedData.Zv = Zv_cat;
    fusedData.Zname = 'Concatenated-RAMP';
    fusedData.Zunit = ref.Zunit;
    fusedData.Zlabel = 'Concatenated RAMP-corrected MDA8 Ozone';
    fusedData.nGrid = totalGrid;
    fusedData.nMonths = nMonths;
    fusedData.modelIndex = modelIndex;  % Track source model for each row
    
    if isfield(ref, 'gridInfo')
        fusedData.gridInfo = ref.gridInfo;
        fusedData.gridInfo.note = 'Grid info from first model; concatenated data has multiple grids';
    end
end


%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function fusedData = buildOutputStruct(ref, Z_fused, Zv_fused, method)
% BUILDOUTPUTSTRUCT Create output struct matching input format

    fusedData = struct();
    
    % Generate combined model name
    fusedData.modelName = sprintf('%sFusion', upper(method(1)));
    
    % Copy spatial-temporal coordinates from reference
    fusedData.years = ref.years;
    if isfield(ref, 'lon')
        fusedData.lon = ref.lon;
    end
    if isfield(ref, 'lat')
        fusedData.lat = ref.lat;
    end
    fusedData.sMS = ref.sMS;
    fusedData.tME = ref.tME;
    
    % Fused values
    fusedData.Z = Z_fused;
    fusedData.Zv = Zv_fused;
    
    % Metadata
    fusedData.Zname = sprintf('%s-Fused-RAMP', upper(method));
    fusedData.Zunit = ref.Zunit;
    fusedData.Zlabel = sprintf('%s-Fused RAMP-corrected MDA8 Ozone', upper(method));
    
    % Dimensions
    fusedData.nGrid = size(Z_fused, 1);
    fusedData.nMonths = size(Z_fused, 2);
    
    % Copy grid info if present
    if isfield(ref, 'gridInfo')
        fusedData.gridInfo = ref.gridInfo;
    end
end


function printDiagnostics(softDataCell, fusedData, method)
% PRINTDIAGNOSTICS Print fusion diagnostics

    K = numel(softDataCell);
    
    fprintf('\n--- Diagnostics ---\n');
    
    % Model agreement (correlation between models)
    if ~strcmp(method, 'concat')
        fprintf('Model Correlations:\n');
        for i = 1:K
            for j = (i+1):K
                Zi = softDataCell{i}.Z(:);
                Zj = softDataCell{j}.Z(:);
                mask = ~isnan(Zi) & ~isnan(Zj);
                if sum(mask) > 10
                    r = corr(Zi(mask), Zj(mask));
                    fprintf('  %s vs %s: r = %.3f\n', ...
                        softDataCell{i}.modelName, softDataCell{j}.modelName, r);
                end
            end
        end
    end
    
    % Variance analysis
    inputVarMean = 0;
    for k = 1:K
        inputVarMean = inputVarMean + mean(softDataCell{k}.Zv(:), "omitmissing");
    end
    inputVarMean = inputVarMean / K;
    
    fusedVarMean = mean(fusedData.Zv(:), "omitmissing");
    varRatio = fusedVarMean / inputVarMean;
    
    fprintf('\nVariance Analysis:\n');
    fprintf('  Mean input variance: %.2f\n', inputVarMean);
    fprintf('  Mean fused variance: %.2f\n', fusedVarMean);
    fprintf('  Ratio (fused/input): %.3f\n', varRatio);
    
    if varRatio > 1.5
        fprintf('  -> High ratio indicates significant model disagreement\n');
    elseif varRatio < 0.8
        fprintf('  -> Low ratio suggests models are quite consistent\n');
    end
    
    % Selection fractions
    if strcmp(method, 'selection') && isfield(fusedData, 'modelSelected')
        fprintf('\nSelection Fractions:\n');
        for k = 1:K
            frac = mean(fusedData.modelSelected(:) == k);
            fprintf('  %s: %.1f%%\n', softDataCell{k}.modelName, frac * 100);
        end
    end
    
    % Concatenation info
    if strcmp(method, 'concat')
        fprintf('\nConcatenation Info:\n');
        fprintf('  Total grid points: %d\n', fusedData.nGrid);
        for k = 1:K
            nk = sum(fusedData.modelIndex == k);
            fprintf('  %s: %d points (%.1f%%)\n', ...
                softDataCell{k}.modelName, nk, nk/fusedData.nGrid*100);
        end
    end
    
    fprintf('\n========================================\n\n');
end
