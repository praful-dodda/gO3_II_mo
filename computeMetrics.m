function [stats] = computeMetrics(zHat, z, sigma_i)
% computeMetrics - Computes a standard set of validation statistics
%
% SYNTAX:
%   stats = computeMetrics(zHat, z, sigma_i)
%
% INPUTS:
%   zHat    - Estimated/predicted values (n × 1 vector)
%   z       - Observed values (n × 1 vector)
%   sigma_i - Estimation uncertainties (optional, n × 1 vector)
%
% OUTPUTS:
%   stats - Structure with validation metrics:
%           .MSE    - Mean Squared Error
%           .RMSE   - Root Mean Squared Error
%           .MAE    - Mean Absolute Error
%           .ME     - Mean Error
%           .VE     - Variance of Error
%           .SE     - Standard Error
%           .r2     - R-squared (coefficient of determination)
%           .r_QA   - Quality-Adjusted correlation
%           .r2_QA  - Quality-Adjusted R-squared
%           .MS     - Mean Standardized error (if sigma_i provided)
%           .RMSS   - Root Mean Squared Standardized error
%           .MR     - Mean of sigma_i

    if nargin < 3 || isempty(sigma_i)
        sigma_i = nan(size(z));
    end

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
        stats.MS = NaN;
        stats.RMSS = NaN;
        stats.MR = NaN;
    end
end
