function [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam)
% analyzeTOAR - Complete TOAR ozone analysis workflow using BME
%
% Orchestrates the full BME analysis pipeline: data loading, exploration,
% global offset estimation, covariance modeling, and spatial BME estimation
%
% SYNTAX:
%   [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam)
%
% INPUT:
%   analyzeParam - Structure with analysis parameters:
%
%     DATA PARAMETERS:
%       .stationTypes     - Station types ('all' or {'urban','rural'})
%                           default: 'all'
%       .timeRange        - [startYear endYear]
%                           default: [2015 2020]
%       .logTransf        - Log transform (0=no, 1=yes)
%                           default: 0
%
%     ANALYSIS LEVEL:
%       .runExplore       - Run exploratory analysis (0/1)
%                           default: 1
%       .runGO            - Estimate global offset (0/1)
%                           default: 1
%       .runCov           - Estimate covariance (0/1)
%                           default: 1
%       .runBME           - Run BME estimation (0/1)
%                           default: 1
%
%     GLOBAL OFFSET:
%       .goScenario       - GO scenario (0-11, see getTOARglobalOffset)
%                           default: 3
%       .forceGO          - Force GO re-estimation (0/1)
%                           default: 0
%       .goPlot           - GO plot level (0-3)
%                           default: 1
%
%     COVARIANCE:
%       .temporalModel    - 'holecos' or 'exponential'
%                           default: 'holecos'
%       .forceCov         - Force covariance re-estimation (0/1)
%                           default: 0
%
%     BME METHOD:
%       .BMEmethod        - 8-digit BME method code
%                           default: '10000132'
%       .softData         - Soft data structure (CTM/satellite)
%                           default: []
%
%     ESTIMATION:
%       .areaCode         - Area code (0-10, see getTOARareaBoundaries)
%                           default: 5 (Continental US)
%       .mapResolution    - Grid resolution in degrees
%                           default: 1.0
%       .tkVec            - Times to estimate (decimal years)
%                           default: 2016:1/12:2017 (monthly 2016)
%       .forceEstimation  - Force BME re-estimation (0/1)
%                           default: 0
%       .plotResults      - Plot level (0-4)
%                           default: 2
%
% OUTPUT:
%   obs      - Observational data structure
%   go       - Global offset structure
%   cov      - Covariance structure
%   KG       - General Knowledge base
%   KS       - Site-specific Knowledge base
%   BMEparam - BME parameters
%
% EXAMPLE:
%   % Basic analysis with defaults
%   param = struct();
%   [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(param);
%
%   % Custom analysis
%   param.stationTypes = {'urban'};
%   param.timeRange = [2015 2018];
%   param.goScenario = 6;
%   param.areaCode = 2;  % Europe
%   param.mapResolution = 0.5;
%   param.tkVec = 2016 + (0:11)/12;  % Monthly 2016
%   [obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(param);

%% Set Default Parameters
if nargin < 1, analyzeParam = struct(); end

% Data parameters
if ~isfield(analyzeParam, 'stationTypes'), analyzeParam.stationTypes = 'all'; end
if ~isfield(analyzeParam, 'timeRange'), analyzeParam.timeRange = [2015 2020]; end
if ~isfield(analyzeParam, 'logTransf'), analyzeParam.logTransf = 0; end

% Analysis level
if ~isfield(analyzeParam, 'runExplore'), analyzeParam.runExplore = 1; end
if ~isfield(analyzeParam, 'runGO'), analyzeParam.runGO = 1; end
if ~isfield(analyzeParam, 'runCov'), analyzeParam.runCov = 1; end
if ~isfield(analyzeParam, 'runBME'), analyzeParam.runBME = 1; end

% Global offset
if ~isfield(analyzeParam, 'goScenario'), analyzeParam.goScenario = 3; end
if ~isfield(analyzeParam, 'forceGO'), analyzeParam.forceGO = 0; end
if ~isfield(analyzeParam, 'goPlot'), analyzeParam.goPlot = 1; end

% Covariance
if ~isfield(analyzeParam, 'temporalModel'), analyzeParam.temporalModel = 'holecos'; end
if ~isfield(analyzeParam, 'forceCov'), analyzeParam.forceCov = 0; end

% BME method
if ~isfield(analyzeParam, 'BMEmethod'), analyzeParam.BMEmethod = '10000132'; end
if ~isfield(analyzeParam, 'softData'), analyzeParam.softData = []; end

% Estimation
if ~isfield(analyzeParam, 'areaCode'), analyzeParam.areaCode = 5; end
if ~isfield(analyzeParam, 'mapResolution'), analyzeParam.mapResolution = 1.0; end
if ~isfield(analyzeParam, 'tkVec'), analyzeParam.tkVec = 2016:1/12:2017; end
if ~isfield(analyzeParam, 'forceEstimation'), analyzeParam.forceEstimation = 0; end
if ~isfield(analyzeParam, 'plotResults'), analyzeParam.plotResults = 2; end

%% Print Configuration
fprintf('\n');
fprintf('====================================================\n');
fprintf('         TOAR OZONE BME ANALYSIS WORKFLOW          \n');
fprintf('====================================================\n\n');

fprintf('CONFIGURATION:\n');
fprintf('  Data:\n');
fprintf('    Station types: %s\n', analyzeParam.stationTypes);
fprintf('    Time range: %d - %d\n', analyzeParam.timeRange(1), analyzeParam.timeRange(2));
fprintf('    Log transform: %d\n', analyzeParam.logTransf);
fprintf('  Analysis:\n');
fprintf('    Explore: %d, GO: %d, Cov: %d, BME: %d\n', ...
    analyzeParam.runExplore, analyzeParam.runGO, analyzeParam.runCov, analyzeParam.runBME);
fprintf('  Global Offset:\n');
fprintf('    Scenario: %d\n', analyzeParam.goScenario);
fprintf('  BME:\n');
fprintf('    Method: %s\n', analyzeParam.BMEmethod);
fprintf('    Area: %d, Resolution: %.2f°\n', analyzeParam.areaCode, analyzeParam.mapResolution);
fprintf('    Time periods: %d\n', length(analyzeParam.tkVec));
fprintf('\n');

%% Step 1: Load Observational Data
fprintf('====================================================\n');
fprintf('STEP 1: Loading Observational Data\n');
fprintf('====================================================\n');

obs = getTOARobservationalData(analyzeParam.stationTypes, ...
    analyzeParam.timeRange, analyzeParam.logTransf);

fprintf('  Loaded %d stations, %d time periods\n', size(obs.Z, 1), size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

%% Step 2: Exploratory Data Analysis
if analyzeParam.runExplore
    fprintf('\n====================================================\n');
    fprintf('STEP 2: Exploratory Data Analysis\n');
    fprintf('====================================================\n');
    
    exploreTOARdata(obs, 8, analyzeParam.areaCode);
end

%% Step 3: Global Offset Estimation
if analyzeParam.runGO
    fprintf('\n====================================================\n');
    fprintf('STEP 3: Global Offset Estimation\n');
    fprintf('====================================================\n');
    
    go = getTOARglobalOffset(obs, analyzeParam.goScenario, ...
        analyzeParam.goPlot, analyzeParam.forceGO, 0);
    
    % Calculate variance reduction with dimension check
    Ygo = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
    
    if isequal(size(Ygo), size(obs.Y))
        residuals = obs.Y - Ygo;
        varReduction = 100*(1 - var(residuals(:), 'omitnan') / var(obs.Y(:), 'omitnan'));
        fprintf('  GO variance reduction: %.1f%%\n', varReduction);
    else
        warning('GO dimensions [%dx%d] do not match obs.Y [%dx%d]. Skipping variance calculation.', ...
            size(Ygo, 1), size(Ygo, 2), size(obs.Y, 1), size(obs.Y, 2));
        fprintf('  Tip: Set forceGO=1 to regenerate GO with current data\n');
    end
else
    go = [];
end

%% Step 4: Covariance Estimation
if analyzeParam.runCov && analyzeParam.runGO
    fprintf('\n====================================================\n');
    fprintf('STEP 4: Covariance Estimation\n');
    fprintf('====================================================\n');
    
    cov = getTOARautoCov(obs, go, analyzeParam.temporalModel, analyzeParam.forceCov);
    
    fprintf('  Variance: %.2f\n', cov.var);
    fprintf('  Space-time metric: %.2f\n', cov.stmetric);
else
    cov = [];
end

%% Step 5: Knowledge Base Preparation
if analyzeParam.runBME && analyzeParam.runGO && analyzeParam.runCov
    fprintf('\n====================================================\n');
    fprintf('STEP 5: Preparing BME Knowledge Bases\n');
    fprintf('====================================================\n');
    
    [KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, ...
        analyzeParam.softData, analyzeParam.BMEmethod);
    
    fprintf('  Hard data points: %d\n', length(KS.harddata.z));
    if ~isempty(KS.softdata.z)
        fprintf('  Soft data points: %d\n', length(KS.softdata.z));
    end
else
    KG = [];
    KS = [];
    BMEparam = [];
end

%% Step 6: BME Spatial Estimation
if analyzeParam.runBME && ~isempty(KG)
    fprintf('\n====================================================\n');
    fprintf('STEP 6: BME Spatial Estimation\n');
    fprintf('====================================================\n');
    
    % Package estimation parameters
    estParam.areaCode = analyzeParam.areaCode;
    estParam.mapResolution = analyzeParam.mapResolution;
    estParam.tkVec = analyzeParam.tkVec;
    estParam.forceEstimation = analyzeParam.forceEstimation;
    estParam.plotResults = analyzeParam.plotResults;
    
    % Add BMEmethod to BMEparam for plotting
    BMEparam.BMEmethod8digits = analyzeParam.BMEmethod;
    
    % Run BME estimation
    estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam);
end

%% Summary
fprintf('\n====================================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('====================================================\n\n');

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

end