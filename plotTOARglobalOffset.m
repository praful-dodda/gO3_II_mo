function plotTOARglobalOffset(obs, go, goPlot, tMEplot, displayArea, plotBorders, yrange)
% plotTOARglobalOffset - Plot global offset of TOAR ozone data
%
% Plots the global offset of TOAR-II ozone observations
% 
% SYNTAX:
%
% plotTOARglobalOffset(obs, go, goPlot, tMEplot, displayArea, plotBorders, yrange)
%
% INPUT:
%
% obs          structure from getTOARobservationalData
% go           structure from getTOARglobalOffset or scalar for scenario (0-4)
%              default: 3
% goPlot       scalar indicating plot detail level:
%              0 - no plots
%              1 - plot of mt and map of ms
%              2 - same as 1 + map of msRaw
%              3 - same as 2 + time series at specific sites and maps at specific times
%              default: 1
% tMEplot      vector with years to plot (must be within data range)
%              default: [2010:5:2020]
% displayArea  [lonmin lonmax latmin latmax] defining display area
%              NaN values are ignored
%              default: [-180 180 -60 75] (global)
% plotBorders  scalar: 1 to plot country borders, 0 otherwise
%              default: 1
% yrange       [min max] for color scale
%              [] uses 5th and 95th percentiles
%              NaN uses automatic scaling
%              default: []
%
% EXAMPLE:
% 
% obs = getTOARobservationalData('all', [2010 2020]);
% go = getTOARglobalOffset(obs, 3, 0);
% plotTOARglobalOffset(obs, go, 3, [2010 2015 2020]);

% Set default inputs
if nargin < 1, error('obs structure required'); end
if nargin < 2, go = 3; end
if nargin < 3, goPlot = 1; end
if nargin < 4, tMEplot = 2010:5:2020; end
if nargin < 5, displayArea = [-180 180 -60 75]; end
if nargin < 6, plotBorders = 1; end
if nargin < 7, yrange = []; end

% Load structures if numeric inputs provided
if isnumeric(go), go = getTOARglobalOffset(obs, go, 0); end

% Set color range
if isempty(yrange)
    yrangeQuant = [0.05 0.95];
    yrange = quantest(obs.Y(~isnan(obs.Y)), yrangeQuant);
end

% Set spatial domain for maps
ax = displayArea;
ax = [ax(1)-5 ax(2)+5 ax(3)-2 ax(4)+2];  % Add padding

% Load border data if available
bordersAvailable = false;
if plotBorders
    if exist('./1data/borderdata.mat', 'file')
        load('./1data/borderdata.mat', 'places', 'lon', 'lat');
        bordersAvailable = true;
    elseif exist('borderdata.mat', 'file')
        load('borderdata.mat', 'places', 'lon', 'lat');
        bordersAvailable = true;
    end
end

% Time series of raw and smoothed mean trend
if goPlot >= 1
    figure;
    hold on;
    htRaw = plot(go.tMEraw, go.mtRaw, 'o-r', 'LineWidth', 1.5, 'MarkerSize', 4);
    ht = plot(go.tME, go.mt, '.-k', 'LineWidth', 1.5);
    xlabel('Time (years)', 'FontSize', 12);
    ylabel(obs.Ylabel, 'FontSize', 12);
    title(sprintf('Raw and smoothed temporal mean trend of %s', obs.Yname), 'FontSize', 14);
    legend([htRaw ht], 'Raw mean trend (spatial average)', 'Smoothed mean trend', 'Location', 'best');
    grid on;
    set(gca, 'FontSize', 12);
end

% Map of raw spatial mean trend
if goPlot >= 2
    figure;
    Property = {'Marker', 'MarkerSize', 'MarkerEdgeColor'};
    Value = {'o', 10, [0 0 0]};
    colorplot(go.sMSraw, go.msRaw, redyellow, Property, Value, yrange);
    clim(yrange);
    cb = colorbar;
    ylabel(cb, obs.Ylabel, 'FontSize', 12);
    axis(ax);
    title(sprintf('Raw spatial trend of %s', obs.Ylabel), 'FontSize', 14);
    xlabel('Longitude (deg.)', 'FontSize', 12);
    ylabel('Latitude (deg.)', 'FontSize', 12);
    hold on;
    
    % Plot borders
    if bordersAvailable
        for k = 1:length(places)
            plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
        end
    end
    set(gca, 'FontSize', 12);
end

% Map of smoothed spatial mean trend
if goPlot >= 1
    figure;
    [xgkm, ygkm] = meshgrid(ax(1):0.5:ax(2), ax(3):0.5:ax(4));
    [zgkm] = griddata(go.sMS(:,1), go.sMS(:,2), go.ms, xgkm, ygkm);
    zgkm = reshape(zgkm, size(xgkm));
    colormap(redyellow);
    pcolor(xgkm, ygkm, zgkm);
    shading interp;
    cb = colorbar;
    ylabel(cb, obs.Ylabel, 'FontSize', 12);
    hold on;
    axis(ax);
    plot(go.sMSraw(:,1), go.sMSraw(:,2), '.k', 'MarkerSize', 4);
    title(sprintf('Smoothed spatial trend of %s', obs.Ylabel), 'FontSize', 14);
    xlabel('Longitude (deg.)', 'FontSize', 12);
    ylabel('Latitude (deg.)', 'FontSize', 12);
    
    % Plot borders
    if bordersAvailable
        for k = 1:length(places)
            plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
        end
    end
    set(gca, 'FontSize', 12);
end

% Plot time series at selected monitoring sites
if goPlot >= 3
    [~, idxObsMS] = sort(sum(isnan(obs.Y), 2)); % Sort sites by number of NaNs
    idxObsMS = idxObsMS(1:min(3, length(idxObsMS))); % Select up to 3 sites with fewest NaNs
    
    for i = 1:length(idxObsMS)
        iObsMS = idxObsMS(i);
        figure;
        hold on;
        hd = plot(obs.tME, obs.Y(iObsMS,:), 'o', 'MarkerSize', 6);
        ht = plot(obs.tME, stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS(iObsMS,:), obs.tME), '.-', 'LineWidth', 1.5);
        xlabel('Time (years)', 'FontSize', 12);
        ylabel(obs.Ylabel, 'FontSize', 12);
        stationInfo = sprintf('%s (%s)', obs.stationID{iObsMS}, obs.stationType{iObsMS});
        title(sprintf('Station: %s', stationInfo), 'FontSize', 14);
        legend([hd ht], 'Observations', 'Global offset', 'Location', 'best');
        grid on;
        set(gca, 'FontSize', 12);
    end
end

% Make maps of data and global offset at selected times
if goPlot >= 3
    % Find valid plot times within data range
    tMEplot = tMEplot(tMEplot >= min(obs.tME) & tMEplot <= max(obs.tME));
    
    for iMEplot = 1:length(tMEplot)
        tk = tMEplot(iMEplot);
        % Find closest time index
        [~, iObsME] = min(abs(obs.tME - tk));
        
        figure;
        hold on;
        
        % Create smoothed background using global offset
        [xgkm, ygkm] = meshgrid(ax(1):0.5:ax(2), ax(3):0.5:ax(4));
        [zgkm] = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, [xgkm(:) ygkm(:)], obs.tME(iObsME));
        zgkm = reshape(zgkm, size(xgkm));
        colormap(redyellow);
        pcolor(xgkm, ygkm, zgkm);
        shading interp;
        cb = colorbar;
        ylabel(cb, obs.Ylabel, 'FontSize', 12);
        
        % Overlay observations
        Property = {'Marker', 'MarkerSize', 'MarkerEdgeColor'};
        Value = {'o', 10, [0 0 0]};
        axis(ax);
        colorplot(obs.sMS, obs.Y(:, iObsME), redyellow, Property, Value, yrange);
        
        title(sprintf('%s for %.2f', obs.Ylabel, obs.tME(iObsME)), 'FontSize', 14);
        xlabel('Longitude (deg.)', 'FontSize', 12);
        ylabel('Latitude (deg.)', 'FontSize', 12);
        
        % Plot borders
        if bordersAvailable
            for k = 1:length(places)
                plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
            end
        end
        set(gca, 'FontSize', 12);
    end
end

end