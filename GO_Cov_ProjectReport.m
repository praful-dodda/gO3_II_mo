%% Global Offset and Covariance Model Presentation
% Comprehensive visual report of Global Offset and Covariance models
% for TOAR ozone data analysis - PROJECT HOLDER VERSION
%
% This script:
% 1. Finds all existing GO and Cov .mat files
% 2. Generates publication-quality plots for presentation
% 3. Creates parameter comparison tables
% 4. Provides executive summary
%
% USAGE:
%   Run this script directly in MATLAB:
%   >> GO_Cov_ProjectReport
%
%   Or convert to .mlx for Live Script:
%   >> matlab.internal.liveeditor.openAndConvert('GO_Cov_ProjectReport.m', 'GO_Cov_ProjectReport.mlx')
%
% OUTPUTS:
%   - All figures in ./2globalOffset/figs and ./3covariance/figs
%   - Parameter tables in ./reports/
%   - Console output with key parameters
%
% Created: 2026-01-29

%% Setup
clear; clc;
fprintf('\n========================================\n');
fprintf('  GLOBAL OFFSET & COVARIANCE REPORT\n');
fprintf('  Project Presentation Version\n');
fprintf('========================================\n\n');

% Create reports directory
reportDir = './reports';
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end

%% SECTION 1: FIND AND PLOT GLOBAL OFFSET CONFIGURATIONS
fprintf('SECTION 1: Global Offset Models\n');
fprintf('--------------------------------\n\n');

% Search for GO files (non-CBV only for main presentation)
goDirs = {'./2globalOffset'};
goFiles = {};
goData = struct();

for iDir = 1:length(goDirs)
    if exist(goDirs{iDir}, 'dir')
        files = dir(fullfile(goDirs{iDir}, 'GO_*.mat'));
        for iFile = 1:length(files)
            % Skip CBV files for presentation
            if contains(files(iFile).name, 'CBV')
                continue;
            end

            fullPath = fullfile(files(iFile).folder, files(iFile).name);
            goFiles{end+1} = fullPath;

            % Extract metadata
            [~, fname, ~] = fileparts(files(iFile).name);
            scenarioMatch = regexp(fname, 'go(\d+)', 'tokens');

            idx = length(goFiles);
            goData(idx).filename = files(iFile).name;
            goData(idx).fullPath = fullPath;

            if ~isempty(scenarioMatch)
                goData(idx).scenario = str2double(scenarioMatch{1}{1});
            else
                goData(idx).scenario = NaN;
            end
        end
    end
end

fprintf('Found %d Global Offset configuration(s)\n\n', length(goFiles));

% Generate plots for each GO configuration
goParams = table();
for i = 1:length(goFiles)
    try
        fprintf('Processing: %s\n', goData(i).filename);
        data = load(goData(i).fullPath);

        if isfield(data, 'go')
            go = data.go;

            % Create minimal obs structure if not saved
            if isfield(data, 'obs')
                obs = data.obs;
            else
                obs = struct();
                obs.Yname = 'Ozone MDA8';
                obs.Ylabel = 'ppb';
                obs.Zname = 'TOAR';
                if isfield(go, 'tME')
                    obs.tME = go.tME;
                end
                if isfield(go, 'sMS')
                    obs.sMS = go.sMS;
                end
                if isfield(go, 'sMS') && isfield(go, 'tME')
                    obs.Y = nan(size(go.sMS, 1), length(go.tME));
                end
            end

            % Generate comprehensive plots (goPlot=3 for full detail)
            fprintf('  Generating plots (goPlot=3)...\n');
            plotTOARglobalOffset(obs, go, 3);

            % Extract parameters for table
            row = table();
            row.Scenario = goData(i).scenario;
            row.ScenarioName = {getScenarioName(goData(i).scenario)};

            if isfield(go, 'sMS')
                row.NumStations = size(go.sMS, 1);
            else
                row.NumStations = NaN;
            end

            if isfield(go, 'tME')
                row.TimeStart = min(go.tME);
                row.TimeEnd = max(go.tME);
            else
                row.TimeStart = NaN;
                row.TimeEnd = NaN;
            end

            if isfield(go, 'mt')
                row.MeanValue = mean(go.mt(~isnan(go.mt)));
                row.TemporalRange = range(go.mt(~isnan(go.mt)));
            else
                row.MeanValue = NaN;
                row.TemporalRange = NaN;
            end

            if isfield(go, 'ms')
                row.SpatialRange = range(go.ms(~isnan(go.ms)));
            else
                row.SpatialRange = NaN;
            end

            goParams = [goParams; row];
            fprintf('  ✓ Complete\n\n');

        else
            warning('File %s does not contain "go" structure', goData(i).filename);
        end
    catch ME
        warning('Failed to process GO file %s: %s', goData(i).filename, ME.message);
    end
end

% Save GO parameters table
if ~isempty(goParams)
    goParamPath = fullfile(reportDir, 'GlobalOffset_Parameters.csv');
    writetable(goParams, goParamPath);
    fprintf('Parameter table saved: %s\n\n', goParamPath);

    % Display table
    fprintf('GLOBAL OFFSET SUMMARY:\n');
    disp(goParams);
    fprintf('\n');
end

%% SECTION 2: FIND AND PLOT COVARIANCE CONFIGURATIONS
fprintf('SECTION 2: Covariance Models\n');
fprintf('-----------------------------\n\n');

% Search for Cov files (non-CBV only for main presentation)
covDirs = {'./3covariance'};
covFiles = {};
covData = struct();

for iDir = 1:length(covDirs)
    if exist(covDirs{iDir}, 'dir')
        files = dir(fullfile(covDirs{iDir}, 'Cov_*.mat'));
        for iFile = 1:length(files)
            % Skip CBV files for presentation
            if contains(files(iFile).name, 'CBV')
                continue;
            end

            fullPath = fullfile(files(iFile).folder, files(iFile).name);
            covFiles{end+1} = fullPath;

            % Extract metadata
            [~, fname, ~] = fileparts(files(iFile).name);
            scenarioMatch = regexp(fname, 'go(\d+)', 'tokens');
            ltMatch = regexp(fname, 'lt(\d+)', 'tokens');
            tempModelMatch = regexp(fname, 'lt\d+_(\w+)(?:_|\.)', 'tokens');

            idx = length(covFiles);
            covData(idx).filename = files(iFile).name;
            covData(idx).fullPath = fullPath;

            if ~isempty(scenarioMatch)
                covData(idx).scenario = str2double(scenarioMatch{1}{1});
            else
                covData(idx).scenario = NaN;
            end

            if ~isempty(ltMatch)
                covData(idx).logTransf = str2double(ltMatch{1}{1});
            else
                covData(idx).logTransf = NaN;
            end

            if ~isempty(tempModelMatch)
                covData(idx).temporalModel = tempModelMatch{1}{1};
            else
                covData(idx).temporalModel = 'unknown';
            end
        end
    end
end

fprintf('Found %d Covariance configuration(s)\n\n', length(covFiles));

% Generate plots for each Cov configuration
covParams = table();
for i = 1:length(covFiles)
    try
        fprintf('Processing: %s\n', covData(i).filename);
        data = load(covData(i).fullPath);

        if isfield(data, 'cov')
            cov = data.cov;

            % Create metadata structures
            obs = struct();
            obs.Yname = 'Ozone MDA8';
            obs.Ylabel = 'ppb';
            if ~isnan(covData(i).logTransf)
                obs.logTransf = covData(i).logTransf;
            end

            go = struct();
            if ~isnan(covData(i).scenario)
                go.scenario = covData(i).scenario;
            end

            % Generate covariance plots (publication style with 3D)
            fprintf('  Generating covariance plots...\n');
            [figPaths, paramSummary] = plotTOARcovariance(cov, 'obs', obs, 'go', go, ...
                'visible', 'off', 'plotStyle', 'diagnostic');

            % Extract parameters for table
            row = table();
            row.Scenario = covData(i).scenario;
            row.LogTransf = covData(i).logTransf;
            row.TemporalModel = {covData(i).temporalModel};
            row.Variance = paramSummary.var;
            row.STmetric = paramSummary.stmetric;
            row.SpatialParams = {strjoin(paramSummary.spatialParams, '; ')};
            row.TemporalParams = {strjoin(paramSummary.temporalParams, '; ')};

            if isfield(paramSummary, 'spatialLagRange')
                row.MaxSpatialLag = paramSummary.spatialLagRange(2);
            else
                row.MaxSpatialLag = NaN;
            end

            if isfield(paramSummary, 'temporalLagRange')
                row.MaxTemporalLag = paramSummary.temporalLagRange(2);
            else
                row.MaxTemporalLag = NaN;
            end

            covParams = [covParams; row];

            % Display key parameters
            fprintf('  Parameters:\n');
            fprintf('    Variance: %.4f\n', paramSummary.var);
            fprintf('    ST-metric: %.2f\n', paramSummary.stmetric);
            fprintf('    Spatial: %s\n', strjoin(paramSummary.spatialParams, '; '));
            fprintf('    Temporal: %s\n', strjoin(paramSummary.temporalParams, '; '));
            fprintf('  ✓ Complete\n\n');

        else
            warning('File %s does not contain "cov" structure', covData(i).filename);
        end
    catch ME
        warning('Failed to process Cov file %s: %s', covData(i).filename, ME.message);
    end
end

% Save Cov parameters table
if ~isempty(covParams)
    covParamPath = fullfile(reportDir, 'Covariance_Parameters.csv');
    writetable(covParams, covParamPath);
    fprintf('Parameter table saved: %s\n\n', covParamPath);

    % Display table
    fprintf('COVARIANCE SUMMARY:\n');
    disp(covParams);
    fprintf('\n');
end

%% SECTION 3: EXECUTIVE SUMMARY
fprintf('\n========================================\n');
fprintf('EXECUTIVE SUMMARY\n');
fprintf('========================================\n\n');

fprintf('CONFIGURATION OVERVIEW:\n');
fprintf('  Global Offset models: %d\n', length(goFiles));
fprintf('  Covariance models: %d\n\n', length(covFiles));

if ~isempty(goParams)
    fprintf('GLOBAL OFFSET HIGHLIGHTS:\n');
    fprintf('  Scenarios tested: %s\n', mat2str(unique(goParams.Scenario)));
    fprintf('  Stations: %d\n', max(goParams.NumStations));
    fprintf('  Time range: %.1f - %.1f\n', min(goParams.TimeStart), max(goParams.TimeEnd));
    fprintf('  Mean ozone: %.2f ± %.2f ppb\n', mean(goParams.MeanValue), std(goParams.MeanValue));
    fprintf('\n');
end

if ~isempty(covParams)
    fprintf('COVARIANCE HIGHLIGHTS:\n');
    uniqueModels = unique(covParams.TemporalModel);
    fprintf('  Temporal models: %s\n', strjoin(uniqueModels, ', '));
    fprintf('  Variance range: [%.4f, %.4f]\n', min(covParams.Variance), max(covParams.Variance));
    fprintf('  ST-metric range: [%.2f, %.2f]\n', min(covParams.STmetric), max(covParams.STmetric));
    fprintf('  Max spatial correlation: %.2f degrees\n', max(covParams.MaxSpatialLag(~isnan(covParams.MaxSpatialLag))));
    fprintf('  Max temporal correlation: %.2f years\n', max(covParams.MaxTemporalLag(~isnan(covParams.MaxTemporalLag))));
    fprintf('\n');
end

fprintf('RECOMMENDATIONS:\n\n');

if isempty(goFiles) && isempty(covFiles)
    fprintf('  ⚠ No configurations found.\n');
    fprintf('  → Generate GO and Cov models first using:\n');
    fprintf('     - getTOARglobalOffset(obs, scenario)\n');
    fprintf('     - getTOARautoCov(obs, go, temporalModel)\n\n');
else
    fprintf('  ✓ Configurations successfully generated.\n\n');

    if ~isempty(goParams)
        fprintf('  Global Offset Selection:\n');
        % Find scenario with best temporal range
        [~, bestIdx] = max(goParams.TemporalRange);
        fprintf('    → Scenario %d (%s) shows largest temporal variation\n', ...
            goParams.Scenario(bestIdx), goParams.ScenarioName{bestIdx});
        fprintf('      Most suitable for capturing long-term trends\n\n');
    end

    if ~isempty(covParams)
        fprintf('  Covariance Model Selection:\n');
        % Find model with lowest residual variance
        [minVar, minIdx] = min(covParams.Variance);
        fprintf('    → GO Scenario %d with %s shows lowest residual variance (%.4f)\n', ...
            covParams.Scenario(minIdx), covParams.TemporalModel{minIdx}, minVar);
        fprintf('      Indicates good fit to spatial-temporal structure\n\n');

        % Check for seasonal models
        hasHolecos = any(contains(covParams.TemporalModel, 'holecos'));
        if hasHolecos
            fprintf('    → Holecos model captures seasonal patterns\n');
            fprintf('      Recommended for data with strong annual cycles\n\n');
        end
    end

    fprintf('  Next Steps:\n');
    fprintf('    1. Review all plots in ./2globalOffset/figs and ./3covariance/figs\n');
    fprintf('    2. Compare parameter tables in ./reports/\n');
    fprintf('    3. Run checker-board validation (CBV) on selected configurations\n');
    fprintf('    4. Apply best-performing configuration to full dataset\n\n');
end

fprintf('========================================\n');
fprintf('  REPORT COMPLETE\n');
fprintf('========================================\n\n');

fprintf('Output locations:\n');
fprintf('  - GO plots: ./2globalOffset/figs/\n');
fprintf('  - Cov plots: ./3covariance/figs/\n');
fprintf('  - Tables: ./reports/\n\n');

%% Helper function
function name = getScenarioName(scenario)
    % Get human-readable name for GO scenario
    switch scenario
        case 0
            name = 'Flat (constant mean)';
        case 1
            name = 'Spatial mean only';
        case 2
            name = 'Temporal mean only';
        case 3
            name = 'Spatial + Temporal';
        case 4
            name = 'Spatial + Temporal + Linear trend';
        otherwise
            name = 'Custom';
    end
end
