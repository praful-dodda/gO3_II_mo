function visualizeBMEdiagnostic(BMEresultFile, options)
% visualizeBMEdiagnostic - Diagnostic tool for visualizing BME results
%
% Creates focused diagnostic plots to investigate artifacts like vertical
% lines in standard deviation maps
%
% SYNTAX:
%   visualizeBMEdiagnostic(BMEresultFile, options)
%
% INPUTS:
%   BMEresultFile - Path to saved BME result .mat file
%                   Example: '5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat'
%
%   options       - Structure with fields:
%                   .metric     - 'mean', 'variance', or 'std' (default: 'std')
%                   .display    - 'obs', 'grid', or 'both' (default: 'both')
%                   .colormap   - Colormap name (default: 'jet')
%                   .clim       - Color limits [min max] or 'auto' (default: 'auto')
%                   .markerSize - Size for observation markers (default: 30)
%                   .saveFig    - Save figure to file (default: true)
%
% EXAMPLES:
%   % Quick check of standard deviation with both grid and obs
%   visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat');
%
%   % Grid only, to see interpolation artifacts
%   opts.metric = 'std';
%   opts.display = 'grid';
%   visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat', opts);
%
%   % Observations only, to check data quality
%   opts.metric = 'mean';
%   opts.display = 'obs';
%   visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat', opts);

%% Parse Inputs
if nargin < 1
    error('BME result file path required');
end

if nargin < 2
    options = struct();
end

% Set defaults
if ~isfield(options, 'metric'),     options.metric = 'std'; end
if ~isfield(options, 'display'),    options.display = 'both'; end
if ~isfield(options, 'colormap'),   options.colormap = 'jet'; end
if ~isfield(options, 'clim'),       options.clim = 'auto'; end
if ~isfield(options, 'markerSize'), options.markerSize = 30; end
if ~isfield(options, 'saveFig'),    options.saveFig = true; end

% Validate inputs
validMetrics = {'mean', 'variance', 'std'};
if ~ismember(options.metric, validMetrics)
    error('metric must be one of: %s', strjoin(validMetrics, ', '));
end

validDisplays = {'obs', 'grid', 'both'};
if ~ismember(options.display, validDisplays)
    error('display must be one of: %s', strjoin(validDisplays, ', '));
end

%% Load Data
fprintf('=== BME Diagnostic Visualization ===\n');
fprintf('Loading: %s\n', BMEresultFile);

if ~exist(BMEresultFile, 'file')
    error('File not found: %s', BMEresultFile);
end

data = load(BMEresultFile);
BMEs = data.BMEs;

% Extract relevant data
sk = BMEs.sk;              % Estimation grid [nk x 2] (lon, lat)
tk = BMEs.tk;              % Time
YkBMEm = BMEs.YkBMEm;      % Mean estimates
XkBMEv = BMEs.XkBMEv;      % Variance

% Observations (if available)
if isfield(BMEs, 'sMSobs') && ~isempty(BMEs.sMSobs)
    sMSobs = BMEs.sMSobs;
    Yobs = BMEs.Yobs;
else
    sMSobs = [];
    Yobs = [];
end

%% Prepare Data for Selected Metric
switch options.metric
    case 'mean'
        gridData = YkBMEm;
        obsData = Yobs;
        metricLabel = 'Mean';

    case 'variance'
        gridData = XkBMEv;
        gridData = real(gridData);  % Remove any imaginary parts
        gridData(gridData < 0) = 0;  % Remove negative values
        obsData = [];  % No obs variance typically
        metricLabel = 'Variance';

    case 'std'
        gridData = sqrt(max(0, real(XkBMEv)));
        obsData = [];  % No obs std typically
        metricLabel = 'Standard Deviation';
end

fprintf('Metric: %s\n', metricLabel);
fprintf('Display mode: %s\n', options.display);
fprintf('Grid points: %d\n', length(gridData));
if ~isempty(obsData)
    fprintf('Observation points: %d\n', length(obsData));
end

%% Prepare Color Limits
if strcmp(options.clim, 'auto')
    % Auto-calculate based on what will be displayed
    allData = [];
    if ismember(options.display, {'grid', 'both'})
        allData = [allData; gridData(~isnan(gridData) & ~isinf(gridData))];
    end
    if ismember(options.display, {'obs', 'both'}) && ~isempty(obsData)
        allData = [allData; obsData(~isnan(obsData) & ~isinf(obsData))];
    end

    if ~isempty(allData)
        climLimits = quantest(allData, [0.05 0.95]);
    else
        climLimits = [min(gridData) max(gridData)];
    end
else
    climLimits = options.clim;
end

fprintf('Color range: [%.4f, %.4f]\n', climLimits(1), climLimits(2));

%% Load Border Data (if available)
bordersAvailable = false;
if exist('1data/borderdata.mat', 'file')
    try
        load('1data/borderdata.mat', 'places', 'lon', 'lat');
        bordersAvailable = true;
    catch
        warning('Could not load border data');
    end
end

%% Create Figure
figure('Position', [100 100 1400 900], 'Color', 'w');
hold on;

%% Plot Based on Display Mode
switch options.display
    case 'grid'
        % Grid only - best for seeing interpolation artifacts
        scatter(sk(:,1), sk(:,2), options.markerSize, gridData, 'filled');
        titleStr = sprintf('%s (Grid Only)', metricLabel);

    case 'obs'
        % Observations only - check data quality
        if ~isempty(obsData)
            scatter(sMSobs(:,1), sMSobs(:,2), options.markerSize, obsData, 'filled');
            titleStr = sprintf('%s (Observations Only)', metricLabel);
        else
            warning('No observation data available for this metric');
            scatter(sk(:,1), sk(:,2), options.markerSize, gridData, 'filled');
            titleStr = sprintf('%s (Grid - No Obs Available)', metricLabel);
        end

    case 'both'
        % Both - see relationship between grid and observations
        % First plot grid
        scatter(sk(:,1), sk(:,2), options.markerSize, gridData, 'filled', ...
            'MarkerFaceAlpha', 0.6);

        % Then overlay observations if available
        if ~isempty(obsData)
            scatter(sMSobs(:,1), sMSobs(:,2), options.markerSize*1.5, obsData, 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            titleStr = sprintf('%s (Grid + Observations)', metricLabel);
        else
            titleStr = sprintf('%s (Grid Only - No Obs Available)', metricLabel);
        end
end

%% Add Map Features
% Set colormap and limits
colormap(options.colormap);
clim(climLimits);

% Colorbar
cb = colorbar;
cb.FontSize = 12;
cb.Label.String = metricLabel;
cb.Label.FontSize = 14;

% Borders
if bordersAvailable
    for k = 1:length(places)
        if ~isempty(lon{k})
            plot(lon{k}, lat{k}, 'k-', 'LineWidth', 0.5);
        end
    end
end

%% Formatting
xlabel('Longitude (°)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Latitude (°)', 'FontSize', 14, 'FontWeight', 'bold');

% Create time string
timeStr = sprintf('Time: %.4f', tk);
if abs(tk - round(tk)) < 1e-6
    timeStr = sprintf('Year: %d', round(tk));
elseif abs(tk*12 - round(tk*12)) < 1e-6
    year = floor(tk);
    month = round((tk - year) * 12) + 1;
    timeStr = sprintf('%d-%02d', year, month);
end

title({titleStr, timeStr, ['File: ' strrep(BMEresultFile, '_', '\_')]}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');

% Statistics box
stats = sprintf('N (grid): %d\nMean: %.4f\nStd: %.4f\nMin: %.4f\nMax: %.4f', ...
    sum(~isnan(gridData)), ...
    mean(gridData, 'omitnan'), ...
    std(gridData, 'omitnan'), ...
    min(gridData), ...
    max(gridData));

if ~isempty(obsData)
    stats = [stats sprintf('\n\nN (obs): %d\nObs Mean: %.4f', ...
        sum(~isnan(obsData)), mean(obsData, 'omitnan'))];
end

annotation('textbox', [0.02 0.02 0.2 0.2], 'String', stats, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
    'EdgeColor', 'black', 'FontSize', 11, 'FontWeight', 'bold');

axis equal tight;
grid on;
set(gca, 'FontSize', 12);

% Enable data cursor mode for inspection
dcm = datacursormode(gcf);
set(dcm, 'UpdateFcn', @dataCursorText);

%% Save Figure
if options.saveFig
    figDir = fullfile('5BMEspatialPlots', 'diagnostic');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end

    [~, fname, ~] = fileparts(BMEresultFile);
    figName = sprintf('%s_DIAGNOSTIC_%s_%s.png', fname, options.metric, options.display);
    figPath = fullfile(figDir, figName);

    print(figPath, '-dpng', '-r300');
    fprintf('\nDiagnostic figure saved: %s\n', figPath);
end

fprintf('\nDiagnostic visualization complete.\n');
fprintf('Use the data cursor tool (toolbar) to inspect individual points.\n');
fprintf('Zoom in to examine regions with artifacts.\n\n');

end

%% Helper Function for Data Cursor
function txt = dataCursorText(~, event_obj)
    pos = get(event_obj, 'Position');
    val = get(event_obj, 'Target');
    idx = get(event_obj, 'DataIndex');

    txt = {sprintf('Lon: %.4f', pos(1)), ...
           sprintf('Lat: %.4f', pos(2)), ...
           sprintf('Value: %.4f', val.CData(idx)), ...
           sprintf('Index: %d', idx)};
end
