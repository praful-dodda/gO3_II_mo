% runBME_temporal.m - Independent BME temporal series analysis workflow
%
% Efficient temporal analysis workflow that estimates BME ONLY at
% representative sites (NO spatial grid estimation required)
%
% WORKFLOW:
% 1. Load soft data (with temporal padding and spatial subsetting)
% 2. Select representative sites
% 3. Prepare BME components (obs → GO → Cov → KB)
% 4. Run BME estimation ONLY at representative sites (fast!)
% 5. Generate temporal series plots
%
% BENEFITS:
% - Much faster than full spatial estimation (10-100x speedup)
% - Focuses on temporal validation at key locations
% - Independent of spatial grid requirements
% - Ideal for model comparison and temporal pattern analysis
%
% OUTPUTS:
% - Site estimates: ./6BMEtemporalSeries/site_estimates_*.mat
% - Temporal plots: ./6BMEtemporalSeries/figs_temporal/
% - Representative sites: ./6BMEtemporalSeries/representative_sites.mat
% - Statistics: ./6BMEtemporalSeries/figs_temporal/temporal_statistics.csv

clear;
close all;

%% ====================================================================
%                    CONFIGURATION
% ====================================================================

% Analysis parameters
analyzeParam = struct();

%% DATA CONFIGURATION

analyzeParam.stationTypes = 'all';      % 'all', 'rural', 'urban'
analyzeParam.logTransf = 0;             % 0=no transform, 1=log transform
analyzeParam.runExplore = 0;
analyzeParam.softDataDir = fullfile('d:\Users\praful\Documents\Data\ramp_data\');  % Parquet directory

% Estimation years (actual years to estimate)
estYears = 2017;

% Temporal padding for observations (years before/after for edge effects)
temporalPadding = 1;  % Load obs for estYears ± this value

% Observation time range (with padding)
analyzeParam.timeRange = [estYears(1) - temporalPadding, estYears(end) + temporalPadding];

%% BME METHOD CONFIGURATION

% 8-digit BME method code (determines soft data sources)
% Examples:
%   '10000133' - Observations only
%   '13000313-02' - Obs + M3fusion
%   '13000313-02-10' - Obs + M3fusion + UKML
% Can specify multiple methods as cell array
BMEmethods = {'10000133'};  % Start with obs-only for fast testing

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

%% REPRESENTATIVE SITE SELECTION

% Geographic area (see getTOARareaBoundaries)
% 0: Global
% 1: North America
% 2: Europe
% ... 10: User defined
analyzeParam.areaCode = 0;

% Site selection criteria
analyzeParam.minCompleteness = 0.40;  % Minimum data completeness (0-1)
analyzeParam.maxCompleteness = 0.8;   % Maximum data completeness (0-1)
analyzeParam.minObservations = 4;    % Minimum number of observations
analyzeParam.selectionMethod = 'completeness';  % 'completeness', 'centroid', 'density'

% Force re-selection of representative sites
analyzeParam.forceRepSites = 1;  % 0=use cached, 1=reselect

%% BME TEMPORAL ESTIMATION CONFIGURATION

% Leave-one-out cross-validation
analyzeParam.exclusionRadius = 0.5;  % Radius (degrees) to exclude nearby obs

% Force re-estimation
analyzeParam.forceEstimation = 1;  % 0=use cached, 1=rerun

% Kriging parameters (will be set by getBMEparam, but can override)
analyzeParam.nhmax = []; % Max hard data neighbors ([] = use default)
analyzeParam.nsmax = []; % Max soft data neighbors ([] = use default)
analyzeParam.dmax = [];  % Max search radius ([] = use default)

%% PLOTTING CONFIGURATION

% Temporal plotting
analyzeParam.plotTemporal = 1;      % Generate temporal series plots
analyzeParam.plotType = 'full';     % 'full', 'simple', 'both'
analyzeParam.uncertaintyBands = [1, 2];  % ±1σ and ±2σ
analyzeParam.combineRegions = true;    % Create multi-region comparison plot
analyzeParam.saveTable = false;         % Save statistics CSV

% Observation matching for plots
analyzeParam.obsMatchRadius = 0.01; % Radius (deg) for matching obs to site
                                     % 0.01 = exact site (~1 km)
                                     % 0.5 = within 0.5 deg (~50 km)

% Soft-data plotting
analyzeParam.plotSoftData = false;      % false=disable, true=plot soft-data if available

% Figure settings
analyzeParam.figDPI = 300;
analyzeParam.figVisible = 'on';

%% WORKFLOW CONTROL

% Control which analysis steps to run
analyzeParam.runGO = 1;       % Global offset estimation
analyzeParam.runCov = 1;      % Covariance modeling
analyzeParam.runBME = 0;      % BME spatial estimation
analyzeParam.runBME_t = 1;    % BME temporal estimation at representative sites

%% ====================================================================
%                    DISPLAY CONFIGURATION SUMMARY
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('                BME TEMPORAL SERIES ANALYSIS (INDEPENDENT)            \n');
fprintf('========================================================================\n');
fprintf('BME Methods: %s\n', strjoin(BMEmethods, ', '));
fprintf('Observation range: %d-%d (with ±%d year padding)\n', ...
    analyzeParam.timeRange(1), analyzeParam.timeRange(2), temporalPadding);
fprintf('Estimation years: %d-%d\n', ...
    estYears(1), estYears(end));
fprintf('Area: %d, Selection: %s (≥%.0f%% complete and ≤%.0f%% complete, ≥%d obs)\n', ...
    analyzeParam.areaCode, analyzeParam.selectionMethod, ...
    analyzeParam.minCompleteness*100, analyzeParam.maxCompleteness*100, analyzeParam.minObservations);
fprintf('GO scenario: %d, Temporal model: %s\n', ...
    analyzeParam.goScenario, analyzeParam.temporalModel);
fprintf('Exclusion radius: %.2f deg (leave-one-out)\n', analyzeParam.exclusionRadius);
fprintf('========================================================================\n\n');

%% ====================================================================
%                    METHOD LOOP
% ====================================================================

for iMethod = 1:length(BMEmethods)
    for eachYear = estYears
        fprintf(' Estimation Year: %d\n', eachYear);

        % Time periods to estimate (monthly resolution, based on the year)
        analyzeParam.tkVec = (eachYear):(1/12):(eachYear + 11/12);

        analyzeParam.BMEmethod = BMEmethods{iMethod};

        fprintf('\n');
        fprintf('************************************************************************\n');
        fprintf('   PROCESSING METHOD %d/%d: %s\n', iMethod, length(BMEmethods), analyzeParam.BMEmethod);
        fprintf('************************************************************************\n\n');

        %% ====================================================================
        %                    SOFT DATA LOADING
        % ====================================================================

        fprintf('=== STAGE 1: Loading Soft Data ===\n');
        tic;

        % Load soft data with temporal padding
        % For temporal-only workflow, we still need soft data but don't need
        % dense spatial coverage (can use coarser grid or thinning if needed)
        analyzeParam.softData = getTOARSoftData(analyzeParam.BMEmethod, analyzeParam, ...
            'spatialBuffer', 2, ...         % ±2 degree buffer
            'temporalPadding', 1, ...       % ±1 year buffer
            'thinningFactor', 0, ...        % No thinning (can increase for speed)
            'forceReload', 0);

        fprintf('  Completed in %.1f seconds\n\n', toc);

        %% =============================================================================
        %     LOAD OBSERVATIONAL DATA AND PREPARE BME COMPONENTS
        % ==============================================================================

        fprintf('=== STAGE 2: Loading Observational Data ===\n');
        tic;

        % obs = getTOARobservationalData(analyzeParam);
        [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);

        fprintf('  Loaded %d stations with %d time points\n', ...
            size(obs.sMS, 1), length(obs.tME));
        fprintf('  Time range: %.2f - %.2f\n', min(obs.tME), max(obs.tME));
        fprintf('  Completed in %.1f seconds\n\n', toc);

        %% ====================================================================
        %                    SELECT REPRESENTATIVE SITES
        % ====================================================================

        fprintf('=== STAGE 3: Selecting Representative Sites ===\n');
        tic;

        repSitesFile = fullfile('6BMEtemporalSeries/', 'representative_sites.mat');

        if exist(repSitesFile, 'file') && ~analyzeParam.forceRepSites
            fprintf('  Loading existing representative sites...\n');
            load(repSitesFile, 'repSites');
        else
            fprintf('  Selecting one site per region...\n');
            repSites = selectRepresentativeSites(obs, analyzeParam.areaCode, ...
                'minCompleteness', analyzeParam.minCompleteness, ...
                'maxCompleteness', analyzeParam.maxCompleteness, ...
                'minObservations', analyzeParam.minObservations, ...
                'selectionMethod', analyzeParam.selectionMethod, ...
                'saveResults', true, ...
                'forYear', eachYear);
            save(repSitesFile, 'repSites');
        end

        regions = fieldnames(repSites);
        fprintf('  Selected %d representative sites:\n', length(regions));
        for i = 1:length(regions)
            site = repSites.(regions{i});
            fprintf('    %s: [%.2f, %.2f] (%d obs, %.1f%% complete)\n', ...
                regions{i}, site.lon, site.lat, site.nObs, site.completeness*100);
        end

        fprintf('  Completed in %.1f seconds\n\n', toc);

        %% ====================================================================
        %                    BME TEMPORAL ESTIMATION
        % ====================================================================

        if analyzeParam.runBME_t
            fprintf('=== STAGE 5: BME Temporal Estimation ===\n');
            tic;

            siteEstFile = fullfile('6BMEtemporalSeries/', ...
                sprintf('site_estimates_%s_year%d.mat', analyzeParam.BMEmethod, eachYear));

            if exist(siteEstFile, 'file') && ~analyzeParam.forceEstimation
                fprintf('  Loading existing site estimates...\n');
                load(siteEstFile, 'siteEstimates');
            else
                fprintf('  Running BME estimation at %d sites × %d times...\n', ...
                    length(regions), length(analyzeParam.tkVec));
                % fprintf('  (Leave-one-out with %.2f deg exclusion radius)\n\n', ...
                %     analyzeParam.exclusionRadius);
                % Add BMEmethod to BMEparam for plotting
                BMEparam.BMEmethod = analyzeParam.BMEmethod;

                siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, ...
                    KG, KS, BMEparam, analyzeParam.tkVec, ...
                    'exclusionRadius', analyzeParam.exclusionRadius, ...
                    'saveResults', false, ...
                    'verbose', true, ...
                    'performValidation', false); % if this is set true, radial validation is done indirectly.

                % Save with year-specific filename
                if ~exist('6BMEtemporalSeries/', 'dir')
                    mkdir('6BMEtemporalSeries/');
                end
                save(siteEstFile, 'siteEstimates', '-v7.3');
                fprintf('  Saved to: %s\n', siteEstFile);
            end

            elapsedTime = toc;
            fprintf('\n  BME estimation completed in %.1f minutes\n', elapsedTime/60);
            fprintf('  Average: %.1f seconds per site\n', elapsedTime/length(regions));
        else
            fprintf('=== STAGE 5: Skipping BME Estimation (runBME = 0) ===\n');
            error('BME estimation is required for temporal analysis');
        end

        %% ====================================================================
        %                    TEMPORAL SERIES PLOTTING
        % ====================================================================

        if analyzeParam.plotTemporal
            fprintf('\n=== STAGE 6: Generating Temporal Series Plots ===\n');
            tic;

            % Method-specific temporal output directory
            temporalFigDir = fullfile('6BMEtemporalSeries/', 'figs_temporal', ...
                sprintf('%s_go%d_areaCode%d_year%d_temporal_only', ...
                analyzeParam.BMEmethod, analyzeParam.goScenario, ...
                analyzeParam.areaCode, eachYear));

            fprintf('  Creating temporal series plots...\n');

            % For temporal-only workflow, we pass empty allBMEs
            % plotBME_TemporalSeries will use siteEstimates instead
            allBMEs = cell(length(analyzeParam.tkVec), 1);

            % Create minimal BMEs structure with just time info
            for iTime = 1:length(analyzeParam.tkVec)
                allBMEs{iTime} = struct('tk', analyzeParam.tkVec(iTime));
            end

            figPaths_temporal = plotBME_TemporalSeries(allBMEs, obs, repSites, analyzeParam, ...
                'figDir', temporalFigDir, ...              % Method-specific directory
                'siteEstimates', siteEstimates, ...        % Use exact site estimates
                'plotType', analyzeParam.plotType, ...     % full/simple/both
                'uncertaintyBands', analyzeParam.uncertaintyBands, ...
                'saveTable', analyzeParam.saveTable, ...
                'combineRegions', analyzeParam.combineRegions, ...
                'obsMatchRadius', analyzeParam.obsMatchRadius, ...
                'plotSoftData', analyzeParam.plotSoftData, ...
                'dpi', analyzeParam.figDPI, ...
                'visible', analyzeParam.figVisible);

            fprintf('  Generated %d temporal figures\n', length(figPaths_temporal));
            fprintf('  Saved to: %s\n', temporalFigDir);
            fprintf('  Completed in %.1f minutes\n', toc/60);
        end

        fprintf('\n');
        fprintf('************************************************************************\n');
        fprintf('   METHOD %s COMPLETE\n', analyzeParam.BMEmethod);
        fprintf('************************************************************************\n');
        close all;
    end % End of year loop

end  % End of method loop

%% ====================================================================
%                    SUMMARY
% ====================================================================

fprintf('\n');
fprintf('========================================================================\n');
fprintf('            TEMPORAL SERIES ANALYSIS COMPLETE                         \n');
fprintf('========================================================================\n');
fprintf('BME Methods processed: %s\n', strjoin(BMEmethods, ', '));
fprintf('Representative sites: %d\n', length(regions));
fprintf('Time periods estimated: %d per site\n', length(analyzeParam.tkVec));
fprintf('Estimation years: %d-%d\n', estYears(1), estYears(end));
fprintf('Observation range: %d-%d (±%d year padding)\n', ...
    analyzeParam.timeRange(1), analyzeParam.timeRange(2), temporalPadding);
fprintf('\nResults saved to:\n');
fprintf('  - Site estimates: ./6BMEtemporalSeries/site_estimates_*.mat\n');
if analyzeParam.plotTemporal
    fprintf('  - Temporal plots: ./6BMEtemporalSeries/figs_temporal/<method>/\n');
    fprintf('  - Statistics table: ./6BMEtemporalSeries/figs_temporal/<method>/temporal_statistics.csv\n');
    fprintf('  - Representative sites: ./6BMEtemporalSeries/representative_sites.mat\n');
end
fprintf('\nBENEFITS OF TEMPORAL-ONLY WORKFLOW:\n');
fprintf('  ✓ Much faster (no spatial grid estimation)\n');
fprintf('  ✓ Focused temporal validation at key sites\n');
fprintf('  ✓ Independent of spatial resolution choices\n');
fprintf('  ✓ Ideal for model comparison and temporal analysis\n');
fprintf('========================================================================\n');
