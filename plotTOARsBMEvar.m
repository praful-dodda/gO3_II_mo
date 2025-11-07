function plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam)
% plotTOARsBMEvar - Plot TOAR BME variance/uncertainty estimates
%
% Creates maps of BME estimation uncertainty with multiple visualization options
%
% SYNTAX:
%   plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   BMEs     - BME results structure with fields:
%              .sk, .tk, .XkBMEv (variance), .sMSobs (optional)
%   BMEparam - BME parameters
%   estParam - Estimation parameters with fields:
%              .plotVariance - Variance plot type:
%                              1 = Standard deviation map
%                              2 = Variance map
%                              3 = Coefficient of variation (CV%)
%                              4 = Multi-panel (all three)
%              .areaCode, .mapResolution (for file naming)
%
% OUTPUTS:
%   Saves figures to ./5BMEspatialPlots/figs/variance/
%
% EXAMPLE:
%   estParam.plotVariance = 4;  % Multi-panel
%   plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam);

if nargin < 5
    error('All 5 inputs required. See help plotTOARsBMEvar');
end

%% Setup
if isfield(estParam, 'plotVariance')
    plotType = estParam.plotVariance;
else
    plotType = 1;  % Default: standard deviation
end

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
figDir = fullfile('5BMEspatialPlots', 'figs', 'variance');
if ~exist(figDir, 'dir'), mkdir(figDir); end

% Clean variance data
XkBMEv = BMEs.XkBMEv;
XkBMEv = real(XkBMEv);  % Remove imaginary parts
XkBMEv(XkBMEv < 0) = 0;  % Remove negative variances

% Calculate derived quantities
stdDev = sqrt(XkBMEv);
if ~isempty(BMEs.YkBMEm)
    CV = (stdDev ./ abs(BMEs.YkBMEm)) * 100;  % Coefficient of variation (%)
    CV(isinf(CV)) = NaN;
    CV(CV > 200) = NaN;  % Cap at 200%
else
    CV = [];
end

% Colormap
useCustomColormap = false;
if exist('NoraColormap.m', 'file')
    cmap = NoraColormap;
    useCustomColormap = true;
else
    cmap = jet(64);
end

%% Load Border Data
bordersAvailable = false;
if exist(fullfile(dataDir, 'borderdata.mat'), 'file')
    load(fullfile(dataDir, 'borderdata.mat'), 'places', 'lon', 'lat');
    bordersAvailable = true;

    % Create mask contour for land areas
    maskcontour = [];
    for k = 1:length(places)
        if ~isempty(lon{k})
            maskcontour = [maskcontour; [lon{k}(:), lat{k}(:)]; [NaN, NaN]];
        end
    end
end

%% Apply Land Mask if Requested
% When keepOnlyLand is true, mask out ocean areas by setting them to NaN
% Use local copies for plotting to avoid modifying the original data
stdDev_plot = stdDev;
XkBMEv_plot = XkBMEv;
CV_plot = CV;
YkBMEm_plot = BMEs.YkBMEm;

if keepOnlyLand
    fprintf('  Applying land mask to variance estimation points...\n');
    stdDev_plot = applyLandMask(BMEs.sk, stdDev_plot, dataDir);
    XkBMEv_plot = applyLandMask(BMEs.sk, XkBMEv_plot, dataDir);
    if ~isempty(CV_plot)
        CV_plot = applyLandMask(BMEs.sk, CV_plot, dataDir);
    end
    if ~isempty(YkBMEm_plot)
        YkBMEm_plot = applyLandMask(BMEs.sk, YkBMEm_plot, dataDir);
    end
end

%% Create Time String
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

%% Plot Based on Type
BMEmethod8digits = BMEparam.BMEmethod8digits;

switch plotType
    case 1  % Standard Deviation
        % figure('Position', [100 100 1200 800], 'Color', 'w');
        hold on;

        % Plot standard deviation
        plotFieldTOAR(BMEs.sk, stdDev_plot, displayArea, maskcontour);
        stdRange = quantest(stdDev_plot(~isnan(stdDev_plot)), [0 0.95]);
        clim(stdRange);
        
        % Add observation locations
        % if ~isempty(BMEs.sMSobs)
        %     scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 2, 'k', ...
        %         'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
        % end
        
        % Formatting
        colormap(cmap);
        cb = colorbar;
        ylabel(cb, sprintf('Standard Deviation (%s)', obs.Zunit), 'FontSize', 12);
        xlabel('Longitude (deg)', 'FontSize', 14);
        ylabel('Latitude (deg)', 'FontSize', 14);
        
        title({sprintf('%s BME Standard Deviation', obs.Zname), timeStr, ...
            sprintf('BME Method: %s, GO: %d, Area: %d, Res: %.2f°, Format: %s', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat)}, ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Statistics
        stats = sprintf('Mean: %.2f %s\nStd: %.2f %s\nMin: %.2f %s\nMax: %.2f %s', ...
            mean(stdDev_plot, 'omitnan'), obs.Zunit, ...
            std(stdDev_plot, 'omitnan'), obs.Zunit, ...
            min(stdDev_plot), obs.Zunit, ...
            max(stdDev_plot), obs.Zunit);
        annotation('textbox', [0.15 0.15 0.2 0.12], 'String', stats, ...
            'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'FontSize', 10);

        % Save
        figFilename = sprintf('BME%s_go%d_area%d_res%.2f_%s_time%.2f_stddev.png', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat, tk);
        
    case 2  % Variance
        % figure('Position', [100 100 1200 800], 'Color', 'w');
        hold on;

        % Plot variance
        plotFieldTOAR(BMEs.sk, XkBMEv_plot, displayArea, maskcontour);
        varRange = quantest(XkBMEv_plot(~isnan(XkBMEv_plot)), [0 0.95]);
        clim(varRange);
        
        % Add observation locations
        % if ~isempty(BMEs.sMSobs)
        %     scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 30, 'k', 'filled', ...
        %         'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
        % end
        
        % Formatting
        colormap(cmap);
        cb = colorbar;
        ylabel(cb, sprintf('Variance (%s²)', obs.Zunit), 'FontSize', 12);
        xlabel('Longitude (deg)', 'FontSize', 14);
        ylabel('Latitude (deg)', 'FontSize', 14);
        
        title({sprintf('%s BME Variance', obs.Zname), timeStr, ...
            sprintf('BME Method: %s, GO: %d, Area: %d, Res: %.2f°, Format: %s', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat)}, ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Statistics
        stats = sprintf('Mean: %.2f %s²\nStd: %.2f %s²\nMin: %.2f %s²\nMax: %.2f %s²', ...
            mean(XkBMEv_plot, 'omitnan'), obs.Zunit, ...
            std(XkBMEv_plot, 'omitnan'), obs.Zunit, ...
            min(XkBMEv_plot), obs.Zunit, ...
            max(XkBMEv_plot), obs.Zunit);
        annotation('textbox', [0.15 0.15 0.2 0.12], 'String', stats, ...
            'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'FontSize', 10);

        % Save
        figFilename = sprintf('BME%s_go%d_area%d_res%.2f_%s_time%.2f_variance.png', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat, tk);
        
    case 3  % Coefficient of Variation
        if isempty(CV_plot)
            warning('Cannot compute CV without YkBMEm. Skipping.');
            return;
        end

        % figure('Position', [100 100 1200 800], 'Color', 'w');
        hold on;

        % Plot CV
        plotFieldTOAR(BMEs.sk, CV_plot, displayArea, maskcontour);
        cvRange = quantest(CV_plot(~isnan(CV_plot) & ~isinf(CV_plot)), [0.05 0.95]);
        clim(cvRange);
        
        % Add observation locations
        if ~isempty(BMEs.sMSobs)
            scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 30, 'k', 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
        end
        
        % Formatting
        colormap(cmap);
        cb = colorbar;
        ylabel(cb, 'Coefficient of Variation (%)', 'FontSize', 12);
        xlabel('Longitude (deg)', 'FontSize', 14);
        ylabel('Latitude (deg)', 'FontSize', 14);
        
        title({sprintf('%s BME Coefficient of Variation', obs.Zname), timeStr, ...
            sprintf('BME Method: %s, GO: %d, Area: %d, Res: %.2f°, Format: %s', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat)}, ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Statistics
        stats = sprintf('Mean: %.1f%%\nStd: %.1f%%\nMin: %.1f%%\nMax: %.1f%%', ...
            mean(CV_plot, 'omitnan'), std(CV_plot, 'omitnan'), min(CV_plot), max(CV_plot));
        annotation('textbox', [0.15 0.15 0.2 0.1], 'String', stats, ...
            'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'FontSize', 10);

        % Save
        figFilename = sprintf('BME%s_go%d_area%d_res%.2f_%s_time%.2f_CV.png', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat, tk);
        
    case 4  % Multi-panel (all three)
        % figure('Position', [100 100 1800 600], 'Color', 'w');
        
        % Panel 1: Standard Deviation
        subplot(1, 3, 1);
        hold on;
        plotFieldTOAR(BMEs.sk, stdDev_plot, displayArea, maskcontour);
        stdRange = quantest(stdDev_plot(~isnan(stdDev_plot)), [0 0.95]);
        clim(stdRange);
        if ~isempty(BMEs.sMSobs)
            scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 20, 'k', 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
        end
        colormap(gca, cmap);
        cb = colorbar;
        ylabel(cb, sprintf('Std Dev (%s)', obs.Zunit), 'FontSize', 10);
        xlabel('Longitude (deg)', 'FontSize', 12);
        ylabel('Latitude (deg)', 'FontSize', 12);
        title('Standard Deviation', 'FontSize', 13, 'FontWeight', 'bold');
        
        % Panel 2: Variance
        subplot(1, 3, 2);
        hold on;
        plotFieldTOAR(BMEs.sk, XkBMEv_plot, displayArea, maskcontour);
        varRange = quantest(XkBMEv_plot(~isnan(XkBMEv_plot)), [0 0.95]);
        clim(varRange);
        if ~isempty(BMEs.sMSobs)
            scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 20, 'k', 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
        end
        colormap(gca, cmap);
        cb = colorbar;
        ylabel(cb, sprintf('Variance (%s²)', obs.Zunit), 'FontSize', 10);
        xlabel('Longitude (deg)', 'FontSize', 12);
        ylabel('Latitude (deg)', 'FontSize', 12);
        title('Variance', 'FontSize', 13, 'FontWeight', 'bold');
        
        % Panel 3: Coefficient of Variation
        subplot(1, 3, 3);
        hold on;
        if ~isempty(CV_plot)
            plotFieldTOAR(BMEs.sk, CV_plot, displayArea, maskcontour);
            cvRange = quantest(CV_plot(~isnan(CV_plot) & ~isinf(CV_plot)), [0.05 0.95]);
            clim(cvRange);
            if ~isempty(BMEs.sMSobs)
                scatter(BMEs.sMSobs(:,1), BMEs.sMSobs(:,2), 20, 'k', 'filled', ...
                    'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
            end
            colormap(gca, cmap);
            cb = colorbar;
            ylabel(cb, 'CV (%)', 'FontSize', 10);
        end
        xlabel('Longitude (deg)', 'FontSize', 12);
        ylabel('Latitude (deg)', 'FontSize', 12);
        title('Coefficient of Variation', 'FontSize', 13, 'FontWeight', 'bold');
        
        % Overall title
        sgtitle({sprintf('%s BME Uncertainty - %s', obs.Zname, timeStr), ...
            sprintf('BME Method: %s, GO: %d, Area: %d, Resolution: %.2f°, Format: %s', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat)}, ...
            'FontSize', 15, 'FontWeight', 'bold');

        % Save
        figFilename = sprintf('BME%s_go%d_area%d_res%.2f_%s_time%.2f_uncertainty_all.png', ...
            BMEmethod8digits, go.scenario, areaCode, mapResolution, BMEparam.dataFormat, tk);
        
    otherwise
        error('plotVariance must be 1 (std), 2 (var), 3 (CV), or 4 (all)');
end

%% Save Figure
figPath = fullfile(figDir, figFilename);
print(figPath, '-dpng', '-r300');
fprintf('  Variance figure saved: %s\n', figFilename);

% close(gcf);

end