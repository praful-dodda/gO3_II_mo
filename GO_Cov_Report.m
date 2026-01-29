%% Global Offset and Covariance Model Report
% Comprehensive report of all global offset (GO) and covariance models
% computed for TOAR ozone data analysis.
%
% This script:
% 1. Catalogs all existing GO and Cov .mat files
% 2. Generates publication-quality plots
% 3. Creates summary tables with parameters
% 4. Provides narrative analysis and recommendations
%
% USAGE:
%   Run this script directly in MATLAB, or convert to Live Script:
%   >> GO_Cov_Report
%
%   Or convert to .mlx:
%   >> matlab.internal.liveeditor.openAndConvert('GO_Cov_Report.m', 'GO_Cov_Report.mlx')
%
% OUTPUTS:
%   - Figures in ./2globalOffset/figs and ./3covariance/figs
%   - Summary tables in ./reports/
%   - Console output with key findings
%
% Created: 2026-01-29

%% Setup
clear; clc;
fprintf('\n========================================\n');
fprintf('  GLOBAL OFFSET & COVARIANCE REPORT\n');
fprintf('========================================\n\n');

% Create reports directory
reportDir = './reports';
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end

%% SECTION 1: CATALOG GLOBAL OFFSET FILES
fprintf('SECTION 1: Cataloging Global Offset Files\n');
fprintf('------------------------------------------\n\n');

% Search for GO files
goDirs = {'./2globalOffset', './2globalOffset/validation', './2globalOffset/CBV'};
goFiles = {};
goMetadata = struct();

for iDir = 1:length(goDirs)
    if exist(goDirs{iDir}, 'dir')
        files = dir(fullfile(goDirs{iDir}, 'GO_*.mat'));
        for iFile = 1:length(files)
            fullPath = fullfile(files(iFile).folder, files(iFile).name);
            goFiles{end+1} = fullPath;

            % Extract metadata from filename
            % Expected format: GO_go{scenario}_lt{logTransf}.mat
            % or: GO_go{scenario}_lt{logTransf}_CBV_box{size}_fold{fold}_{startYr}-{endYr}.mat
            [~, fname, ~] = fileparts(files(iFile).name);

            % Parse scenario and logTransf
            scenarioMatch = regexp(fname, 'go(\d+)', 'tokens');
            ltMatch = regexp(fname, 'lt(\d+)', 'tokens');

            idx = length(goFiles);
            goMetadata(idx).filename = files(iFile).name;
            goMetadata(idx).fullPath = fullPath;
            goMetadata(idx).directory = files(iFile).folder;
            goMetadata(idx).filesize = files(iFile).bytes / 1024; % KB
            goMetadata(idx).dateModified = files(iFile).date;

            if ~isempty(scenarioMatch)
                goMetadata(idx).scenario = str2double(scenarioMatch{1}{1});
            else
                goMetadata(idx).scenario = NaN;
            end

            if ~isempty(ltMatch)
                goMetadata(idx).logTransf = str2double(ltMatch{1}{1});
            else
                goMetadata(idx).logTransf = NaN;
            end

            % Check if CBV file
            if contains(fname, 'CBV')
                goMetadata(idx).isCBV = true;

                % Extract CBV-specific info
                boxMatch = regexp(fname, 'box([\d.]+)', 'tokens');
                foldMatch = regexp(fname, 'fold(\d+)', 'tokens');
                yearMatch = regexp(fname, '_(\d{4})-(\d{4})', 'tokens');

                if ~isempty(boxMatch)
                    goMetadata(idx).boxSize = str2double(boxMatch{1}{1});
                end
                if ~isempty(foldMatch)
                    goMetadata(idx).foldIdx = str2double(foldMatch{1}{1});
                end
                if ~isempty(yearMatch)
                    goMetadata(idx).yearRange = [str2double(yearMatch{1}{1}), str2double(yearMatch{1}{2})];
                end
            else
                goMetadata(idx).isCBV = false;
            end
        end
    end
end

fprintf('Found %d global offset files:\n', length(goFiles));
if ~isempty(goMetadata)
    % Group by scenario
    uniqueScenarios = unique([goMetadata.scenario]);
    uniqueScenarios = uniqueScenarios(~isnan(uniqueScenarios));

    for iScen = 1:length(uniqueScenarios)
        scenario = uniqueScenarios(iScen);
        count = sum([goMetadata.scenario] == scenario);
        fprintf('  Scenario %d: %d files\n', scenario, count);
    end
    fprintf('\n');
else
    fprintf('  No GO files found.\n\n');
end

%% SECTION 2: CATALOG COVARIANCE FILES
fprintf('SECTION 2: Cataloging Covariance Files\n');
fprintf('---------------------------------------\n\n');

% Search for Cov files
covDirs = {'./3covariance', './3covariance/validation', './3covariance/CBV'};
covFiles = {};
covMetadata = struct();

for iDir = 1:length(covDirs)
    if exist(covDirs{iDir}, 'dir')
        files = dir(fullfile(covDirs{iDir}, 'Cov_*.mat'));
        for iFile = 1:length(files)
            fullPath = fullfile(files(iFile).folder, files(iFile).name);
            covFiles{end+1} = fullPath;

            % Extract metadata from filename
            % Expected format: Cov_go{scenario}_lt{logTransf}.mat
            % or: Cov_go{scenario}_lt{logTransf}_{tempModel}_CBV_box{size}_fold{fold}_{startYr}-{endYr}.mat
            [~, fname, ~] = fileparts(files(iFile).name);

            % Parse scenario, logTransf, and temporal model
            scenarioMatch = regexp(fname, 'go(\d+)', 'tokens');
            ltMatch = regexp(fname, 'lt(\d+)', 'tokens');
            tempModelMatch = regexp(fname, 'lt\d+_(\w+)_?', 'tokens');

            idx = length(covFiles);
            covMetadata(idx).filename = files(iFile).name;
            covMetadata(idx).fullPath = fullPath;
            covMetadata(idx).directory = files(iFile).folder;
            covMetadata(idx).filesize = files(iFile).bytes / 1024; % KB
            covMetadata(idx).dateModified = files(iFile).date;

            if ~isempty(scenarioMatch)
                covMetadata(idx).scenario = str2double(scenarioMatch{1}{1});
            else
                covMetadata(idx).scenario = NaN;
            end

            if ~isempty(ltMatch)
                covMetadata(idx).logTransf = str2double(ltMatch{1}{1});
            else
                covMetadata(idx).logTransf = NaN;
            end

            if ~isempty(tempModelMatch)
                covMetadata(idx).temporalModel = tempModelMatch{1}{1};
            else
                covMetadata(idx).temporalModel = 'unknown';
            end

            % Check if CBV file
            if contains(fname, 'CBV')
                covMetadata(idx).isCBV = true;

                % Extract CBV-specific info
                boxMatch = regexp(fname, 'box([\d.]+)', 'tokens');
                foldMatch = regexp(fname, 'fold(\d+)', 'tokens');
                yearMatch = regexp(fname, '_(\d{4})-(\d{4})', 'tokens');

                if ~isempty(boxMatch)
                    covMetadata(idx).boxSize = str2double(boxMatch{1}{1});
                end
                if ~isempty(foldMatch)
                    covMetadata(idx).foldIdx = str2double(foldMatch{1}{1});
                end
                if ~isempty(yearMatch)
                    covMetadata(idx).yearRange = [str2double(yearMatch{1}{1}), str2double(yearMatch{1}{2})];
                end
            else
                covMetadata(idx).isCBV = false;
            end
        end
    end
end

fprintf('Found %d covariance files:\n', length(covFiles));
if ~isempty(covMetadata)
    % Group by scenario and temporal model
    uniqueScenarios = unique([covMetadata.scenario]);
    uniqueScenarios = uniqueScenarios(~isnan(uniqueScenarios));
    uniqueModels = unique({covMetadata.temporalModel});

    for iScen = 1:length(uniqueScenarios)
        scenario = uniqueScenarios(iScen);
        for iModel = 1:length(uniqueModels)
            model = uniqueModels{iModel};
            count = sum([covMetadata.scenario] == scenario & strcmp({covMetadata.temporalModel}, model));
            if count > 0
                fprintf('  Scenario %d, %s: %d files\n', scenario, model, count);
            end
        end
    end
    fprintf('\n');
else
    fprintf('  No Cov files found.\n\n');
end

%% SECTION 3: GENERATE SUMMARY TABLES
fprintf('SECTION 3: Generating Summary Tables\n');
fprintf('-------------------------------------\n\n');

% Create GO summary table
if ~isempty(goMetadata)
    fprintf('Creating Global Offset Summary Table...\n');

    % Extract fields for table
    T_GO = struct2table(goMetadata);

    % Select key columns
    if ismember('scenario', T_GO.Properties.VariableNames)
        T_GO_summary = T_GO(:, {'filename', 'scenario', 'logTransf', 'isCBV', 'filesize', 'dateModified'});
    else
        T_GO_summary = T_GO;
    end

    % Save to CSV
    goTablePath = fullfile(reportDir, 'GlobalOffset_Summary.csv');
    writetable(T_GO_summary, goTablePath);
    fprintf('  Saved: %s\n', goTablePath);

    % Display key statistics
    fprintf('\nGlobal Offset Statistics:\n');
    fprintf('  Total files: %d\n', height(T_GO));
    fprintf('  Training files: %d\n', sum(~[goMetadata.isCBV]));
    fprintf('  CBV files: %d\n', sum([goMetadata.isCBV]));
    fprintf('  Scenarios: %s\n', mat2str(uniqueScenarios));
    fprintf('\n');
else
    fprintf('  No GO files to summarize.\n\n');
end

% Create Cov summary table
if ~isempty(covMetadata)
    fprintf('Creating Covariance Summary Table...\n');

    % Extract fields for table
    T_Cov = struct2table(covMetadata);

    % Select key columns
    if ismember('scenario', T_Cov.Properties.VariableNames)
        T_Cov_summary = T_Cov(:, {'filename', 'scenario', 'logTransf', 'temporalModel', 'isCBV', 'filesize', 'dateModified'});
    else
        T_Cov_summary = T_Cov;
    end

    % Save to CSV
    covTablePath = fullfile(reportDir, 'Covariance_Summary.csv');
    writetable(T_Cov_summary, covTablePath);
    fprintf('  Saved: %s\n', covTablePath);

    % Display key statistics
    fprintf('\nCovariance Statistics:\n');
    fprintf('  Total files: %d\n', height(T_Cov));
    fprintf('  Training files: %d\n', sum(~[covMetadata.isCBV]));
    fprintf('  CBV files: %d\n', sum([covMetadata.isCBV]));
    fprintf('  Scenarios: %s\n', mat2str(uniqueScenarios));
    fprintf('  Temporal models: %s\n', strjoin(uniqueModels, ', '));
    fprintf('\n');
else
    fprintf('  No Cov files to summarize.\n\n');
end

%% SECTION 4: GENERATE PLOTS FOR KEY CONFIGURATIONS
fprintf('SECTION 4: Generating Plots\n');
fprintf('---------------------------\n\n');

% Plot non-CBV (training) configurations
fprintf('Plotting Global Offset configurations (non-CBV)...\n');
goPlotCount = 0;

for i = 1:length(goFiles)
    if ~goMetadata(i).isCBV
        try
            fprintf('  Loading: %s\n', goMetadata(i).filename);
            data = load(goMetadata(i).fullPath);

            if isfield(data, 'go')
                go = data.go;

                % Check if obs is available (might not be saved with GO)
                if isfield(data, 'obs')
                    obs = data.obs;
                else
                    % Create minimal obs structure for plotting
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
                    % Create dummy Y for plotting
                    if isfield(go, 'sMS') && isfield(go, 'tME')
                        obs.Y = nan(size(go.sMS, 1), length(go.tME));
                    end
                end

                % Generate GO plot with minimal detail (goPlot=1)
                fprintf('    Generating GO plot...\n');
                plotTOARglobalOffset(obs, go, 1);
                goPlotCount = goPlotCount + 1;

            else
                warning('File %s does not contain "go" structure', goMetadata(i).filename);
            end
        catch ME
            warning('Failed to plot GO file %s: %s', goMetadata(i).filename, ME.message);
        end
    end
end

fprintf('  Generated %d GO plots\n\n', goPlotCount);

% Plot covariance configurations
fprintf('Plotting Covariance configurations (non-CBV)...\n');
covPlotCount = 0;

for i = 1:length(covFiles)
    if ~covMetadata(i).isCBV
        try
            fprintf('  Loading: %s\n', covMetadata(i).filename);
            data = load(covMetadata(i).fullPath);

            if isfield(data, 'cov')
                cov = data.cov;

                % Create metadata for plot naming
                plotOpts = struct();
                if ~isnan(covMetadata(i).scenario)
                    plotOpts.scenario = covMetadata(i).scenario;
                end
                if ~isnan(covMetadata(i).logTransf)
                    plotOpts.logTransf = covMetadata(i).logTransf;
                end

                % Create minimal obs and go structures for metadata
                obs = struct();
                obs.Yname = 'Ozone MDA8';
                obs.Ylabel = 'ppb';
                if ~isnan(covMetadata(i).logTransf)
                    obs.logTransf = covMetadata(i).logTransf;
                end

                go = struct();
                if ~isnan(covMetadata(i).scenario)
                    go.scenario = covMetadata(i).scenario;
                end

                % Generate covariance plot
                fprintf('    Generating covariance plot...\n');
                [figPaths, paramSummary] = plotTOARcovariance(cov, 'obs', obs, 'go', go, ...
                    'visible', 'off', 'plotStyle', 'publication');

                % Display key parameters
                fprintf('      Variance: %.4f\n', paramSummary.var);
                fprintf('      ST-metric: %.2f\n', paramSummary.stmetric);
                fprintf('      Spatial params: %s\n', strjoin(paramSummary.spatialParams, '; '));
                fprintf('      Temporal params: %s\n', strjoin(paramSummary.temporalParams, '; '));

                covPlotCount = covPlotCount + 1;

            else
                warning('File %s does not contain "cov" structure', covMetadata(i).filename);
            end
        catch ME
            warning('Failed to plot Cov file %s: %s', covMetadata(i).filename, ME.message);
        end
    end
end

fprintf('  Generated %d covariance plots\n\n', covPlotCount);

%% SECTION 5: DETAILED PARAMETER EXTRACTION
fprintf('SECTION 5: Extracting Detailed Parameters\n');
fprintf('------------------------------------------\n\n');

% Extract detailed covariance parameters
if ~isempty(covFiles)
    fprintf('Extracting detailed covariance parameters...\n');

    covParamTable = table();

    for i = 1:length(covFiles)
        if ~covMetadata(i).isCBV
            try
                data = load(covMetadata(i).fullPath);

                if isfield(data, 'cov')
                    cov = data.cov;

                    % Create obs and go for metadata
                    obs = struct();
                    if ~isnan(covMetadata(i).logTransf)
                        obs.logTransf = covMetadata(i).logTransf;
                    end

                    go = struct();
                    if ~isnan(covMetadata(i).scenario)
                        go.scenario = covMetadata(i).scenario;
                    end

                    % Get parameter summary
                    [~, paramSummary] = plotTOARcovariance(cov, 'obs', obs, 'go', go, 'saveFigs', false);

                    % Add to table
                    row = table();
                    row.Filename = {covMetadata(i).filename};
                    row.Scenario = covMetadata(i).scenario;
                    row.LogTransf = covMetadata(i).logTransf;
                    row.TemporalModel = {covMetadata(i).temporalModel};
                    row.Variance = paramSummary.var;
                    row.STmetric = paramSummary.stmetric;
                    row.SpatialParams = {strjoin(paramSummary.spatialParams, '; ')};
                    row.TemporalParams = {strjoin(paramSummary.temporalParams, '; ')};

                    if isfield(paramSummary, 'spatialLagRange')
                        row.SpatialLagMax = paramSummary.spatialLagRange(2);
                    else
                        row.SpatialLagMax = NaN;
                    end

                    if isfield(paramSummary, 'temporalLagRange')
                        row.TemporalLagMax = paramSummary.temporalLagRange(2);
                    else
                        row.TemporalLagMax = NaN;
                    end

                    covParamTable = [covParamTable; row];
                end
            catch ME
                warning('Failed to extract parameters from %s: %s', covMetadata(i).filename, ME.message);
            end
        end
    end

    % Save parameter table
    if ~isempty(covParamTable)
        covParamPath = fullfile(reportDir, 'Covariance_Parameters.csv');
        writetable(covParamTable, covParamPath);
        fprintf('  Saved: %s\n\n', covParamPath);

        % Display table
        disp(covParamTable);
    end
else
    fprintf('  No covariance files found for parameter extraction.\n\n');
end

%% SECTION 6: RECOMMENDATIONS AND INSIGHTS
fprintf('\n========================================\n');
fprintf('SECTION 6: Recommendations & Insights\n');
fprintf('========================================\n\n');

fprintf('KEY FINDINGS:\n\n');

% Global Offset Analysis
if ~isempty(goMetadata)
    fprintf('1. GLOBAL OFFSET CONFIGURATIONS:\n');
    fprintf('   - %d total configurations found\n', length(goFiles));

    scenarios = unique([goMetadata.scenario]);
    scenarios = scenarios(~isnan(scenarios));

    fprintf('   - Scenarios analyzed:\n');
    for iScen = 1:length(scenarios)
        scenario = scenarios(iScen);
        switch scenario
            case 0
                desc = 'Flat (constant mean)';
            case 1
                desc = 'Spatial mean only';
            case 2
                desc = 'Temporal mean only';
            case 3
                desc = 'Spatial + Temporal (regional)';
            case 4
                desc = 'Spatial + Temporal + Linear trend';
            otherwise
                desc = 'Custom';
        end
        fprintf('     * Scenario %d: %s\n', scenario, desc);
    end
    fprintf('\n');
end

% Covariance Analysis
if ~isempty(covMetadata)
    fprintf('2. COVARIANCE MODEL CONFIGURATIONS:\n');
    fprintf('   - %d total configurations found\n', length(covFiles));

    models = unique({covMetadata.temporalModel});
    fprintf('   - Temporal models used:\n');
    for iModel = 1:length(models)
        model = models{iModel};
        count = sum(strcmp({covMetadata.temporalModel}, model));
        fprintf('     * %s: %d files\n', model, count);
    end
    fprintf('\n');

    % Parameter analysis if table exists
    if exist('covParamTable', 'var') && ~isempty(covParamTable)
        fprintf('   - Variance range: [%.4f, %.4f]\n', min(covParamTable.Variance), max(covParamTable.Variance));
        fprintf('   - ST-metric range: [%.2f, %.2f]\n', min(covParamTable.STmetric), max(covParamTable.STmetric));
        fprintf('   - Maximum spatial lag: %.2f degrees\n', max(covParamTable.SpatialLagMax(~isnan(covParamTable.SpatialLagMax))));
        fprintf('   - Maximum temporal lag: %.2f years\n', max(covParamTable.TemporalLagMax(~isnan(covParamTable.TemporalLagMax))));
        fprintf('\n');
    end
end

% Recommendations
fprintf('3. RECOMMENDATIONS:\n\n');

if isempty(goFiles) && isempty(covFiles)
    fprintf('   ⚠ No GO or Covariance files found.\n');
    fprintf('   → Run getTOARglobalOffset and getTOARautoCov to generate configurations.\n');
    fprintf('   → Start with scenario 3 (regional spatial + temporal) as baseline.\n');
    fprintf('   → Use "holecos" temporal model to capture seasonal patterns.\n\n');
else
    if ~isempty(goFiles) && ~isempty(covFiles)
        fprintf('   ✓ Both GO and Covariance configurations exist.\n');
        fprintf('   → Review plots in ./2globalOffset/figs and ./3covariance/figs\n');
        fprintf('   → Check parameter tables in ./reports/\n');
        fprintf('   → Consider running CBV analysis to validate configurations\n\n');
    elseif ~isempty(goFiles)
        fprintf('   ⚠ GO files found, but no Covariance files.\n');
        fprintf('   → Run getTOARautoCov to compute covariance models.\n\n');
    else
        fprintf('   ⚠ Covariance files found, but no GO files.\n');
        fprintf('   → Run getTOARglobalOffset to compute global offsets.\n\n');
    end

    % Specific recommendations based on parameters
    if exist('covParamTable', 'var') && ~isempty(covParamTable)
        % Check for high ST-metric (suggests strong spatial correlation)
        highSTmetric = covParamTable.STmetric > 1000;
        if any(highSTmetric)
            fprintf('   ⚠ High ST-metric detected (>1000):\n');
            fprintf('     Files: %s\n', strjoin(covParamTable.Filename(highSTmetric), ', '));
            fprintf('     → This suggests spatial correlation is much stronger than temporal.\n');
            fprintf('     → Consider refining temporal model or checking residual stationarity.\n\n');
        end

        % Check for low variance
        lowVariance = covParamTable.Variance < 10;
        if any(lowVariance)
            fprintf('   ℹ Low variance detected (<10 ppb²):\n');
            fprintf('     Files: %s\n', strjoin(covParamTable.Filename(lowVariance), ', '));
            fprintf('     → Residuals after GO removal are small - good global offset fit.\n\n');
        end
    end
end

fprintf('4. NEXT STEPS FOR PROJECT:\n\n');
fprintf('   1. Review all generated plots for quality and consistency\n');
fprintf('   2. Select best GO scenario based on:\n');
fprintf('      - Physical interpretation (regional trends vs global)\n');
fprintf('      - Residual variance (lower is better)\n');
fprintf('      - Computational efficiency for BME\n');
fprintf('   3. Select covariance temporal model based on:\n');
fprintf('      - Seasonal pattern presence (holecos for annual cycles)\n');
fprintf('      - Fit quality (visual inspection of plots)\n');
fprintf('      - Model complexity vs benefit\n');
fprintf('   4. Run checker-board validation (CBV) to test configurations\n');
fprintf('   5. Apply best configuration to full dataset for BME estimation\n\n');

fprintf('========================================\n');
fprintf('  REPORT COMPLETE\n');
fprintf('========================================\n\n');

fprintf('Output files saved to:\n');
fprintf('  - GO plots: ./2globalOffset/figs/\n');
fprintf('  - Cov plots: ./3covariance/figs/\n');
fprintf('  - Tables: ./reports/\n\n');
