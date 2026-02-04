% runBME_estimation.m - Production BME data-fusion estimation workflow
%
% Comprehensive BME estimation pipeline leveraging proven analyzeTOAR workflow
% with enhanced Phase 1 plotting for spatial and temporal analysis
%
% WORKFLOW:
% 1. Load soft data (with temporal padding and spatial subsetting)
% 2. Run analyzeTOAR pipeline (obs → GO → Cov → KB → BME estimation)
% 3. Generate Phase 1 plots (spatial maps and temporal series)
%
% OUTPUTS:
% - BME estimates: ./5BMEspatialPlots/BME{method}_*.mat
% - Spatial plots: ./5BMEspatialPlots/figs/spatial/
% - Temporal plots: ./5BMEspatialPlots/figs_temporal/
% - Representative sites: ./5BMEspatialPlots/representative_sites.mat

clear;
close all;

%% ====================================================================
%                    CONFIGURATION
% ====================================================================

% Analysis parameters (matches analyzeTOAR structure)
analyzeParam = struct();

%% DATA CONFIGURATION

analyzeParam.stationTypes = 'all';      % 'all', 'rural', 'urban'
analyzeParam.timeRange = [2015, 2020];  % [startYear, endYear]
analyzeParam.logTransf = 0;             % 0=no transform, 1=log transform

%% BME METHOD CONFIGURATION

% 8-digit BME method code (determines soft data sources)
% Examples:
%   '10000133' - Observations only
%   '13000313-02' - Obs + M3fusion
%   '13000313-02-10' - Obs + M3fusion + UKML
analyzeParam.BMEmethod = '13000313-12';

% Data format for kriging computation
% 'stv'  - Space-Time Vector (slowest, any grid)
% 'stg'  - Space-Time Grid (faster, regular grids)
% 'stug' - Space-Time Unstructured Grid (fastest, uniform grids)
analyzeParam.dataFormat = 'stug';

%% GLOBAL OFFSET CONFIGURATION

% Global offset scenario (0-4)
% 0: No offset
% 1: Global mean
% 2: Regional offset
% 3: Smooth spatial offset (RECOMMENDED)
% 4: Full space-time offset
analyzeParam.goScenario = 3;
analyzeParam.forceGO = 0;    % 0=use cached, 1=recompute
analyzeParam.goPlot = 0;     % 0=no plots, 1=basic, 2=detailed

%% COVARIANCE CONFIGURATION

% Temporal covariance model
% 'holecos': Damped oscillating (good for seasonal patterns)
% 'exponential': Smooth decay
analyzeParam.temporalModel = 'holecos';
analyzeParam.forceCov = 0;   % 0=use cached, 1=recompute

%% ESTIMATION CONFIGURATION

% Geographic area (see getTOARareaBoundaries)
% 0: Global
% 1: North America
% 2: Europe
% ...
% 10: Continental USA (DEFAULT)
analyzeParam.areaCode = 10;

% Grid resolution (degrees)
analyzeParam.mapResolution = 1.0;

% Estimation grid options
analyzeParam.keepOnlyLand = true;        % true=land only, false=include ocean
analyzeParam.includeAntarctica = false;  % false=exclude Antarctica

% Time periods to estimate (monthly resolution)
analyzeParam.tkVec = (2015):(1/12):(2020 + 11/12);  % Monthly 2015-2020

% Force re-estimation
analyzeParam.forceEstimation = 0;  % 0=use cached, 1=rerun all

%% PLOTTING CONFIGURATION

% Spatial plotting (handled by estTOARsBME)
analyzeParam.plotResults = 2;   % 0=none, 1=basic, 2=with observations
analyzeParam.plotVariance = 1;  % 0=none, 1=std, 2=var, 3=CV, 4=all

% Phase 1 plotting (temporal and enhanced spatial)
analyzeParam.plotTemporal = 1;      % Generate temporal series plots
analyzeParam.plotSpatialStats = 1;  % Generate multi-panel spatial summary
analyzeParam.parallelPlotting = 0;  % 0=sequential, 1=parallel (for plotting only)

%% WORKFLOW CONTROL

% Control which analysis steps to run
analyzeParam.runExplore = 0;  % Exploratory data analysis
analyzeParam.runGO = 1;       % Global offset estimation
analyzeParam.runCov = 1;      % Covariance modeling
analyzeParam.runBME = 1;      % BME spatial estimation

%% ====================================================================
%                    DISPLAY CONFIGURATION SUMMARY
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                    BME DATA-FUSION ESTIMATION                         \n');
fprintf('========================================================================\n');
fprintf('BME Method: %s\n', analyzeParam.BMEmethod);
fprintf('Time range: %d-%d (%d time periods)\n', ...
    analyzeParam.timeRange(1), analyzeParam.timeRange(2), length(analyzeParam.tkVec));
fprintf('Area: %d, Resolution: %.2f deg, Land only: %d\n', ...
    analyzeParam.areaCode, analyzeParam.mapResolution, analyzeParam.keepOnlyLand);
fprintf('GO scenario: %d, Temporal model: %s\n', ...
    analyzeParam.goScenario, analyzeParam.temporalModel);
fprintf('Data format: %s\n', analyzeParam.dataFormat);
fprintf('========================================================================\n\n');

%% ====================================================================
%                    SOFT DATA LOADING
% ====================================================================

fprintf('=== STAGE 1: Loading Soft Data ===\n');
tic;

% Load soft data with temporal padding and spatial subsetting
% This function:
% - Parses BME method to extract CTM models
% - Loads data with ±1 year padding (avoids edge effects)
% - Subsets to estimation area + buffer
% - Marks as CTM data (.ctm = 1)
analyzeParam.softData = getTOARSoftData(analyzeParam.BMEmethod, analyzeParam, ...
    'temporalPadding', 1, ...      % ±1 year padding
    'spatialBuffer', 2, ...         % ±2 degree buffer
    'thinningFactor', 0, ...        % No thinning
    'forceReload', 0);

fprintf('  Completed in %.1f seconds\n\n', toc);

%% ====================================================================
%                    MAIN WORKFLOW (using proven pipeline)
% ====================================================================

fprintf('=== STAGE 2: Running BME Analysis Pipeline ===\n');
fprintf('Using proven analyzeTOAR → estTOARsBME workflow\n\n');

tic;

% Run the proven analysis pipeline
% This handles:
% - Loading observational data
% - Computing/loading global offset
% - Computing/loading covariance
% - Preparing knowledge bases (KG, KS)
% - Running BME estimation (calls estTOARsBME internally)
[obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);

elapsedTime = toc;

fprintf('\n=== BME Analysis Pipeline Complete ===\n');
fprintf('Total time: %.1f minutes\n', elapsedTime/60);
fprintf('Average: %.1f seconds per time period\n\n', elapsedTime/length(analyzeParam.tkVec));

%% ====================================================================
%                    PHASE 1: ENHANCED PLOTTING
% ====================================================================

if analyzeParam.plotTemporal || analyzeParam.plotSpatialStats
    fprintf('=== STAGE 3: Phase 1 Plotting ===\n');
end

%% Select Representative Sites

if analyzeParam.plotTemporal
    fprintf('\n--- Selecting Representative Sites ---\n');
    tic;

    repSitesFile = fullfile('5BMEspatialPlots', 'representative_sites.mat');

    if exist(repSitesFile, 'file')
        fprintf('  Loading existing representative sites...\n');
        load(repSitesFile, 'repSites');
    else
        fprintf('  Selecting one site per region...\n');
        repSites = selectRepresentativeSites(obs, analyzeParam.areaCode, ...
            'minCompleteness', 0.70, ...
            'minObservations', 100, ...
            'selectionMethod', 'centroid', ...
            'saveResults', true);
        save(repSitesFile, 'repSites');
    end

    regions = fieldnames(repSites);
    fprintf('  Selected %d representative sites\n', length(regions));
    for i = 1:length(regions)
        site = repSites.(regions{i});
        fprintf('    %s: [%.2f, %.2f] (%d obs, %.1f%% complete)\n', ...
            regions{i}, site.lon, site.lat, site.nObs, site.completeness*100);
    end

    fprintf('  Completed in %.1f seconds\n', toc);
end

%% Temporal Series Plots

if analyzeParam.plotTemporal
    fprintf('\n--- Generating Temporal Series Plots ---\n');
    tic;

    % Load all BME results for temporal analysis
    % Build filename pattern from BME configuration
    BMEsDir = '5BMEspatialPlots';
    BMEsFileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', ...
        analyzeParam.BMEmethod, analyzeParam.goScenario, analyzeParam.logTransf, ...
        analyzeParam.areaCode, analyzeParam.mapResolution, analyzeParam.dataFormat, ...
        analyzeParam.keepOnlyLand);

    % Load all estimation results
    allBMEs = cell(length(analyzeParam.tkVec), 1);
    fprintf('  Loading %d time periods...\n', length(analyzeParam.tkVec));

    if analyzeParam.parallelPlotting
        % Parallel loading
        parfor iTime = 1:length(analyzeParam.tkVec)
            tk = analyzeParam.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                data = load(BMEsPath);
                allBMEs{iTime} = data.BMEs;
            end
        end
    else
        % Sequential loading
        for iTime = 1:length(analyzeParam.tkVec)
            tk = analyzeParam.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                if mod(iTime, 12) == 1
                    fprintf('    Loading time %d/%d (%.2f)...\n', iTime, length(analyzeParam.tkVec), tk);
                end
                data = load(BMEsPath);
                allBMEs{iTime} = data.BMEs;
            end
        end
    end

    % Generate temporal plots
    fprintf('  Creating temporal series plots...\n');
    figPaths_temporal = plotBME_TemporalSeries(allBMEs, obs, repSites, analyzeParam, ...
        'plotType', 'full', ...           % full=4-panel, simple=1-panel, both=both
        'uncertaintyBands', [1, 2], ...    % ±1σ and ±2σ
        'saveTable', true, ...             % Save statistics CSV
        'combineRegions', true, ...        % Multi-region comparison plot
        'dpi', 300, ...
        'visible', 'off');

    fprintf('  Generated %d temporal figures\n', length(figPaths_temporal));
    fprintf('  Completed in %.1f minutes\n', toc/60);
end

%% Enhanced Spatial Statistics Plots

if analyzeParam.plotSpatialStats
    fprintf('\n--- Generating Enhanced Spatial Plots ---\n');
    tic;

    % Multi-panel spatial summary plots (mean, std, CV, obs density)
    % This is done in addition to the standard plots from estTOARsBME

    fprintf('  Creating multi-panel spatial summaries...\n');
    nPlots = 0;

    if analyzeParam.parallelPlotting
        % Parallel plotting
        parfor iTime = 1:length(analyzeParam.tkVec)
            tk = analyzeParam.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                data = load(BMEsPath);
                plotBME_SpatialStats(data.BMEs, obs, go, analyzeParam, ...
                    'plotMultiPanel', true, ...   % 4-panel summary
                    'plotMean', false, ...         % Skip (already done by estTOARsBME)
                    'plotVariance', false, ...     % Skip (already done by estTOARsBME)
                    'plotCV', false, ...           % Skip (already done by estTOARsBME)
                    'dpi', 300, ...
                    'visible', 'off');
            end
        end
    else
        % Sequential plotting
        for iTime = 1:length(analyzeParam.tkVec)
            tk = analyzeParam.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                if mod(iTime, 12) == 1
                    fprintf('    Plotting time %d/%d (%.2f)...\n', iTime, length(analyzeParam.tkVec), tk);
                end
                data = load(BMEsPath);
                plotBME_SpatialStats(data.BMEs, obs, go, analyzeParam, ...
                    'plotMultiPanel', true, ...
                    'plotMean', false, ...
                    'plotVariance', false, ...
                    'plotCV', false, ...
                    'dpi', 300, ...
                    'visible', 'off');
                nPlots = nPlots + 1;
            end
        end
    end

    fprintf('  Generated %d spatial summary figures\n', nPlots);
    fprintf('  Completed in %.1f minutes\n', toc/60);
end

%% ====================================================================
%                    SUMMARY
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                    ESTIMATION COMPLETE                                \n');
fprintf('========================================================================\n');
fprintf('BME Method: %s\n', analyzeParam.BMEmethod);
fprintf('Time periods estimated: %d\n', length(analyzeParam.tkVec));
fprintf('\nResults saved to:\n');
fprintf('  - BME estimates: ./5BMEspatialPlots/\n');
fprintf('  - Spatial plots: ./5BMEspatialPlots/figs/\n');
if analyzeParam.plotTemporal
    fprintf('  - Temporal plots: ./5BMEspatialPlots/figs_temporal/\n');
    fprintf('  - Representative sites: ./5BMEspatialPlots/representative_sites.mat\n');
end
if analyzeParam.plotSpatialStats
    fprintf('  - Spatial summaries: ./5BMEspatialPlots/figs/spatial/\n');
end
fprintf('========================================================================\n');
