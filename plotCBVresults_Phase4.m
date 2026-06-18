function figPaths = plotCBVresults_Phase4(configDirs, configNames, varargin)
% plotCBVresults_Phase4 - Enhanced time-series analysis for CBV configurations
%
% Creates time-series visualizations with distinct colors and line styles
% for each model configuration. Handles missing years gracefully with NaN
% values (lines break at missing data).
%
% SYNTAX:
%   figPaths = plotCBVresults_Phase4(configDirs, configNames)
%   figPaths = plotCBVresults_Phase4(configDirs, configNames, 'Name', Value, ...)
%
% INPUTS:
%   configDirs  - Cell array of directories containing CBV results for each config
%   configNames - Cell array of configuration names (same length as configDirs)
%
% OPTIONAL PARAMETERS:
%   'methodCodes'    - BME method codes for color/style assignment (default: extracted from filePattern)
%   'metrics'        - Metrics to analyze (default: {'R2','RMSE','MAE','NMB'})
%   'years'          - Years to include in analysis (default: [] = all years)
%   'boxSize'        - Specific box size to analyze (default: [] = all sizes)
%   'saveDir'        - Directory to save figures (default: './figs_phase4')
%   'dpi'            - Figure resolution (default: 300)
%   'visible'        - 'on' or 'off' for figure visibility (default: 'off')
%   'filePattern'    - Pattern to match result files (default: 'CBV_*.mat')
%   'saveTables'     - Save summary tables as CSV (default: true)
%   'plotIndividualMetrics' - Generate individual metric figures (default: false)
%
% OUTPUTS:
%   figPaths - Structure with paths to all generated figures and tables
%
% FEATURES:
%   - Unique colors for each model (ColorBrewer-inspired palette)
%   - Line style by model category (obs only, single CTM, 2 CTMs, 3+ CTMs)
%   - Robust handling of missing years (NaN instead of errors)
%   - Multiple visualization types (time-series, heatmap, winner analysis)
%
% EXAMPLE:
%   configDirs = repmat({'./7validation/CBV'}, 1, 3);
%   configNames = {'Obs. only', 'Obs. + MERRA2-GMI', 'Obs. + M3fusion'};
%   configPatterns = {'CBV_BME10000133*.mat', 'CBV_BME13000313-01*.mat', 'CBV_BME13000313-02*.mat'};
%   methodCodes = {'10000133', '13000313-01', '13000313-02'};
%
%   figPaths = plotCBVresults_Phase4(configDirs, configNames, ...
%       'filePattern', configPatterns, ...
%       'methodCodes', methodCodes, ...
%       'years', 2005:2020);
%
% SEE ALSO: getCBVmodelStyles, plotPhase4TimeSeries, plotCBVresults_Phase3

%% Parse inputs
p = inputParser;
addRequired(p, 'configDirs', @iscell);
addRequired(p, 'configNames', @iscell);
addParameter(p, 'methodCodes', {}, @iscell);
addParameter(p, 'metrics', {'R2','RMSE','MAE','NMB'}, @iscell);
addParameter(p, 'years', [], @isnumeric);
addParameter(p, 'boxSize', [], @isnumeric);
addParameter(p, 'saveDir', './figs_phase4', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', {'CBV_*.mat'}, @iscell);
addParameter(p, 'leakTag', '', @ischar);   % ''=legacy only, '_lc<R>'=leakage-controlled only
addParameter(p, 'saveTables', true, @islogical);
addParameter(p, 'plotIndividualMetrics', false, @islogical);

parse(p, configDirs, configNames, varargin{:});
opts = p.Results;

% Validate inputs
nConfigs = length(configDirs);
if length(configNames) ~= nConfigs
    error('configDirs and configNames must have the same length');
end

% Ensure filePattern is a cell array matching configDirs
if length(opts.filePattern) == 1
    opts.filePattern = repmat(opts.filePattern, 1, nConfigs);
end

% Extract method codes from file patterns if not provided
if isempty(opts.methodCodes)
    opts.methodCodes = extractMethodCodesFromPatterns(opts.filePattern);
end

% Create save directory
if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('\n=== Phase 4: Enhanced Time-Series Analysis ===\n');
fprintf('Number of configurations: %d\n', nConfigs);
if ~isempty(opts.years)
    fprintf('Years to analyze: %s\n', mat2str(opts.years));
else
    fprintf('Years to analyze: all available\n');
end
fprintf('Save directory: %s\n\n', opts.saveDir);

%% Load data for all configurations
fprintf('Loading configuration data...\n');
configs = struct();

for iConfig = 1:nConfigs
    fprintf('  [%d/%d] Loading: %s\n', iConfig, nConfigs, configNames{iConfig});

    % Load all CBV result files for this configuration
    resultFiles = dir(fullfile(configDirs{iConfig}, opts.filePattern{iConfig}));
    resultFiles = filterLeakFiles(resultFiles, opts.leakTag);

    if isempty(resultFiles)
        warning('No result files found for config: %s (pattern: %s)', ...
            configNames{iConfig}, opts.filePattern{iConfig});
        configs(iConfig).name = configNames{iConfig};
        configs(iConfig).data = [];
        configs(iConfig).nFiles = 0;
        continue;
    end

    fprintf('    Found %d result files\n', length(resultFiles));

    % Aggregate data
    configData = [];
    for i = 1:length(resultFiles)
        filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);

        % Extract year from filename (e.g., CBV_...._2016.mat -> 2016)
        [~, fname, ~] = fileparts(resultFiles(i).name);
        yearMatch = regexp(fname, '_(\d{4})$', 'tokens');
        fileYear = NaN;
        if ~isempty(yearMatch)
            fileYear = str2double(yearMatch{1}{1});
        end

        % Skip if years specified and this file doesn't match
        if ~isempty(opts.years) && ~isnan(fileYear) && ~ismember(fileYear, opts.years)
            continue;
        end

        try
            data = load(filePath);

            % Extract key information
            if isfield(data, 'annualResults') && isfield(data, 'annualStats')
                entry = struct();
                entry.Y_obs = data.annualResults.Y_obs;
                entry.Y_est = data.annualResults.Y_est;
                entry.Year = data.annualStats.Year;

                % Use year from filename if not in stats
                if isempty(entry.Year) || entry.Year == 0
                    entry.Year = fileYear;
                end

                configData = [configData; entry];
            end
        catch ME
            warning('Failed to load %s: %s', resultFiles(i).name, ME.message);
        end
    end

    configs(iConfig).name = configNames{iConfig};
    configs(iConfig).data = configData;
    configs(iConfig).nFiles = length(configData);
    fprintf('    Loaded %d valid entries\n', length(configData));
end

fprintf('\n');

%% Get colors and styles
fprintf('Assigning colors and styles...\n');
[colors, lineStyles, markers, lineWidths] = getCBVmodelStyles(opts.methodCodes, configNames);
fprintf('  Assigned %d unique styles\n\n', nConfigs);

%% Prepare time-series data with NaN for missing years
fprintf('Preparing time-series data (handling missing years with NaN)...\n');
yearlyData = prepareTimeSeriesData(configs, opts);
fprintf('  Years: %s\n', mat2str(yearlyData.years));
fprintf('  Metrics: %s\n\n', strjoin(opts.metrics, ', '));

%% Initialize output structure
figPaths = struct();
figPaths.timeseries = {};
figPaths.tables = {};

%% Generate time-series plots
fprintf('Generating time-series plots...\n');
try
    plotOpts = opts;
    plotOpts.plotIndividualMetrics = opts.plotIndividualMetrics;

    figs = plotPhase4TimeSeries(yearlyData, configs, colors, lineStyles, markers, lineWidths, plotOpts);
    figPaths.timeseries = figs;
    fprintf('  Generated %d figures\n', length(figs));
catch ME
    warning('Time-series plotting failed: %s', ME.message);
    fprintf('  Error details: %s\n', ME.message);
end

%% Save data tables
if opts.saveTables
    fprintf('\nSaving data tables...\n');
    try
        tablePaths = saveTimeSeriesTables(yearlyData, configs, opts);
        figPaths.tables = tablePaths;
        fprintf('  Saved %d tables\n', length(tablePaths));
    catch ME
        warning('Table saving failed: %s', ME.message);
    end
end

%% Summary
fprintf('\n=== Phase 4 Analysis Complete ===\n');
fprintf('Total figures generated: %d\n', length(figPaths.timeseries));
fprintf('Total tables saved: %d\n', length(figPaths.tables));
fprintf('All outputs saved to: %s\n', opts.saveDir);

end

%% Helper function: Extract method codes from file patterns
function methodCodes = extractMethodCodesFromPatterns(patterns)
    methodCodes = cell(size(patterns));
    for i = 1:length(patterns)
        % Try to extract BME method code from pattern
        % e.g., 'CBV_BME13000313-01_go3*.mat' -> '13000313-01'
        match = regexp(patterns{i}, 'BME(\d{8}(?:-[0-9A-Fa-f]{2})?)', 'tokens');
        if ~isempty(match)
            methodCodes{i} = match{1}{1};
        else
            methodCodes{i} = '';
        end
    end
end

%% Helper function: Prepare time-series data with NaN for missing years
function yearlyData = prepareTimeSeriesData(configs, opts)
    % Determine all years to include
    if isempty(opts.years)
        % Collect all years from all configs
        allYears = [];
        for iConfig = 1:length(configs)
            if ~isempty(configs(iConfig).data)
                allYears = [allYears, [configs(iConfig).data.Year]];
            end
        end
        allYears = unique(allYears);
        allYears = allYears(~isnan(allYears));
        allYears = sort(allYears);
    else
        allYears = opts.years;
    end

    nConfigs = length(configs);
    nYears = length(allYears);
    nMetrics = length(opts.metrics);

    % Initialize with NaN
    yearlyData = struct();
    yearlyData.years = allYears;
    yearlyData.values = NaN(nConfigs, nYears, nMetrics);
    yearlyData.N = zeros(nConfigs, nYears);

    % Metric name to index mapping
    metricIdx = containers.Map(opts.metrics, 1:nMetrics);

    % Fill available data
    for iConfig = 1:nConfigs
        data = configs(iConfig).data;
        if isempty(data)
            continue;
        end

        % Get unique years for this config
        configYears = unique([data.Year]);

        for year = configYears
            yearIdx = find(allYears == year);
            if isempty(yearIdx)
                continue;  % Year not in requested range
            end

            % Collect all observations for this config-year combination
            Y_obs_year = [];
            Y_est_year = [];
            for i = 1:length(data)
                if data(i).Year == year
                    Y_obs_year = [Y_obs_year; data(i).Y_obs(:)];
                    Y_est_year = [Y_est_year; data(i).Y_est(:)];
                end
            end

            % Remove NaN values
            validIdx = ~isnan(Y_obs_year) & ~isnan(Y_est_year);
            Y_obs_year = Y_obs_year(validIdx);
            Y_est_year = Y_est_year(validIdx);

            if isempty(Y_obs_year)
                continue;  % No valid data for this year
            end

            % Compute metrics
            yearlyData.N(iConfig, yearIdx) = length(Y_obs_year);

            % R2
            if isKey(metricIdx, 'R2')
                idx = metricIdx('R2');
                yearlyData.values(iConfig, yearIdx, idx) = calculateR2(Y_obs_year, Y_est_year);
            end

            % RMSE
            if isKey(metricIdx, 'RMSE')
                idx = metricIdx('RMSE');
                yearlyData.values(iConfig, yearIdx, idx) = sqrt(mean((Y_obs_year - Y_est_year).^2));
            end

            % MAE
            if isKey(metricIdx, 'MAE')
                idx = metricIdx('MAE');
                yearlyData.values(iConfig, yearIdx, idx) = mean(abs(Y_obs_year - Y_est_year));
            end

            % NMB
            if isKey(metricIdx, 'NMB')
                idx = metricIdx('NMB');
                yearlyData.values(iConfig, yearIdx, idx) = 100 * mean(Y_est_year - Y_obs_year) / mean(Y_obs_year);
            end
        end
    end
end

%% Helper function: Calculate R-squared
function r2 = calculateR2(obs, est)
    if isempty(obs)
        r2 = NaN;
        return;
    end

    SS_res = sum((obs - est).^2);
    SS_tot = sum((obs - mean(obs)).^2);

    if SS_tot == 0
        r2 = NaN;
    else
        r2 = 1 - SS_res / SS_tot;
    end
end

%% Helper function: Save time-series tables
function tablePaths = saveTimeSeriesTables(yearlyData, configs, opts)
    tablePaths = {};

    % Table 1: Raw time-series data
    nConfigs = length(configs);
    nYears = length(yearlyData.years);
    nMetrics = length(opts.metrics);

    % Create a long-format table
    tableData = {};
    for iConfig = 1:nConfigs
        for iYear = 1:nYears
            row = {configs(iConfig).name, yearlyData.years(iYear)};
            for iMetric = 1:nMetrics
                row{end+1} = yearlyData.values(iConfig, iYear, iMetric);
            end
            row{end+1} = yearlyData.N(iConfig, iYear);
            tableData = [tableData; row];
        end
    end

    varNames = ['Configuration', 'Year', opts.metrics, 'N'];
    T = cell2table(tableData, 'VariableNames', varNames);

    tableFile1 = fullfile(opts.saveDir, 'phase4_timeseries_data.csv');
    writetable(T, tableFile1);
    tablePaths{end+1} = tableFile1;
    fprintf('    Saved: %s\n', tableFile1);

    % Table 2: Summary statistics (mean, std across years)
    summaryData = {};
    for iConfig = 1:nConfigs
        row = {configs(iConfig).name};
        for iMetric = 1:nMetrics
            values = squeeze(yearlyData.values(iConfig, :, iMetric));
            row{end+1} = mean(values, 'omitnan');
            row{end+1} = std(values, 'omitnan');
        end
        summaryData = [summaryData; row];
    end

    summaryVarNames = {'Configuration'};
    for iMetric = 1:nMetrics
        summaryVarNames{end+1} = [opts.metrics{iMetric}, '_Mean'];
        summaryVarNames{end+1} = [opts.metrics{iMetric}, '_Std'];
    end

    T2 = cell2table(summaryData, 'VariableNames', summaryVarNames);

    tableFile2 = fullfile(opts.saveDir, 'phase4_summary_stats.csv');
    writetable(T2, tableFile2);
    tablePaths{end+1} = tableFile2;
    fprintf('    Saved: %s\n', tableFile2);
end
