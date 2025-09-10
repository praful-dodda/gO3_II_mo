function assessTOARdataQuality(obs, go, timePoints)
% assessTOARdataQuality - Assess data quality and provide summary statistics
%
% SYNTAX:
%
% assessTOARdataQuality(obs, go, timePoints)

% Remove global offset
X = obs.Y - stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);

% Calculate summary statistics
validData = ~isnan(obs.Y);
nTotalObs = numel(obs.Y);
nValidObs = sum(validData(:));
dataCompleteness = nValidObs / nTotalObs * 100;

fprintf('Data completeness: %.1f%% (%d/%d observations)\n', ...
        dataCompleteness, nValidObs, nTotalObs);

% Station-wise completeness
stationCompleteness = sum(validData, 2) / size(obs.Y, 2) * 100;
fprintf('Station completeness - Mean: %.1f%%, Min: %.1f%%, Max: %.1f%%\n', ...
        mean(stationCompleteness), min(stationCompleteness), max(stationCompleteness));

% Temporal completeness
temporalCompleteness = sum(validData, 1) / size(obs.Y, 1) * 100;
fprintf('Temporal completeness - Mean: %.1f%%, Min: %.1f%%, Max: %.1f%%\n', ...
        mean(temporalCompleteness), min(temporalCompleteness), max(temporalCompleteness));

% Summary statistics of raw data
validObs = obs.Y(validData);
validResiduals = X(~isnan(X));

fprintf('\nOzone concentration statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validObs), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validObs), obs.Zunit);
fprintf('  Min:  %.2f %s\n', min(validObs), obs.Zunit);
fprintf('  Max:  %.2f %s\n', max(validObs), obs.Zunit);

fprintf('\nResidual (offset-removed) statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validResiduals), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validResiduals), obs.Zunit);
fprintf('  Min:  %.2f %s\n', min(validResiduals), obs.Zunit);
fprintf('  Max:  %.2f %s\n', max(validResiduals), obs.Zunit);

% Global offset contribution
globalOffsetValues = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
validGO = globalOffsetValues(validData);

fprintf('\nGlobal offset statistics:\n');
fprintf('  Mean: %.2f %s\n', mean(validGO), obs.Zunit);
fprintf('  Std:  %.2f %s\n', std(validGO), obs.Zunit);
fprintf('  Range: %.2f to %.2f %s\n', min(validGO), max(validGO), obs.Zunit);

% Variance decomposition
totalVar = var(validObs);
offsetVar = var(validGO);
residualVar = var(validResiduals);
varianceExplained = offsetVar / totalVar * 100;

fprintf('\nVariance decomposition:\n');
fprintf('  Total variance: %.3f %s^2\n', totalVar, obs.Zunit);
fprintf('  Global offset variance: %.3f %s^2 (%.1f%%)\n', offsetVar, obs.Zunit, varianceExplained);
fprintf('  Residual variance: %.3f %s^2 (%.1f%%)\n', residualVar, obs.Zunit, (100-varianceExplained));

end