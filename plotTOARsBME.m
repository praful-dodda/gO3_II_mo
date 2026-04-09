function plotTOARsBME(obs, go, BMEs, BMEparam, estParam, dispParam)
% plotTOARsBME - Plot TOAR BME spatial estimates with observations
%
% Creates maps of BME estimated ozone concentrations with optional
% observation overlay
%
% SYNTAX:
%   plotTOARsBME(obs, go, BMEs, BMEparam, estParam)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   BMEs     - BME results structure with fields:
%              .sk, .tk, .YkBMEm, .XkBMEm, .XkBMEv, .sMSobs, .Yobs
%   BMEparam - BME parameters with fields:
%              .covModel - Covariance model parameters
%   estParam - Estimation parameters with fields:
%              .plotResults - Plot type:
%                             1 = BME estimates only
%                             2 = BME estimates + observations
%                             3 = Residuals (offset-removed)
%                             4 = BME uncertainty (std dev)
%              .areaCode, .mapResolution (for file naming)
%   dispParam - Display parameters (optiona)
%              .nxpix - Number of pixels in x-direction (default=150)
%              .nypix - Number of pixels in y-direction (default=100)
%              .bufferDist - Buffer distance for masking (default=0.5 degrees)
%              .bufferType - 'soft' (gradual fade) or 'hard' (sharp cut) (default='soft')
%              .interpMethod - Interpolation method for griddata (default='natural')
%
% OUTPUTS:
%   Saves figures to ./5BMEspatialPlots/figs/
%
% EXAMPLE:
%   plotTOARsBME(obs, go, BMEs, BMEparam, estParam);

if nargin < 5
    error('All 4 inputs required. See help plotTOARsBME');
end

if nargin < 6
    dispParam = struct();
    % set initial defaults for display parameters
    dispParam.nxpix = 150;
    dispParam.nypix = 100;
    dispParam.bufferDist = 0.5;  % degrees
    dispParam.bufferType = 'soft';  % 'soft' or 'hard'
    dispParam.interpMethod = 'natural';  % 'natural', 'linear', 'cubic', 'nearest', or 'v4'
else
    % Set defaults for display parameters
    if ~isfield(dispParam, 'nxpix'), dispParam.nxpix = 150; end
    if ~isfield(dispParam, 'nypix'), dispParam.nypix = 100; end
    if ~isfield(dispParam, 'bufferDist'), dispParam.bufferDist = 0.5; end
    if ~isfield(dispParam, 'bufferType'), dispParam.bufferType = 'soft'; end
    if ~isfield(dispParam, 'interpMethod'), dispParam.interpMethod = 'natural'; end
end

%% Setup
plotType = estParam.plotResults;
areaCode = estParam.areaCode;
mapResolution = estParam.mapResolution;
tk = BMEs.tk;
displayArea = BMEs.estGridArea;

% Get keepOnlyLand parameter (default to true)
keepOnlyLand = true;
if isfield(estParam, 'keepOnlyLand')
    keepOnlyLand = estParam.keepOnlyLand;
end

% Directories
dataDir = '1data';

% check if the figDir field exists in estParam, otherwise use default
if isfield(estParam, 'figDir')
    figDir = estParam.figDir;
else
    figDir = fullfile('5BMEspatialPlots', 'figs');
end

if ~exist(figDir, 'dir'), mkdir(figDir); end

% Color range for concentrations
yrangeQuant = [0.05 0.95];
allValues = BMEs.YkBMEm(~isnan(BMEs.YkBMEm));
if ~isempty(BMEs.Yobs)
    allValues = [allValues; BMEs.Yobs(~isnan(BMEs.Yobs))];
end
yrange = quantest(allValues, yrangeQuant);

% Colormap
useCustomColormap = false;
if exist('NoraColormap.m', 'file')
    cmap = NoraColormap;
    useCustomColormap = true;
else
    cmap = jet(64);
end

%% Setup Mask Contour
% When keepOnlyLand is true, use land contour to mask ocean areas
% Otherwise, use country borders for reference
maskcontour = [];

if keepOnlyLand
    % Get land boundary contour for ocean masking
    fprintf('  Setting up land contour for ocean masking...\n');
    maskcontour = getLandContour(dataDir);
else
    % Use country borders (if available) for reference
    if exist(fullfile(dataDir, 'borderdata.mat'), 'file')
        load(fullfile(dataDir, 'borderdata.mat'), 'places', 'lon', 'lat');

        % Combine all country boundaries
        for k = 1:length(places)
            if ~isempty(lon{k})
                maskcontour = [maskcontour; [lon{k}(:), lat{k}(:)]; [NaN, NaN]];
            end
        end
    end
end

%% Create Figure
% figure('Position', [100 100 1200 800]);
% hold on;

%% Plot Based on Type
switch plotType
    case 1  % BME estimates only
        plotFieldTOAR(BMEs.sk, BMEs.YkBMEm, displayArea, maskcontour, dispParam.nxpix, dispParam.nypix, dispParam.bufferDist, dispParam.bufferType, dispParam.interpMethod, dispParam.dxRes, dispParam.dyRes);
        clim(yrange);
        plotTitle = sprintf('%s BME Estimate', obs.Zname);
        figSuffix = 'BME';
        
    case 2  % BME estimates + observations
        plotFieldTOAR(BMEs.sk, BMEs.YkBMEm, displayArea, maskcontour, dispParam.nxpix, dispParam.nypix, dispParam.bufferDist, dispParam.bufferType, dispParam.interpMethod, dispParam.dxRes, dispParam.dyRes);
        clim(yrange);
        
        % Overlay observations
        if ~isempty(BMEs.Yobs)
            Property = {'Marker', 'MarkerSize', 'MarkerEdgeColor'};
            Value = {'o', 8, 'k'};
            colorplot(BMEs.sMSobs, BMEs.Yobs, cmap, Property, Value, yrange);
        end
        plotTitle = sprintf('%s BME Estimate + Observations', obs.Zname);
        figSuffix = 'BME_obs';
        
    case 3  % Residuals (offset-removed)
        plotFieldTOAR(BMEs.sk, BMEs.XkBMEm, displayArea, maskcontour, dispParam.nxpix, dispParam.nypix, dispParam.bufferDist, dispParam.bufferType, dispParam.interpMethod, dispParam.dxRes, dispParam.dyRes);
        xrange = quantest(BMEs.XkBMEm(~isnan(BMEs.XkBMEm)), yrangeQuant);
        clim(xrange);
        
        % Overlay residual observations
        if ~isempty(BMEs.Xobs)
            Property = {'Marker', 'MarkerSize', 'MarkerEdgeColor'};
            Value = {'o', 8, 'k'};
            colorplot(BMEs.sMSobs, BMEs.Xobs, cmap, Property, Value, xrange);
        end
        plotTitle = sprintf('%s Residuals (Offset-Removed)', obs.Yname);
        figSuffix = 'residuals';
        
    case 4  % BME uncertainty
        % Plot standard deviation
        stdDev = sqrt(max(0, BMEs.XkBMEv));
        plotFieldTOAR(BMEs.sk, stdDev, displayArea, maskcontour, dispParam.nxpix, dispParam.nypix, dispParam.bufferDist, dispParam.bufferType, dispParam.interpMethod, dispParam.dxRes, dispParam.dyRes);
        stdRange = quantest(stdDev(~isnan(stdDev)), [0 0.95]);
        clim(stdRange);
        plotTitle = sprintf('%s BME Uncertainty (Std Dev)', obs.Zname);
        figSuffix = 'uncertainty';
        
    otherwise
        error('plotResults must be 1 (BME only), 2 (BME+obs), 3 (residuals), or 4 (uncertainty)');
end

%% Add Map Features
% Set colormap
colormap(cmap);

% Add country borders
% if bordersAvailable
%     for k = 1:length(places)
%         if ~isempty(lon{k})
%             plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
%         end
%     end
% end

% Add colorbar
cb = colorbar;
if plotType == 4
    ylabel(cb, sprintf('Std Dev (%s)', obs.Zunit), 'FontSize', 12);
else
    ylabel(cb, obs.Zlabel, 'FontSize', 12);
end

%% Labels and Title
xlabel('Longitude (deg)', 'FontSize', 14);
ylabel('Latitude (deg)', 'FontSize', 14);

% Create detailed title
timeStr = sprintf('Time: %.2f', tk);
if abs(tk - round(tk)) < 1e-6
    % Annual
    timeStr = sprintf('Year: %d', round(tk));
elseif abs(tk*12 - round(tk*12)) < 1e-6
    % Monthly
    year = floor(tk);
    month = round((tk - year) * 12) + 1;
    timeStr = sprintf('Year: %d, Month: %d', year, month);
end

title({plotTitle, timeStr, ...
    sprintf('BME Method: %s, GO Scenario: %d, Area: %d, Resolution: %.2f°, Format: %s', ...
    BMEparam.BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat)}, 'FontSize', 14);

% Add statistics text box
if plotType <= 2
    stats = sprintf('Mean: %.2f %s\nStd: %.2f %s\nMin: %.2f %s\nMax: %.2f %s', ...
        mean(BMEs.YkBMEm, 'omitnan'), obs.Zunit, ...
        std(BMEs.YkBMEm, 'omitnan'), obs.Zunit, ...
        min(BMEs.YkBMEm), obs.Zunit, ...
        max(BMEs.YkBMEm), obs.Zunit);
elseif plotType == 4
    stdDev = sqrt(max(0, BMEs.XkBMEv));
    stats = sprintf('Mean Unc: %.2f %s\nMax Unc: %.2f %s', ...
        mean(stdDev, 'omitnan'), obs.Zunit, ...
        max(stdDev), obs.Zunit);
end

if exist('stats', 'var')
    annotation('textbox', [0.15 0.15 0.2 0.1], 'String', stats, ...
        'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
        'EdgeColor', 'black', 'FontSize', 10);
end

%% Save Figure
% Create filename
BMEmethod8digits = BMEparam.BMEmethod8digits;
dataFormat = BMEparam.dataFormat;
figFilename = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_time%.2f_%s.png', ...
    BMEmethod8digits, go.scenario, obs.logTransf, areaCode, mapResolution, dataFormat, tk, figSuffix);
figPath = fullfile(figDir, figFilename);

% Save figure
saveas(gcf, figPath);
fprintf('  Figure saved: %s\n', figFilename);

hold off;

end