function figPaths = plotBME_TemporalSeries(allBMEs, obs, repSites, estConfig, varargin)
% plotBME_TemporalSeries - Generate temporal plots at representative sites
%
% Creates comprehensive time series visualizations showing observations vs
% BME estimates with uncertainty bands at selected representative sites
%
% SYNTAX:
%   figPaths = plotBME_TemporalSeries(allBMEs, obs, repSites, estConfig)
%   figPaths = plotBME_TemporalSeries(..., 'Name', Value)
%
% INPUTS:
%   allBMEs    - Cell array of BME results structures (one per time period)
%   obs        - Observation structure from getTOARobservationalData
%   repSites   - Representative sites structure from selectRepresentativeSites
%   estConfig  - Estimation configuration structure
%
% OPTIONAL PARAMETERS:
%   'figDir'         - Output directory (default: './5BMEspatialPlots/figs_temporal/')
%   'dpi'            - Figure resolution (default: 300)
%   'visible'        - Figure visibility 'on'/'off' (default: 'off')
%   'plotType'       - Plot type (default: 'full')
%                      'full': 6-panel comprehensive plot (2×3 layout)
%                      'simple': Single time series panel
%                      'both': Generate both types
%   'uncertaintyBands' - Uncertainty levels to plot (default: [1, 2])
%                        1 = ±1σ (68% confidence), 2 = ±2σ (95% confidence)
%   'saveTable'      - Save statistics table (default: true)
%   'combineRegions' - Create multi-region comparison plot (default: true)
%   'siteEstimates'  - Structure with exact site estimates (leave-one-out)
%                      If provided, uses exact BME at site locations
%                      If empty, uses nearest grid point (default: [])
%   'showLocationMap' - Show location map panel (default: true)
%
% OUTPUTS:
%   figPaths - Cell array of generated figure paths
%
% EXAMPLE:
%   figPaths = plotBME_TemporalSeries(allBMEs, obs, repSites, estConfig, ...
%       'plotType', 'full', 'dpi', 300);

%% Parse inputs
p = inputParser;
addRequired(p, 'allBMEs', @iscell);
addRequired(p, 'obs', @isstruct);
addRequired(p, 'repSites', @isstruct);
addRequired(p, 'estConfig', @isstruct);
addParameter(p, 'figDir', fullfile('5BMEspatialPlots', 'figs_temporal'), @ischar);
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'visible', 'off', @(x) ismember(x, {'on', 'off'}));
addParameter(p, 'plotType', 'full', @(x) ismember(x, {'full', 'simple', 'both'}));
addParameter(p, 'uncertaintyBands', [1, 2], @isnumeric);
addParameter(p, 'saveTable', true, @islogical);
addParameter(p, 'combineRegions', true, @islogical);
addParameter(p, 'siteEstimates', [], @(x) isstruct(x) || isempty(x));
addParameter(p, 'showLocationMap', true, @islogical);

parse(p, allBMEs, obs, repSites, estConfig, varargin{:});
opts = p.Results;

%% Setup
fprintf('=== Generating Temporal Series Plots ===\n');

% Create output directory
if ~exist(opts.figDir, 'dir')
    mkdir(opts.figDir);
end

figPaths = {};
regions = fieldnames(repSites);
nRegions = length(regions);

fprintf('  Regions to plot: %d\n', nRegions);
fprintf('  Time periods: %d\n', length(allBMEs));
fprintf('  Output directory: %s\n\n', opts.figDir);

%% Extract time series data for each site

fprintf('  Extracting time series at representative sites...\n');

timeSeriesData = struct();

for iReg = 1:nRegions
    regionName = regions{iReg};
    site = repSites.(regionName);

    fprintf('    %s: [%.2f, %.2f]...\n', site.region, site.lon, site.lat);

    % Initialize arrays
    nTimes = length(allBMEs);
    tkVec = nan(nTimes, 1);
    BMEmean = nan(nTimes, 1);
    BMEstd = nan(nTimes, 1);
    obsValues = cell(nTimes, 1);
    obsTimes = cell(nTimes, 1);

    % Check if we have exact site estimates (leave-one-out at exact location)
    useExactEstimates = ~isempty(opts.siteEstimates) && ...
                        isfield(opts.siteEstimates, 'estimates') && ...
                        isfield(opts.siteEstimates.estimates, regionName);

    if useExactEstimates
        % Use exact leave-one-out estimates at site location
        siteEst = opts.siteEstimates.estimates.(regionName);
        tkVec = opts.siteEstimates.tkVec;
        BMEmean = siteEst.BMEmean;
        BMEstd = siteEst.BMEstd;
        nTimes = length(tkVec);
        obsValues = cell(nTimes, 1);
        obsTimes = cell(nTimes, 1);
    end

    % Extract BME estimates at this location for each time
    for iTime = 1:nTimes
        if isempty(allBMEs{iTime})
            continue;
        end

        BMEs = allBMEs{iTime};

        if ~useExactEstimates
            % Use nearest grid point (original approach)
            tkVec(iTime) = BMEs.tk;

            % Find nearest grid point to site location
            distances = sqrt((BMEs.sk(:,1) - site.lon).^2 + (BMEs.sk(:,2) - site.lat).^2);
            [minDist, nearestIdx] = min(distances);

            if minDist < 2.0  % Within 2 degrees
                BMEmean(iTime) = BMEs.YkBMEm(nearestIdx);
                BMEstd(iTime) = sqrt(BMEs.XkBMEv(nearestIdx));
            end
        else
            % Just get tk from BMEs for alignment
            if iTime <= length(allBMEs)
                tkVec(iTime) = BMEs.tk;
            end
        end

        % Get observations near this site
        % obs.Y is [nStations × nTimes], need to find both station and time indices

        % Find stations near this representative site (within 0.5 degrees)
        locDist = sqrt((obs.sMS(:, 1) - site.lon).^2 + (obs.sMS(:, 2) - site.lat).^2);
        nearStations = find(locDist < 0.5);

        if ~isempty(nearStations)
            % Find time index closest to BMEs.tk (within ±15 days)
            timeWindow = 15/365;  % ±15 days in decimal years
            [minTimeDiff, closestTimeIdx] = min(abs(obs.tME - BMEs.tk));

            if minTimeDiff < timeWindow
                % Extract observations at nearby stations for this time
                obsAtTime = obs.Y(nearStations, closestTimeIdx);
                validObs = ~isnan(obsAtTime);

                if any(validObs)
                    obsValues{iTime} = obsAtTime(validObs);
                    obsTimes{iTime} = repmat(obs.tME(closestTimeIdx), sum(validObs), 1);
                end
            end
        end
    end

    % Remove NaN times
    validTimes = ~isnan(tkVec);
    tkVec = tkVec(validTimes);
    BMEmean = BMEmean(validTimes);
    BMEstd = BMEstd(validTimes);
    obsValues = obsValues(validTimes);
    obsTimes = obsTimes(validTimes);

    % Flatten observations for statistics
    obsFlat = [];
    BMEatObs = [];
    for iTime = 1:length(obsValues)
        if ~isempty(obsValues{iTime})
            obsFlat = [obsFlat; obsValues{iTime}];
            BMEatObs = [BMEatObs; repmat(BMEmean(iTime), length(obsValues{iTime}), 1)];
        end
    end

    % Calculate statistics
    if length(obsFlat) >= 10
        residuals = obsFlat - BMEatObs;
        R2 = 1 - sum(residuals.^2) / sum((obsFlat - mean(obsFlat)).^2);
        RMSE = sqrt(mean(residuals.^2));
        MAE = mean(abs(residuals));
        Bias = mean(residuals);
        NMB = 100 * Bias / mean(obsFlat);

        % Coverage probability (% within ±2σ)
        BMEstdAtObs = [];
        for iTime = 1:length(obsValues)
            if ~isempty(obsValues{iTime})
                BMEstdAtObs = [BMEstdAtObs; repmat(BMEstd(iTime), length(obsValues{iTime}), 1)];
            end
        end
        within2sigma = abs(residuals) <= (2 * BMEstdAtObs);
        coverage = 100 * sum(within2sigma) / length(residuals);
    else
        R2 = NaN; RMSE = NaN; MAE = NaN; Bias = NaN; NMB = NaN; coverage = NaN;
    end

    % Store data
    timeSeriesData.(regionName).site = site;
    timeSeriesData.(regionName).tkVec = tkVec;
    timeSeriesData.(regionName).BMEmean = BMEmean;
    timeSeriesData.(regionName).BMEstd = BMEstd;
    timeSeriesData.(regionName).obsValues = obsValues;
    timeSeriesData.(regionName).obsTimes = obsTimes;
    timeSeriesData.(regionName).obsFlat = obsFlat;
    timeSeriesData.(regionName).stats.R2 = R2;
    timeSeriesData.(regionName).stats.RMSE = RMSE;
    timeSeriesData.(regionName).stats.MAE = MAE;
    timeSeriesData.(regionName).stats.Bias = Bias;
    timeSeriesData.(regionName).stats.NMB = NMB;
    timeSeriesData.(regionName).stats.coverage = coverage;
    timeSeriesData.(regionName).stats.nObs = length(obsFlat);
end

fprintf('    Time series extraction complete\n\n');

%% Generate individual plots for each region

fprintf('  Generating individual temporal plots...\n');

for iReg = 1:nRegions
    regionName = regions{iReg};
    tsData = timeSeriesData.(regionName);

    if isempty(tsData.tkVec)
        fprintf('    %s: No data, skipping\n', regionName);
        continue;
    end

    fprintf('    %s...\n', regionName);

    % Create figure
    if strcmp(opts.plotType, 'full') || strcmp(opts.plotType, 'both')
        fig = figure('Visible', opts.visible, 'Position', [100, 100, 1800, 900]);

        % Subplot 1: Full time series
        subplot(2, 3, 1);
        plotTimeSeriesPanel(tsData, opts, 'full');
        title(sprintf('%s - Time Series', tsData.site.region), 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 2: Seasonal cycle
        subplot(2, 3, 2);
        plotSeasonalPanel(tsData);
        title('Seasonal Cycle', 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 3: Location Map
        subplot(2, 3, 3);
        if opts.showLocationMap
            plotLocationMap(tsData.site, obs, repSites);
            title('Site Location', 'FontSize', 12, 'FontWeight', 'bold');
        end

        % Subplot 4: Residuals over time
        subplot(2, 3, 4);
        plotResidualsPanel(tsData);
        title('Residuals (Obs - BME)', 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 5: Uncertainty over time
        subplot(2, 3, 5);
        plotUncertaintyPanel(tsData);
        title('BME Uncertainty', 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 6: Statistics Summary
        subplot(2, 3, 6);
        plotStatisticsSummary(tsData);
        title('Performance Metrics', 'FontSize', 12, 'FontWeight', 'bold');

        % Add overall title with statistics
        sgtitle(sprintf(['%s: [%.2f°, %.2f°] | R²=%.2f, RMSE=%.1f ppb, ' ...
            'Bias=%.1f ppb | n=%d obs'], ...
            tsData.site.region, tsData.site.lon, tsData.site.lat, ...
            tsData.stats.R2, tsData.stats.RMSE, tsData.stats.Bias, ...
            tsData.stats.nObs), 'FontSize', 14, 'FontWeight', 'bold');

        % Save figure
        figFile = fullfile(opts.figDir, sprintf('temporal_full_%s.png', regionName));
        print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
        figPaths{end+1} = figFile;

        if strcmp(opts.visible, 'off')
            close(fig);
        end
    end

    % Simple plot (single panel)
    if strcmp(opts.plotType, 'simple') || strcmp(opts.plotType, 'both')
        fig = figure('Visible', opts.visible, 'Position', [100, 100, 1000, 500]);
        plotTimeSeriesPanel(tsData, opts, 'simple');

        title(sprintf('%s: [%.2f°, %.2f°] | R²=%.2f, RMSE=%.1f ppb, n=%d', ...
            tsData.site.region, tsData.site.lon, tsData.site.lat, ...
            tsData.stats.R2, tsData.stats.RMSE, tsData.stats.nObs), ...
            'FontSize', 12, 'FontWeight', 'bold');

        % Save figure
        figFile = fullfile(opts.figDir, sprintf('temporal_simple_%s.png', regionName));
        print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
        figPaths{end+1} = figFile;

        if strcmp(opts.visible, 'off')
            close(fig);
        end
    end
end

fprintf('    Individual plots complete\n\n');

%% Create multi-region comparison plot

if opts.combineRegions && nRegions > 1
    fprintf('  Generating multi-region comparison plot...\n');

    % Determine layout (rows x cols)
    nRows = ceil(sqrt(nRegions));
    nCols = ceil(nRegions / nRows);

    fig = figure('Visible', opts.visible, 'Position', [100, 100, 400*nCols, 300*nRows]);

    for iReg = 1:nRegions
        regionName = regions{iReg};
        tsData = timeSeriesData.(regionName);

        if isempty(tsData.tkVec)
            continue;
        end

        subplot(nRows, nCols, iReg);
        plotTimeSeriesPanel(tsData, opts, 'compact');

        title(sprintf('%s\nR²=%.2f, RMSE=%.1f ppb', ...
            tsData.site.region, tsData.stats.R2, tsData.stats.RMSE), ...
            'FontSize', 10, 'FontWeight', 'bold');
    end

    sgtitle(sprintf('BME Temporal Analysis - All Regions | Method: %s', ...
        estConfig.BMEmethod), 'FontSize', 14, 'FontWeight', 'bold');

    % Save figure
    figFile = fullfile(opts.figDir, 'temporal_all_regions.png');
    print(fig, figFile, '-dpng', sprintf('-r%d', opts.dpi));
    figPaths{end+1} = figFile;

    if strcmp(opts.visible, 'off')
        close(fig);
    end

    fprintf('    Multi-region plot complete\n\n');
end

%% Save statistics table

if opts.saveTable
    fprintf('  Saving statistics table...\n');

    % Preallocate table
    T = table();
    iRow = 0;

    for iReg = 1:nRegions
        regionName = regions{iReg};
        tsData = timeSeriesData.(regionName);

        if isempty(tsData.tkVec)
            continue;
        end

        iRow = iRow + 1;
        T.Region{iRow} = tsData.site.region;
        T.Longitude(iRow) = tsData.site.lon;
        T.Latitude(iRow) = tsData.site.lat;
        T.NumObservations(iRow) = tsData.stats.nObs;
        T.R2(iRow) = tsData.stats.R2;
        T.RMSE_ppb(iRow) = tsData.stats.RMSE;
        T.MAE_ppb(iRow) = tsData.stats.MAE;
        T.Bias_ppb(iRow) = tsData.stats.Bias;
        T.NMB_percent(iRow) = tsData.stats.NMB;
        T.Coverage_percent(iRow) = tsData.stats.coverage;
        T.MeanBME_ppb(iRow) = mean(tsData.BMEmean, 'omitnan');
        T.MeanUncertainty_ppb(iRow) = mean(tsData.BMEstd, 'omitnan');
    end

    tableFile = fullfile(opts.figDir, 'temporal_statistics.csv');
    writetable(T, tableFile);
    fprintf('    Saved to: %s\n\n', tableFile);
end

%% Summary

fprintf('  Summary:\n');
fprintf('    Figures generated: %d\n', length(figPaths));
fprintf('    Output directory: %s\n', opts.figDir);

end

%% Helper functions

function plotTimeSeriesPanel(tsData, opts, style)
% Plot time series with uncertainty bands

hold on;

% Plot uncertainty bands
for iSigma = sort(opts.uncertaintyBands, 'descend')
    sigmaColor = [0.7, 0.85, 1.0] .^ iSigma;  % Darker for ±2σ
    fill([tsData.tkVec; flipud(tsData.tkVec)], ...
         [tsData.BMEmean + iSigma*tsData.BMEstd; ...
          flipud(tsData.BMEmean - iSigma*tsData.BMEstd)], ...
         sigmaColor, 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
         'DisplayName', sprintf('BME ±%dσ', iSigma));
end

% Plot BME mean
plot(tsData.tkVec, tsData.BMEmean, 'b-', 'LineWidth', 2, 'DisplayName', 'BME Mean');

% Plot observations
obsX = [];
obsY = [];
for i = 1:length(tsData.obsTimes)
    if ~isempty(tsData.obsTimes{i})
        obsX = [obsX; tsData.obsTimes{i}];
        obsY = [obsY; tsData.obsValues{i}];
    end
end
if ~isempty(obsX)
    plot(obsX, obsY, 'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
        'DisplayName', 'Observations');
end

hold off;

xlabel('Time (year)', 'FontSize', 10);
ylabel('Ozone (ppb)', 'FontSize', 10);
grid on;

if ~strcmp(style, 'compact')
    legend('Location', 'best', 'FontSize', 9);
end

xlim([min(tsData.tkVec), max(tsData.tkVec)]);
end

function plotSeasonalPanel(tsData)
% Plot seasonal cycle (monthly boxes)

% Extract month from decimal year
months = round(mod(tsData.tkVec, 1) * 12) + 1;

% Group BME by month
monthlyBME = cell(12, 1);
for i = 1:length(months)
    monthlyBME{months(i)} = [monthlyBME{months(i)}; tsData.BMEmean(i)];
end

% Group obs by month
monthlyObs = cell(12, 1);
for i = 1:length(tsData.obsTimes)
    if ~isempty(tsData.obsTimes{i})
        obsMonths = round(mod(tsData.obsTimes{i}, 1) * 12) + 1;
        for j = 1:length(obsMonths)
            monthlyObs{obsMonths(j)} = [monthlyObs{obsMonths(j)}; tsData.obsValues{i}(j)];
        end
    end
end

hold on;

% Plot BME seasonal cycle
monthVec = 1:12;
BMEmonthly = cellfun(@(x) mean(x, 'omitnan'), monthlyBME);
plot(monthVec, BMEmonthly, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b', ...
    'DisplayName', 'BME Mean');

% Plot obs seasonal cycle
obsMonthly = cellfun(@(x) mean(x, 'omitnan'), monthlyObs);
validMonths = ~isnan(obsMonthly);
plot(monthVec(validMonths), obsMonthly(validMonths), 'ko', 'MarkerSize', 6, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'Obs Mean');

hold off;

xlabel('Month', 'FontSize', 10);
ylabel('Ozone (ppb)', 'FontSize', 10);
xlim([0.5, 12.5]);
xticks(1:12);
xticklabels({'J','F','M','A','M','J','J','A','S','O','N','D'});
grid on;
legend('Location', 'best', 'FontSize', 9);
end

function plotResidualsPanel(tsData)
% Plot residuals over time

% Calculate residuals at observation times
residuals = [];
residualTimes = [];
for i = 1:length(tsData.obsTimes)
    if ~isempty(tsData.obsTimes{i})
        residuals = [residuals; tsData.obsValues{i} - tsData.BMEmean(i)];
        residualTimes = [residualTimes; tsData.obsTimes{i}];
    end
end

if isempty(residuals)
    text(0.5, 0.5, 'No observations', 'HorizontalAlignment', 'center', 'FontSize', 12);
    return;
end

hold on;

% Plot zero line
plot([min(residualTimes), max(residualTimes)], [0, 0], 'k--', 'LineWidth', 1);

% Plot residuals
plot(residualTimes, residuals, 'ko', 'MarkerSize', 3, 'MarkerFaceColor', 'k');

% Add mean residual line
meanResidual = mean(residuals);
plot([min(residualTimes), max(residualTimes)], [meanResidual, meanResidual], ...
    'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('Mean: %.2f ppb', meanResidual));

hold off;

xlabel('Time (year)', 'FontSize', 10);
ylabel('Residual (ppb)', 'FontSize', 10);
grid on;
legend('Location', 'best', 'FontSize', 9);
xlim([min(residualTimes), max(residualTimes)]);
end

function plotUncertaintyPanel(tsData)
% Plot BME uncertainty over time

plot(tsData.tkVec, tsData.BMEstd, 'r-', 'LineWidth', 2);

xlabel('Time (year)', 'FontSize', 10);
ylabel('Uncertainty (σ, ppb)', 'FontSize', 10);
grid on;
xlim([min(tsData.tkVec), max(tsData.tkVec)]);

% Add mean uncertainty annotation
meanUncertainty = mean(tsData.BMEstd, 'omitnan');
text(0.98, 0.95, sprintf('Mean: %.2f ppb', meanUncertainty), ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', 'w');
end

function plotLocationMap(site, obs, repSites)
% Plot location map showing representative site and all observations

hold on;

% Plot all observation stations (gray dots)
plot(obs.sMS(:,1), obs.sMS(:,2), '.', 'Color', [0.7 0.7 0.7], ...
    'MarkerSize', 2, 'DisplayName', 'All Stations');

% Plot all representative sites (smaller colored markers)
regions = fieldnames(repSites);
colors = lines(length(regions));
for i = 1:length(regions)
    otherSite = repSites.(regions{i});
    plot(otherSite.lon, otherSite.lat, 'o', ...
        'MarkerSize', 6, 'MarkerFaceColor', colors(i,:), ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5, ...
        'HandleVisibility', 'off');
end

% Highlight current site (larger marker)
plot(site.lon, site.lat, 'p', 'MarkerSize', 15, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 2, ...
    'DisplayName', site.region);

% Add text label for current site
text(site.lon, site.lat, sprintf('  %s', site.region), ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', 'r', ...
    'VerticalAlignment', 'bottom');

hold off;

xlabel('Longitude (°E)', 'FontSize', 10);
ylabel('Latitude (°N)', 'FontSize', 10);
grid on;
axis equal tight;

% Set reasonable axis limits
lonRange = max(obs.sMS(:,1)) - min(obs.sMS(:,1));
latRange = max(obs.sMS(:,2)) - min(obs.sMS(:,2));
padding = 0.1;

xlim([site.lon - lonRange*padding, site.lon + lonRange*padding]);
ylim([site.lat - latRange*padding, site.lat + latRange*padding]);

legend('Location', 'best', 'FontSize', 8);

% Add count
nStations = size(obs.sMS, 1);
text(0.02, 0.98, sprintf('%d total stations', nStations), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 9, 'BackgroundColor', 'w');
end

function plotStatisticsSummary(tsData)
% Plot summary statistics as text

axis off;

% Title
text(0.5, 0.95, 'Validation Statistics', ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 11, 'FontWeight', 'bold');

% Statistics text
statsText = {
    sprintf('R² = %.3f', tsData.stats.R2);
    sprintf('RMSE = %.2f ppb', tsData.stats.RMSE);
    sprintf('MAE = %.2f ppb', tsData.stats.MAE);
    sprintf('Bias = %.2f ppb', tsData.stats.Bias);
    sprintf('NMB = %.1f%%', tsData.stats.NMB);
    '';
    sprintf('Coverage (±2σ) = %.1f%%', tsData.stats.coverage);
    sprintf('Mean BME = %.1f ppb', mean(tsData.BMEmean, 'omitnan'));
    sprintf('Mean σ = %.2f ppb', mean(tsData.BMEstd, 'omitnan'));
    '';
    sprintf('Observations: %d', tsData.stats.nObs);
};

yPos = 0.80;
for i = 1:length(statsText)
    text(0.1, yPos, statsText{i}, ...
        'Units', 'normalized', 'FontSize', 10, ...
        'VerticalAlignment', 'top');
    yPos = yPos - 0.08;
end

% Add interpretation guide
text(0.1, 0.15, 'Performance Guide:', ...
    'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold');

guideText = {
    'Excellent: R² > 0.75, RMSE < 5 ppb';
    'Good: R² > 0.65, RMSE < 7 ppb';
    'Fair: R² > 0.50, RMSE < 10 ppb';
};

yPos = 0.10;
for i = 1:length(guideText)
    text(0.1, yPos, guideText{i}, ...
        'Units', 'normalized', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
    yPos = yPos - 0.05;
end
end
