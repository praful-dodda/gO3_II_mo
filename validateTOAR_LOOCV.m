function [valOut, valPairOut] = validateTOAR_LOOCV(obs, go, cov, KG, KS, BMEparam, valParam)
% validateTOAR_LOOCV - Leave-One-Out Cross Validation for TOAR BME estimates
%
% Performs LOOCV by iteratively removing each observation and estimating
% it using all remaining observations
%
% SYNTAX:
%   [valOut, valPairOut] = validateTOAR_LOOCV(obs, go, cov, KG, KS, BMEparam, valParam)
%
% INPUTS:
%   obs       - Structure from getTOARobservationalData
%   go        - Structure from getTOARglobalOffset
%   cov       - Structure from getTOARautoCov
%   KG        - General Knowledge from getTOARknowledgeBase
%   KS        - Site-specific Knowledge from getTOARknowledgeBase
%   BMEparam  - BME parameters from getTOARknowledgeBase
%   valParam  - Validation parameters structure:
%               .valYears        - Years to validate (e.g., [2016 2017])
%               .valMonths       - Months to validate (e.g., 1:12 or [6 7 8])
%               .forceEstimation - Force re-calculation (1) or use saved (0)
%               .savePlots       - Save validation plots (0/1)
%
% OUTPUTS:
%   valOut     - Table with validation statistics (R, RMSE, MAE, ME, etc.)
%   valPairOut - Structure with obs/predicted pairs for analysis
%
% EXAMPLE:
%   valParam.valYears = [2016 2017];
%   valParam.valMonths = 1:12;
%   valParam.forceEstimation = 0;
%   valParam.savePlots = 1;
%   [valOut, valPairOut] = validateTOAR_LOOCV(obs, go, cov, KG, KS, BMEparam, valParam);

%% Input Validation
if nargin < 7
    error('All 7 inputs required');
end

% Set defaults
if ~isfield(valParam, 'valYears'), valParam.valYears = [2016]; end
if ~isfield(valParam, 'valMonths'), valParam.valMonths = 1:12; end
if ~isfield(valParam, 'forceEstimation'), valParam.forceEstimation = 0; end
if ~isfield(valParam, 'savePlots'), valParam.savePlots = 1; end

%% Setup
fprintf('\n=== TOAR BME LEAVE-ONE-OUT CROSS VALIDATION ===\n');
fprintf('Validation years: %s\n', mat2str(valParam.valYears));
fprintf('Validation months: %s\n', mat2str(valParam.valMonths));

% Create output directory
valDir = fullfile('7validation');
if ~exist(valDir, 'dir')
    mkdir(valDir);
end

% Initialize output arrays
Y_obs_all = [];
Y_est_all = [];
Y_estNoGo_all = [];
sk_all = [];
tk_all = [];

%% Loop Through Years and Months
for iYear = 1:length(valParam.valYears)
    valYear = valParam.valYears(iYear);
    
    for iMonth = valParam.valMonths
        fprintf('\n--- Validating Year %d, Month %d ---\n', valYear, iMonth);
        
        % Create filename
        valFilename = sprintf('TOAR_LOOCV_BME%s_go%d_y%d_m%02d.mat', ...
            BMEparam.BMEmethod8digits, go.scenario, valYear, iMonth);
        valPath = fullfile(valDir, valFilename);
        
        % Check if already computed
        if exist(valPath, 'file') && ~valParam.forceEstimation
            fprintf('  Loading cached results...\n');
            load(valPath, 'valResults');
            
            Y_obs_month = valResults.Y_obs;
            Y_est_month = valResults.Y_est;
            Y_estNoGo_month = valResults.Y_estNoGo;
            sk_month = valResults.sk;
            tk_month = valResults.tk;
        else
            %% Select Data for This Month
            % Define time window (month ± temporal search radius)
            monthStart = valYear + (iMonth - 1)/12;
            monthEnd = valYear + iMonth/12;
            
            % Find observations in this time window
            inTimeWindow = (obs.tME >= monthStart - BMEparam.dmax(2)) & ...
                           (obs.tME < monthEnd + BMEparam.dmax(2));
            
            % Extract subset of data
            obs_subset.sMS = obs.sMS;
            obs_subset.tME = obs.tME(inTimeWindow);
            obs_subset.Y = obs.Y(:, inTimeWindow);
            
            % Convert to space-time format
            [ch, zh] = valstg2stv(obs_subset.Y, obs_subset.sMS, obs_subset.tME);
            
            % Remove NaN values
            validIdx = ~isnan(zh);
            ch = ch(validIdx, :);
            zh = zh(validIdx);
            
            nObs = length(zh);
            fprintf('  Observations in time window: %d\n', nObs);
            
            if nObs < 10
                fprintf('  WARNING: Too few observations for validation. Skipping.\n');
                continue;
            end
            
            %% Perform LOOCV
            fprintf('  Performing LOOCV...\n');
            
            % Remove global offset from observations
            goh = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ch(:,1:2), ch(:,3)');
            xh = zh - goh;
            
            % Call LOOCV function
            tic;
            % [XkBMEm,XkBMEv,MSE,MAE,ME]=krigingME_Xvalidation(1,KS.ph,KS.ps,KS.xh,KS.xms,KS.xvs,KG.covmodel,KG.covparam,BMEparam.nhmax,BMEparam.nsmax,BMEparam.dmax,KG.order,BMEparam.options);
            [XkBMEm,XkBMEv,MSE,MAE,ME]=krigingME_Xvalidation(1,KS.harddata.p,KS.softdata.p,KS.harddata.harddata.Xh,KS.xms,KS.xvs,KG.covmodel,KG.covparam,BMEparam.nhmax,BMEparam.nsmax,BMEparam.dmax,KG.order,BMEparam.options);
            elapsedTime = toc;
            
            fprintf('  LOOCV completed in %.1f seconds\n', elapsedTime);
            
            %% Process Results
            % Add global offset back
            gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ch(:,1:2), ch(:,3));
            YkBMEm = XkBMEm + gok;
            
            % Clean up variance
            XkBMEv(isnan(XkBMEv)) = max(XkBMEv(~isnan(XkBMEv)));
            XkBMEv = real(XkBMEv);
            
            % Filter to exact month being validated
            inExactMonth = (ch(:,3) >= monthStart) & (ch(:,3) < monthEnd);
            
            Y_obs_month = zh(inExactMonth);
            Y_est_month = YkBMEm(inExactMonth);
            Y_estNoGo_month = XkBMEm(inExactMonth);
            sk_month = ch(inExactMonth, 1:2);
            tk_month = ch(inExactMonth, 3);
            
            % Remove any remaining NaNs
            validPairs = ~isnan(Y_obs_month) & ~isnan(Y_est_month);
            Y_obs_month = Y_obs_month(validPairs);
            Y_est_month = Y_est_month(validPairs);
            Y_estNoGo_month = Y_estNoGo_month(validPairs);
            sk_month = sk_month(validPairs, :);
            tk_month = tk_month(validPairs);
            
            fprintf('  Valid pairs: %d\n', length(Y_obs_month));
            
            %% Save Results
            valResults.Y_obs = Y_obs_month;
            valResults.Y_est = Y_est_month;
            valResults.Y_estNoGo = Y_estNoGo_month;
            valResults.sk = sk_month;
            valResults.tk = tk_month;
            valResults.XkBMEv = XkBMEv(inExactMonth & validPairs);
            
            save(valPath, 'valResults', '-v7.3');
            fprintf('  Results saved: %s\n', valFilename);
        end
        
        %% Accumulate Results
        Y_obs_all = [Y_obs_all; Y_obs_month];
        Y_est_all = [Y_est_all; Y_est_month];
        Y_estNoGo_all = [Y_estNoGo_all; Y_estNoGo_month];
        sk_all = [sk_all; sk_month];
        tk_all = [tk_all; tk_month];
    end
end

%% Calculate Overall Validation Statistics
fprintf('\n=== OVERALL VALIDATION STATISTICS ===\n');
fprintf('Total validation pairs: %d\n', length(Y_obs_all));

if isempty(Y_obs_all)
    warning('No validation data available');
    valOut = [];
    valPairOut = [];
    return;
end

% Calculate metrics
valStats = calculateValidationStats(Y_obs_all, Y_est_all);

% Create results table
valOut = struct2table(valStats);

% Display results
fprintf('\nValidation Metrics:\n');
fprintf('  Pearson R: %.3f\n', valStats.PearsonR);
fprintf('  R²: %.3f\n', valStats.R2);
fprintf('  RMSE: %.2f ppb\n', valStats.RMSE);
fprintf('  MAE: %.2f ppb\n', valStats.MAE);
fprintf('  ME: %.2f ppb\n', valStats.ME);
fprintf('  MBE: %.2f ppb\n', valStats.MBE);

%% Package Output
valPairOut.Y_obs = Y_obs_all;
valPairOut.Y_est = Y_est_all;
valPairOut.Y_estNoGo = Y_estNoGo_all;
valPairOut.sk = sk_all;
valPairOut.tk = tk_all;

%% Create Validation Plots
if valParam.savePlots
    plotTOARvalidation(valPairOut, valStats, valParam, obs, go);
end

fprintf('\n=== VALIDATION COMPLETE ===\n\n');

end

%% Helper Functions

% function [XkBMEm, XkBMEv] = krigingME_Xvalidation_TOAR(ch, xh, covmodel, covparam, nhmax, dmax, order)
% % Leave-one-out cross validation using krigingME
% %
% % For each observation, estimate it using all other observations

% nObs = length(xh);
% XkBMEm = NaN(nObs, 1);
% XkBMEv = NaN(nObs, 1);

% for i = 1:nObs
%     if mod(i, 100) == 0
%         fprintf('    Progress: %d/%d\n', i, nObs);
%     end
    
%     % Estimation point
%     pk = ch(i, :);
    
%     % Training data (all except i)
%     ch_train = ch([1:i-1, i+1:end], :);
%     xh_train = xh([1:i-1, i+1:end]);
    
%     try
%         % Perform kriging
%         [moments, ~] = BMEprobaMoments(pk, ch_train, [], xh_train, ...
%             [], [], [], [], covmodel, covparam, ...
%             nhmax, 0, dmax, order, []);
        
%         XkBMEm(i) = moments(1);
%         XkBMEv(i) = moments(2);
%     catch ME
%         warning('Kriging failed for observation %d: %s', i, ME.message);
%         XkBMEm(i) = NaN;
%         XkBMEv(i) = NaN;
%     end
% end

% end

function stats = calculateValidationStats(Y_obs, Y_est)
% Calculate comprehensive validation statistics

% Remove NaN pairs
valid = ~isnan(Y_obs) & ~isnan(Y_est);
Y_obs = Y_obs(valid);
Y_est = Y_est(valid);

n = length(Y_obs);

% Pearson correlation
stats.PearsonR = corr(Y_obs, Y_est, 'Type', 'Pearson');

% Spearman correlation
stats.SpearmanR = corr(Y_obs, Y_est, 'Type', 'Spearman');

% R-squared
stats.R2 = stats.PearsonR^2;

% Root Mean Square Error
stats.RMSE = sqrt(mean((Y_obs - Y_est).^2));

% Mean Absolute Error
stats.MAE = mean(abs(Y_obs - Y_est));

% Mean Error (bias)
stats.ME = mean(Y_obs - Y_est);

% Mean Bias Error
stats.MBE = mean(Y_est - Y_obs);

% Normalized Mean Bias
stats.NMB = sum(Y_est - Y_obs) / sum(Y_obs) * 100;

% Normalized Mean Error
stats.NME = sum(abs(Y_est - Y_obs)) / sum(Y_obs) * 100;

% Index of Agreement
stats.IOA = 1 - sum((Y_obs - Y_est).^2) / ...
    sum((abs(Y_est - mean(Y_obs)) + abs(Y_obs - mean(Y_obs))).^2);

% Number of pairs
stats.N = n;

% Mean observed and predicted
stats.MeanObs = mean(Y_obs);
stats.MeanEst = mean(Y_est);

end

function plotTOARvalidation(valPairOut, valStats, valParam, obs, go)
% Create validation plots

figDir = fullfile('7validation', 'figs');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

Y_obs = valPairOut.Y_obs;
Y_est = valPairOut.Y_est;

%% Figure 1: Scatter Plot
figure('Position', [100 100 800 800], 'Color', 'w');

% Scatter plot
scatter(Y_obs, Y_est, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
hold on;

% 1:1 line
maxVal = max([Y_obs; Y_est]);
minVal = min([Y_obs; Y_est]);
plot([minVal maxVal], [minVal maxVal], 'k--', 'LineWidth', 2);

% Best fit line
p = polyfit(Y_obs, Y_est, 1);
yfit = polyval(p, [minVal maxVal]);
plot([minVal maxVal], yfit, 'r-', 'LineWidth', 2);

% Formatting
xlabel('Observed Ozone (ppb)', 'FontSize', 14);
ylabel('Predicted Ozone (ppb)', 'FontSize', 14);
title('TOAR BME Leave-One-Out Cross Validation', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
axis equal;
xlim([minVal maxVal]);
ylim([minVal maxVal]);

% Add statistics text
statsText = sprintf(['N = %d\n' ...
    'R = %.3f\n' ...
    'R² = %.3f\n' ...
    'RMSE = %.2f ppb\n' ...
    'MAE = %.2f ppb\n' ...
    'ME = %.2f ppb'], ...
    valStats.N, valStats.PearsonR, valStats.R2, ...
    valStats.RMSE, valStats.MAE, valStats.ME);

annotation('textbox', [0.15 0.75 0.2 0.15], 'String', statsText, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
    'EdgeColor', 'black', 'FontSize', 11, 'FontWeight', 'bold');

legend('Data', '1:1 Line', 'Best Fit', 'Location', 'southeast', 'FontSize', 11);

% Save
filename = sprintf('TOAR_LOOCV_scatter_BME%s_go%d_y%s.png', ...
    valParam.BMEmethod8digits, go.scenario, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

%% Figure 2: Residual Plot
figure('Position', [100 100 1000 400], 'Color', 'w');

residuals = Y_obs - Y_est;

subplot(1, 2, 1);
scatter(Y_est, residuals, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
plot([minVal maxVal], [0 0], 'k--', 'LineWidth', 2);
xlabel('Predicted Ozone (ppb)', 'FontSize', 12);
ylabel('Residuals (Obs - Pred, ppb)', 'FontSize', 12);
title('Residual Plot', 'FontSize', 14);
grid on;

subplot(1, 2, 2);
histogram(residuals, 30, 'FaceColor', 'b', 'FaceAlpha', 0.6);
xlabel('Residuals (ppb)', 'FontSize', 12);
ylabel('Frequency', 'FontSize', 12);
title('Residual Distribution', 'FontSize', 14);
grid on;

% Save
filename = sprintf('TOAR_LOOCV_residuals_BME%s_go%d_y%s.png', ...
    valParam.BMEmethod8digits, go.scenario, mat2str(valParam.valYears));
print(fullfile(figDir, filename), '-dpng', '-r300');

fprintf('Validation plots saved to: %s\n', figDir);

end