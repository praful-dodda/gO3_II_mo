function figPaths = plotBME_SpatialStats(BMEs, obs, go, estParam, varargin)
% plotBME_SpatialStats - Generate comprehensive spatial statistics plots for BME estimates
%
% Creates multiple spatial visualizations including mean estimates, uncertainty
% maps, coefficient of variation, and observation density
%
% SYNTAX:
%   figPaths = plotBME_SpatialStats(BMEs, obs, go, estParam)
%   figPaths = plotBME_SpatialStats(..., 'Name', Value)
%
% INPUTS:
%   BMEs      - BME results structure with fields:
%               .sk, .tk, .YkBMEm (mean), .XkBMEv (variance)
%   obs       - Observation structure from getTOARobservationalData
%   go        - Global offset structure from getTOARglobalOffset
%   estParam  - Estimation parameters structure
%
% OPTIONAL PARAMETERS:
%   'figDir'         - Output directory (default: './5BMEspatialPlots/figs/spatial/')
%   'dpi'            - Figure resolution (default: 300)
%   'visible'        - Figure visibility 'on'/'off' (default: 'off')
%   'plotMean'       - Plot mean estimates (default: true)
%   'plotVariance'   - Plot variance/uncertainty (default: true)
%   'plotCV'         - Plot coefficient of variation (default: true)
%   'plotMultiPanel' - Create 4-panel summary plot (default: true)
%   'saveFormat'     - Save format: 'png', 'pdf', or 'both' (default: 'png')
%
% OUTPUTS:
%   figPaths - Cell array of generated figure paths
%
% NOTES:
%   - Reuses existing plotTOARsBME and plotTOARsBMEvar functions
%   - Adds multi-panel summary and enhanced annotations
%   - Consistent file naming across all plots
%
% EXAMPLE:
%   figPaths = plotBME_SpatialStats(BMEs, obs, go, estParam, ...
%       'plotMultiPanel', true, 'dpi', 300);

%% Parse inputs
p = inputParser;
addRequired(p, 'BMEs', @isstruct);
addRequired(p, 'obs', @isstruct);
addRequired(p, 'go', @isstruct);
addRequired(p, 'estParam', @isstruct);
addParameter(p, 'figDir', fullfile('5BMEspatialPlots', 'figs', 'spatial'), @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'plotMean', true, @islogical);
addParameter(p, 'plotVariance', true, @islogical);
addParameter(p, 'plotCV', true, @islogical);
addParameter(p, 'plotMultiPanel', true, @islogical);
addParameter(p, 'saveFormat', 'png', @(x) ismember(x, {'png', 'pdf', 'both'}));

parse(p, BMEs, obs, go, estParam, varargin{:});
opts = p.Results;

%% Setup
% Create output directory
if ~exist(opts.figDir, 'dir')
    mkdir(opts.figDir);
end

figPaths = {};

% Extract time for file naming
tk = BMEs.tk;
[year, month] = decimalYearToYearMonth(tk);

% Create base filename
BMEmethod = '';
if isfield(BMEs, 'BMEmethod')
    BMEmethod = BMEs.BMEmethod;
elseif isfield(estParam, 'BMEmethod')
    BMEmethod = estParam.BMEmethod;
end

goScenario = go.scenario;
if isfield(BMEs, 'goScenario')
    goScenario = BMEs.goScenario;
end

baseFilename = sprintf('BME%s_go%d_area%d_res%.2f_%04d%02d', ...
    BMEmethod, goScenario, estParam.areaCode, estParam.mapResolution, year, month);

%% Create dummy BMEparam for compatibility with existing plot functions

BMEparam = struct();
BMEparam.BMEmethod8digits = BMEmethod;
BMEparam.dmax = [10, 1, 100];  % Dummy values
BMEparam.nhmax = 30;
BMEparam.nsmax = 60;
BMEparam.order = 0;

%% Plot 1: Mean estimates map

if opts.plotMean
    try
        % Use existing plotTOARsBME function
        estParam.plotResults = 2;  % Plot with observations
        estParam.plotType = 2;  % Mean estimates only

        plotTOARsBME(obs, go, BMEs, BMEparam, estParam);

        % Get the generated filename and move to our directory
        defaultFigDir = fullfile('5BMEspatialPlots', 'figs');
        if exist(defaultFigDir, 'dir')
            % Find most recent figure file
            files = dir(fullfile(defaultFigDir, '*.png'));
            if ~isempty(files)
                [~, idx] = max([files.datenum]);
                latestFile = fullfile(files(idx).folder, files(idx).name);

                % Move to our directory with consistent naming
                newFile = fullfile(opts.figDir, [baseFilename '_mean.png']);
                movefile(latestFile, newFile);
                figPaths{end+1} = newFile;
            end
        end
    catch ME
        warning('Mean plot failed: %s', ME.message);
    end
end

%% Plot 2: Variance/Uncertainty maps

if opts.plotVariance
    try
        % Use existing plotTOARsBMEvar function
        estParam.plotVariance = 1;  % Standard deviation map

        plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam);

        % Get the generated filename and move to our directory
        defaultFigDir = fullfile('5BMEspatialPlots', 'figs', 'variance');
        if exist(defaultFigDir, 'dir')
            files = dir(fullfile(defaultFigDir, '*.png'));
            if ~isempty(files)
                [~, idx] = max([files.datenum]);
                latestFile = fullfile(files(idx).folder, files(idx).name);

                % Move to our directory with consistent naming
                newFile = fullfile(opts.figDir, [baseFilename '_std.png']);
                movefile(latestFile, newFile);
                figPaths{end+1} = newFile;
            end
        end
    catch ME
        warning('Variance plot failed: %s', ME.message);
    end
end

%% Plot 3: Coefficient of Variation

if opts.plotCV
    try
        % Use existing plotTOARsBMEvar function
        estParam.plotVariance = 3;  % Coefficient of variation

        plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam);

        % Get the generated filename and move to our directory
        defaultFigDir = fullfile('5BMEspatialPlots', 'figs', 'variance');
        if exist(defaultFigDir, 'dir')
            files = dir(fullfile(defaultFigDir, '*.png'));
            if ~isempty(files)
                [~, idx] = max([files.datenum]);
                latestFile = fullfile(files(idx).folder, files(idx).name);

                % Move to our directory with consistent naming
                newFile = fullfile(opts.figDir, [baseFilename '_cv.png']);
                movefile(latestFile, newFile);
                figPaths{end+1} = newFile;
            end
        end
    catch ME
        warning('CV plot failed: %s', ME.message);
    end
end

%% Plot 4: Multi-panel summary

if opts.plotMultiPanel
    try
        fig = figure('Visible', opts.visible, 'Position', [100, 100, 1400, 1000]);

        % Clean variance data
        XkBMEv = BMEs.XkBMEv;
        XkBMEv = real(XkBMEv);
        XkBMEv(XkBMEv < 0) = 0;
        stdDev = sqrt(XkBMEv);
        CV = (stdDev ./ abs(BMEs.YkBMEm)) * 100;
        CV(isinf(CV) | CV > 200) = NaN;

        % Panel 1: Mean estimates
        subplot(2, 2, 1);
        plotSpatialPanel(BMEs.sk, BMEs.YkBMEm, 'Ozone Concentration (ppb)', jet(64));
        title('BME Mean Estimates', 'FontSize', 12, 'FontWeight', 'bold');

        % Panel 2: Standard deviation
        subplot(2, 2, 2);
        plotSpatialPanel(BMEs.sk, stdDev, 'Std Dev (ppb)', hot(64));
        title('BME Uncertainty (σ)', 'FontSize', 12, 'FontWeight', 'bold');

        % Panel 3: Coefficient of variation
        subplot(2, 2, 3);
        plotSpatialPanel(BMEs.sk, CV, 'CV (%)', parula(64));
        title('Coefficient of Variation', 'FontSize', 12, 'FontWeight', 'bold');

        % Panel 4: Observation density
        subplot(2, 2, 4);
        plotObservationDensity(BMEs, obs);
        title('Observation Density', 'FontSize', 12, 'FontWeight', 'bold');

        % Overall title
        sgtitle(sprintf('BME Spatial Statistics | %04d-%02d | Method: %s | GO: %d', ...
            year, month, BMEmethod, goScenario), ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Save figure
        figFile = fullfile(opts.figDir, [baseFilename '_summary.png']);
        print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
        figPaths{end+1} = figFile;

        if strcmp(opts.saveFormat, 'both') || strcmp(opts.saveFormat, 'pdf')
            figFilePDF = fullfile(opts.figDir, [baseFilename '_summary.pdf']);
            print(fig, figFilePDF, '-dpdf');
            figPaths{end+1} = figFilePDF;
        end

        if strcmp(opts.visible, 'off')
            close(fig);
        end
    catch ME
        warning('Multi-panel plot failed: %s', ME.message);
        fprintf('  Error details: %s\n', ME.stack(1).name);
    end
end

end

%% Helper functions

function plotSpatialPanel(sk, values, colorbarLabel, colormap_data)
% Plot spatial data with consistent styling

% Remove NaN for color limits
validValues = values(~isnan(values));
if isempty(validValues)
    text(0.5, 0.5, 'No valid data', 'HorizontalAlignment', 'center', 'FontSize', 12);
    return;
end

% Create scatter plot
scatter(sk(:,1), sk(:,2), 20, values, 'filled');
colormap(colormap_data);

% FIX: Get colorbar handle, then set label
cb = colorbar;
cb.Label.String = colorbarLabel;

clim([prctile(validValues, 2), prctile(validValues, 98)]);  % 2-98 percentile

xlabel('Longitude (°E)', 'FontSize', 10);
ylabel('Latitude (°N)', 'FontSize', 10);
grid on;
axis equal tight;

% Add summary statistics
meanVal = mean(validValues, 'omitnan');
stdVal = std(validValues, 'omitnan');
text(0.02, 0.98, sprintf('Mean: %.1f ± %.1f', meanVal, stdVal), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 9, 'BackgroundColor', 'w');
end

function plotObservationDensity(BMEs, obs)
% Plot observation locations and density

% Get observations near this time
% obs.Y is [nStations × nTimes], need to find time index then extract valid stations

% Find time index closest to BMEs.tk (within ±15 days)
timeWindow = 15/365;  % ±15 days
[minTimeDiff, closestTimeIdx] = min(abs(obs.tME - BMEs.tk));

if minTimeDiff > timeWindow
    text(0.5, 0.5, 'No observations', 'HorizontalAlignment', 'center', 'FontSize', 12);
    return;
end

% Extract observations at this time across all stations
obsAtTime = obs.Y(:, closestTimeIdx);
validStations = ~isnan(obsAtTime);

if ~any(validStations)
    text(0.5, 0.5, 'No observations', 'HorizontalAlignment', 'center', 'FontSize', 12);
    return;
end

% Get locations of stations with valid observations
obsLocs = obs.sMS(validStations, :);

% Create density map using 2D histogram
lonEdges = linspace(min(BMEs.sk(:,1)), max(BMEs.sk(:,1)), 50);
latEdges = linspace(min(BMEs.sk(:,2)), max(BMEs.sk(:,2)), 50);
density = histcounts2(obsLocs(:,1), obsLocs(:,2), lonEdges, latEdges);

% Plot density as image
imagesc(lonEdges, latEdges, density');
colormap(flipud(gray));

% FIX: Get colorbar handle, then set label
cb = colorbar;
cb.Label.String = 'Observation Count';

axis xy;

% Overlay observation locations
hold on;
plot(obsLocs(:,1), obsLocs(:,2), 'r.', 'MarkerSize', 3);
hold off;

xlabel('Longitude (°E)', 'FontSize', 10);
ylabel('Latitude (°N)', 'FontSize', 10);
axis equal tight;

% Add count
text(0.02, 0.98, sprintf('Total: %d obs', size(obsLocs, 1)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 9, 'BackgroundColor', 'w', 'Color', 'k');
end

function [year, month] = decimalYearToYearMonth(decimalYear)
% Convert decimal year to year and month integers

year = floor(decimalYear);
fractionalYear = decimalYear - year;
month = round(fractionalYear * 12) + 1;

% Handle edge cases
if month > 12
    month = 12;
end
if month < 1
    month = 1;
end
end
