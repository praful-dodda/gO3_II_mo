function plotSoftData(softData, obs, timeIndex, plotType)
% plotSoftData - Visualize RAMP-corrected soft data
%
% Creates maps of soft data (mean and variance) for specified time periods,
% optionally overlaying hard data locations.
%
% SYNTAX:
%   plotSoftData(softData, obs, timeIndex, plotType)
%
% INPUTS:
%   softData  - Structure from createSoftDataStructure
%   obs       - Observational data structure (optional, for overlay)
%   timeIndex - Time indices to plot (e.g., 1 for first month, or 1:3)
%   plotType  - 'mean', 'variance', or 'both' (default: 'both')
%
% EXAMPLES:
%   % Plot first month (mean and variance)
%   plotSoftData(softData, obs, 1);
%
%   % Plot mean only for January 2016
%   plotSoftData(softData, [], 1, 'mean');
%
%   % Plot first 3 months
%   plotSoftData(softData, obs, 1:3);

%% Input Validation
if nargin < 2, obs = []; end
if nargin < 3, timeIndex = 1; end
if nargin < 4, plotType = 'both'; end

% Validate time indices
if max(timeIndex) > length(softData.tME)
    error('timeIndex exceeds available time periods (%d)', length(softData.tME));
end

plotDir = fullfile('2softdata', 'plots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

%% Create Plots for Each Time Index
for iTime = timeIndex
    tME = softData.tME(iTime);
    year = floor(tME);
    month = round((tME - year) * 12) + 1;

    fprintf('Plotting time index %d: Year %d, Month %d (tME=%.4f)\n', ...
        iTime, year, month, tME);

    %% Prepare Data
    Z_time = softData.Z(:, iTime);
    Zv_time = softData.Zv(:, iTime);
    lon = softData.sMS(:, 1);
    lat = softData.sMS(:, 2);

    % Remove NaN for plotting
    validIdx = ~isnan(Z_time);
    if sum(validIdx) == 0
        warning('No valid data for time index %d', iTime);
        continue;
    end

    lon_valid = lon(validIdx);
    lat_valid = lat(validIdx);
    Z_valid = Z_time(validIdx);
    Zv_valid = Zv_time(validIdx);

    %% Plot Mean Field
    if strcmpi(plotType, 'mean') || strcmpi(plotType, 'both')
        figure('Position', [100 100 1200 900], 'Color', 'w');

        scatter(lon_valid, lat_valid, 40, Z_valid, 'filled');
        hold on;

        % Overlay obs locations if provided
        if ~isempty(obs)
            % Find obs at this time
            [~, obsTimeIdx] = min(abs(obs.tME - tME));
            obsAtTime = ~isnan(obs.Z(:, obsTimeIdx));

            if sum(obsAtTime) > 0
                plot(obs.sMS(obsAtTime, 1), obs.sMS(obsAtTime, 2), ...
                    'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'LineWidth', 1.5);
            end
        end

        % Add borders if available
        if exist('1data/borderdata.mat', 'file')
            load('1data/borderdata.mat', 'places', 'lon', 'lat');
            for k = 1:length(places)
                if ~isempty(lon{k})
                    plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
                end
            end
        end

        colormap(jet);
        cb = colorbar;
        ylabel(cb, [softData.Zlabel ' (' softData.Zunit ')'], 'FontSize', 12);
        caxis([prctile(Z_valid, 1), prctile(Z_valid, 99)]);

        xlabel('Longitude (°)', 'FontSize', 14, 'FontWeight', 'bold');
        ylabel('Latitude (°)', 'FontSize', 14, 'FontWeight', 'bold');
        title({sprintf('%s Mean Field', softData.modelName), ...
            sprintf('Year %d, Month %d', year, month)}, ...
            'FontSize', 16, 'FontWeight', 'bold');

        axis equal tight;
        grid on;
        set(gca, 'FontSize', 12);

        % Stats text
        statsText = sprintf('Grid points: %d\nMean: %.1f %s\nStd: %.1f %s\nRange: [%.1f, %.1f] %s', ...
            sum(validIdx), mean(Z_valid), softData.Zunit, ...
            std(Z_valid), softData.Zunit, ...
            min(Z_valid), max(Z_valid), softData.Zunit);

        annotation('textbox', [0.02 0.75 0.15 0.15], 'String', statsText, ...
            'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'FontSize', 10, 'FontWeight', 'bold');

        if ~isempty(obs)
            legend('Soft Data', 'Obs Locations', 'Borders', 'Location', 'southeast');
        end

        % Save
        filename = sprintf('%s_mean_y%d_m%02d.png', softData.modelName, year, month);
        print(fullfile(plotDir, filename), '-dpng', '-r300');
        fprintf('  Saved: %s\n', filename);
    end

    %% Plot Variance Field
    if strcmpi(plotType, 'variance') || strcmpi(plotType, 'both')
        figure('Position', [100 100 1200 900], 'Color', 'w');

        scatter(lon_valid, lat_valid, 40, sqrt(Zv_valid), 'filled');
        hold on;

        % Overlay obs locations if provided
        if ~isempty(obs)
            [~, obsTimeIdx] = min(abs(obs.tME - tME));
            obsAtTime = ~isnan(obs.Z(:, obsTimeIdx));

            if sum(obsAtTime) > 0
                plot(obs.sMS(obsAtTime, 1), obs.sMS(obsAtTime, 2), ...
                    'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'LineWidth', 1.5);
            end
        end

        % Add borders if available
        if exist('1data/borderdata.mat', 'file')
            load('1data/borderdata.mat', 'places', 'lon', 'lat');
            for k = 1:length(places)
                if ~isempty(lon{k})
                    plot(lon{k}, lat{k}, 'k', 'LineWidth', 0.5);
                end
            end
        end

        colormap(hot);
        cb = colorbar;
        ylabel(cb, sprintf('Std Dev (%s)', softData.Zunit), 'FontSize', 12);
        caxis([prctile(sqrt(Zv_valid), 1), prctile(sqrt(Zv_valid), 99)]);

        xlabel('Longitude (°)', 'FontSize', 14, 'FontWeight', 'bold');
        ylabel('Latitude (°)', 'FontSize', 14, 'FontWeight', 'bold');
        title({sprintf('%s Uncertainty Field (Std Dev)', softData.modelName), ...
            sprintf('Year %d, Month %d', year, month)}, ...
            'FontSize', 16, 'FontWeight', 'bold');

        axis equal tight;
        grid on;
        set(gca, 'FontSize', 12);

        % Stats text
        statsText = sprintf('Grid points: %d\nMean σ: %.2f %s\nRange: [%.2f, %.2f] %s', ...
            sum(validIdx), mean(sqrt(Zv_valid)), softData.Zunit, ...
            min(sqrt(Zv_valid)), max(sqrt(Zv_valid)), softData.Zunit);

        annotation('textbox', [0.02 0.75 0.15 0.15], 'String', statsText, ...
            'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'FontSize', 10, 'FontWeight', 'bold');

        if ~isempty(obs)
            legend('Soft Data Uncertainty', 'Obs Locations', 'Borders', 'Location', 'southeast');
        end

        % Save
        filename = sprintf('%s_variance_y%d_m%02d.png', softData.modelName, year, month);
        print(fullfile(plotDir, filename), '-dpng', '-r300');
        fprintf('  Saved: %s\n', filename);
    end
end

fprintf('\nPlots saved to: %s\n', plotDir);
close all;

end
