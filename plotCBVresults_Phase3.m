function figPaths = plotCBVresults_Phase3(configDirs, configNames, varargin)
% plotCBVresults_Phase3 - Comparison tools for multiple CBV configurations
%
% Creates comprehensive comparison visualizations across different soft data
% configurations including:
% 1. Model configuration comparison (side-by-side metrics)
% 2. Temporal trend analysis (year-by-year stability)
% 3. Soft data contribution analysis (incremental value)
%
% SYNTAX:
%   figPaths = plotCBVresults_Phase3(configDirs, configNames)
%   figPaths = plotCBVresults_Phase3(configDirs, configNames, 'Name', Value, ...)
%
% INPUTS:
%   configDirs  - Cell array of directories containing CBV results for each config
%   configNames - Cell array of configuration names (same length as configDirs)
%
% OPTIONAL PARAMETERS:
%   'baselineConfig' - Index of baseline configuration (default: 1)
%   'metrics'        - Metrics to compare (default: {'R2','RMSE','MAE','NMB'})
%   'saveDir'        - Directory to save figures (default: './figs_phase3')
%   'dpi'            - Figure resolution (default: 300)
%   'visible'        - 'on' or 'off' for figure visibility (default: 'off')
%   'filePattern'    - Pattern to match result files (default: 'CBV_*.mat')
%   'saveTables'     - Save summary tables as CSV (default: true)
%
% OUTPUTS:
%   figPaths - Structure with paths to all generated figures and tables
%
% EXAMPLE:
%   configDirs = {
%       './7validation/CBV_baseline',
%       './7validation/CBV_M3fusion',
%       './7validation/CBV_OMI_MLS',
%       './7validation/CBV_all'
%   };
%   configNames = {
%       'Baseline (no soft)',
%       'M3fusion only',
%       'M3fusion + OMI-MLS',
%       'All sources'
%   };
%   figPaths = plotCBVresults_Phase3(configDirs, configNames, ...
%       'baselineConfig', 1, 'saveDir', './figs_comparison');

%% Parse inputs
p = inputParser;
addRequired(p, 'configDirs', @iscell);
addRequired(p, 'configNames', @iscell);
addParameter(p, 'baselineConfig', 1, @isnumeric);
addParameter(p, 'metrics', {'R2','RMSE','MAE','NMB'}, @iscell);
addParameter(p, 'saveDir', './figs_phase3', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', 'CBV_*.mat', @ischar);
addParameter(p, 'saveTables', true, @islogical);

parse(p, configDirs, configNames, varargin{:});
opts = p.Results;

% Validate inputs
if length(configDirs) ~= length(configNames)
    error('configDirs and configNames must have the same length');
end

if opts.baselineConfig < 1 || opts.baselineConfig > length(configDirs)
    error('baselineConfig must be between 1 and %d', length(configDirs));
end

% Create save directory
if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('\n=== Phase 3: Configuration Comparison Analysis ===\n');
fprintf('Number of configurations: %d\n', length(configDirs));
fprintf('Baseline configuration: %s\n', configNames{opts.baselineConfig});
fprintf('Save directory: %s\n\n', opts.saveDir);

%% Load data for all configurations
configs = struct();
for iConfig = 1:length(configDirs)
    fprintf('Loading config %d/%d: %s\n', iConfig, length(configDirs), configNames{iConfig});

    % Load all CBV result files for this configuration
    resultFiles = dir(fullfile(configDirs{iConfig}, opts.filePattern));

    if isempty(resultFiles)
        warning('No result files found for config: %s', configNames{iConfig});
        continue;
    end

    fprintf('  Found %d result files\n', length(resultFiles));

    % Aggregate data
    configData = [];
    for i = 1:length(resultFiles)
        filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);
        try
            data = load(filePath);

            % Extract key information
            if isfield(data, 'annualResults') && isfield(data, 'annualStats')
                entry = struct();
                entry.Y_obs = data.annualResults.Y_obs;
                entry.Y_est = data.annualResults.Y_est;
                entry.sk = data.annualResults.sk;
                entry.tk = data.annualResults.tk;
                entry.BoxSize = data.annualStats.BoxSize;
                entry.Fold = data.annualStats.Fold;
                entry.Year = data.annualStats.Year;
                entry.stats = data.annualStats;

                % Extract soft data info from valParam if available
                if isfield(data, 'valParam') && isfield(data.valParam, 'softData')
                    entry.softData = data.valParam.softData;

                    % Decode CTM models if BMEmethod contains CTM encoding
                    if isfield(data.valParam, 'BMEmethod')
                        bmeStr = data.valParam.BMEmethod;
                        % Extract CTM bitmask (last 2 hex digits)
                        if length(bmeStr) >= 2
                            ctmHex = bmeStr(end-1:end);
                            [models, ~] = decodeCTMmodels(ctmHex);
                            entry.ctmModels = models;
                        end
                    end
                end

                % Assign regions
                entry.regions = assignRegions(entry.sk(:,1), entry.sk(:,2));

                configData = [configData; entry];
            end
        catch ME
            warning('Failed to load %s: %s', resultFiles(i).name, ME.message);
        end
    end

    if ~isempty(configData)
        configs(iConfig).name = configNames{iConfig};
        configs(iConfig).dir = configDirs{iConfig};
        configs(iConfig).data = configData;
        configs(iConfig).nFiles = length(configData);
        fprintf('  Loaded %d valid entries\n', length(configData));
    else
        warning('No valid data loaded for config: %s', configNames{iConfig});
    end
end

fprintf('\n');

%% Initialize output structure
figPaths = struct();
figPaths.configComparison = {};
figPaths.temporalTrends = {};
figPaths.softDataContribution = {};
figPaths.tables = {};

%% 1. Model Configuration Comparison
fprintf('=== Generating Configuration Comparison Plots ===\n');
try
    [figs, tables] = plotConfigComparison(configs, opts);
    figPaths.configComparison = figs;
    figPaths.tables = [figPaths.tables; tables];
    fprintf('✓ Configuration comparison complete\n\n');
catch ME
    warning('Configuration comparison failed: %s', ME.message);
end

%% 2. Temporal Trend Analysis
fprintf('=== Generating Temporal Trend Analysis ===\n');
try
    figs = plotTemporalTrends(configs, opts);
    figPaths.temporalTrends = figs;
    fprintf('✓ Temporal trend analysis complete\n\n');
catch ME
    warning('Temporal trend analysis failed: %s', ME.message);
end

%% 3. Soft Data Contribution Analysis
fprintf('=== Generating Soft Data Contribution Analysis ===\n');
try
    [figs, tables] = plotSoftDataContribution(configs, opts);
    figPaths.softDataContribution = figs;
    figPaths.tables = [figPaths.tables; tables];
    fprintf('✓ Soft data contribution analysis complete\n\n');
catch ME
    warning('Soft data contribution analysis failed: %s', ME.message);
end

%% Summary
fprintf('=== Phase 3 Analysis Complete ===\n');
fprintf('Total figures generated: %d\n', ...
    length(figPaths.configComparison) + ...
    length(figPaths.temporalTrends) + ...
    length(figPaths.softDataContribution));
fprintf('Total tables saved: %d\n', length(figPaths.tables));
fprintf('All outputs saved to: %s\n', opts.saveDir);

end
