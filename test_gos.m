%% runTOARglobalOffsetAnalysis.m
% Script to compute and analyze multiple global offset scenarios for TOAR data
%
% This script:
% 1. Loads TOAR observational data
% 2. Computes global offsets for different scenarios
% 3. Estimates covariance for each scenario
% 4. Generates diagnostic plots

clear; close all;

%% --- Configuration ---
% Data parameters
stationTypes = 'all';           % 'all' or {'urban', 'rural', 'background'}
timeRange = [2015 2020];        % [startYear endYear]
logTransf = 0;                  % 0 = no log transform, 1 = log transform

% Global offset scenarios to test
goScenarioVec = 0:11;    % 0=zero, 1=flat, 2=domain, 3=regional, 4=local

% Processing flags
forceGOestimation = 1;          % 1 to force recompute GO, 0 to use saved
forceEstCov = 1;                % 1 to force recompute cov, 0 to use saved
inValidation = 0;               % Set to 0 for normal analysis

% Plotting options
goPlot = 1;                     % GO plot detail level (0-3)
temporalModelType = 'exponential';  % 'holecos' or 'exponential'

%% --- Load Observational Data ---
fprintf('=== Loading TOAR Observational Data ===\n');
obs = getTOARobservationalData(stationTypes, timeRange, logTransf);

fprintf('\nData summary:\n');
fprintf('  Stations: %d\n', size(obs.Z, 1));
fprintf('  Time points: %d\n', size(obs.Z, 2));
fprintf('  Valid observations: %d\n', sum(~isnan(obs.Z(:))));

%% --- Loop Through Global Offset Scenarios ---
fprintf('\n=== Processing Global Offset Scenarios ===\n');

% Store results
results = struct();

for i = 1:length(goScenarioVec)
    goScenario = goScenarioVec(i);
    
    fprintf('\n--- Scenario %d: ', goScenario);
    switch goScenario
        case 0, fprintf('Zero Offset ---\n');
        case 1, fprintf('Flat ---\n');
        case 2, fprintf('Domain Wide ---\n');
        case 3, fprintf('Regional Spatial ---\n');
        case 4, fprintf('Local Spatial ---\n');
        case 5, fprintf('Regional Spatio-Temporal ---\n');
        case 6, fprintf('Local Spatio-Temporal ---\n');
        case 7, fprintf('Super-Local Spatio-Temporal ---\n');
        case 8, fprintf('Regional (Balanced) ---\n');
        case 9, fprintf('Sub-Regional ---\n');
        case 10, fprintf('Local (with Seasonal) ---\n');
        case 11, fprintf('Fine-Scale ---\n');
        otherwise, fprintf('Unknown Scenario ---\n');
    end
    
    % Compute global offset
    go = getTOARglobalOffset(obs, goScenario, 0, forceGOestimation, inValidation);
    
    goPlots = 1:1;

    for goPlot = goPlots
        plotTOARglobalOffset(obs, go, goPlot)
    end
    
    % Compute covariance
    % cov = getTOARautoCov(obs, go, temporalModelType, forceEstCov);
    cov = getTOARautoCov_updated(obs, go, temporalModelType, forceEstCov);
    plotTOARcovariance(cov, 'visible', 'on')
    
    % Store results
    results(i).goScenario = goScenario;
    results(i).go = go;
    results(i).cov = cov;
    
    % Print summary
    fprintf('  Covariance variance: %.4f\n', cov.var);
    fprintf('  Space-time metric: %.4f\n', cov.stmetric);
end

%% --- Create Comparison Plot ---
fprintf('\n=== Creating Comparison Plots ===\n');

% Extract metrics for comparison
scenarios = [results.goScenario];
variances = arrayfun(@(x) x.cov.var, results);
stmetrics = arrayfun(@(x) x.cov.stmetric, results);

% Create comparison figure
figure('Position', [100 100 1200 500]);

% Variance comparison
subplot(1, 2, 1);
bar(scenarios, variances);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('Residual Variance', 'FontSize', 12);
title('Variance by GO Scenario', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);
xticks(scenarios);
% xticklabels are also just the scenario numbers for simplicity
xticklabels(arrayfun(@num2str, scenarios, 'UniformOutput', false));

% Space-time metric comparison
subplot(1, 2, 2);
bar(scenarios, stmetrics);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('Space-Time Metric', 'FontSize', 12);
title('Space-Time Metric by GO Scenario', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);
xticks(scenarios);
% xticklabels({'Zero', 'Flat', 'Domain', 'Regional', 'Local'});
xticklabels(arrayfun(@num2str, scenarios, 'UniformOutput', false));

sgtitle('Global Offset Scenario Comparison', 'FontSize', 16, 'FontWeight', 'bold');

% Save comparison plot
comparisonDir = '3covariance/figs';
if ~exist(comparisonDir, 'dir'), mkdir(comparisonDir); end
saveas(gcf, fullfile(comparisonDir, 'go_scenario_comparison.png'));
fprintf('Saved comparison plot to: %s\n', fullfile(comparisonDir, 'go_scenario_comparison.png'));

%% --- Summary Table ---
fprintf('\n=== Summary Table ===\n');
summaryTable = table(scenarios', variances', stmetrics', ...
    'VariableNames', {'GoScenario', 'Variance', 'STmetric'});
disp(summaryTable);

%% --- Save Results ---
resultsFile = fullfile('3covariance', 'go_analysis_results.mat');
save(resultsFile, 'results', 'summaryTable', 'obs');
fprintf('\nSaved all results to: %s\n', resultsFile);

fprintf('\n=== Analysis Complete ===\n');