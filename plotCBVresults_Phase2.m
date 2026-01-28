function figPaths = plotCBVresults_Phase2(cbvResultsDir, varargin)
% plotCBVresults_Phase2 - Advanced CBV diagnostics (Phase 2: Advanced analysis)
%
% Creates advanced diagnostic plots including residual analysis, uncertainty
% quantification, and detailed regional performance breakdown.
%
% SYNTAX:
%   figPaths = plotCBVresults_Phase2(cbvResultsDir)
%   figPaths = plotCBVresults_Phase2(cbvResultsDir, 'Name', Value, ...)
%
% INPUTS:
%   cbvResultsDir - Directory containing CBV result .mat files
%
% OPTIONAL PARAMETERS:
%   'saveDir'     - Base directory to save figures (default: cbvResultsDir/figs_phase2)
%   'dpi'         - Figure resolution (default: 300)
%   'visible'     - 'on' or 'off' for figure visibility (default: 'off')
%   'filePattern' - Pattern to match result files (default: 'CBV_*.mat')
%   'years'       - Years to include in analysis (default: [] = all years)
%   'analysisTypes' - Cell array of analyses to run (default: {'residuals', 'uncertainty', 'regional'})
%   'aggregate'   - Aggregate across all files or process separately (default: true)
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% ANALYSIS TYPES:
%   'residuals'   - Residual analysis plots (obs - pred patterns)
%   'uncertainty' - Uncertainty quantification and calibration
%   'regional'    - Detailed regional performance breakdown
%
% EXAMPLE:
%   % Run all analyses
%   figPaths = plotCBVresults_Phase2('./7validation/CBV', 'visible', 'on');
%
%   % Run only residual and uncertainty analysis
%   figPaths = plotCBVresults_Phase2('./7validation/CBV', ...
%       'analysisTypes', {'residuals', 'uncertainty'});

%% Parse inputs
p = inputParser;
addRequired(p, 'cbvResultsDir', @ischar);
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', 'CBV_*.mat', @ischar);
addParameter(p, 'years', [], @isnumeric);
addParameter(p, 'analysisTypes', {'residuals', 'uncertainty', 'regional'}, @iscell);
addParameter(p, 'aggregate', true, @islogical);

parse(p, cbvResultsDir, varargin{:});
opts = p.Results;

% Set default save directory
if isempty(opts.saveDir)
    opts.saveDir = fullfile(cbvResultsDir, 'figs_phase2');
end

if ~exist(opts.saveDir, 'dir')
    mkdir(opts.saveDir);
end

fprintf('=== Phase 2: Advanced CBV Diagnostics ===\n');
fprintf('Results directory: %s\n', cbvResultsDir);
fprintf('Save directory: %s\n', opts.saveDir);
fprintf('Analysis types: %s\n', strjoin(opts.analysisTypes, ', '));

%% Load all CBV result files
resultFiles = dir(fullfile(cbvResultsDir, opts.filePattern));
if isempty(resultFiles)
    error('No CBV result files found matching pattern: %s', opts.filePattern);
end

fprintf('Found %d CBV result files\n', length(resultFiles));

% Load and aggregate data
allData = [];
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

        if isfield(data, 'annualResults')
            entry = struct();
            entry.Y_obs = data.annualResults.Y_obs;
            entry.Y_est = data.annualResults.Y_est;
            entry.sk = data.annualResults.sk;

            % Optional fields
            if isfield(data.annualResults, 'tk')
                entry.tk = data.annualResults.tk;
            end
            if isfield(data.annualResults, 'XkBMEv')
                entry.XkBMEv = data.annualResults.XkBMEv;
            end
            if isfield(data, 'annualStats')
                if isfield(data.annualStats, 'Year')
                    entry.Year = data.annualStats.Year;
                end
                if isfield(data.annualStats, 'BoxSize')
                    entry.BoxSize = data.annualStats.BoxSize;
                end
                if isfield(data.annualStats, 'Fold')
                    entry.Fold = data.annualStats.Fold;
                end
            end
            if isfield(data, 'valParam')
                entry.valParam = data.valParam;
            end

            % Use year from filename if not in stats
            if ~isfield(entry, 'Year') || isempty(entry.Year) || entry.Year == 0
                entry.Year = fileYear;
            end

            % Assign regions
            entry.regions = assignRegions(entry.sk(:,1), entry.sk(:,2));

            allData = [allData; entry];
        end
    catch ME
        warning('Failed to load %s: %s', resultFiles(i).name, ME.message);
    end
end

if isempty(allData)
    error('No valid data found in result files');
end

fprintf('Loaded data from %d result files\n', length(allData));

figPaths = {};

%% Run selected analyses
for iAnalysis = 1:length(opts.analysisTypes)
    analysisType = opts.analysisTypes{iAnalysis};

    switch lower(analysisType)
        case 'residuals'
            fprintf('\n=== Running Residual Analysis ===\n');
            residualDir = fullfile(opts.saveDir, 'residuals');
            try
                resPaths = plotResidualAnalysis(allData, ...
                    'saveDir', residualDir, ...
                    'dpi', opts.dpi, ...
                    'visible', opts.visible, ...
                    'titlePrefix', 'CBV: ');
                figPaths = [figPaths; resPaths];
                fprintf('Residual analysis complete: %d figures\n', length(resPaths));
            catch ME
                warning('Residual analysis failed: %s', ME.message);
            end

        case 'uncertainty'
            fprintf('\n=== Running Uncertainty Analysis ===\n');
            uncertDir = fullfile(opts.saveDir, 'uncertainty');

            % Check if uncertainty data is available
            hasUncertainty = false;
            for i = 1:length(allData)
                if isfield(allData(i), 'XkBMEv') && ~isempty(allData(i).XkBMEv)
                    hasUncertainty = true;
                    break;
                end
            end

            if hasUncertainty
                try
                    uncertPaths = plotUncertaintyAnalysis(allData, ...
                        'saveDir', uncertDir, ...
                        'dpi', opts.dpi, ...
                        'visible', opts.visible, ...
                        'titlePrefix', 'CBV: ');
                    figPaths = [figPaths; uncertPaths];
                    fprintf('Uncertainty analysis complete: %d figures\n', length(uncertPaths));
                catch ME
                    warning('Uncertainty analysis failed: %s', ME.message);
                end
            else
                warning('XkBMEv (estimation variance) not found in data - skipping uncertainty analysis');
            end

        case 'regional'
            fprintf('\n=== Running Regional Breakdown ===\n');
            regionalDir = fullfile(opts.saveDir, 'regional');
            try
                regPaths = plotRegionalBreakdown(allData, ...
                    'saveDir', regionalDir, ...
                    'dpi', opts.dpi, ...
                    'visible', opts.visible, ...
                    'titlePrefix', 'CBV: ');
                figPaths = [figPaths; regPaths];
                fprintf('Regional breakdown complete: %d figures\n', length(regPaths));
            catch ME
                warning('Regional breakdown failed: %s', ME.message);
            end

        otherwise
            warning('Unknown analysis type: %s', analysisType);
    end
end

fprintf('\n=== Phase 2 diagnostics complete ===\n');
fprintf('Created %d total figures in %s\n', length(figPaths), opts.saveDir);

end
