function analyzeTOARscenario(obs, goScenario, covPlot, timePoints)
% analyzeTOARscenario - Complete analysis workflow for TOAR data
%
% Performs comprehensive analysis of TOAR ozone data including:
% 1. Global offset estimation and de-trending
% 2. Covariance analysis of residuals
% 3. Summary statistics and diagnostics
%
% SYNTAX:
%
% analyzeTOARscenario(obs, goScenario, covPlot, timePoints)
%
% INPUT:
%
% obs         structure from getTOARobservationalData
% goScenario  scalar specifying global offset scenario (0-4)
%             default: 3 (regional)
% covPlot     scalar for covariance plotting (0-2)
%             default: 1
% timePoints  vector of specific time points for detailed analysis
%             default: [2012 2015 2018] (if available in data)

if nargin < 1, error('obs structure required'); end
if nargin < 2, goScenario = 3; end
if nargin < 3, covPlot = 1; end
if nargin < 4
    % Select representative time points from available data
    availableYears = floor(obs.tME);
    uniqueYears = unique(availableYears);
    if length(uniqueYears) >= 3
        timePoints = uniqueYears([1 round(end/2) end]);
    else
        timePoints = uniqueYears;
    end
end

fprintf('\n=== TOAR-II Data Analysis Summary ===\n');
fprintf('Dataset: %s\n', obs.Zname);
fprintf('Number of stations: %d\n', size(obs.Y, 1));
fprintf('Time period: %.2f - %.2f %s\n', min(obs.tME), max(obs.tME), obs.timeUnit);
fprintf('Global offset scenario: %d\n', goScenario);

% Step 1: Global offset estimation
fprintf('\n--- Step 1: Global Offset Estimation ---\n');
go = getTOARglobalOffset(obs, goScenario, 1);

% Step 2: Covariance analysis
fprintf('\n--- Step 2: Covariance Analysis ---\n');
cov = getTOARcovariance(obs, go, covPlot);

% Step 3: Data quality assessment
fprintf('\n--- Step 3: Data Quality Assessment ---\n');
assessTOARdataQuality(obs, go, timePoints);

fprintf('\n=== Analysis Complete ===\n');

end