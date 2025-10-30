%% checkAllGridUniformity.m
% Script to check uniformity of all model spatial grids
%
% This script:
% 1. Finds all spatial grid .mat files
% 2. Analyzes each for uniformity
% 3. Generates a summary report
% 4. Identifies which models can use simple thinning
%
% Run this script after extractModelSpatialInfo.m

clear; clc;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                CHECK ALL SPATIAL GRIDS FOR UNIFORMITY\n');
fprintf('========================================================================\n');
fprintf('\n');

%% Configuration
spatialGridDir = fullfile('1data', 'CTM', 'model_output_data', 'spatial_grids');

if ~exist(spatialGridDir, 'dir')
    error('Spatial grid directory not found: %s\nPlease run extractModelSpatialInfo.m first.', spatialGridDir);
end

%% Find all spatial grid files
matFiles = dir(fullfile(spatialGridDir, '*_spatial_grid.mat'));

if isempty(matFiles)
    error('No spatial grid .mat files found in: %s\nPlease run extractModelSpatialInfo.m first.', spatialGridDir);
end

nModels = length(matFiles);
fprintf('Found %d spatial grid files to analyze\n\n', nModels);

%% Analyze each grid
results = struct();

for i = 1:nModels
    matFile = matFiles(i).name;
    modelName = strrep(matFile, '_spatial_grid.mat', '');
    matPath = fullfile(spatialGridDir, matFile);

    fprintf('========================================================================\n');
    fprintf('[%d/%d] Analyzing: %s\n', i, nModels, modelName);
    fprintf('========================================================================\n');

    try
        % Analyze uniformity
        analysis = analyzeGridUniformity(matPath, 'mat');

        % Store results
        results.(modelName) = analysis;

    catch ME
        warning('Failed to analyze %s: %s', modelName, ME.message);
        results.(modelName).isUniform = false;
        results.(modelName).gridType = 'error';
        results.(modelName).error = ME.message;
    end

    fprintf('\n');
end

%% Generate summary report
fprintf('========================================================================\n');
fprintf('                         SUMMARY REPORT\n');
fprintf('========================================================================\n\n');

% Table header
fprintf('%-25s %10s %10s %12s %12s %s\n', ...
    'Model', 'Points', 'Grid Type', 'Lon Res (°)', 'Lat Res (°)', 'Thinning');
fprintf('%s\n', repmat('-', 100, 1));

% Sort models alphabetically
modelNames = sort(fieldnames(results));

nUniform = 0;
nIrregular = 0;

for i = 1:length(modelNames)
    modelName = modelNames{i};
    analysis = results.(modelName);

    if isfield(analysis, 'error')
        fprintf('%-25s %10s %10s %12s %12s %s\n', ...
            modelName, 'ERROR', analysis.gridType, 'N/A', 'N/A', 'N/A');
        continue;
    end

    % Format resolution
    if isnan(analysis.lonResolution)
        lonResStr = 'N/A';
        latResStr = 'N/A';
    else
        lonResStr = sprintf('%.4f', analysis.lonResolution);
        latResStr = sprintf('%.4f', analysis.latResolution);
    end

    % Thinning recommendation
    if analysis.isUniform
        nUniform = nUniform + 1;
        if analysis.lonResolution < 0.3
            thinStr = 'Factor 2-4';
        else
            thinStr = 'Keep all';
        end
    else
        nIrregular = nIrregular + 1;
        thinStr = 'NOT VALID';
    end

    fprintf('%-25s %10d %10s %12s %12s %s\n', ...
        modelName, analysis.nPoints, analysis.gridType, ...
        lonResStr, latResStr, thinStr);
end

fprintf('\n');
fprintf('Summary:\n');
fprintf('  Uniform grids (can use simple thinning): %d\n', nUniform);
fprintf('  Irregular grids (need special handling): %d\n', nIrregular);
fprintf('  Total models: %d\n', length(modelNames));

%% Specific recommendations
fprintf('\n========================================================================\n');
fprintf('                         RECOMMENDATIONS\n');
fprintf('========================================================================\n\n');

fprintf('MODELS SAFE FOR SIMPLE THINNING (use subsetSoftData):\n');
fprintf('------------------------------------------------------\n');
for i = 1:length(modelNames)
    modelName = modelNames{i};
    analysis = results.(modelName);

    if isfield(analysis, 'isUniform') && analysis.isUniform
        if ~isnan(analysis.lonResolution)
            fprintf('  ✓ %-20s  (%.4f° × %.4f°)\n', ...
                modelName, analysis.lonResolution, analysis.latResolution);
        end
    end
end

fprintf('\n');
fprintf('MODELS REQUIRING SPECIAL HANDLING:\n');
fprintf('----------------------------------\n');
for i = 1:length(modelNames)
    modelName = modelNames{i};
    analysis = results.(modelName);

    if isfield(analysis, 'isUniform') && ~analysis.isUniform
        fprintf('  ✗ %-20s  (%s)\n', modelName, analysis.recommendations);
    end
end

%% Save results
saveFile = fullfile(spatialGridDir, 'grid_uniformity_analysis.mat');
save(saveFile, 'results', 'modelNames');
fprintf('\n');
fprintf('Results saved to: %s\n', saveFile);

fprintf('\n========================================================================\n');
fprintf('                         ANALYSIS COMPLETE\n');
fprintf('========================================================================\n\n');
