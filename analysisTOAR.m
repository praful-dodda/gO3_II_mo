%% runTOARanalysis.m
% Script to run TOAR ozone BME analysis
% Modify parameters in each section, then run the script
%
% Quick start: Just run as-is for default Continental US analysis
% Advanced: Uncomment different scenarios below or modify parameters

clear; close all;

analysisScenario = 4;
% 4 for cross-validation
% 5 for BMEs-estimation

%% ====================================================================
%                    DATA CONFIGURATION
% ====================================================================

% Station types to include
analyzeParam.stationTypes = 'all';  % 'all', 'urban', 'rural', or {'urban','rural'}

% Time range for analysis
analyzeParam.timeRange = [2015 2020];  % [startYear endYear]

% Log transformation
analyzeParam.logTransf = 0;  % 0=no, 1=yes (use 0 for regular concentrations)

%%  ====================================================================
%                    RUN SELECTED SCENARIO
% ====================================================================

% Scenario selection
switch analysisScenario
    case 1
        % Runs estimation for a specified region via analysisTOAR.m
        %% ====================================================================
        %                    ANALYSIS WORKFLOW CONTROL
        % ====================================================================

        % Control which analysis steps to run (1=run, 0=skip)
        analyzeParam.runExplore = 0;    % Exploratory data analysis
        analyzeParam.runGO = 1;         % Global offset estimation
        analyzeParam.runCov = 1;        % Covariance modeling
        analyzeParam.runBME = 1;        % BME spatial estimation

        %% ====================================================================
        %                    GLOBAL OFFSET CONFIGURATION
        % ====================================================================

        % Global offset scenario (controls spatial/temporal smoothing)
        %   0 = Zero (no offset)
        %   1 = Flat (constant mean)
        %   2 = Domain-wide S/T smoothing
        %   3 = Regional S/T smoothing (RECOMMENDED)
        %   6 = Local S/T smoothing
        %   7 = Spatial LUR + regional temporal
        %  10 = Spatial LUR + local temporal
        analyzeParam.goScenario = 3;

        % Force re-estimation (useful if parameters changed)
        analyzeParam.forceGO = 0;  % 0=use cached, 1=force new estimation

        % Plotting level for global offset
        %   0 = No plots
        %   1 = Basic plots (spatial/temporal patterns)
        %   2 = Detailed plots
        %   3 = Full diagnostic plots
        analyzeParam.goPlot = 1;

        %% ====================================================================
        %                    COVARIANCE CONFIGURATION
        % ====================================================================

        % Temporal covariance model
        analyzeParam.temporalModel = 'holecos';  % 'holecos' or 'exponential'

        % Force re-estimation
        analyzeParam.forceCov = 0;  % 0=use cached, 1=force new estimation

        %% ====================================================================
        %                    BME METHOD CONFIGURATION
        % ====================================================================

        % 8-digit BME method code: [obsType][CTMtype][RAMP][RAMP][RAMP][nsmax][nhmax][BMEtype]
        %
        % Digit 1 (obsType): 0=none, 1=hard only, 2=hard+soft obs
        % Digit 2 (CTMtype): 0=none, 1=CTM model data
        % Digits 3-5 (RAMP): Correction parameters (0=none)
        % Digit 6 (nsmax): 0=0, 1=3, 2=4, 3=5, 4=50, 5=100, 6=200 soft data neighbors
        % Digit 7 (nhmax): 1=50, 2=100, 3=200 hard data neighbors
        % Digit 8 (BMEtype): 1=BMEprobaMoments, 2=krigingME
        %
        % Common configurations:
        %   '10000132' = Hard data only, nhmax=100, nsmax=4, krigingME (DEFAULT)
        %   '10000232' = Hard data only, nhmax=100, nsmax=50, krigingME (more neighbors)
        %   '10000122' = Hard data only, nhmax=50, nsmax=4, krigingME (fewer neighbors)
        analyzeParam.BMEmethod = '10000132';

        % Data format for kriging computation
        % 'stv'  = Space-Time Vector (default, works with any grid, slower)
        % 'stg'  = Space-Time Grid (faster for regular grids, RECOMMENDED)
        % 'stug' = Space-Time Unstructured Grid (fastest for large uniform grids)
        % Note: Use analyzeGridUniformity.m to check if your grid supports 'stug'
        analyzeParam.dataFormat = 'stg';  % Default: space-time grid

        % Soft data structure (leave empty if not using CTM/satellite data)
        analyzeParam.softData = [];

        % Example soft data setup (uncomment to use):
        % analyzeParam.BMEmethod = '11000132';  % Enable CTM data
        % analyzeParam.softData.ctm.sMS = ctm_coords;  % [nPoints x 2] lon/lat
        % analyzeParam.softData.ctm.tME = ctm_times;   % [1 x nTimes] decimal years
        % analyzeParam.softData.ctm.Z = ctm_values;    % [nPoints x nTimes] predictions
        % analyzeParam.softData.ctm.Zv = ctm_variance; % [nPoints x nTimes] variance

        %% ====================================================================
        %                    ESTIMATION CONFIGURATION
        % ====================================================================

        % Geographic area for estimation
        %   0  = Global (use with caution)
        %   1  = North America
        %   2  = Europe
        %   3  = East Asia
        %   4  = South Asia
        %   5  = Continental US (RECOMMENDED)
        %   6  = Western Europe
        %   7  = Eastern US
        %   8  = California
        %   9  = Northeast US corridor
        %  10  = User defined (modify getTOARareaBoundaries.m)
        analyzeParam.areaCode = 0;

        % Grid resolution in degrees
        %   0.25 = Very fine (slow, large files)
        %   0.5  = Fine (recommended for regional)
        %   1.0  = Coarse (fast, good for continental) (RECOMMENDED)
        %   2.0  = Very coarse (very fast, rough patterns)
        analyzeParam.mapResolution = 1.0;

        % Times to estimate (decimal years)
        % Examples:
        analyzeParam.tkVec = 2016:1/12:2017;        % Monthly for 2016
        % analyzeParam.tkVec = 2017:1/12:2018;        % Monthly for 2017
        % analyzeParam.tkVec = [2016 2017 2018];    % Annual 2016-2018
        % analyzeParam.tkVec = 2016.0:0.25:2017.0;  % Quarterly 2016
        % analyzeParam.tkVec = 2016 + [0 90 180 270]/365;  % Seasonal 2016

        % Force re-estimation
        analyzeParam.forceEstimation = 0;  % 0=use cached, 1=force new estimation

         % Include only land points in grid
        analyzeParam.keepOnlyLand = true;  % true/false

        % Include Antarctica in grid
        analyzeParam.includeAntarctica = false;  % true/false

        % Plotting level for BME Mean results
        %   0 = No plots
        %   1 = BME estimates only
        %   2 = BME estimates + observations (RECOMMENDED)
        %   3 = Residuals (offset-removed)
        %   4 = Uncertainty maps
        analyzeParam.plotResults = 1;

        % Plotting level for BME Variance results
        %   0 = No plots
        %   1 = standard deviation map
        %   2 = variance map
        %   3 = coefficient of variation map
        %   4 = Multi-panel with all three - std, var, and CV
        analyzeParam.plotVariance = 1;

       

        %% ====================================================================
        %                    PRE-CONFIGURED SCENARIOS
        % ====================================================================
        % Uncomment one of these sections to use a pre-configured scenario

        % % SCENARIO 1: Quick test (1 month, coarse resolution)
        % analyzeParam.timeRange = [2016 2016];
        % analyzeParam.areaCode = 7;  % Eastern US
        % analyzeParam.mapResolution = 2.0;
        % analyzeParam.tkVec = 2016.5;  % July 2016
        % analyzeParam.forceGO = 0;
        % analyzeParam.forceCov = 0;
        % analyzeParam.forceEstimation = 1;
        % analyzeParam.plotResults = 2;

        % % SCENARIO 2: High-resolution California
        % analyzeParam.timeRange = [2015 2020];
        % analyzeParam.areaCode = 8;  % California
        % analyzeParam.mapResolution = 0.5;
        % analyzeParam.tkVec = 2016:1/12:2017;  % Monthly 2016
        % analyzeParam.goScenario = 6;  % Local GO
        % analyzeParam.BMEmethod = '10000232';  % More neighbors
        % analyzeParam.plotResults = 2;

        % % SCENARIO 3: European analysis
        % analyzeParam.timeRange = [2015 2018];
        % analyzeParam.areaCode = 2;  % Europe
        % analyzeParam.mapResolution = 0.5;
        % analyzeParam.tkVec = [2015 2016 2017 2018];  % Annual
        % analyzeParam.goScenario = 3;
        % analyzeParam.plotResults = 2;

        % % SCENARIO 4: Compare GO scenarios (no BME, just diagnostics)
        % analyzeParam.runBME = 0;  % Skip BME
        % analyzeParam.goScenario = 3;
        % analyzeParam.goPlot = 2;  % Detailed GO plots
        % analyzeParam.plotResults = 0;

        % % SCENARIO 5: Full Continental US annual climatology
        % analyzeParam.timeRange = [2015 2020];
        % analyzeParam.areaCode = 5;
        % analyzeParam.mapResolution = 1.0;
        % analyzeParam.tkVec = 2015:2020;  % Annual averages
        % analyzeParam.goScenario = 3;
        % analyzeParam.BMEmethod = '10000232';
        % analyzeParam.forceEstimation = 1;
        % analyzeParam.plotResults = 2;

        %% ====================================================================
        %                    DISPLAY CONFIGURATION SUMMARY
        % ====================================================================

        fprintf('\n');
        fprintf('========================================================\n');
        fprintf('         TOAR ANALYSIS CONFIGURATION SUMMARY           \n');
        fprintf('========================================================\n\n');

        fprintf('DATA:\n');
        fprintf('  Station types: %s\n', string(analyzeParam.stationTypes));
        fprintf('  Time range: %d - %d\n', analyzeParam.timeRange(1), analyzeParam.timeRange(2));
        fprintf('  Log transform: %d\n\n', analyzeParam.logTransf);

        fprintf('WORKFLOW:\n');
        fprintf('  Explore: %d, GO: %d, Cov: %d, BME: %d\n\n', ...
            analyzeParam.runExplore, analyzeParam.runGO, analyzeParam.runCov, analyzeParam.runBME);

        fprintf('GLOBAL OFFSET:\n');
        fprintf('  Scenario: %d, Force: %d, Plot: %d\n\n', ...
            analyzeParam.goScenario, analyzeParam.forceGO, analyzeParam.goPlot);

        fprintf('COVARIANCE:\n');
        fprintf('  Model: %s, Force: %d\n\n', analyzeParam.temporalModel, analyzeParam.forceCov);

        fprintf('BME:\n');
        fprintf('  Method: %s\n', analyzeParam.BMEmethod);
        fprintf('  Data format: %s\n', analyzeParam.dataFormat);
        fprintf('  Area: %d, Resolution: %.2f°\n', analyzeParam.areaCode, analyzeParam.mapResolution);
        fprintf('  Time periods: %d\n', length(analyzeParam.tkVec));
        fprintf('  Force: %d, Plot: %d\n\n', analyzeParam.forceEstimation, analyzeParam.plotResults);

        fprintf('========================================================\n\n');

        %% ====================================================================
        %                    CONFIRM BEFORE RUNNING
        % ====================================================================

        % Uncomment this section to require user confirmation before running
        % response = input('Proceed with analysis? (y/n): ', 's');
        % if ~strcmpi(response, 'y')
        %     fprintf('Analysis cancelled.\n');
        %     return;
        % end

        %% ====================================================================
        %                    RUN ANALYSIS
        % ====================================================================

        fprintf('Starting analysis...\n\n');
        tic;

        % Run the analysis
        [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);

        elapsedTime = toc;

        %% ====================================================================
        %                    COMPLETION SUMMARY
        % ====================================================================

        fprintf('\n');
        fprintf('========================================================\n');
        fprintf('         ANALYSIS COMPLETED SUCCESSFULLY!               \n');
        fprintf('========================================================\n\n');

        fprintf('Total time: %.1f minutes\n', elapsedTime/60);
        fprintf('Results saved in:\n');
        if analyzeParam.runGO
            fprintf('  - Global Offset: ./2globalOffset/\n');
        end
        if analyzeParam.runCov
            fprintf('  - Covariance: ./3covariance/\n');
        end
        if analyzeParam.runBME
            fprintf('  - BME Maps: ./5BMEspatialPlots/\n');
            fprintf('  - Figures: ./5BMEspatialPlots/figs/\n');
        end

        fprintf('\n');

        %% ====================================================================
        %                    OPTIONAL: POST-PROCESSING
        % ====================================================================

        % % Uncomment to save workspace
        % save('TOAR_analysis_workspace.mat', 'obs', 'go', 'cov', 'KG', 'KS', 'BMEparam', 'analyzeParam');
        % fprintf('Workspace saved to: TOAR_analysis_workspace.mat\n');

        % % Uncomment to create summary statistics
        % if analyzeParam.runBME
        %     fprintf('\nGenerating summary statistics...\n');
        %     createTOARsummaryStats(analyzeParam);
        % end

    case 4
        % Performs validation via analyzeTOAR_val.m
        % set parameters
        valParam = [];
        valParam.stationTypes = 'all';  % 'all', 'urban', 'rural', or {'urban','rural'}
        valParam.timeRange = [2015 2020];  % [startYear endYear]
        valParam.logTransf = 0;  % 0=no, 1=yes
        valParam.goScenario = 0;
        valParam.temporalModel = 'holecos';
        valParam.BMEmethod = '10000133';
        valParam.areaCode = 5;
        valParam.mapResolution = 1.0;
        valParam.tkVec = 2016:1/12:2017;  % Monthly 2016
        
        valParam.valYears = 2016:2017;  % years to validate (only for LOOCV)
        valParam.valMonths = 1:12;  % months to validate (only for LOOCV)

        % ------------ Specific to LOOCV ------------------ %
        % Note: LOOCV now uses monthly approach to avoid memory issues

        % valParam.method = 'loocv'; % 'loocv' = monthly LOOCV (recommended), 'rcv' or 'kfold'
        % valParam.nFolds = 5;  % only used if method='kfold'

        % ------------ Specific to CBV ------------------- %
        valParam.method = 'cbv'; % 'cbv' = checker-board validation
        valParam.boxSizes = 5; % valid for [5, 10, 15]
        
        % plot settings
        valParam.goPlot = 0;
        valParam.covPlot = 0;

        % Validation plot settings
        valParam.plotResults = 1;

        % force re-calculation of each step
        valParam.forceGO = 0;
        valParam.forceCov = 0;
        valParam.forceEstimation = 0; % this can't be 0 for validation

        % run validation
        run_TOARvalidation(valParam);

    case 5
        % BME Kriging Estimation with Soft Data (RAMP-corrected CTM)
        % This case demonstrates data fusion using hard observations + CTM soft data

        fprintf('\n');
        fprintf('========================================================\n');
        fprintf('  BME KRIGING WITH SOFT DATA (METHOD 11000132)\n');
        fprintf('========================================================\n\n');

        %% ====================================================================
        %                    SOFT DATA LOADING
        % ====================================================================

        fprintf('STEP 1: Loading RAMP-corrected soft data...\n');
        fprintf('--------------------------------------------\n');

        % Soft datasets configuration
        modelNames = {'M3fusion', 'MERRA2-GMI'};  % List of CTM models to load
        modelYears = {2016:2017, 2016:2017};  % Corresponding years for each model
        % softDataDir = fullfile('1data', 'CTM', 'ramp_data');  % Parquet directory
        softDataDir = fullfile('d:\Users\praful\Documents\Data\ramp_data\');  % Parquet directory
        softDataForceReload = {0, 0};  % Use cache if available
        joinMethod = 'concat';

        % Initialize cell-array to hold multiple soft datasets as per the size of modelNames
        softDatasets = cell(length(modelNames), 1);
        
        for m = 1:length(modelNames)
            

            modelName = modelNames{m};
            fprintf('\nLoading soft data for model: %s\n', modelName);
            softDataConfig = struct();
            softDataConfig.modelName = modelName;
            softDataConfig.years = modelYears{m};
            softDataConfig.dataDir = softDataDir;
            softDataConfig.forceReload = softDataForceReload{m};

            try 
                softDataModel = loadRAMPdata(softDataConfig.modelName, ...
                                            softDataConfig.years, ...
                                            softDataConfig.dataDir, ...
                                            softDataConfig.forceReload);

                % Mark as CTM data for getTOARknowledgeBase
                softDataModel.ctm = 1;

                fprintf('✓ Soft data loaded successfully\n');
                fprintf('    Grid points: %d\n', size(softDataModel.sMS, 1));
                fprintf('    Time periods: %d months\n', length(softDataModel.tME));
                fprintf('    Coverage: %.4f - %.4f\n', min(softDataModel.tME), max(softDataModel.tME));

                % Store in array
                softDatasets{m} = softDataModel;
            catch ME
                warning('Could not load soft data for model %s: %s', modelName, ME.message);
            end  
        end

        % % Fuse multiple soft datasets if more than one model is loaded
        % if length(softDatasets) > 1
        %     fprintf('\nFusing multiple soft datasets using method: %s\n', joinMethod);
        %     try
        %         softData = fuseSoftData(softDatasets, joinMethod);
        %         fprintf('✓ Soft data fused successfully\n');
        %         fprintf('    Total grid points: %d\n', size(softData.sMS, 1));
        %         fprintf('    Total time periods: %d months\n', length(softData.tME));
        %         fprintf('    Coverage: %.4f - %.4f\n', min(softData.tME), max(softData.tME));
        %     catch ME
        %         warning(ME.identifier, '%s', ME.message);
        %         fprintf('Proceeding without soft data (hard data only)\n');
        %         softData = [];
        %     end
        % else
        %     softData = softDatasets{1};
        % end
        softData = softDatasets;

        % softDataConfig = struct();
        % softDataConfig.modelName = 'M3fusion';  % Model to use for soft data - MERRA2-GMI
        % softDataConfig.years = 2016:2017;      % Years to load
        % softDataConfig.dataDir = fullfile('1data', 'CTM', 'ramp_data');  % Parquet directory
        % softDataConfig.forceReload = 0;        % Use cache if available

        % % Load RAMP data
        % fprintf('  Model: %s\n', softDataConfig.modelName);
        % fprintf('  Years: %s\n', mat2str(softDataConfig.years));
        % fprintf('  Directory: %s\n', softDataConfig.dataDir);

        % if ~exist(softDataConfig.dataDir, 'dir')
        %     error('Soft data directory not found: %s\nPlease ensure parquet files are in this directory.', softDataConfig.dataDir);
        % end

        % try
        %     softData = loadRAMPdata(softDataConfig.modelName, ...
        %                            softDataConfig.years, ...
        %                            softDataConfig.dataDir, ...
        %                            softDataConfig.forceReload);

        %     % Mark as CTM data for getTOARknowledgeBase
        %     softData.ctm = 1;

        %     fprintf('✓ Soft data loaded successfully\n');
        %     fprintf('    Grid points: %d\n', size(softData.sMS, 1));
        %     fprintf('    Time periods: %d months\n', length(softData.tME));
        %     fprintf('    Coverage: %.4f - %.4f\n', min(softData.tME), max(softData.tME));
        % catch ME
        %     % warning('Could not load soft data: %s', ME.message);
        %     fprintf('Proceeding without soft data (hard data only)\n');
        %     softData = [];
        % end

        %% ====================================================================
        %                    SOFT DATA OPTIMIZATION
        % ====================================================================

        % Define estimation area code and time vector (always define these)
        estimationAreaCode = 0;              % Continental US
        estimationTkVec = 2016:1/12:2017;    % Monthly 2016

        if ~isempty(softData)
            fprintf('\n');
            fprintf('STEP 2: Optimizing soft data for estimation...\n');
            fprintf('--------------------------------------------\n');

            % Configure subsetting options
            subsetOptions = struct();
            subsetOptions.spatialBounds = getTOARareaBoundaries(estimationAreaCode, []) ;  % Use area code

            % Temporal bounds: estimation period ± 6 months buffer
            temporalBuffer = 0.5;  % 6 months
            subsetOptions.temporalBounds = [min(estimationTkVec) - temporalBuffer, ...
                                            max(estimationTkVec) + temporalBuffer];

            % Spatial thinning: match or slightly finer than estimation resolution
            % For 1° estimation grid, use thinning factor 2-4
            subsetOptions.thinningFactor = 0;  % Keep every 2nd point
            subsetOptions.minVariance = 0;
            subsetOptions.verbose = 1;

            % Apply subsetting
            try
                if iscell(softData)
                    for m = 1:length(softData)
                        fprintf('\nSubsetting soft data model: %s\n', softData{m}.modelName);
                        softData{m} = subsetSoftData(softData{m}, subsetOptions);
                        % Mark as CTM data again after subsetting
                        softData{m}.ctm = 1;
                    end
                else
                    fprintf('\nSubsetting soft data...\n');
                    softData = subsetSoftData(softData, subsetOptions);
                    % Mark as CTM data again after subsetting
                    softData.ctm = 1;
                end
            catch ME
                warning('Soft data subsetting failed. Using full dataset.');
            end
        end

        %% ====================================================================
        %                    BME ANALYSIS CONFIGURATION
        % ====================================================================

        fprintf('\n');
        fprintf('STEP 3: Configuring BME analysis...\n');
        fprintf('--------------------------------------------\n');

        % Initialize analysis parameters (same structure as case 1)
        analyzeParam = struct();

        % Data configuration
        analyzeParam.stationTypes = 'all';
        analyzeParam.timeRange = [2015 2020];
        analyzeParam.logTransf = 0;

        % Workflow control
        analyzeParam.runExplore = 0;
        analyzeParam.runGO = 1;
        analyzeParam.runCov = 1;
        analyzeParam.runBME = 1;

        % Global offset
        analyzeParam.goScenario = 3;      % Regional S/T smoothing (recommended)
        analyzeParam.forceGO = 0;
        analyzeParam.goPlot = 0;

        % Covariance
        analyzeParam.temporalModel = 'holecos';
        analyzeParam.forceCov = 0;

        % BME method with soft data
        BMEmethod_init = '13000113';  % Digit 2 = 1 enables soft data
        [obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype] = parseBMEcode(BMEmethod_init);
        analyzeParam.BMEmethod = generateBMEcode(obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, modelNames);
        
        analyzeParam.dataFormat = 'stug';     % Use optimized STUG for uniform grids
        analyzeParam.softData = softData;     % Pass soft data structure

        % Estimation configuration (use same as subsetting for consistency)
        analyzeParam.areaCode = estimationAreaCode;     % Continental US
        analyzeParam.mapResolution = 1.0;               % 1 degree resolution
        analyzeParam.tkVec = estimationTkVec;           % Monthly 2016

        % Force and plotting
        analyzeParam.forceEstimation = 0;
        analyzeParam.keepOnlyLand = true;
        analyzeParam.includeAntarctica = false;
        analyzeParam.plotResults = 1;         % 2 for Estimates + observations
        analyzeParam.plotVariance = 1;        % Standard deviation map

        %% ====================================================================
        %                    DISPLAY CONFIGURATION SUMMARY
        % ====================================================================

        fprintf('\n');
        fprintf('========================================================\n');
        fprintf('         CONFIGURATION SUMMARY (WITH SOFT DATA)         \n');
        fprintf('========================================================\n\n');

        fprintf('DATA:\n');
        fprintf('  Station types: %s\n', string(analyzeParam.stationTypes));
        fprintf('  Time range: %d - %d\n', analyzeParam.timeRange(1), analyzeParam.timeRange(2));
        fprintf('  Log transform: %d\n\n', analyzeParam.logTransf);

        fprintf('SOFT DATA:\n');
        if ~isempty(softData) && ~iscell(softData)
            fprintf('  Model: %s\n', softData.modelName);
            fprintf('  Grid points: %d\n', size(softData.sMS, 1));
            fprintf('  Time coverage: %d months\n', length(softData.tME));
            fprintf('  Years: %s\n\n', mat2str(softData.years));
        elseif ~isempty(softData) && iscell(softData)
            for m = 1:length(softData)
                fprintf('  Model: %s\n', softData{m}.modelName);
                fprintf('  Grid points: %d\n', size(softData{m}.sMS, 1));
                fprintf('  Time coverage: %d months\n', length(softData{m}.tME));
                fprintf('  Years: %s\n\n', mat2str(softData{m}.years));
            end
        else
            fprintf('  None (hard data only)\n\n');
        end

        fprintf('WORKFLOW:\n');
        fprintf('  Explore: %d, GO: %d, Cov: %d, BME: %d\n\n', ...
            analyzeParam.runExplore, analyzeParam.runGO, analyzeParam.runCov, analyzeParam.runBME);

        fprintf('GLOBAL OFFSET:\n');
        fprintf('  Scenario: %d, Force: %d, Plot: %d\n\n', ...
            analyzeParam.goScenario, analyzeParam.forceGO, analyzeParam.goPlot);

        fprintf('COVARIANCE:\n');
        fprintf('  Model: %s, Force: %d\n\n', analyzeParam.temporalModel, analyzeParam.forceCov);

        fprintf('BME:\n');
        fprintf('  Method: %s (WITH SOFT DATA)\n', analyzeParam.BMEmethod);
        fprintf('  Data format: %s\n', analyzeParam.dataFormat);
        fprintf('  Area: %d, Resolution: %.2f°\n', analyzeParam.areaCode, analyzeParam.mapResolution);
        fprintf('  Time periods: %d\n', length(analyzeParam.tkVec));
        fprintf('  Force: %d, Plot: %d\n', analyzeParam.forceEstimation, analyzeParam.plotResults);
        fprintf('  NOTE: Search radius optimized to 20° spatial, 0.5 yr temporal\n\n');

        fprintf('========================================================\n\n');

        %% ====================================================================
        %                    RUN ANALYSIS
        % ====================================================================

        fprintf('STEP 4: Running BME analysis with soft data...\n');
        fprintf('--------------------------------------------\n\n');

        tic;

        % Run the analysis
        [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);

        elapsedTime = toc;

        %% ====================================================================
        %                    COMPLETION SUMMARY
        % ====================================================================

        fprintf('\n');
        fprintf('========================================================\n');
        fprintf('   SOFT DATA FUSION COMPLETED SUCCESSFULLY!             \n');
        fprintf('========================================================\n\n');

        fprintf('Total time: %.1f minutes\n', elapsedTime/60);

        % Display soft data statistics
        if ~isempty(softData) && ~iscell(softData)
            fprintf('\nData Fusion Summary:\n');
            fprintf('  Hard data points: %d\n', length(KS.harddata.z));
            fprintf('  Soft data points: %d\n', length(KS.softdata.z));
            fprintf('  Ratio (soft:hard): %.1f:1\n', length(KS.softdata.z)/length(KS.harddata.z));
        elseif ~isempty(softData) && iscell(softData)
            intotal = 0;
            for m = 1:length(softData)
                intotal = intotal + length(KS.softdata{m}.z);
            end
            fprintf('\nData Fusion Summary (multiple soft data models):\n');
            fprintf('  Hard data points: %d\n', length(KS.harddata.z));
            fprintf('  Soft data points (total): %d\n', intotal);
            fprintf('  Ratio (soft:hard): %.1f:1\n', intotal/length(KS.harddata.z));
        end

        fprintf('\nResults saved in:\n');
        if analyzeParam.runGO
            fprintf('  - Global Offset: ./2globalOffset/\n');
        end
        if analyzeParam.runCov
            fprintf('  - Covariance: ./3covariance/\n');
        end
        if analyzeParam.runBME
            fprintf('  - BME Maps: ./5BMEspatialPlots/\n');
            fprintf('  - Figures: ./5BMEspatialPlots/figs/\n');
        end
end


