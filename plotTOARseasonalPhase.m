function plotTOARseasonalPhase(obs, seasonality, saveFigs)
% plotTOARseasonalPhase - Create visualizations of seasonal patterns
%
% SYNTAX:
%   plotTOARseasonalPhase(obs, seasonality, saveFigs)
%
% INPUTS:
%   obs         - Structure from getTOARobservationalData
%   seasonality - Structure from calculateTOARseasonality
%   saveFigs    - Save figures (0/1), default: 1

if nargin < 3, saveFigs = 1; end

figDir = fullfile('0figures', 'seasonality');
if saveFigs && ~exist(figDir, 'dir')
    mkdir(figDir);
end

% Extract valid data
valid = seasonality.isValid;
lat = seasonality.lat(valid);
lon = seasonality.lon(valid);
peakMonth = seasonality.peakMonth(valid);
amplitude = seasonality.amplitude(valid);
phase = seasonality.phase(valid);
hemisphere = seasonality.hemisphere(valid);
climatology_valid = seasonality.climatology(valid, :);

NHmask = strcmp(hemisphere, 'NH');
SHmask = strcmp(hemisphere, 'SH');

%% Figure 1: Spatial Map of Peak Month
figure('Position', [100 100 1400 600], 'Color', 'w');

% Create circular colormap (12 months)
monthColors = hsv(12);

subplot(1, 2, 1);
hold on;

% Plot stations colored by peak month
for iMonth = 1:12
    monthMask = (peakMonth == iMonth);
    if sum(monthMask) > 0
        scatter(lon(monthMask), lat(monthMask), 60, monthColors(iMonth, :), ...
            'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    end
end

% Add borders
if exist('borderdata.mat', 'file')
    load('borderdata.mat', 'places', 'longitude', 'latitude');
    for k = 1:length(places)
        if ~isempty(longitude{k})
            plot(longitude{k}, latitude{k}, 'k', 'LineWidth', 0.5);
        end
    end
end

% Formatting
xlabel('Longitude (°)', 'FontSize', 12);
ylabel('Latitude (°)', 'FontSize', 12);
title('Peak Ozone Month by Station', 'FontSize', 14, 'FontWeight', 'bold');
axis equal tight;
grid on;

% Colorbar with month labels
colormap(gca, monthColors);
cb = colorbar;
cb.Ticks = linspace(1/24, 1-1/24, 12);
cb.TickLabels = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', ...
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};
cb.Label.String = 'Peak Month';
cb.Label.FontSize = 12;

subplot(1, 2, 2);
hold on;

% Plot amplitude
scatter(lon, lat, 60, amplitude, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);

% Add borders
if exist('borderdata.mat', 'file')
    for k = 1:length(places)
        if ~isempty(longitude{k})
            plot(longitude{k}, latitude{k}, 'k', 'LineWidth', 0.5);
        end
    end
end

xlabel('Longitude (°)', 'FontSize', 12);
ylabel('Latitude (°)', 'FontSize', 12);
title('Seasonal Amplitude (Peak - Trough)', 'FontSize', 14, 'FontWeight', 'bold');
axis equal tight;
grid on;

colormap(gca, jet);
cb = colorbar;
cb.Label.String = 'Amplitude (ppb)';
cb.Label.FontSize = 12;

if saveFigs
    print(fullfile(figDir, 'seasonal_peak_month_map.png'), '-dpng', '-r300');
end

%% Figure 2: Peak Month vs Latitude
figure('Position', [100 100 1000 600], 'Color', 'w');

hold on;

% Scatter plot
scatter(lat(NHmask), peakMonth(NHmask), 50, 'b', 'filled', ...
    'MarkerFaceAlpha', 0.6, 'DisplayName', 'Northern Hemisphere');
scatter(lat(SHmask), peakMonth(SHmask), 50, 'r', 'filled', ...
    'MarkerFaceAlpha', 0.6, 'DisplayName', 'Southern Hemisphere');

% Add smoothed trend line
if sum(valid) > 20
    latBins = -60:10:60;
    peakMean = NaN(length(latBins)-1, 1);
    
    for i = 1:length(latBins)-1
        binMask = lat >= latBins(i) & lat < latBins(i+1);
        if sum(binMask) >= 3
            peaks = peakMonth(binMask);
            % Handle circular mean for SH (Dec-Jan wrap)
            if latBins(i) < 0
                peaks(peaks < 6) = peaks(peaks < 6) + 12;
            end
            peakMean(i) = mod(mean(peaks), 12);
            if peakMean(i) == 0, peakMean(i) = 12; end
        end
    end
    
    binCenters = latBins(1:end-1) + 5;
    validBins = ~isnan(peakMean);
    plot(binCenters(validBins), peakMean(validBins), 'k-', 'LineWidth', 2.5, ...
        'DisplayName', 'Latitudinal Mean');
end

% Formatting
xlabel('Latitude (°)', 'FontSize', 14);
ylabel('Peak Ozone Month', 'FontSize', 14);
title('Seasonal Peak Timing vs Latitude', 'FontSize', 16, 'FontWeight', 'bold');
yticks(1:12);
yticklabels({'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', ...
             'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'});
ylim([0.5 12.5]);
grid on;
legend('Location', 'best', 'FontSize', 11);

% Add equator line
plot([0 0], [0.5 12.5], 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
text(0, 13, 'Equator', 'HorizontalAlignment', 'center', 'FontSize', 10);

if saveFigs
    print(fullfile(figDir, 'peak_month_vs_latitude.png'), '-dpng', '-r300');
end

%% Figure 3: Monthly Climatology by Hemisphere
figure('Position', [100 100 1200 500], 'Color', 'w');

subplot(1, 2, 1);
hold on;

% NH climatology - FIX: Use climatology_valid instead of indexing twice
if sum(NHmask) > 0
    NHclim = climatology_valid(NHmask, :);  % ← FIXED
    NHmean = mean(NHclim, 1, 'omitnan');
    NHstd = std(NHclim, 0, 1, 'omitnan');
    NHse = NHstd / sqrt(sum(NHmask));
    
    monthVec = 1:12;
    fill([monthVec, fliplr(monthVec)], ...
         [NHmean - NHse, fliplr(NHmean + NHse)], ...
         'b', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(monthVec, NHmean, 'b-', 'LineWidth', 2.5);
end

xlabel('Month', 'FontSize', 12);
ylabel('Ozone (ppb)', 'FontSize', 12);
title('Northern Hemisphere', 'FontSize', 14, 'FontWeight', 'bold');
xticks(1:12);
xticklabels({'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'});
grid on;
xlim([0.5 12.5]);

subplot(1, 2, 2);
hold on;

% SH climatology - FIX: Use climatology_valid instead of indexing twice
if sum(SHmask) > 0
    SHclim = climatology_valid(SHmask, :);  % ← FIXED
    SHmean = mean(SHclim, 1, 'omitnan');
    SHstd = std(SHclim, 0, 1, 'omitnan');
    SHse = SHstd / sqrt(sum(SHmask));
    
    monthVec = 1:12;
    fill([monthVec, fliplr(monthVec)], ...
         [SHmean - SHse, fliplr(SHmean + SHse)], ...
         'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(monthVec, SHmean, 'r-', 'LineWidth', 2.5);
end

xlabel('Month', 'FontSize', 12);
ylabel('Ozone (ppb)', 'FontSize', 12);
title('Southern Hemisphere', 'FontSize', 14, 'FontWeight', 'bold');
xticks(1:12);
xticklabels({'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'});
grid on;
xlim([0.5 12.5]);

sgtitle('Mean Monthly Climatology', 'FontSize', 16, 'FontWeight', 'bold');

if saveFigs
    print(fullfile(figDir, 'hemisphere_climatology.png'), '-dpng', '-r300');
end

%% Figure 4: Polar Plot of Phase
figure('Position', [100 100 800 800], 'Color', 'w');

ax = polaraxes;
hold on;

% Convert peak month to angle (radians)
thetaNH = (peakMonth(NHmask) - 1) * 2*pi/12;
thetaSH = (peakMonth(SHmask) - 1) * 2*pi/12;

% Radius = absolute latitude
rNH = abs(lat(NHmask));
rSH = abs(lat(SHmask));

% Plot
polarscatter(thetaNH, rNH, 50, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
polarscatter(thetaSH, rSH, 50, 'r', 'filled', 'MarkerFaceAlpha', 0.6);

% Formatting
ax.ThetaZeroLocation = 'top';
ax.ThetaDir = 'clockwise';
ax.ThetaTick = 0:30:330;
ax.ThetaTickLabel = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', ...
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};
ax.RLim = [0 70];
title('Seasonal Peak Timing (Polar View)', 'FontSize', 16, 'FontWeight', 'bold');

legend({'Northern Hemisphere', 'Southern Hemisphere'}, 'Location', 'southoutside', ...
    'Orientation', 'horizontal', 'FontSize', 12);

if saveFigs
    print(fullfile(figDir, 'seasonal_phase_polar.png'), '-dpng', '-r300');
end

%% Figure 5: Latitude Bins Comparison
figure('Position', [100 100 1200 800], 'Color', 'w');

latBins = [-60 -40 -20 0 20 40 60];
colors = jet(length(latBins)-1);

for i = 1:length(latBins)-1
    subplot(3, 2, i);
    hold on;
    
    binMask = lat >= latBins(i) & lat < latBins(i+1);
    
    if sum(binMask) > 0
        
        binClim = climatology_valid(binMask, :);
        binMean = mean(binClim, 1, 'omitnan');
        binStd = std(binClim, 0, 1, 'omitnan');
        
        monthVec = 1:12;
        fill([monthVec, fliplr(monthVec)], ...
             [binMean - binStd, fliplr(binMean + binStd)], ...
             colors(i, :), 'FaceAlpha', 0.3, 'EdgeColor', 'none');
        plot(monthVec, binMean, 'Color', colors(i, :), 'LineWidth', 2);
        
        % Mark peak
        [~, peakIdx] = max(binMean);
        plot(peakIdx, binMean(peakIdx), 'ko', 'MarkerSize', 8, ...
            'MarkerFaceColor', 'k');
        
        title(sprintf('%.0f° to %.0f° (%d stations)', ...
            latBins(i), latBins(i+1), sum(binMask)), 'FontSize', 11);
    else
        title(sprintf('%.0f° to %.0f° (no data)', ...
            latBins(i), latBins(i+1)), 'FontSize', 11);
    end
    
    xlabel('Month', 'FontSize', 10);
    ylabel('Ozone (ppb)', 'FontSize', 10);
    xticks(1:12);
    xticklabels({'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'});
    grid on;
    xlim([0.5 12.5]);
end

sgtitle('Monthly Climatology by Latitude Band', 'FontSize', 16, 'FontWeight', 'bold');

if saveFigs
    print(fullfile(figDir, 'latitude_band_climatology.png'), '-dpng', '-r300');
end

fprintf('Seasonal phase plots created and saved to: %s\n', figDir);

end