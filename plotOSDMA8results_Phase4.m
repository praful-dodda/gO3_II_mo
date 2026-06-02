function figPaths = plotOSDMA8results_Phase4(configDirs, configNames, varargin)
% plotOSDMA8results_Phase4 - Enhanced time-series analysis for OSDMA8 configs
%
% OSDMA8 counterpart to plotCBVresults_Phase4. Reads the per-case OSDMA8 files
% produced by runOSDMA8validation (OSDMA8_BME*_box*_fold*_YEAR.mat, each holding
% a `caseRes` struct with osRef/osTest/coords/year), builds per-config, per-year
% metric time series, and plots them with the SAME styling helpers used for CBV
% (getCBVmodelStyles + plotPhase4TimeSeries) so the look matches your paper.
%
% Each year's metrics are computed by pooling osRef (observed OSDMA8) vs osTest
% (estimated OSDMA8) across folds. A grouped-years summary (mean/std across years
% AND metrics pooled over all years) is written to CSV.
%
% SYNTAX:
%   figPaths = plotOSDMA8results_Phase4(configDirs, configNames, 'Name', Value, ...)
%
% INPUTS / OPTIONS: identical to plotCBVresults_Phase4, except 'filePattern'
%   defaults to {'OSDMA8_*.mat'}.
%
% EXAMPLE:
%   dirs = repmat({'./7validation/OSDMA8'}, 1, 2);
%   names = {'Obs. only', 'Obs. + M3fusion'};
%   pats = {'OSDMA8_BME10000133_go3*.mat', 'OSDMA8_BME13000313-02_go3*.mat'};
%   plotOSDMA8results_Phase4(dirs, names, 'filePattern', pats, 'years', 2016:2018);
%
% SEE ALSO: runOSDMA8validation, summarizeOSDMA8forPaper, plotCBVresults_Phase4,
%           getCBVmodelStyles, plotPhase4TimeSeries

%% Parse inputs
p = inputParser;
addRequired(p, 'configDirs', @iscell);
addRequired(p, 'configNames', @iscell);
addParameter(p, 'methodCodes', {}, @iscell);
addParameter(p, 'metrics', {'R2','RMSE','MAE','NMB'}, @iscell);
addParameter(p, 'years', [], @isnumeric);
addParameter(p, 'boxSize', [], @isnumeric);
addParameter(p, 'saveDir', './figs_phase4_osdma8', @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'filePattern', {'OSDMA8_*.mat'}, @iscell);
addParameter(p, 'saveTables', true, @islogical);
addParameter(p, 'plotIndividualMetrics', false, @islogical);
parse(p, configDirs, configNames, varargin{:});
opts = p.Results;

nConfigs = length(configDirs);
if length(configNames) ~= nConfigs
    error('configDirs and configNames must have the same length');
end
if length(opts.filePattern) == 1
    opts.filePattern = repmat(opts.filePattern, 1, nConfigs);
end
if isempty(opts.methodCodes)
    opts.methodCodes = extractMethodCodesFromPatterns(opts.filePattern);
end
if ~exist(opts.saveDir, 'dir'), mkdir(opts.saveDir); end

fprintf('\n=== OSDMA8 Phase 4: Time-Series Analysis ===\n');
fprintf('Configurations: %d | Save dir: %s\n\n', nConfigs, opts.saveDir);

%% Load OSDMA8 per-case data for all configurations
configs = struct();
for iConfig = 1:nConfigs
    fprintf('  [%d/%d] %s\n', iConfig, nConfigs, configNames{iConfig});
    resultFiles = dir(fullfile(configDirs{iConfig}, opts.filePattern{iConfig}));

    configData = [];
    for i = 1:length(resultFiles)
        filePath = fullfile(resultFiles(i).folder, resultFiles(i).name);
        [~, fname, ~] = fileparts(resultFiles(i).name);
        yearMatch = regexp(fname, '_(\d{4})$', 'tokens');
        fileYear = NaN;
        if ~isempty(yearMatch), fileYear = str2double(yearMatch{1}{1}); end
        if ~isempty(opts.years) && ~isnan(fileYear) && ~ismember(fileYear, opts.years)
            continue;
        end
        % Optional box-size filter (parse from filename _box%.1f_)
        if ~isempty(opts.boxSize)
            bm = regexp(fname, '_box([0-9.]+)_', 'tokens');
            if ~isempty(bm) && abs(str2double(bm{1}{1}) - opts.boxSize) > 1e-6
                continue;
            end
        end
        try
            data = load(filePath, 'caseRes');
            if isfield(data, 'caseRes')
                cr = data.caseRes;
                entry = struct();
                entry.Y_obs = cr.osRef(:);     % observed OSDMA8 (reference)
                entry.Y_est = cr.osTest(:);    % estimated OSDMA8 (test)
                if isfield(cr, 'coords'), entry.sk = cr.coords; else, entry.sk = []; end
                entry.Year = cr.year;
                if isempty(entry.Year) || entry.Year == 0, entry.Year = fileYear; end
                configData = [configData; entry]; %#ok<AGROW>
            end
        catch ME
            warning('Failed to load %s: %s', resultFiles(i).name, ME.message);
        end
    end
    configs(iConfig).name = configNames{iConfig};
    configs(iConfig).data = configData;
    configs(iConfig).nFiles = length(configData);
    fprintf('    Loaded %d case entries\n', length(configData));
end
fprintf('\n');

%% Colors and styles (shared with CBV for visual consistency)
[colors, lineStyles, markers, lineWidths] = getCBVmodelStyles(opts.methodCodes, configNames);

%% Build time-series data (pool folds per year, NaN for missing years)
yearlyData = prepareTimeSeriesData(configs, opts);
fprintf('Years: %s | Metrics: %s\n\n', mat2str(yearlyData.years), strjoin(opts.metrics, ', '));

%% Plots (own time-series plotter with AUTO y-limits, CBV styling reused)
% NOTE: we intentionally do NOT call plotPhase4TimeSeries here - it hardcodes
% R2/RMSE y-limits tuned for CBV monthly data, which would clip OSDMA8 values
% (e.g. obs-only baseline R2 ~0.54 < its 0.6 floor).
figPaths = struct('timeseries', {{}}, 'tables', {{}});
try
    figs = localTimeSeriesPlot(yearlyData, configs, colors, lineStyles, markers, lineWidths, opts);
    figPaths.timeseries = figs;
catch ME
    warning('OSDMA8 time-series plotting failed: %s', ME.message);
end

%% Tables (per-year + grouped-years summary)
if opts.saveTables
    try
        figPaths.tables = saveOSDMA8tables(yearlyData, configs, opts);
    catch ME
        warning('Table saving failed: %s', ME.message);
    end
end

fprintf('\n=== OSDMA8 Phase 4 complete: %d figures, %d tables -> %s ===\n', ...
    numel(figPaths.timeseries), numel(figPaths.tables), opts.saveDir);
end

% ========================================================================
function methodCodes = extractMethodCodesFromPatterns(patterns)
methodCodes = cell(size(patterns));
for i = 1:length(patterns)
    match = regexp(patterns{i}, 'BME(\d{8}(?:-[0-9A-Fa-f]{2})?)', 'tokens');
    if ~isempty(match), methodCodes{i} = match{1}{1}; else, methodCodes{i} = ''; end
end
end

% ------------------------------------------------------------------------
function yearlyData = prepareTimeSeriesData(configs, opts)
if isempty(opts.years)
    allYears = [];
    for iConfig = 1:length(configs)
        if ~isempty(configs(iConfig).data)
            allYears = [allYears, [configs(iConfig).data.Year]]; %#ok<AGROW>
        end
    end
    allYears = sort(unique(allYears(~isnan(allYears))));
else
    allYears = opts.years;
end

nConfigs = length(configs);
nYears = length(allYears);
nMetrics = length(opts.metrics);

yearlyData = struct();
yearlyData.years  = allYears;
yearlyData.values = NaN(nConfigs, nYears, nMetrics);
yearlyData.N      = zeros(nConfigs, nYears);
metricIdx = containers.Map(opts.metrics, 1:nMetrics);

for iConfig = 1:nConfigs
    data = configs(iConfig).data;
    if isempty(data), continue; end
    for year = unique([data.Year])
        yi = find(allYears == year);
        if isempty(yi), continue; end
        yo = []; ye = [];
        for i = 1:length(data)
            if data(i).Year == year
                yo = [yo; data(i).Y_obs(:)]; %#ok<AGROW>
                ye = [ye; data(i).Y_est(:)]; %#ok<AGROW>
            end
        end
        v = ~isnan(yo) & ~isnan(ye);
        yo = yo(v); ye = ye(v);
        if isempty(yo), continue; end
        yearlyData.N(iConfig, yi) = numel(yo);
        if isKey(metricIdx, 'R2')
            yearlyData.values(iConfig, yi, metricIdx('R2')) = localR2(yo, ye);
        end
        if isKey(metricIdx, 'RMSE')
            yearlyData.values(iConfig, yi, metricIdx('RMSE')) = sqrt(mean((yo-ye).^2));
        end
        if isKey(metricIdx, 'MAE')
            yearlyData.values(iConfig, yi, metricIdx('MAE')) = mean(abs(yo-ye));
        end
        if isKey(metricIdx, 'NMB')
            yearlyData.values(iConfig, yi, metricIdx('NMB')) = 100*mean(ye-yo)/mean(yo);
        end
    end
end
end

% ------------------------------------------------------------------------
function figPaths = localTimeSeriesPlot(yearlyData, configs, colors, lineStyles, markers, lineWidths, opts)
% OSDMA8 time-series: multi-panel metrics over years (auto y-limits) plus a
% grouped-years average bar. Styling matches CBV via the passed-in style arrays.
figPaths = {};
allYears = yearlyData.years;
nYears   = numel(allYears);
nConfigs = size(yearlyData.values, 1);
metrics  = opts.metrics;
nMetrics = numel(metrics);
if nConfigs < 1 || nYears < 1, warning('No data to plot'); return; end

% Box-size label for titles (e.g., "20 deg CBV")
if isfield(opts, 'boxSize') && ~isempty(opts.boxSize)
    boxLabel = sprintf('%g%s CBV', opts.boxSize, char(176));
else
    boxLabel = 'CBV';
end

% Manuscript-quality font sizes (match plotPhase4TimeSeries)
axFont    = 15;   % tick labels
labelFont = 16;   % axis labels
titleFont = 18;   % titles
legFont   = 13;   % legend

hasData = false(nConfigs, 1);
for iC = 1:nConfigs
    hasData(iC) = any(~isnan(yearlyData.values(iC, :, :)), 'all');
end

%% Figure 1: metrics over years (one panel per metric)
nLegendCols = 4;
legRows = ceil(sum(hasData)/nLegendCols);
fig1 = figure('Visible', opts.visible, 'Position', [100 100 1400 320*nMetrics + 60 + 24*legRows]);
h = gobjects(nConfigs, 1);
ax = gobjects(nMetrics, 1); axpos = cell(nMetrics, 1);
for iM = 1:nMetrics
    ax(iM) = subplot(nMetrics, 1, iM); hold on;
    for iC = 1:nConfigs
        vals = squeeze(yearlyData.values(iC, :, iM));
        hh = plot(allYears, vals, 'LineStyle', lineStyles{iC}, 'Color', colors(iC,:), ...
            'Marker', markers{iC}, 'LineWidth', lineWidths(iC), 'MarkerSize', 7, ...
            'MarkerFaceColor', colors(iC,:), 'DisplayName', configs(iC).name);
        if iM == 1, h(iC) = hh; end
    end
    set(gca, 'FontSize', axFont);
    ylabel(metrics{iM}, 'FontSize', labelFont); grid on; box on;
    title(sprintf('OSDMA8 %s | %s', metrics{iM}, boxLabel), ...
        'FontSize', titleFont, 'FontWeight', 'bold');
    if nYears > 1, xlim([min(allYears)-0.5 max(allYears)+0.5]); end
    xticks(allYears); ylim auto;     % AUTO limits (no clipping)
    if iM == nMetrics, xlabel('Year', 'FontSize', labelFont); end
    axpos{iM} = ax(iM).Position;
end
lgd = legend(h(hasData), {configs(hasData).name}, 'Orientation', 'horizontal', ...
    'NumColumns', min(nLegendCols, sum(hasData)));
lgd.FontSize = legFont; lgd.Units = 'normalized';
lgd.Position(1) = 0.5 - lgd.Position(3)/2; lgd.Position(2) = 0.01;
for iM = 1:nMetrics, ax(iM).Position = axpos{iM}; end
f1 = fullfile(opts.saveDir, 'osdma8_phase4_timeseries_metrics.png');
print(fig1, f1, '-dpng', sprintf('-r%d', opts.dpi)); figPaths{end+1} = f1;
fprintf('  Saved: %s\n', f1);
if strcmp(opts.visible, 'off'), close(fig1); end

%% Figure 2: grouped-years average per config (bar)
fig2 = figure('Visible', opts.visible, 'Position', [100 100 max(700, 180*nConfigs) 320*nMetrics]);
for iM = 1:nMetrics
    subplot(nMetrics, 1, iM); hold on;
    avg = nan(nConfigs,1); sd = nan(nConfigs,1);
    for iC = 1:nConfigs
        v = squeeze(yearlyData.values(iC, :, iM));
        avg(iC) = mean(v, 'omitnan'); sd(iC) = std(v, 'omitnan');
    end
    b = bar(1:nConfigs, avg, 0.7, 'FaceColor', 'flat');
    for iC = 1:nConfigs, b.CData(iC,:) = colors(iC,:); end
    errorbar(1:nConfigs, avg, sd, 'k', 'LineStyle', 'none', 'LineWidth', 1);
    ylabel(metrics{iM}, 'FontSize', labelFont); grid on; box on;
    title(sprintf('Grouped-years mean OSDMA8 %s (\\pm std) | %s', metrics{iM}, boxLabel), ...
        'FontSize', titleFont - 2, 'FontWeight', 'bold');
    set(gca, 'XTick', 1:nConfigs, 'XTickLabel', {configs.name}, ...
        'XTickLabelRotation', 25, 'FontSize', axFont);
end
f2 = fullfile(opts.saveDir, 'osdma8_phase4_grouped_years_bar.png');
print(fig2, f2, '-dpng', sprintf('-r%d', opts.dpi)); figPaths{end+1} = f2;
fprintf('  Saved: %s\n', f2);
if strcmp(opts.visible, 'off'), close(fig2); end
end

% ------------------------------------------------------------------------
function r2 = localR2(obs, est)
if isempty(obs), r2 = NaN; return; end
cc = corrcoef(obs, est);
r2 = cc(1,2)^2;
end

% ------------------------------------------------------------------------
function tablePaths = saveOSDMA8tables(yearlyData, configs, opts)
tablePaths = {};
nConfigs = length(configs);
nYears   = length(yearlyData.years);
nMetrics = length(opts.metrics);

% Table 1: per-year long-format
rows = {};
for iC = 1:nConfigs
    for iY = 1:nYears
        row = {configs(iC).name, yearlyData.years(iY)};
        for iM = 1:nMetrics, row{end+1} = yearlyData.values(iC, iY, iM); end %#ok<AGROW>
        row{end+1} = yearlyData.N(iC, iY); %#ok<AGROW>
        rows = [rows; row]; %#ok<AGROW>
    end
end
T1 = cell2table(rows, 'VariableNames', ['Configuration','Year',opts.metrics,'N']);
f1 = fullfile(opts.saveDir, 'osdma8_phase4_timeseries_data.csv');
writetable(T1, f1); tablePaths{end+1} = f1;
fprintf('    Saved: %s\n', f1);

% Table 2: grouped-years summary — mean/std ACROSS years + pooled-all-years
rows2 = {};
for iC = 1:nConfigs
    row = {configs(iC).name};
    for iM = 1:nMetrics
        vals = squeeze(yearlyData.values(iC, :, iM));
        row{end+1} = mean(vals, 'omitnan'); %#ok<AGROW>
        row{end+1} = std(vals, 'omitnan');  %#ok<AGROW>
    end
    % Pooled-all-years metrics (concatenate raw OSDMA8 pairs across years/folds)
    yo = []; ye = [];
    for i = 1:numel(configs(iC).data)
        yo = [yo; configs(iC).data(i).Y_obs(:)]; %#ok<AGROW>
        ye = [ye; configs(iC).data(i).Y_est(:)]; %#ok<AGROW>
    end
    v = ~isnan(yo) & ~isnan(ye); yo = yo(v); ye = ye(v);
    if numel(yo) >= 2
        s = calculateValidationStats(yo, ye);
        row{end+1} = s.R2;   %#ok<AGROW>
        row{end+1} = s.RMSE; %#ok<AGROW>
        row{end+1} = numel(yo); %#ok<AGROW>
    else
        row{end+1} = NaN; row{end+1} = NaN; row{end+1} = numel(yo); %#ok<AGROW>
    end
    rows2 = [rows2; row]; %#ok<AGROW>
end
vn = {'Configuration'};
for iM = 1:nMetrics
    vn{end+1} = [opts.metrics{iM} '_MeanAcrossYears']; %#ok<AGROW>
    vn{end+1} = [opts.metrics{iM} '_StdAcrossYears'];  %#ok<AGROW>
end
vn = [vn, {'R2_PooledAllYears','RMSE_PooledAllYears','N_PooledAllYears'}];
T2 = cell2table(rows2, 'VariableNames', vn);
f2 = fullfile(opts.saveDir, 'osdma8_phase4_grouped_years_summary.csv');
writetable(T2, f2); tablePaths{end+1} = f2;
fprintf('    Saved: %s\n', f2);
end
