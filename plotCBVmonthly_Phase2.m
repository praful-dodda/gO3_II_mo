function figPaths = plotCBVmonthly_Phase2(cbvMonthlyDir, varargin)
% plotCBVmonthly_Phase2 - Advanced monthly CBV diagnostics (Phase 2)
%
% Parallel to plotCBVresults_Phase2 but operates on monthly .mat files.
% Groups residuals and uncertainty by calendar month.
% Delegates aggregate analysis to existing plotResidualAnalysis and
% plotRegionalBreakdown functions.
%
% SYNTAX:
%   figPaths = plotCBVmonthly_Phase2(cbvMonthlyDir)
%   figPaths = plotCBVmonthly_Phase2(cbvMonthlyDir, 'Name', Value, ...)
%
% INPUTS:
%   cbvMonthlyDir - Directory containing monthly CBV .mat files
%
% OPTIONAL PARAMETERS:
%   'saveDir'       - Base directory for figures (default: cbvMonthlyDir/../figs_monthly_phase2)
%   'dpi'           - Figure resolution (default: 300)
%   'visible'       - 'on' or 'off' (default: 'off')
%   'filePattern'   - Glob pattern (default: 'CBV_*_??_??.mat')
%   'years'         - Years to include (default: [] = all)
%   'analysisTypes' - Cell array: {'residuals','uncertainty','regional'}
%                     (default: all three)
%
% OUTPUTS:
%   figPaths - Cell array of saved figure paths
%
% PRODUCES (under saveDir):
%   residuals/CBV_monthly_residuals_by_month.png  — boxplot of (est-obs) per month
%   residuals/  — standard residual analysis plots (via plotResidualAnalysis)
%   uncertainty/CBV_monthly_uncertainty_by_month.png — mean var per month
%   uncertainty/ — standard uncertainty plots (via plotUncertaintyAnalysis)
%   regional/   — regional breakdown (via plotRegionalBreakdown)
%
% SEE ALSO:
%   plotCBVresults_Phase2, plotCBVmonthly_Phase1, example_plotCBV_monthly

%% Parse inputs
p = inputParser;
addRequired(p, 'cbvMonthlyDir', @ischar);
addParameter(p, 'saveDir', '', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', 'CBV_*_??_??.mat', @ischar);
addParameter(p, 'years', [], @isnumeric);
addParameter(p, 'analysisTypes', {'residuals', 'uncertainty', 'regional'}, @iscell);

parse(p, cbvMonthlyDir, varargin{:});
opts = p.Results;

if isempty(opts.saveDir)
    opts.saveDir = fullfile(cbvMonthlyDir, '..', 'figs_monthly_phase2');
end
if ~exist(opts.saveDir, 'dir'), mkdir(opts.saveDir); end

monthAbbr = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};

fprintf('=== Monthly Phase 2: Advanced Monthly CBV Diagnostics ===\n');
fprintf('Results directory: %s\n', cbvMonthlyDir);
fprintf('Save directory: %s\n', opts.saveDir);
fprintf('Analysis types: %s\n', strjoin(opts.analysisTypes, ', '));

%% Load all monthly CBV result files (identical to plotCBVmonthly_Phase1)
resultFiles = dir(fullfile(cbvMonthlyDir, opts.filePattern));
if isempty(resultFiles)
    error('No monthly CBV files found matching: %s\n  in: %s', opts.filePattern, cbvMonthlyDir);
end

fprintf('Found %d monthly CBV files\n', length(resultFiles));

allData = [];
for i = 1:length(resultFiles)
    filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);
    [~, fname, ~] = fileparts(resultFiles(i).name);

    ymMatch = regexp(fname, '_(\d{4})_(\d{2})$', 'tokens');
    if isempty(ymMatch), continue; end
    fileYear  = str2double(ymMatch{1}{1});
    fileMonth = str2double(ymMatch{1}{2});
    if ~isempty(opts.years) && ~ismember(fileYear, opts.years), continue; end

    boxMatch  = regexp(fname, '_box([\d.]+)_', 'tokens');
    foldMatch = regexp(fname, '_fold(\d+)_', 'tokens');
    fileBoxSize = NaN;  fileFold = NaN;
    if ~isempty(boxMatch),  fileBoxSize = str2double(boxMatch{1}{1}); end
    if ~isempty(foldMatch), fileFold    = str2double(foldMatch{1}{1}); end

    try
        data = load(filePath);
        if ~isfield(data, 'monthResults'), continue; end
        mr = data.monthResults;
        if isempty(mr.Y_obs) || isempty(mr.Y_est), continue; end

        entry         = struct();
        entry.Y_obs   = mr.Y_obs(:);
        entry.Y_est   = mr.Y_est(:);
        entry.sk      = mr.sk;
        entry.tk      = mr.tk(:);
        entry.Year    = fileYear;
        entry.Month   = fileMonth;
        entry.BoxSize = fileBoxSize;
        entry.Fold    = fileFold;
        if isfield(mr, 'XkBMEv'), entry.XkBMEv = mr.XkBMEv(:); end

        entry.regions = assignRegions(mr.sk(:,1), mr.sk(:,2));

        allData = [allData; entry]; %#ok<AGROW>
    catch ME
        warning('plotCBVmonthly_Phase2:loadFail', 'Failed to load %s: %s', fname, ME.message);
    end
end

if isempty(allData)
    error('No valid monthly data found. Check filePattern and directory.');
end

fprintf('Loaded %d monthly entries\n', length(allData));

figPaths = {};

%% Dispatch analysis types (mirrors plotCBVresults_Phase2.m lines 147-214)
for iAnalysis = 1:length(opts.analysisTypes)
    switch lower(opts.analysisTypes{iAnalysis})

        case 'residuals'
            fprintf('\n=== Monthly Residual Analysis ===\n');
            residualDir = fullfile(opts.saveDir, 'residuals');
            if ~exist(residualDir, 'dir'), mkdir(residualDir); end

            % New: residual boxplot by calendar month
            figPaths = [figPaths; plotResidualsByMonth(allData, monthAbbr, residualDir, opts)];

            % Standard residual analysis with all data (from plotResidualAnalysis.m)
            try
                resPaths = plotResidualAnalysis(allData, ...
                    'saveDir', residualDir, 'dpi', opts.dpi, ...
                    'visible', opts.visible, 'titlePrefix', 'CBV Monthly: ');
                figPaths = [figPaths; resPaths];
                fprintf('Standard residual analysis: %d figures\n', length(resPaths));
            catch ME
                warning('plotResidualAnalysis failed: %s', ME.message);
            end

        case 'uncertainty'
            fprintf('\n=== Monthly Uncertainty Analysis ===\n');
            uncertDir = fullfile(opts.saveDir, 'uncertainty');
            if ~exist(uncertDir, 'dir'), mkdir(uncertDir); end

            hasUncertainty = any(arrayfun( ...
                @(e) isfield(e, 'XkBMEv') && ~isempty(e.XkBMEv), allData));

            if hasUncertainty
                % New: mean uncertainty by calendar month
                figPaths = [figPaths; plotUncertaintyByMonth(allData, monthAbbr, uncertDir, opts)];

                try
                    uncertPaths = plotUncertaintyAnalysis(allData, ...
                        'saveDir', uncertDir, 'dpi', opts.dpi, ...
                        'visible', opts.visible, 'titlePrefix', 'CBV Monthly: ');
                    figPaths = [figPaths; uncertPaths];
                    fprintf('Standard uncertainty analysis: %d figures\n', length(uncertPaths));
                catch ME
                    warning('plotUncertaintyAnalysis failed: %s', ME.message);
                end
            else
                warning('XkBMEv (estimation variance) not found — skipping uncertainty analysis');
            end

        case 'regional'
            fprintf('\n=== Monthly Regional Breakdown ===\n');
            regionalDir = fullfile(opts.saveDir, 'regional');
            if ~exist(regionalDir, 'dir'), mkdir(regionalDir); end

            try
                regPaths = plotRegionalBreakdown(allData, ...
                    'saveDir', regionalDir, 'dpi', opts.dpi, ...
                    'visible', opts.visible, 'titlePrefix', 'CBV Monthly: ');
                figPaths = [figPaths; regPaths];
                fprintf('Regional breakdown: %d figures\n', length(regPaths));
            catch ME
                warning('plotRegionalBreakdown failed: %s', ME.message);
            end

        otherwise
            warning('Unknown analysis type: %s', opts.analysisTypes{iAnalysis});
    end
end

fprintf('\n=== Monthly Phase 2 complete — %d figures in %s ===\n', length(figPaths), opts.saveDir);

end  % main function


%% ========================================================================
%% Local: Residual boxplot by calendar month
%% ========================================================================
function figPaths = plotResidualsByMonth(allData, monthAbbr, saveDir, opts)

figPaths = {};

% Collect (Y_est - Y_obs) per calendar month
residualsByMonth = cell(12, 1);
for i = 1:length(allData)
    m   = allData(i).Month;
    res = allData(i).Y_est - allData(i).Y_obs;
    res = res(isfinite(res));
    residualsByMonth{m} = [residualsByMonth{m}; res];
end

% Check there is data
nTotal = sum(cellfun(@numel, residualsByMonth));
if nTotal == 0
    warning('No finite residuals found — skipping residuals-by-month plot');
    return;
end

% Build vectors for boxplot
allRes   = [];
groupVec = [];
for m = 1:12
    r = residualsByMonth{m};
    allRes   = [allRes;   r]; %#ok<AGROW>
    groupVec = [groupVec; repmat(m, numel(r), 1)]; %#ok<AGROW>
end

fig = figure('Visible', opts.visible, 'Position', [100 100 1200 500]);
hold on;

boxplot(allRes, groupVec, 'Labels', monthAbbr, 'Symbol', '.', 'Whisker', 1.5);
yline(0, 'r-', 'LineWidth', 2);

xlabel('Month', 'FontSize', 12);
ylabel('Residual Y_{est} − Y_{obs} (ppbv)', 'FontSize', 12);
title('CBV Residuals by Calendar Month (All Years, Folds, Box Sizes)', ...
    'FontSize', 13, 'FontWeight', 'bold');
grid on;

figPath = saveTOARfigure(fig, 'CBV_monthly_residuals_by_month', saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;
if strcmp(opts.visible, 'off'), close(fig); end

end


%% ========================================================================
%% Local: Mean estimation variance by calendar month
%% ========================================================================
function figPaths = plotUncertaintyByMonth(allData, monthAbbr, saveDir, opts)

figPaths = {};

meanSigma = NaN(12, 1);
for m = 1:12
    idx = find([allData.Month] == m);
    sigVals = [];
    for k = idx
        if isfield(allData(k), 'XkBMEv') && ~isempty(allData(k).XkBMEv)
            sigVals = [sigVals; allData(k).XkBMEv(isfinite(allData(k).XkBMEv))]; %#ok<AGROW>
        end
    end
    if ~isempty(sigVals)
        meanSigma(m) = mean(sigVals);
    end
end

if all(isnan(meanSigma))
    warning('No XkBMEv data found — skipping uncertainty-by-month plot');
    return;
end

fig = figure('Visible', opts.visible, 'Position', [100 100 900 400]);
bar(1:12, meanSigma, 'FaceColor', [0.4 0.6 0.9]);
set(gca, 'XTick', 1:12, 'XTickLabel', monthAbbr);
xlabel('Month', 'FontSize', 12);
ylabel('Mean Estimation Variance', 'FontSize', 12);
title('CBV Estimation Uncertainty by Calendar Month', 'FontSize', 13, 'FontWeight', 'bold');
grid on;

figPath = saveTOARfigure(fig, 'CBV_monthly_uncertainty_by_month', saveDir, 'dpi', opts.dpi);
figPaths{end+1} = figPath;
if strcmp(opts.visible, 'off'), close(fig); end

end
