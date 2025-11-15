function plotTOARvalidation(valPairOut, valStats, valParam, obs, go, BMEparam)
% plotTOARvalidation - Create comprehensive validation plots
%
% SYNTAX:
%   plotTOARvalidation(valPairOut, valStats, valParam, obs, go, BMEparam)

figDir = fullfile('7validation', 'figs');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

Y_obs = valPairOut.Y_obs;
Y_est = valPairOut.Y_est;
sk = valPairOut.sk;
tk = valPairOut.tk;

% Add log-transform indicator
ltStr = sprintf(', lt=%d', obs.logTransf);
ltSuffix = sprintf('_lt%d', obs.logTransf);

%% Figure 1: Scatter Plot with Statistics
figure('Position', [100 100 900 900], 'Color', 'w');

% Scatter plot
scatter(Y_obs, Y_est, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.4);
hold on;

% 1:1 line
maxVal = max([Y_obs; Y_est]);
minVal = min([Y_obs; Y_est]);
plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 2.5);

% Best fit line
p = polyfit(Y_obs, Y_est, 1);
yfit = polyval(p, [minVal maxVal]);
plot([minVal maxVal], yfit, 'r-', 'LineWidth', 2.5);

% Formatting
xlabel(['Observed ' obs.Zlabel], 'FontSize', 16, 'FontWeight', 'bold');
ylabel(['Predicted ' obs.Zlabel], 'FontSize', 16, 'FontWeight', 'bold');
title({'TOAR BME Leave-One-Out Cross Validation', ...
    sprintf('BME Method: %s, GO Scenario: %d, Format: %s%s', ...
    BMEparam.BMEmethod8digits, go.scenario, BMEparam.dataFormat, ltStr)}, ...
    'FontSize', 18, 'FontWeight', 'bold');
grid on;
axis equal;
xlim([minVal maxVal]);
ylim([minVal maxVal]);
set(gca, 'FontSize', 14);

% Statistics text box
statsText = sprintf(['N = %d\n' ...
    'R = %.3f\n' ...
    'R² = %.3f\n' ...
    'RMSE = %.2f %s\n' ...
    'MAE = %.2f %s\n' ...
    'ME = %.2f %s\n' ...
    'NMB = %.1f%%\n' ...
    'Slope = %.3f\n' ...
    'Intercept = %.2f'], ...
    valStats.N, valStats.PearsonR, valStats.R2, ...
    valStats.RMSE, obs.Zunit, valStats.MAE, obs.Zunit, ...
    valStats.ME, obs.Zunit, valStats.NMB, ...
    valStats.Slope, valStats.Intercept);

annotation('textbox', [0.15 0.65 0.25 0.25], 'String', statsText, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
    'EdgeColor', 'black', 'FontSize', 13, 'FontWeight', 'bold', ...
    'LineWidth', 1.5);

legend('Validation Pairs', '1:1 Line', ...
    sprintf('Best Fit (y=%.2fx+%.2f)', p(1), p(2)), ...
    'Location', 'southeast', 'FontSize', 13);

% Save
filename = sprintf('TOAR_LOOCV_scatter_BME%s_go%d%s_%s_y%s.png', ...
    BMEparam.BMEmethod8digits, go.scenario, ltSuffix, BMEparam.dataFormat, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

%% Figure 2: Residual Analysis
figure('Position', [100 100 1400 600], 'Color', 'w');

residuals = Y_obs - Y_est;

% Residual vs Predicted
subplot(1, 2, 1);
scatter(Y_est, residuals, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.4);
hold on;
plot([minVal maxVal], [0 0], 'k--', 'LineWidth', 2);
yline(mean(residuals), 'r-', 'LineWidth', 2, ...
    'Label', sprintf('Mean = %.2f', mean(residuals)));
yline(2*std(residuals), 'r:', 'LineWidth', 1.5);
yline(-2*std(residuals), 'r:', 'LineWidth', 1.5);
xlabel(['Predicted ' obs.Zlabel], 'FontSize', 14, 'FontWeight', 'bold');
ylabel(['Residuals (' obs.Zunit ')'], 'FontSize', 14, 'FontWeight', 'bold');
title('Residual Plot', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12);

% Residual histogram
subplot(1, 2, 2);
histogram(residuals, 50, 'FaceColor', 'b', 'FaceAlpha', 0.6, 'EdgeColor', 'k');
hold on;
xline(0, 'k--', 'LineWidth', 2);
xline(mean(residuals), 'r-', 'LineWidth', 2, ...
    'Label', sprintf('Mean = %.2f', mean(residuals)));
xlabel(['Residuals (' obs.Zunit ')'], 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Frequency', 'FontSize', 14, 'FontWeight', 'bold');
title('Residual Distribution', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12);

sgtitle('Residual Analysis', 'FontSize', 18, 'FontWeight', 'bold');

% Save
filename = sprintf('TOAR_LOOCV_residuals_BME%s_go%d_%s_y%s.png', ...
    BMEparam.BMEmethod8digits, go.scenario, BMEparam.dataFormat, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

%% Figure 3: Spatial Distribution of Errors
figure('Position', [100 100 1200 900], 'Color', 'w');

% Absolute error spatial map
absError = abs(residuals);
scatter(sk(:,1), sk(:,2), 40, absError, 'filled');
hold on;

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
ylabel(cb, ['Absolute Error (' obs.Zunit ')'], 'FontSize', 14);
xlabel('Longitude (°)', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Latitude (°)', 'FontSize', 16, 'FontWeight', 'bold');
title({'Spatial Distribution of Absolute Errors', ...
    sprintf('Mean Abs Error: %.2f %s', valStats.MAE, obs.Zunit)}, ...
    'FontSize', 18, 'FontWeight', 'bold');
axis equal tight;
grid on;
set(gca, 'FontSize', 14);

% Save
filename = sprintf('TOAR_LOOCV_spatial_error_BME%s_go%d_%s_y%s.png', ...
    BMEparam.BMEmethod8digits, go.scenario, BMEparam.dataFormat, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

%% Figure 4: Temporal Analysis
figure('Position', [100 100 1400 600], 'Color', 'w');

% Convert decimal year to year-month for grouping
years = floor(tk);
months = round((tk - years) * 12) + 1;
yearMonth = years + (months - 0.5) / 12;  % Mid-month

% Monthly statistics
uniqueYM = unique(yearMonth);
monthlyRMSE = NaN(length(uniqueYM), 1);
monthlyN = NaN(length(uniqueYM), 1);

for i = 1:length(uniqueYM)
    idx = (yearMonth == uniqueYM(i));
    monthlyRMSE(i) = sqrt(mean((Y_obs(idx) - Y_est(idx)).^2));
    monthlyN(i) = sum(idx);
end

% Plot monthly RMSE
subplot(1, 2, 1);
bar(uniqueYM, monthlyRMSE, 'FaceColor', 'b', 'EdgeColor', 'k');
xlabel('Time (Year)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(['RMSE (' obs.Zunit ')'], 'FontSize', 14, 'FontWeight', 'bold');
title('Monthly RMSE', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12);

% Plot sample size
subplot(1, 2, 2);
bar(uniqueYM, monthlyN, 'FaceColor', 'g', 'EdgeColor', 'k');
xlabel('Time (Year)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Number of Validation Pairs', 'FontSize', 14, 'FontWeight', 'bold');
title('Sample Size by Month', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12);

sgtitle('Temporal Validation Analysis', 'FontSize', 18, 'FontWeight', 'bold');

% Save
filename = sprintf('TOAR_LOOCV_temporal_BME%s_go%d_%s_y%s.png', ...
    BMEparam.BMEmethod8digits, go.scenario, BMEparam.dataFormat, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

fprintf('Validation plots saved to: %s\n', figDir);
% close all;

end
