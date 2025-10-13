function exploreTOARdata(obs, explorePlot, mapArea)
% exploreTOARdata - Exploratory data analysis of TOAR ozone data
%
% Performs exploratory data analysis of TOAR-II ozone observational data
%
% SYNTAX
%
% exploreTOARdata(obs, explorePlot, mapArea);
%
% INPUT:
%
% obs          structure containing TOAR obs data from getTOARobservationalData
%              See help getTOARobservationalData for details
%              default: loads all station types for 2010-2020
% explorePlot  scalar indicating plots cumulatively, as follows:
%              0 : no plot
%              1 : colorplot of data year 2015
%              2 : plot 1 + time series at 10 sites with most obs
%              3 : plot 1,2 + histogram of Y (possibly log concentrations)
%              4 : plot 2,3 + colorplot of data years 2010, 2015, 2020
%              5 : plot 2,3,4 + time series at site with least/most obs
%              6 : plot 2,3,4,5 + time trend percentiles
%              7 : plot 2,3,4,5,6 + time trend mean +/- stdev
%              8 : plot 2,3,4,5,6,7 + histogram of Z if Y is log transformed
%              9: all plots + seasonal plots
%              default: explorePlot=8
% mapArea      scalar determining the geographical mapping area:
%              1-Global, 2-North America, 3-Europe, 4-Asia, 
%              5-US, 6-User defined
%              default: mapArea=1
%
% EXAMPLE
%
% % Explore ozone data for 2010-2020
% obs = getTOARobservationalData('all', [2010 2020]);
% exploreTOARdata(obs);
%
% % Explore only urban stations
% obs = getTOARobservationalData({'urban'}, [2015 2020]);
% exploreTOARdata(obs, 8, 2);

if nargin < 1
    obs = getTOARobservationalData('all', [2015 2020]);
end
if nargin < 2, explorePlot = 8; end
if nargin < 3, mapArea = 1; end

% Set up explore options structure
exploreOptions.plotHistogram = 0;
exploreOptions.plotTimeTrendMeanStdev = 0;
exploreOptions.plotTimeTrendPercentiles = 0;
exploreOptions.plotTimeSeriesLeastMostObs = 0;
exploreOptions.plotTimeSeriesSitesMostObs = 0;
exploreOptions.plotColorPlots = 0;
exploreOptions.mapArea = mapArea;

if explorePlot >= 1, exploreOptions.plotColorPlots = 1; end
if explorePlot >= 2, exploreOptions.plotTimeSeriesSitesMostObs = 1; end
if explorePlot >= 3, exploreOptions.plotHistogram = 1; end
if explorePlot >= 4, exploreOptions.plotColorPlots = 2; end
if explorePlot >= 5, exploreOptions.plotTimeSeriesLeastMostObs = 1; end
if explorePlot >= 6, exploreOptions.plotTimeTrendPercentiles = 1; end
if explorePlot >= 7, exploreOptions.plotTimeTrendMeanStdev = 1; end
if explorePlot >= 8, exploreOptions.plotHistogram = 2; end
if explorePlot >= 9, exploreOptions.plotSeasonality = 1; end

% Set parameters
zHistogramLowerPercentile = 0;
zHistogramUpperPercentile = 0.999;
yHistogramLowerPercentile = 0.001;
yHistogramUpperPercentile = 1;
nSitesMostObs = 10;
yDisplayLowerPercentile = 0.001;
yDisplayUpperPercentile = 0.999;
plotBorders = 1;

if exploreOptions.plotColorPlots == 1
    tMEplot = 2015;
elseif exploreOptions.plotColorPlots == 2
    tMEplot = 2010:5:2020;
end

% Set map display areas
switch exploreOptions.mapArea
    case 1, displayArea = [-180 180 -60 75];      % Global
    case 2, displayArea = [-170 -50 15 75];       % North America
    case 3, displayArea = [-15 40 35 72];         % Europe
    case 4, displayArea = [60 150 -10 55];        % Asia
    case 5, displayArea = [-126 -66 24 50];       % Continental USA
    case 6
        error('User definable displayArea is not defined, see code');
    otherwise
        error('mapArea needs to be 1-6, see help exploreTOARdata.m');
end

% Get dimensions
nMS = size(obs.Z, 1);
nME = size(obs.Z, 2);

fprintf('\nData Summary:\n');
fprintf('  Number of stations: %d\n', nMS);
fprintf('  Number of time periods: %d\n', nME);
fprintf('  Time range: %.2f to %.2f %s\n', min(obs.tME), max(obs.tME), obs.timeUnit);

% Histogram of original data (Z)
if exploreOptions.plotHistogram > 1 && obs.logTransf == 1
    z = obs.Z(:);
    z = z(~isnan(z));
    figure
    histline(z, 30, quantest(z, [zHistogramLowerPercentile zHistogramUpperPercentile]));
    set(gca, 'FontSize', 14);
    title(['Histogram of ' obs.Zname]);
    xlabel(obs.Zlabel);
    ylabel('pdf');
    xl = xlim;
    yl = ylim;
    zmeanstr = ['Mean = ' num2str(mean(z), 4) ' (' obs.Zunit ')'];
    zstdstr = ['StDev = ' num2str(std(z), 4) ' (' obs.Zunit ')'];
    zskewnessstr = ['Skewness = ' num2str(skewness(z), 2) ' (unitless)'];
    text(xl(1) + 0.55*diff(xl), yl(1) + 0.8*diff(yl), ...
        sprintf('%s\n%s\n%s', zmeanstr, zstdstr, zskewnessstr), ...
        'FontSize', 12);
end

% Histogram of analysis variable (Y)
if exploreOptions.plotHistogram > 0
    y = obs.Y(:);
    y = y(~isnan(y));
    figure
    histline(y, 30, quantest(y, [yHistogramLowerPercentile yHistogramUpperPercentile]));
    set(gca, 'FontSize', 14);
    title(['Histogram of ' obs.Yname]);
    xlabel(obs.Ylabel);
    ylabel('pdf');
    xl = xlim;
    yl = ylim;
    ymeanstr = ['Mean = ' num2str(mean(y), 4) ' (' obs.Yunit ')'];
    ystdstr = ['StDev = ' num2str(std(y), 4) ' (' obs.Yunit ')'];
    yskewnessstr = ['Skewness = ' num2str(skewness(y), 2) ' (unitless)'];
    text(xl(1) + 0.55*diff(xl), yl(1) + 0.8*diff(yl), ...
        sprintf('%s\n%s\n%s', ymeanstr, ystdstr, yskewnessstr), ...
        'FontSize', 12);
end

% Time trend of observation areal mean and variance
if exploreOptions.plotTimeTrendMeanStdev == 1
    obsMean = NaN(1, nME);
    obsVar = NaN(1, nME);
    for iME = 1:nME
        yiME = obs.Y(:, iME);
        idx = ~isnan(yiME);
        if sum(idx) > 0
            obsMean(iME) = mean(yiME(idx));
            obsVar(iME) = var(yiME(idx));
        end
    end
    figure
    hold on;
    hM(1) = plot(obs.tME, obsMean, '-k', 'LineWidth', 1.5);
    hM(2) = plot(obs.tME, obsMean + sqrt(obsVar), '--k', 'LineWidth', 1);
    plot(obs.tME, obsMean - sqrt(obsVar), '--k', 'LineWidth', 1);
    xlim([obs.tME(1) obs.tME(end)]);
    legendTextM = {'Areal mean', 'Areal mean ± std'};
    set(gca, 'FontSize', 14);
    title(['Time trend of ' obs.Yname ' areal mean and std']);
    xlabel(['Time (' obs.timeUnit ')']);
    ylabel(obs.Ylabel);
    legend(hM, legendTextM);
    grid on;
end

% Time trend of observation quantiles
if exploreOptions.plotTimeTrendPercentiles == 1
    quantVec = [0.95 0.75 0.50 0.25 0.05]';
    obsQuant = NaN(length(quantVec), nME);
    for iME = 1:nME
        yiME = obs.Y(:, iME);
        idx = ~isnan(yiME);
        if sum(idx) > 0
            obsQuant(:, iME) = quantest(yiME(idx), quantVec);
        end
    end
    figure
    hold on;
    colors = lines(length(quantVec));
    for j = 1:length(quantVec)
        h(j) = plot(obs.tME, obsQuant(j, :), 'Color', colors(j, :), 'LineWidth', 1.5);
        legendText{j} = sprintf('%d percentile', round(100 * quantVec(j)));
    end
    xlim([obs.tME(1) obs.tME(end)]);
    set(gca, 'FontSize', 14);
    title(['Time trend of ' obs.Yname ' percentiles']);
    xlabel(['Time (' obs.timeUnit ')']);
    ylabel(obs.Ylabel);
    legend(h, legendText, 'Location', 'best');
    grid on;
end

% Time series at monitoring stations with least and most obs
if exploreOptions.plotTimeSeriesLeastMostObs == 1
    nObs = sum(~isnan(obs.Y), 2);
    [~, idxSortedMS] = sort(nObs);
    idxMS = [idxSortedMS(1); idxSortedMS(end)];
    for ii = 1:length(idxMS)
        iMS = idxMS(ii);
        yiMS = obs.Y(iMS, :);
        idx = ~isnan(yiMS);
        figure;
        plot(obs.tME(idx), yiMS(idx), 'o-', 'MarkerSize', 4);
        xlim([obs.tME(1) obs.tME(end)]);
        set(gca, 'FontSize', 12);
        stationInfo = sprintf('%s (%s)', obs.stationID{iMS}, obs.stationType{iMS});
        title(sprintf('%s at station %s', obs.Yname, stationInfo));
        xlabel(['Time (' obs.timeUnit ')']);
        ylabel(obs.Ylabel);
        grid on;
    end
end

% Time series at sites with most observations
if exploreOptions.plotTimeSeriesSitesMostObs == 1
    nObs = sum(~isnan(obs.Y), 2);
    [~, idxSortedMS] = sort(nObs);
    idxMS = idxSortedMS(max(1, end - nSitesMostObs + 1):end);
    nSitesMostObs = length(idxMS);
    figure
    hold on;
    colors = lines(nSitesMostObs);
    for ii = 1:nSitesMostObs
        iMS = idxMS(ii);
        yiMS = obs.Y(iMS, :);
        idx = ~isnan(yiMS);
        hTS(ii) = plot(obs.tME(idx), yiMS(idx), 'o-', 'Color', colors(ii, :), 'MarkerSize', 3);
        legendTextTS{ii} = sprintf('%s', obs.stationID{iMS});
    end
    xlim([obs.tME(1) obs.tME(end)]);
    set(gca, 'FontSize', 12);
    title(sprintf('Time series of %s at %d sites with most observations', obs.Yname, nSitesMostObs));
    xlabel(['Time (' obs.timeUnit ')']);
    ylabel(obs.Ylabel);
    legend(hTS, legendTextTS, 'Location', 'best', 'FontSize', 8);
    grid on;
end

% Colorplots for different time events
if exploreOptions.plotColorPlots > 0
    y = obs.Y(~isnan(obs.Y));
    yLow = quantest(y, yDisplayLowerPercentile);
    yUp = quantest(y, yDisplayUpperPercentile);
    
    for ii = 1:length(tMEplot)
        % Find closest time index
        [~, iME] = min(abs(obs.tME - tMEplot(ii)));
        
        % Check if we're within a reasonable time window (e.g., 1 month)
        if abs(obs.tME(iME) - tMEplot(ii)) < 1/12
            yiME = obs.Y(:, iME);
            figure
            hold on
            idx = ~isnan(yiME);
            colorplot(obs.sMS(idx, :), yiME(idx), 'jet', {'Marker', 'MarkerSize'}, {'o', 8});
            clim([yLow yUp]);
            set(gca, 'FontSize', 14);
            cb = colorbar('FontSize', 14);
            ylabel(cb, obs.Ylabel);
            xlabel(['Longitude (' obs.spaceUnit ')']);
            ylabel(['Latitude (' obs.spaceUnit ')']);
            title(sprintf('%s for time %.1f (%s)', obs.Ylabel, obs.tME(iME), obs.timeUnit));
            
            % Plot borders using borderdata.mat
            if plotBorders
                % Try to load borderdata.mat from common locations
                borderdataPath = '';
                if exist('./1data/borderdata.mat', 'file')
                    borderdataPath = './1data/borderdata.mat';
                elseif exist('borderdata.mat', 'file')
                    borderdataPath = 'borderdata.mat';
                end
                
                if ~isempty(borderdataPath)
                    try
                        load(borderdataPath, 'places', 'lon', 'lat');
                        % Plot country borders
                        for k = 1:length(places)
                            if contains(lower(places{k}), 'country') || ...
                               ismember(places{k}, {'United States', 'Canada', 'Mexico', 'China', 'India', 'Germany', 'France', 'United Kingdom'})
                                plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
                            end
                        end
                    catch
                        % If borderdata.mat has a different structure, try alternative
                        % Or if USA-specific, load USAstates5.mat
                        if exist('./1data/USAstates5.mat', 'file') && mapArea == 5
                            load('./1data/USAstates5.mat', 'X', 'Y');
                            for iState = 1:length(X)
                                plot(X{iState}, Y{iState}, 'k', 'LineWidth', 0.5);
                            end
                        end
                    end
                end
            end
            
            axis(displayArea);
            axis equal tight
        else
            fprintf('Warning: No data found close to year %d\n', tMEplot(ii));
        end
    end
end

%% Add to exploreTOARdata.m (around line 50, after basic statistics)

%% Seasonal Phase Analysis
if exploreOptions.plotSeasonality > 0
    fprintf('\n--- Seasonal Phase Analysis ---\n');
    
    % Calculate seasonality
    seasonality = calculateTOARseasonality(obs, 24);
    
    % Create plots
    plotTOARseasonalPhase(obs, seasonality, 1);
    
    % Save seasonality results
    saveDir = '3covariance';  % Or wherever appropriate
    if ~exist(saveDir, 'dir'), mkdir(saveDir); end
    
    savePath = fullfile(saveDir, sprintf('TOAR_seasonality_%d_%d.mat', ...
        obs.tME(1), obs.tME(end)));
    save(savePath, 'seasonality');
    fprintf('Seasonality results saved to: %s\n', savePath);
end

fprintf('\nExploratory analysis complete.\n');

end