% runBME_estimation.m - Master script for BME data-fusion estimation
%
% Comprehensive BME estimation workflow for TOAR ozone data with multiple
% soft data sources (CTM models, satellites, ML models)
%
% WORKFLOW:
% 1. Load observational data
% 2. Compute/load global offset (reuse from CBV if available)
% 3. Compute/load covariance (reuse from CBV if available)
% 4. Load soft data based on BME method code
% 5. Prepare knowledge bases
% 6. Run BME estimation for all time periods (monthly)
% 7. Generate spatial and temporal plots
%
% OUTPUTS:
% - BME estimates: ./5BMEspatialPlots/BME{method}_go{scenario}_area{code}_*.mat
% - Spatial plots: ./5BMEspatialPlots/figs/
% - Temporal plots: ./5BMEspatialPlots/figs_temporal/
% - Representative sites: ./5BMEspatialPlots/representative_sites.mat

clear;
close all;

%% ====================================================================
%                    CONFIGURATION - BME METHOD
% ====================================================================

% BME method code (8 digits) - determines observation type and soft data sources
% Digit 1: obsType (1=hard only, 2=hard+soft)
% Digit 2: CTMtype (0=none, 1=single, 2=multiple, 3=ensemble)
% Digits 3-5: RAMP corrections (non-linearity, non-homoscedasticity, non-stationarity)
% Digit 6: BME nsmax (soft data neighbors: 0=00, 1=20, 2=40, 3=60, ...)
% Digit 7: BME nhmax (hard data neighbors: 1=10, 2=20, 3=30)
% Digit 8: BME estimation method (1=BMEprobaMoments, 2=KrigingME)
%
% Examples:
% '10000133' - Observations only (no soft data)
% '13000313' - Obs + ensemble CTM (3 models)
% '13000313-02' - Same + M3fusion
% '13000313-12' - Same + M3fusion + UKML

estConfig.BMEmethod = '13000313-12';  % Full data fusion configuration

%% ====================================================================
%                    CONFIGURATION - DATA
% ====================================================================

% Observation data parameters
estConfig.stationTypes = 'all';      % 'all', 'rural', 'urban'
estConfig.timeRange = [2015, 2020];  % [startYear, endYear]

% Global offset scenario (0-4)
% 0: No offset (use raw observations)
% 1: Global mean offset
% 2: Regional offset
% 3: Smooth spatial offset
% 4: Full space-time offset
estConfig.goScenario = 3;

% Covariance model
% 'holecos': Damped oscillating (good for seasonal patterns)
% 'exponential': Smooth decay (good for year-round estimation)
estConfig.temporalModel = 'holecos';

% Log transformation flag
estConfig.logTransf = 0;  % 0=no transform, 1=log transform

%% ====================================================================
%                    CONFIGURATION - SPATIAL DOMAIN
% ====================================================================

% Area code (see getTOARareaBoundaries.m)
% 0: Global
% 1: North America
% 2: Europe
% 3: East Asia
% 4: South Asia
% 5: South America
% 6: Africa
% 7: Australia
% 8: Arctic
% 9: Antarctica
% 10: Continental USA (DEFAULT for initial runs)
estConfig.areaCode = 10;  % Continental USA

% Grid resolution (degrees)
estConfig.mapResolution = 1.0;  % 1 degree grid

% Land-only estimation (exclude ocean points)
estConfig.keepOnlyLand = 1;  % 1=land only, 0=all points

% Include Antarctica
estConfig.includeAntarctica = 0;  % 0=exclude, 1=include

%% ====================================================================
%                    CONFIGURATION - TEMPORAL
% ====================================================================

% Time periods to estimate (monthly resolution)
% Generate monthly time points: Jan 2015 = 2015.042, Feb 2015 = 2015.125, etc.
estConfig.timeStart = estConfig.timeRange(1);
estConfig.timeEnd = estConfig.timeRange(2);

% Create monthly time vector
months = (estConfig.timeStart):(1/12):(estConfig.timeEnd + 1/12);
months = months(1:(12 * (estConfig.timeEnd - estConfig.timeStart + 1)));
estConfig.tkVec = months;

fprintf('Time periods: %d months from %.2f to %.2f\n', ...
    length(estConfig.tkVec), estConfig.tkVec(1), estConfig.tkVec(end));

%% ====================================================================
%                    CONFIGURATION - EXECUTION CONTROL
% ====================================================================

% Force recomputation flags
estConfig.forceGO = 0;          % 1=recompute GO, 0=use existing
estConfig.forceCov = 0;         % 1=recompute Cov, 0=use existing
estConfig.forceKB = 0;          % 1=rebuild KB, 0=use existing
estConfig.forceEstimation = 0;  % 1=rerun BME, 0=use cached results

% Plotting control
estConfig.plotSpatial = 1;      % Generate spatial plots (mean, variance)
estConfig.plotTemporal = 1;     % Generate temporal plots at representative sites
estConfig.plotStats = 1;        % Generate comprehensive statistics plots

% Parallel plotting (requires Parallel Computing Toolbox)
% NOTE: Estimation runs sequentially, only plotting is parallelized
estConfig.parallelPlotting = 0;  % 1=parallel, 0=sequential

%% ====================================================================
%                    WORKFLOW EXECUTION
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                    BME DATA-FUSION ESTIMATION                         \n');
fprintf('========================================================================\n');
fprintf('BME Method: %s\n', estConfig.BMEmethod);
fprintf('Time range: %d-%d (monthly)\n', estConfig.timeRange(1), estConfig.timeRange(2));
fprintf('Area code: %d, Resolution: %.2f deg\n', estConfig.areaCode, estConfig.mapResolution);
fprintf('GO scenario: %d, Temporal model: %s\n', estConfig.goScenario, estConfig.temporalModel);
fprintf('========================================================================\n\n');

%% STAGE 1: Load Observational Data

fprintf('=== STAGE 1: Loading Observational Data ===\n');
tic;

obs = getTOARobservationalData(estConfig.stationTypes, estConfig.timeRange);
obs.logTransf = estConfig.logTransf;

fprintf('  Loaded %d observations from %d stations\n', length(obs.Y), size(obs.sMS, 1));
fprintf('  Time range: %.2f to %.2f\n', min(obs.tME), max(obs.tME));
fprintf('  Spatial extent: [%.1f, %.1f] x [%.1f, %.1f]\n', ...
    min(obs.sMS(:,1)), max(obs.sMS(:,1)), min(obs.sMS(:,2)), max(obs.sMS(:,2)));
fprintf('  Completed in %.1f seconds\n\n', toc);

%% STAGE 2: Compute/Load Global Offset

fprintf('=== STAGE 2: Global Offset Computation ===\n');
tic;

% Check if GO exists from previous run (same scenario and time range)
[yearStart, yearEnd] = deal(estConfig.timeRange(1), estConfig.timeRange(2));
goFile = fullfile('3globalOffsets', sprintf('OZONE-TOARgo_%d_%d-%d.mat', ...
    estConfig.goScenario, yearStart, yearEnd));

if exist(goFile, 'file') && ~estConfig.forceGO
    fprintf('  Loading existing global offset: %s\n', goFile);
    load(goFile, 'go');
else
    fprintf('  Computing global offset (scenario %d)...\n', estConfig.goScenario);
    go = getTOARglobalOffset(obs, estConfig.goScenario);
end

fprintf('  GO scenario: %d\n', go.scenario);
fprintf('  GO grid: %d points\n', length(go.ms));
fprintf('  GO range: [%.2f, %.2f] ppb\n', min(go.ms), max(go.ms));
fprintf('  Completed in %.1f seconds\n\n', toc);

%% STAGE 3: Compute/Load Covariance

fprintf('=== STAGE 3: Covariance Model Estimation ===\n');
tic;

% Check if covariance exists
covFile = fullfile('4covariance', sprintf('Cov_go%d_lt%d_%s_%d-%d.mat', ...
    estConfig.goScenario, estConfig.logTransf, estConfig.temporalModel, yearStart, yearEnd));

if exist(covFile, 'file') && ~estConfig.forceCov
    fprintf('  Loading existing covariance: %s\n', covFile);
    load(covFile, 'cov');
else
    fprintf('  Computing covariance model (temporal: %s)...\n', estConfig.temporalModel);
    cov = getTOARautoCov_updated(obs, go, estConfig.temporalModel);
end

fprintf('  Covariance model: %s\n', cov.covmodel);
fprintf('  Total variance: %.2f ppb²\n', cov.var);
fprintf('  Nugget: %.2f%% (%.2f ppb²)\n', cov.nuggetPercent, cov.covparam{1}(1));
fprintf('  Space-time metric: %.2f\n', cov.stmetric);
fprintf('  Completed in %.1f seconds\n\n', toc);

%% STAGE 4: Load Soft Data

fprintf('=== STAGE 4: Loading Soft Data ===\n');
tic;

% Parse BME method code to determine which soft data to load
BMEmethod8digits = estConfig.BMEmethod;
[obsType, CTMtype, ~, ~, ~, ~, ctm_models] = parseBMEcode(BMEmethod8digits);

softData = [];
if CTMtype >= 1 && ~isempty(ctm_models)
    fprintf('  Loading soft data for CTM models:\n');
    for iModel = 1:length(ctm_models)
        fprintf('    %d. %s\n', iModel, ctm_models{iModel});
    end

    % Load soft data using existing functions
    softData = loadRAMPdata(ctm_models, estConfig.timeRange);

    if ~isempty(softData)
        fprintf('  Soft data loaded: %d models with %d total points\n', ...
            length(ctm_models), length(softData.Z));
    else
        warning('No soft data loaded - will run with observations only');
    end
else
    fprintf('  No soft data requested (observations only)\n');
end

fprintf('  Completed in %.1f seconds\n\n', toc);

%% STAGE 5: Prepare Knowledge Bases

fprintf('=== STAGE 5: Preparing BME Knowledge Bases ===\n');
tic;

% Get knowledge bases
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod8digits, 'stug');

fprintf('  General Knowledge (KG):\n');
fprintf('    Covariance model: %s\n', strjoin(KG.covmodel, ', '));
fprintf('    Total variance: %.2f ppb²\n', KG.sill);
fprintf('    Mean order: %s\n', mat2str(KG.order));
fprintf('  Site-Specific Knowledge (KS):\n');
fprintf('    Hard data: %d points\n', length(KS.harddata.z));
if ~isempty(KS.softdata.z)
    fprintf('    Soft data: %d points\n', length(KS.softdata.z));
else
    fprintf('    Soft data: none\n');
end
fprintf('  BME Parameters:\n');
fprintf('    nhmax: %d, nsmax: %d\n', BMEparam.nhmax, BMEparam.nsmax);
fprintf('    Search radius: [%.1f deg spatial, %.1f yr temporal]\n', ...
    BMEparam.dmax(1), BMEparam.dmax(2));
fprintf('  Completed in %.1f seconds\n\n', toc);

%% STAGE 6: BME Estimation

fprintf('=== STAGE 6: BME Spatial Estimation ===\n');

% Create estimation parameters
estParam.areaCode = estConfig.areaCode;
estParam.mapResolution = estConfig.mapResolution;
estParam.keepOnlyLand = estConfig.keepOnlyLand;
estParam.includeAntarctica = estConfig.includeAntarctica;
estParam.tkVec = estConfig.tkVec;
estParam.forceEstimation = estConfig.forceEstimation;
estParam.plotResults = 0;  % Don't plot during estimation (do later in batch)
estParam.BMEmethod = BMEmethod8digits;

% Create estimation grid
fprintf('  Creating estimation grid...\n');
[axMS_est, estGridArea] = getTOARareaBoundaries(estConfig.areaCode);
sk = getTOARmapGrid(estConfig.mapResolution, estConfig.keepOnlyLand, estConfig.includeAntarctica);

% Filter to estimation area
inArea = (sk(:,1) >= axMS_est(1)) & (sk(:,1) <= axMS_est(2)) & ...
         (sk(:,2) >= axMS_est(3)) & (sk(:,2) <= axMS_est(4));
sk = sk(inArea, :);

fprintf('    Grid points: %d\n', size(sk, 1));
fprintf('    Spatial extent: [%.1f, %.1f] x [%.1f, %.1f]\n', ...
    min(sk(:,1)), max(sk(:,1)), min(sk(:,2)), max(sk(:,2)));

% Create output directory
BMEsDir = '5BMEspatialPlots';
if ~exist(BMEsDir, 'dir')
    mkdir(BMEsDir);
end

% Base filename
BMEsFileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_stug_land%d', ...
    BMEmethod8digits, go.scenario, obs.logTransf, estConfig.areaCode, ...
    estConfig.mapResolution, estConfig.keepOnlyLand);

% Run estimation for each time period
fprintf('\n  Running BME estimation for %d time periods...\n', length(estConfig.tkVec));
totalTic = tic;

for iTime = 1:length(estConfig.tkVec)
    tk = estConfig.tkVec(iTime);

    % Create filename
    BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
    BMEsPath = fullfile(BMEsDir, BMEsFile);

    fprintf('\n  [%d/%d] Time = %.2f (%.0f-%02.0f)\n', ...
        iTime, length(estConfig.tkVec), tk, floor(tk), round(mod(tk, 1)*12)+1);

    % Check if already estimated
    if exist(BMEsPath, 'file') && ~estConfig.forceEstimation
        fprintf('    Results exist, skipping...\n');
        continue;
    end

    % Create space-time estimation points
    ck = [sk, tk * ones(size(sk, 1), 1)];

    % Perform BME estimation using krigingME_stug_multi
    fprintf('    Estimating %d points using krigingME_stug_multi...\n', size(ck, 1));
    estTic = tic;

    try
        if isempty(KS.softdata.p)
            % Hard data only
            [XkBMEm, XkBMEv] = krigingME_stug_multi(ck, KS.harddata.p, [], ...
                KS.harddata.z, [], [], KG.covmodel, KG.covparam, ...
                BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, ...
                BMEparam.order, BMEparam.options);
        else
            % Hard and soft data
            [XkBMEm, XkBMEv] = krigingME_stug_multi(ck, KS.harddata.p, KS.softdata.p, ...
                KS.harddata.z, KS.softdata.z, KS.softdata.vs, ...
                KG.covmodel, KG.covparam, BMEparam.nhmax, BMEparam.nsmax, ...
                BMEparam.dmax, BMEparam.order, BMEparam.options);
        end

        % Add back global offset
        gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk * ones(size(sk, 1), 1));
        YkBMEm = XkBMEm + gok;

        % Get observations at this time (for plotting/validation)
        timeWindow = 1/24;  % ±1 day window
        obsIdx = abs(obs.tME - tk) < timeWindow;
        sMSobs = obs.sMS(obsIdx, :);
        Yobs = obs.Y(obsIdx);

        % Store results
        BMEs = struct();
        BMEs.sk = sk;
        BMEs.tk = tk;
        BMEs.XkBMEm = XkBMEm;
        BMEs.XkBMEv = XkBMEv;
        BMEs.YkBMEm = YkBMEm;
        BMEs.gok = gok;
        BMEs.sMSobs = sMSobs;
        BMEs.Yobs = Yobs;
        BMEs.estGridArea = estGridArea;
        BMEs.BMEmethod = BMEmethod8digits;
        BMEs.goScenario = go.scenario;
        BMEs.temporalModel = estConfig.temporalModel;

        % Save results
        save(BMEsPath, 'BMEs', 'estConfig', '-v7.3');

        fprintf('    Completed in %.1f seconds\n', toc(estTic));
        fprintf('    Estimate range: [%.1f, %.1f] ppb\n', ...
            min(YkBMEm(~isnan(YkBMEm))), max(YkBMEm(~isnan(YkBMEm))));
        fprintf('    Mean uncertainty: %.1f ppb (std dev)\n', ...
            mean(sqrt(XkBMEv(~isnan(XkBMEv)))));

    catch ME
        warning('Estimation failed for time %.2f: %s', tk, ME.message);
        fprintf('    Stack: %s\n', ME.stack(1).name);
        continue;
    end
end

totalTime = toc(totalTic);
fprintf('\n  All estimations completed in %.1f minutes\n', totalTime/60);
fprintf('  Average: %.1f seconds per time period\n\n', totalTime/length(estConfig.tkVec));

%% STAGE 7: Select Representative Sites

if estConfig.plotTemporal
    fprintf('=== STAGE 7: Selecting Representative Sites ===\n');
    tic;

    repSitesFile = fullfile(BMEsDir, 'representative_sites.mat');

    if exist(repSitesFile, 'file')
        fprintf('  Loading existing representative sites...\n');
        load(repSitesFile, 'repSites');
    else
        fprintf('  Selecting one site per region...\n');
        repSites = selectRepresentativeSites(obs, estConfig.areaCode);
        save(repSitesFile, 'repSites');
    end

    fprintf('  Selected %d representative sites\n', length(fieldnames(repSites)));
    regions = fieldnames(repSites);
    for iReg = 1:length(regions)
        site = repSites.(regions{iReg});
        fprintf('    %s: [%.2f, %.2f], %d obs (%.1f%% complete)\n', ...
            regions{iReg}, site.lon, site.lat, site.nObs, site.completeness*100);
    end

    fprintf('  Completed in %.1f seconds\n\n', toc);
end

%% STAGE 8: Generate Plots

fprintf('=== STAGE 8: Generating Plots ===\n');

% Spatial plots (mean and variance maps)
if estConfig.plotSpatial
    fprintf('  Generating spatial plots...\n');
    tic;

    if estConfig.parallelPlotting
        % Parallel plotting
        fprintf('    Using parallel plotting...\n');
        parfor iTime = 1:length(estConfig.tkVec)
            tk = estConfig.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                data = load(BMEsPath);
                plotBME_SpatialStats(data.BMEs, obs, go, estParam);
            end
        end
    else
        % Sequential plotting
        for iTime = 1:length(estConfig.tkVec)
            tk = estConfig.tkVec(iTime);
            BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
            BMEsPath = fullfile(BMEsDir, BMEsFile);

            if exist(BMEsPath, 'file')
                if mod(iTime, 12) == 1
                    fprintf('    Plotting time %d/%d (%.2f)...\n', iTime, length(estConfig.tkVec), tk);
                end
                data = load(BMEsPath);
                plotBME_SpatialStats(data.BMEs, obs, go, estParam);
            end
        end
    end

    fprintf('    Spatial plots completed in %.1f minutes\n', toc/60);
end

% Temporal plots at representative sites
if estConfig.plotTemporal
    fprintf('  Generating temporal series plots...\n');
    tic;

    % Load all BME results for temporal analysis
    allBMEs = cell(length(estConfig.tkVec), 1);
    for iTime = 1:length(estConfig.tkVec)
        tk = estConfig.tkVec(iTime);
        BMEsFile = sprintf('%s_time%.2f.mat', BMEsFileBase, tk);
        BMEsPath = fullfile(BMEsDir, BMEsFile);

        if exist(BMEsPath, 'file')
            data = load(BMEsPath);
            allBMEs{iTime} = data.BMEs;
        end
    end

    % Generate temporal plots
    plotBME_TemporalSeries(allBMEs, obs, repSites, estConfig);

    fprintf('    Temporal plots completed in %.1f minutes\n', toc/60);
end

%% Summary

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                    ESTIMATION COMPLETE                                \n');
fprintf('========================================================================\n');
fprintf('BME Method: %s\n', BMEmethod8digits);
fprintf('Time periods estimated: %d\n', length(estConfig.tkVec));
fprintf('Results saved to: %s\n', BMEsDir);
fprintf('  - Estimation files: %s_time*.mat\n', BMEsFileBase);
if estConfig.plotSpatial
    fprintf('  - Spatial plots: ./figs/spatial/\n');
end
if estConfig.plotTemporal
    fprintf('  - Temporal plots: ./figs_temporal/\n');
    fprintf('  - Representative sites: representative_sites.mat\n');
end
fprintf('========================================================================\n');
