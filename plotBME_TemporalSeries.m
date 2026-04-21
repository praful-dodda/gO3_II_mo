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
%   'obsMatchRadius' - Radius (degrees) for matching observations to site (default: 0.01)
%                      0.01 = exact site only, 0.5 = within 0.5 degrees
%   'plot_soft_data'   - Plot soft-data if available (default: true)
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
addParameter(p, 'obsMatchRadius', 0.01, @isnumeric);
addParameter(p, 'plot_soft_data', true, @islogical);

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

% Determine workflow type
usingSiteEstimates = ~isempty(opts.siteEstimates);
hasFullGrids = ~isempty(allBMEs{1}) && isfield(allBMEs{1}, 'sk') && ...
               ~isempty(allBMEs{1}.sk);

fprintf('  Regions to plot: %d\n', nRegions);
fprintf('  Time periods: %d\n', length(allBMEs));

if usingSiteEstimates
    fprintf('  Data source: Exact site estimates (leave-one-out)\n');
elseif hasFullGrids
    fprintf('  Data source: Nearest grid point (spatial workflow)\n');
else
    error('plotBME_TemporalSeries: No valid BME estimates available (no grids and no siteEstimates)');
end

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

    % Check if allBMEs contains full spatial grids or just minimal time info
    hasFullGrids = ~isempty(allBMEs{1}) && isfield(allBMEs{1}, 'sk') && ...
                   ~isempty(allBMEs{1}.sk);

    if useExactEstimates
        % Use exact leave-one-out estimates at site location
        siteEst = opts.siteEstimates.estimates.(regionName);
        tkVec = opts.siteEstimates.tkVec;
        BMEmean = siteEst.BMEmean;
        BMEstd = siteEst.BMEstd;

        % Safety: ensure no complex numbers (take real part if present)
        if ~isreal(BMEmean)
            BMEmean = real(BMEmean);
        end
        if ~isreal(BMEstd)
            BMEstd = real(BMEstd);
        end

        nTimes = length(tkVec);
        obsValues = cell(nTimes, 1);
        obsTimes = cell(nTimes, 1);
    elseif ~hasFullGrids
        % Temporal-only workflow: no grid data available
        % Must have siteEstimates to proceed
        error('plotBME_TemporalSeries: No grid data in allBMEs and no siteEstimates provided. Cannot extract time series for %s', regionName);
    end

    % Extract BME estimates at this location for each time
    for iTime = 1:nTimes
        if isempty(allBMEs{iTime})
            continue;
        end

        BMEs = allBMEs{iTime};

        if ~useExactEstimates && hasFullGrids
            % Use nearest grid point (spatial workflow approach)
            tkVec(iTime) = BMEs.tk;

            % Find nearest grid point to site location
            distances = sqrt((BMEs.sk(:,1) - site.lon).^2 + (BMEs.sk(:,2) - site.lat).^2);
            [minDist, nearestIdx] = min(distances);

            if minDist == 0
                % Exact match
                BMEmean(iTime) = BMEs.YkBMEm(nearestIdx);
                BMEstd(iTime) = sqrt(BMEs.XkBMEv(nearestIdx));
            elseif minDist < 2.0
                % If no exact match, check if within reasonable distance (e.g., 2 degrees)
                BMEmean(iTime) = BMEs.YkBMEm(nearestIdx);
                BMEstd(iTime) = sqrt(BMEs.XkBMEv(nearestIdx));
            end
        elseif useExactEstimates && iTime <= length(allBMEs)
            % Just get tk from BMEs for alignment (if available)
            if isfield(BMEs, 'tk')
                tkVec(iTime) = BMEs.tk;
            end
        end

        % Get observations near this site
        % obs.Y is [nStations × nTimes], need to find both station and time indices

        % Find stations near this representative site (using obsMatchRadius)
        locDist = sqrt((obs.sMS(:, 1) - site.lon).^2 + (obs.sMS(:, 2) - site.lat).^2);
        nearStations = find(locDist < opts.obsMatchRadius);

        if ~isempty(nearStations)
            % Find time index closest to BMEs.tk (within ±15 days)
            timeWindow = 15/365;  % ±15 days in decimal years
            [minTimeDiff, closestTimeIdx] = min(abs(obs.tME - BMEs.tk));

            if minTimeDiff < timeWindow
                % Extract observations at nearby stations for this time
                obsAtTime = obs.Y(nearStations, closestTimeIdx);
                validObs = ~isnan(obsAtTime);

                if any(validObs)
                    % Take mean if multiple observations (avoids duplicate points in plot)
                    obsValues{iTime} = mean(obsAtTime(validObs));
                    obsTimes{iTime} = obs.tME(closestTimeIdx);
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

    % Extract soft-data at this site (if available and requested)
    softValues = cell(nTimes, 1);
    softTimes = cell(nTimes, 1);
    hasSoftData = false;

    if opts.plot_soft_data && isfield(estConfig, 'softData') && ~isempty(estConfig.softData)
        softData = estConfig.softData;

        % Find soft-data near this representative site
        for iTime = 1:nTimes
            if isempty(allBMEs{iTime})
                continue;
            end

            BMEs = allBMEs{iTime};

            % Find soft-data points near this site
            softLocDist = sqrt((softData.sMS(:, 1) - site.lon).^2 + ...
                              (softData.sMS(:, 2) - site.lat).^2);
            nearSoftPoints = find(softLocDist < opts.obsMatchRadius);

            % If no soft-data within radius, find the closest point
            if isempty(nearSoftPoints)
                [~, nearSoftPoints] = min(softLocDist);
            end

            if ~isempty(nearSoftPoints)
                % Find time index closest to BMEs.tk (within ±15 days)
                timeWindow = 15/365;  % ±15 days in decimal years
                [minTimeDiff, closestTimeIdx] = min(abs(softData.tME - BMEs.tk));

                if minTimeDiff < timeWindow
                    % Extract soft-data at nearby points for this time
                    softAtTime = softData.Z(nearSoftPoints, closestTimeIdx);
                    validSoft = ~isnan(softAtTime);

                    if any(validSoft)
                        % Take mean if multiple soft-data values (avoids duplicate points)
                        softValues{iTime} = mean(softAtTime(validSoft));
                        softTimes{iTime} = softData.tME(closestTimeIdx);
                        hasSoftData = true;
                    end
                end
            end
        end

        % Apply same time filtering as observations
        softValues = softValues(validTimes);
        softTimes = softTimes(validTimes);
    end

    % Flatten observations for statistics (now each cell has scalar, not array)
    obsFlat = [];
    BMEatObs = [];
    for iTime = 1:length(obsValues)
        if ~isempty(obsValues{iTime})
            obsFlat = [obsFlat; obsValues{iTime}];  % Now scalar per time
            BMEatObs = [BMEatObs; BMEmean(iTime)];
        end
    end

    % Calculate statistics (NaN-safe, no minimum sample size requirement)
    validIdx = ~isnan(obsFlat) & ~isnan(BMEatObs);
    obsFlat_clean = obsFlat(validIdx);
    BMEatObs_clean = BMEatObs(validIdx);

    if ~isempty(obsFlat_clean)
        residuals = obsFlat_clean - BMEatObs_clean;
        obsMean = mean(obsFlat_clean);
        SStot = sum((obsFlat_clean - obsMean).^2);
        R2 = 1 - sum(residuals.^2) / max(SStot, eps);  % avoid div-by-zero
        RMSE = sqrt(mean(residuals.^2));
        MAE = mean(abs(residuals));
        Bias = mean(residuals);
        NMB = 100 * Bias / max(abs(obsMean), eps);

        % Coverage probability (% within ±2σ)
        BMEstdAtObs = [];
        for iTime = 1:length(obsValues)
            if ~isempty(obsValues{iTime}) && ~isnan(obsValues{iTime})
                BMEstdAtObs = [BMEstdAtObs; BMEstd(iTime)];
            end
        end
        if length(BMEstdAtObs) == length(residuals)
            within2sigma = abs(residuals) <= (2 * BMEstdAtObs);
            coverage = 100 * sum(within2sigma) / length(residuals);
        else
            coverage = NaN;
        end
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
    timeSeriesData.(regionName).softValues = softValues;
    timeSeriesData.(regionName).softTimes = softTimes;
    timeSeriesData.(regionName).hasSoftData = hasSoftData;
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

        % Subplot 1: Full time series (larger, takes up 2 columns)
        subplot(2, 3, [1 2]);
        plotTimeSeriesPanel(tsData, opts, 'full');
        title(sprintf('%s - Time Series', tsData.site.region), 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 2: Location Map (top right)
        subplot(2, 3, 3);
        if opts.showLocationMap
            plotLocationMap(tsData.site, obs, repSites);
            title('Site Location', 'FontSize', 12, 'FontWeight', 'bold');
        end

        % Subplot 3: Uncertainty over time (bottom left)
        subplot(2, 3, 4);
        plotUncertaintyPanel(tsData);
        title('BME Uncertainty', 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 4: Statistics Summary (bottom middle)
        subplot(2, 3, 5);
        plotStatisticsSummary(tsData);
        title('Performance Metrics', 'FontSize', 12, 'FontWeight', 'bold');

        % Subplot 5: Seasonal cycle (bottom right) - HIDDEN but code kept
        % subplot(2, 3, 6);
        % plotSeasonalPanel(tsData);
        % title('Seasonal Cycle', 'FontSize', 12, 'FontWeight', 'bold');

        % Add overall title (without R2/RMSE as requested)
        sgtitle(sprintf('%s: [%.2f°, %.2f°] | Bias=%.1f ppb | n=%d obs', ...
            tsData.site.region, tsData.site.lon, tsData.site.lat, ...
            tsData.stats.Bias, tsData.stats.nObs), ...
            'FontSize', 14, 'FontWeight', 'bold');

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

        % Title without R2/RMSE as requested
        title(sprintf('%s: [%.2f°, %.2f°] | Bias=%.1f ppb, n=%d', ...
            tsData.site.region, tsData.site.lon, tsData.site.lat, ...
            tsData.stats.Bias, tsData.stats.nObs), ...
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

        % Simple title without stats
        title(sprintf('%s', tsData.site.region), ...
            'FontSize', 10, 'FontWeight', 'bold');
    end

    % Use empty panel(s) to show legend
    nSlots = nRows * nCols;
    if nSlots > nRegions
        % Determine if any region has soft data (for conditional legend entry)
        hasSoftDataAny = false;
        for iReg = 1:nRegions
            if isfield(timeSeriesData.(regions{iReg}), 'hasSoftData') && ...
               timeSeriesData.(regions{iReg}).hasSoftData
                hasSoftDataAny = true;
                break;
            end
        end
        subplot(nRows, nCols, nRegions + 1);
        plotLegendPanel(opts.uncertaintyBands, hasSoftDataAny);
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
    fill([tsData.tkVec'; flipud(tsData.tkVec')], ...
         [tsData.BMEmean + iSigma*tsData.BMEstd; ...
          flipud(tsData.BMEmean - iSigma*tsData.BMEstd)], ...
         sigmaColor, 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
         'DisplayName', sprintf('BME ±%dσ', iSigma));
end

% Plot BME mean - thick blue line for clear distinction
plot(tsData.tkVec, tsData.BMEmean, '-', 'Color', [0 0.4470 0.7410], ...
    'LineWidth', 2.5, 'DisplayName', 'BME Estimate');

% Plot observations - red circles with thick edge for clear distinction
obsX = [];
obsY = [];
for i = 1:length(tsData.obsTimes)
    if ~isempty(tsData.obsTimes{i})
        obsX = [obsX; tsData.obsTimes{i}];
        obsY = [obsY; tsData.obsValues{i}];
    end
end
if ~isempty(obsX)
    plot(obsX, obsY, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
        'MarkerEdgeColor', [0.6 0.2 0.05], 'LineWidth', 1.5, ...
        'DisplayName', 'Observations');
end

% Plot soft-data - green squares for clear distinction from obs and BME
if isfield(tsData, 'hasSoftData') && tsData.hasSoftData
    softX = [];
    softY = [];
    for i = 1:length(tsData.softTimes)
        if ~isempty(tsData.softTimes{i})
            softX = [softX; tsData.softTimes{i}];
            softY = [softY; tsData.softValues{i}];
        end
    end
    if ~isempty(softX)
        plot(softX, softY, 's', 'MarkerSize', 6, ...
            'MarkerFaceColor', [0.4660 0.6740 0.1880], ...
            'MarkerEdgeColor', [0.3 0.5 0.1], 'LineWidth', 1.2, ...
            'DisplayName', 'Soft-Data (CTM)');
    end
end

hold off;

xlabel('Time', 'FontSize', 10);
ylabel('Ozone (ppb)', 'FontSize', 10);
grid on;

if ~strcmp(style, 'compact')
    legend('Location', 'best', 'FontSize', 9);
end

xlim([min(tsData.tkVec), max(tsData.tkVec)]);

% Format x-axis with full year and month
ax = gca;
ax.XTick = floor(min(tsData.tkVec)):1/12:(floor(max(tsData.tkVec)) + 11/12);
formatDecimalYearAxis(ax);
end

function plotSeasonalPanel(tsData)
% Plot seasonal cycle (monthly boxes)
% NOTE: This panel is currently HIDDEN but code is kept for future use

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
    if ~isempty(tsData.obsTimes{i}) && ~isnan(tsData.obsValues{i})
        obsMonths = round(mod(tsData.obsTimes{i}, 1) * 12) + 1;
        monthlyObs{obsMonths} = [monthlyObs{obsMonths}; tsData.obsValues{i}];
    end
end

hold on;

% Plot BME seasonal cycle - blue line with filled circles
monthVec = 1:12;
BMEmonthly = cellfun(@(x) mean(x, 'omitnan'), monthlyBME);
plot(monthVec, BMEmonthly, '-o', 'Color', [0 0.4470 0.7410], ...
    'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'DisplayName', 'BME Estimate');

% Plot obs seasonal cycle - orange circles
obsMonthly = cellfun(@(x) mean(x, 'omitnan'), monthlyObs);
validMonths = ~isnan(obsMonthly);
plot(monthVec(validMonths), obsMonthly(validMonths), 'o', 'MarkerSize', 8, ...
    'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'MarkerEdgeColor', [0.6 0.2 0.05], 'LineWidth', 1.5, ...
    'DisplayName', 'Observations');

% Plot soft-data seasonal cycle - green squares
if isfield(tsData, 'hasSoftData') && tsData.hasSoftData
    monthlySoft = cell(12, 1);
    for i = 1:length(tsData.softTimes)
        if ~isempty(tsData.softTimes{i}) && ~isnan(tsData.softValues{i})
            softMonths = round(mod(tsData.softTimes{i}, 1) * 12) + 1;
            monthlySoft{softMonths} = [monthlySoft{softMonths}; tsData.softValues{i}];
        end
    end

    softMonthly = cellfun(@(x) mean(x, 'omitnan'), monthlySoft);
    validSoftMonths = ~isnan(softMonthly);
    if any(validSoftMonths)
        plot(monthVec(validSoftMonths), softMonthly(validSoftMonths), 's', ...
            'MarkerSize', 7, 'MarkerFaceColor', [0.4660 0.6740 0.1880], ...
            'MarkerEdgeColor', [0.3 0.5 0.1], 'LineWidth', 1.2, ...
            'DisplayName', 'Soft-Data (CTM)');
    end
end

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
% NOTE: This panel is currently HIDDEN but code is kept for future use

% Calculate residuals at observation times
residuals = [];
residualTimes = [];
for i = 1:length(tsData.obsTimes)
    if ~isempty(tsData.obsTimes{i}) && ~isnan(tsData.obsValues{i})
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
meanResidual = mean(residuals, 'omitnan');
plot([min(residualTimes), max(residualTimes)], [meanResidual, meanResidual], ...
    'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('Mean: %.2f ppb', meanResidual));

hold off;

xlabel('Time', 'FontSize', 10);
ylabel('Residual (ppb)', 'FontSize', 10);
grid on;
legend('Location', 'best', 'FontSize', 9);
xlim([min(residualTimes), max(residualTimes)]);

% Format x-axis with full year and month
ax = gca;
ax.XTick = floor(min(residualTimes)):1/12:(floor(max(residualTimes)) + 11/12);
formatDecimalYearAxis(ax);
end

function plotUncertaintyPanel(tsData)
% Plot BME uncertainty over time

plot(tsData.tkVec, tsData.BMEstd, 'r-', 'LineWidth', 2);

xlabel('Time', 'FontSize', 10);
ylabel('Uncertainty (σ, ppb)', 'FontSize', 10);
grid on;
xlim([min(tsData.tkVec), max(tsData.tkVec)]);

% Add mean uncertainty annotation
meanUncertainty = mean(tsData.BMEstd, 'omitnan');
text(0.98, 0.95, sprintf('Mean: %.2f ppb', meanUncertainty), ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', 'w');

% Format x-axis with full year and month
ax = gca;
ax.XTick = floor(min(tsData.tkVec)):1/12:(floor(max(tsData.tkVec)) + 11/12);
formatDecimalYearAxis(ax);
end

function plotLocationMap(site, obs, repSites)
% Plot location map showing representative site and all observations

hold on;

% Plot world coastlines (lightweight)
try
    load coastlines coastlat coastlon
    plot(coastlon, coastlat, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
catch
    % If coastlines.mat not available, try to use borders
    warning('coastlines.mat not found, map will not show coastlines');
end

% Plot all observation stations (light gray dots)
plot(obs.sMS(:,1), obs.sMS(:,2), '.', 'Color', [0.5 0.5 0.5], ...
    'MarkerSize', 3);

% Plot all representative sites (small colored markers)
regions = fieldnames(repSites);
colors = lines(length(regions));
for i = 1:length(regions)
    otherSite = repSites.(regions{i});
    plot(otherSite.lon, otherSite.lat, 'o', ...
        'MarkerSize', 5, 'MarkerFaceColor', colors(i,:), ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
end

% Highlight current site (larger red marker)
plot(site.lon, site.lat, 'p', 'MarkerSize', 15, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Add text label for current site
text(site.lon, site.lat + 5, sprintf('%s', site.region), ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', 'r', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

hold off;

xlabel('Longitude (°E)', 'FontSize', 10);
ylabel('Latitude (°N)', 'FontSize', 10);
grid on;
axis equal tight;

% Set reasonable axis limits around the site
lonRange = max(obs.sMS(:,1)) - min(obs.sMS(:,1));
latRange = max(obs.sMS(:,2)) - min(obs.sMS(:,2));
padding = 0.15;

xlim([site.lon - lonRange*padding, site.lon + lonRange*padding]);
ylim([site.lat - latRange*padding, site.lat + latRange*padding]);

% Add count annotation
nStations = size(obs.sMS, 1);
text(0.02, 0.98, sprintf('%d stations', nStations), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 8, 'BackgroundColor', 'w');
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

% % Add interpretation guide
% text(0.1, 0.15, 'Performance Guide:', ...
%     'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold');

% guideText = {
%     'Excellent: R² > 0.75, RMSE < 5 ppb';
%     'Good: R² > 0.65, RMSE < 7 ppb';
%     'Fair: R² > 0.50, RMSE < 10 ppb';
% };

% yPos = 0.10;
% for i = 1:length(guideText)
%     text(0.1, yPos, guideText{i}, ...
%         'Units', 'normalized', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
%     yPos = yPos - 0.05;
% end
end

function plotLegendPanel(uncertaintyBands, hasSoftData)
% Draw a standalone legend in an otherwise empty subplot panel

axis([0 1 0 1]);
axis off;
hold on;

% Position parameters
xL = 0.15;   % left margin
yStart = 0.85;
dy = 0.15;   % vertical spacing
boxWidth = 0.2;
boxHeight = 0.06;

% Title
text(0.5, 0.95, 'Legend', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');

y = yStart;

% Uncertainty bands (draw largest first)
for iSigma = sort(uncertaintyBands, 'descend')
    sigmaColor = [0.7, 0.85, 1.0] .^ iSigma;
    fill([xL, xL+boxWidth, xL+boxWidth, xL], ...
         [y-boxHeight/2, y-boxHeight/2, y+boxHeight/2, y+boxHeight/2], ...
         sigmaColor, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    text(xL + boxWidth + 0.05, y, sprintf('BME ±%d\\sigma', iSigma), ...
        'FontSize', 10, 'VerticalAlignment', 'middle');
    y = y - dy;
end

% BME mean line
plot([xL, xL+boxWidth], [y, y], '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 2.5);
text(xL + boxWidth + 0.05, y, 'BME Estimate', ...
    'FontSize', 10, 'VerticalAlignment', 'middle');
y = y - dy;

% Observations
plot(xL + boxWidth/2, y, 'o', 'MarkerSize', 7, ...
    'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'MarkerEdgeColor', [0.6 0.2 0.05], 'LineWidth', 1.5);
text(xL + boxWidth + 0.05, y, 'Observations', ...
    'FontSize', 10, 'VerticalAlignment', 'middle');
y = y - dy;

% Soft data (only if present)
if hasSoftData
    plot(xL + boxWidth/2, y, 's', 'MarkerSize', 7, ...
        'MarkerFaceColor', [0.4660 0.6740 0.1880], ...
        'MarkerEdgeColor', [0.3 0.5 0.1], 'LineWidth', 1.2);
    text(xL + boxWidth + 0.05, y, 'Soft-Data (CTM)', ...
        'FontSize', 10, 'VerticalAlignment', 'middle');
end

hold off;
end

function formatDecimalYearAxis(ax)
% Convert decimal-year XTick values to 'mmm-yyyy' labels without
% using fractional year arithmetic (avoids duplicate-month bug).
ticks = ax.XTick;
tickYears  = floor(ticks);
tickMonths = round(mod(ticks, 1) * 12) + 1;

% Clamp: mod rounding can yield 13 at exactly the year boundary
overflow = tickMonths > 12;
tickMonths(overflow) = 1;
tickYears(overflow)  = tickYears(overflow) + 1;

tickDates = datetime(tickYears(:), tickMonths(:), 1);
ax.XTickLabel = datestr(tickDates, 'mmm-yyyy');
ax.XTickLabelRotation = 45;
end
