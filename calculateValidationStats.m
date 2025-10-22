function stats = calculateValidationStats(Y_obs, Y_est, obs)
% calculateValidationStats - Calculate comprehensive validation metrics
%
% SYNTAX:
%   stats = calculateValidationStats(Y_obs, Y_est, obs)
%
% INPUTS:
%   Y_obs - Observed values
%   Y_est - Estimated values
%   obs   - Observation structure (for units)
%
% OUTPUTS:
%   stats - Structure with validation statistics

% Remove NaN pairs
valid = ~isnan(Y_obs) & ~isnan(Y_est) & isfinite(Y_obs) & isfinite(Y_est);
Y_obs = Y_obs(valid);
Y_est = Y_est(valid);

n = length(Y_obs);

if n < 2
    warning('Insufficient valid pairs for statistics');
    stats = struct();
    return;
end

%% Basic Statistics
stats.N = n;
stats.MeanObs = mean(Y_obs);
stats.MeanEst = mean(Y_est);
stats.StdObs = std(Y_obs);
stats.StdEst = std(Y_est);

%% Correlation Metrics
% Pearson correlation
stats.PearsonR = corr(Y_obs, Y_est, 'Type', 'Pearson');

% Spearman correlation
stats.SpearmanR = corr(Y_obs, Y_est, 'Type', 'Spearman');

% R-squared
stats.R2 = stats.PearsonR^2;

%% Error Metrics
residuals = Y_obs - Y_est;

% Root Mean Square Error
stats.RMSE = sqrt(mean(residuals.^2));

% Mean Absolute Error
stats.MAE = mean(abs(residuals));

% Mean Error (observed - estimated)
stats.ME = mean(residuals);

% Mean Bias Error (estimated - observed)
stats.MBE = -stats.ME;

% Normalized Mean Bias (%)
if sum(Y_obs) ~= 0
    stats.NMB = sum(Y_est - Y_obs) / sum(Y_obs) * 100;
else
    stats.NMB = NaN;
end

% Normalized Mean Error (%)
if sum(Y_obs) ~= 0
    stats.NME = sum(abs(Y_est - Y_obs)) / sum(Y_obs) * 100;
else
    stats.NME = NaN;
end

%% Agreement Metrics
% Index of Agreement (Willmott, 1981)
meanObs = mean(Y_obs);
numerator = sum((Y_obs - Y_est).^2);
denominator = sum((abs(Y_est - meanObs) + abs(Y_obs - meanObs)).^2);
if denominator ~= 0
    stats.IOA = 1 - numerator / denominator;
else
    stats.IOA = NaN;
end

% Modified Index of Agreement
stats.IOAmod = 1 - sum(abs(Y_obs - Y_est)) / sum(abs(Y_obs - meanObs));

%% Fraction Within Factor of 2
ratio = Y_est ./ Y_obs;
ratio(Y_obs == 0) = NaN;  % Exclude zero observations
stats.FAC2 = sum(ratio >= 0.5 & ratio <= 2, 'omitnan') / sum(~isnan(ratio)) * 100;

%% Linear Regression
p = polyfit(Y_obs, Y_est, 1);
stats.Slope = p(1);
stats.Intercept = p(2);

end
