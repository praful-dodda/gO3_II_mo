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
