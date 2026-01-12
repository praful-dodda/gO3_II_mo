function stats = computeMetrics(Y_obs, Y_est, obs)
% computeMetrics - Compute validation metrics for observed vs estimated values
%
% Wrapper around calculateValidationStats that provides a consistent
% interface for validation metric computation across different CV methods.
%
% SYNTAX:
%   stats = computeMetrics(Y_obs, Y_est, obs)
%
% INPUTS:
%   Y_obs - Observed values (n × 1 vector)
%   Y_est - Estimated/predicted values (n × 1 vector)
%   obs   - Observation structure (for metadata/units)
%           Optional - can pass [] if not needed
%
% OUTPUTS:
%   stats - Structure with validation metrics:
%           .N          - Number of valid pairs
%           .MeanObs    - Mean of observations
%           .MeanEst    - Mean of estimates
%           .StdObs     - Standard deviation of observations
%           .StdEst     - Standard deviation of estimates
%           .PearsonR   - Pearson correlation coefficient
%           .SpearmanR  - Spearman correlation coefficient
%           .R2         - R-squared (coefficient of determination)
%           .RMSE       - Root Mean Square Error
%           .MAE        - Mean Absolute Error
%           .ME         - Mean Error (obs - est)
%           .MBE        - Mean Bias Error (est - obs)
%           .NMB        - Normalized Mean Bias (%)
%           .NME        - Normalized Mean Error (%)
%           .IOA        - Index of Agreement
%           .IOAmod     - Modified Index of Agreement
%           .FAC2       - Fraction within factor of 2 (%)
%           .Slope      - Linear regression slope
%           .Intercept  - Linear regression intercept
%
% EXAMPLE:
%   stats = computeMetrics(obs.Z(:), predictions, obs);
%   fprintf('R² = %.3f, RMSE = %.2f\n', stats.R2, stats.RMSE);
%
% SEE ALSO:
%   calculateValidationStats

%% Input Handling
if nargin < 3 || isempty(obs)
    % Create minimal obs structure if not provided
    obs.Zunit = 'ppbv';
    obs.Zname = 'Ozone';
end

%% Ensure Column Vectors
if size(Y_obs, 2) > 1
    Y_obs = Y_obs(:);
end

if size(Y_est, 2) > 1
    Y_est = Y_est(:);
end

%% Compute Statistics
stats = calculateValidationStats(Y_obs, Y_est, obs);

=======
% ---
% File: computeMetrics.m
function [stats] = computeMetrics(zHat, z, sigma_i)
% computeCVStats - Computes a standard set of statistics.

    if nargin < 3 || isempty(sigma_i), sigma_i = nan(size(z)); end

    e = zHat(:) - z(:);
    
    stats.MSE  = mean(e.^2);
    stats.RMSE = sqrt(stats.MSE);
    stats.MAE  = mean(abs(e));
    stats.ME   = mean(e);
    stats.VE   = var(e);
    stats.SE   = std(e);
    stats.r2   = corr(z, zHat)^2;
    
    numer = var(zHat) + var(z) - (stats.MSE - stats.ME^2);
    denom = 2 * std(zHat) * std(z);
    stats.r_QA  = numer / denom;
    stats.r2_QA = max(0, min(1, stats.r_QA^2));
    
    if all(~isnan(sigma_i)) && all(sigma_i > 0)
        S = e ./ sigma_i(:);
        stats.MS   = mean(S);
        stats.RMSS = sqrt(mean(S.^2));
        stats.MR   = mean(sigma_i);
    else
        stats.MS = NaN; stats.RMSS = NaN; stats.MR = NaN;
    end
end
