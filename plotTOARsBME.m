function plotTOARsBME(obs, go, BMEs, BMEparam, estParam)
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
%
% OUTPUTS:
%   Saves figures to ./5BMEspatialPlots/figs/
%
% EXAMPLE:
%   plotTOARsBME(obs, go, BMEs, BMEparam, estParam);

if nargin < 5
    error('All 4 inputs required. See help plotTOARsBME');
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
figDir = fullfile('5BMEspatialPlots', 'figs');
if ~exist(figDir, 'dir'), mkdir(figDir); end

% Select data to plot (use back-transformed if available, otherwise use log-space)
if isfield(BMEs, 'ZkBMEm') && ~isempty(BMEs.ZkBMEm)
    plotData = BMEs.ZkBMEm;  % Back-transformed (original concentration space)
    if isfield(BMEs, 'Zobs') && ~isempty(BMEs.Zobs)
        obsData = BMEs.Zobs;  % Back-transformed observations
    else
        obsData = BMEs.Yobs;  % Fallback to log space
    end
else
    plotData = BMEs.YkBMEm;  % Log space (fallback)
    obsData = BMEs.Yobs;     % Log space
end

% Color range for concentrations
yrangeQuant = [0.05 0.95];
allValues = plotData(~isnan(plotData));
if ~isempty(obsData)
    allValues = [allValues; obsData(~isnan(obsData))];
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
        plotFieldTOAR(BMEs.sk, plotData, displayArea, maskcontour);
        clim(yrange);
        plotTitle = sprintf('%s BME Estimate', obs.Zname);
        figSuffix = 'BME';

    case 2  % BME estimates + observations
        plotFieldTOAR(BMEs.sk, plotData, displayArea, maskcontour);
        clim(yrange);

        % Overlay observations
        if ~isempty(obsData)
            Property = {'Marker', 'MarkerSize', 'MarkerEdgeColor'};
            Value = {'o', 8, 'k'};
            colorplot(BMEs.sMSobs, obsData, cmap, Property, Value, yrange);
        end
        plotTitle = sprintf('%s BME Estimate + Observations', obs.Zname);
        figSuffix = 'BME_obs';
        
    case 3  % Residuals (offset-removed)
        plotField(BMEs.sk, BMEs.XkBMEm, displayArea, maskcontour);
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
        plotField(BMEs.sk, stdDev, displayArea, maskcontour);
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

% Add log-transform indicator to title
ltStr = sprintf(', lt=%d', obs.logTransf);

title({plotTitle, timeStr, ...
    sprintf('BME Method: %s, GO Scenario: %d, Area: %d, Resolution: %.2f°, Format: %s%s', ...
    BMEparam.BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat, ltStr)}, 'FontSize', 14);

% Add statistics text box
if plotType <= 2
    stats = sprintf('Mean: %.2f %s\nStd: %.2f %s\nMin: %.2f %s\nMax: %.2f %s', ...
        mean(plotData, 'omitnan'), obs.Zunit, ...
        std(plotData, 'omitnan'), obs.Zunit, ...
        min(plotData), obs.Zunit, ...
        max(plotData), obs.Zunit);
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
% Create filename with lt0 or lt1 suffix
BMEmethod8digits = BMEparam.BMEmethod8digits;
dataFormat = BMEparam.dataFormat;
ltSuffix = sprintf('_lt%d', obs.logTransf);
figFilename = sprintf('BME%s_go%d%s_area%d_res%.2f_%s_time%.2f_%s.png', ...
    BMEmethod8digits, go.scenario, ltSuffix, areaCode, mapResolution, dataFormat, tk, figSuffix);
figPath = fullfile(figDir, figFilename);

% Save figure
saveas(gcf, figPath);
fprintf('  Figure saved: %s\n', figFilename);

hold off;

end