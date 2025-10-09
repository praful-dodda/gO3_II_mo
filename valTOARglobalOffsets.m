function valTable = valTOARglobalOffsets(stationTypes, timeRange, goScenarioVec, trainRatio, forceEstGO, goPlot, displayArea, valPlot)
% valTOARglobalOffsets - Validate global offsets for TOAR data
%
% Creates train/test splits and validates different GO scenarios
%
% SYNTAX:
%   valTable = valTOARglobalOffsets(stationTypes, timeRange, goScenarioVec, ...
%                                   trainRatio, forceEstGO, goPlot, displayArea, valPlot)
%
% INPUTS:
%   stationTypes - Station types to include ('all' or cell array)
%                  default: 'all'
%   timeRange    - [startYear endYear] for data
%                  default: [2015 2020]
%   goScenarioVec - Vector of GO scenarios to test (0-4)
%                  default: [0 1 2 3 4]
%   trainRatio   - Proportion of data for training
%                  default: 0.95
%   forceEstGO   - Force re-estimation of GO (1) or use saved (0)
%                  default: 0
%   goPlot       - Plotting level for GO plots (0-3)
%                  default: 1
%   displayArea  - [lonmin lonmax latmin latmax]
%                  default: [-180 180 -60 75] (global)
%   valPlot      - Plot validation statistics (1) or not (0)
%                  default: 1
%
% OUTPUT:
%   valTable - Table with validation statistics for each GO scenario
%              Columns: GoScenario, MSE, MAE, ME, RMSE, PearsonR, SpearmanR,
%                       TrainVar, TestVar
%
% EXAMPLE:
%   % Validate regional GO scenario
%   valTable = valTOARglobalOffsets('all', [2015 2020], 3);
%   
%   % Compare multiple GO scenarios
%   valTable = valTOARglobalOffsets('all', [2015 2020], [0 1 2 3 4]);

if nargin < 1, stationTypes = 'all'; end
if nargin < 2, timeRange = [2015 2020]; end
if nargin < 3, goScenarioVec = [0 1 2 3 4 5 6 7 8 9 10 11]; end
if nargin < 4, trainRatio = 0.8; end
if nargin < 5, forceEstGO = 1; end
if nargin < 6, goPlot = 1; end
if nargin < 7, displayArea = [-180 180 -60 75]; end
if nargin < 8, valPlot = 1; end

% Set random seed for reproducibility
rng(1);

fprintf('=== TOAR Global Offset Validation ===\n');
fprintf('Time range: %d-%d\n', timeRange(1), timeRange(2));
fprintf('Train/test ratio: %.2f/%.2f\n', trainRatio, 1-trainRatio);
fprintf('GO scenarios to test: %s\n\n', mat2str(goScenarioVec));

% Get observational data
obs = getTOARobservationalData(stationTypes, timeRange);

% Split into training and testing sets
[trainObs, testObs] = subsetTOARdata(obs, trainRatio);

% Initialize results table
nScenarios = length(goScenarioVec);
valTable = table('Size', [nScenarios, 9], ...
    'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'GoScenario', 'MSE', 'MAE', 'ME', 'RMSE', 'PearsonR', 'SpearmanR', 'TrainVar', 'TestVar'});

% Loop through GO scenarios
for iScenario = 1:nScenarios
    goScenario = goScenarioVec(iScenario);
    fprintf('\n--- Testing GO Scenario %d ---\n', goScenario);
    
    % Get global offset from training data
    % Temporarily override forceGOestimation in getTOARglobalOffset
    go = getTOARglobalOffset(trainObs, goScenario, goPlot, 1, 1);
    
    % Prepare training data
    train_Ygo = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, trainObs.sMS, trainObs.tME);
    train_Ym = trainObs.Y;
    train_X = train_Ym - train_Ygo;
    trainVar = var(train_X(~isnan(train_X)));
    fprintf('Training residual variance: %.4e\n', trainVar);
    
    % Prepare test data
    test_Ygo = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, testObs.sMS, testObs.tME);
    test_Ym = testObs.Y;
    test_X = test_Ym - test_Ygo;
    testVar = var(test_X(~isnan(test_X)));
    fprintf('Test residual variance: %.4e\n', testVar);
    
    % Compute validation statistics
    test_obs = test_Ym(:);
    test_pred = test_Ygo(:);
    
    % Remove NaN values
    idxValid = ~isnan(test_obs) & ~isnan(test_pred);
    test_obs = test_obs(idxValid);
    test_pred = test_pred(idxValid);
    
    fprintf('Number of test observations: %d\n', length(test_obs));
    
    % Calculate statistics
    errors = test_pred - test_obs;
    mse = mean(errors.^2);
    mae = mean(abs(errors));
    me = mean(errors);
    rmse = sqrt(mse);
    
    % Pearson correlation
    [r, ~] = corrcoef(test_obs, test_pred);
    pearsonR = r(1, 2);
    
    % Spearman correlation
    spearmanR = corr(test_obs, test_pred, 'Type', 'Spearman');
    
    % Store results
    valTable.GoScenario(iScenario) = goScenario;
    valTable.MSE(iScenario) = mse;
    valTable.MAE(iScenario) = mae;
    valTable.ME(iScenario) = me;
    valTable.RMSE(iScenario) = rmse;
    valTable.PearsonR(iScenario) = pearsonR;
    valTable.SpearmanR(iScenario) = spearmanR;
    valTable.TrainVar(iScenario) = trainVar;
    valTable.TestVar(iScenario) = testVar;
    
    fprintf('Validation metrics:\n');
    fprintf('  RMSE: %.4f\n', rmse);
    fprintf('  MAE: %.4f\n', mae);
    fprintf('  Pearson R: %.4f\n', pearsonR);
    fprintf('  Spearman R: %.4f\n', spearmanR);
end

% Display results table
fprintf('\n=== Validation Results Summary ===\n');
disp(valTable);

% Plot validation statistics if requested
if valPlot
    plotTOARvalidationStats(valTable);
end

end

function plotTOARvalidationStats(valTable)
% plotTOARvalidationStats - Plot validation statistics
%
% Creates subplot with 6 panels showing different metrics

figure('Position', [100 100 1200 800]);

% Pearson correlation
subplot(2, 3, 1);
plot(valTable.GoScenario, valTable.PearsonR, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('Pearson R', 'FontSize', 12);
title('Pearson Correlation', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);

% Spearman correlation
subplot(2, 3, 2);
plot(valTable.GoScenario, valTable.SpearmanR, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('Spearman R', 'FontSize', 12);
title('Spearman Correlation', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);

% RMSE
subplot(2, 3, 3);
plot(valTable.GoScenario, valTable.RMSE, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('RMSE', 'FontSize', 12);
title('Root Mean Square Error', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);

% MAE
subplot(2, 3, 4);
plot(valTable.GoScenario, valTable.MAE, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('MAE', 'FontSize', 12);
title('Mean Absolute Error', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);

% ME
subplot(2, 3, 5);
plot(valTable.GoScenario, valTable.ME, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('GO Scenario', 'FontSize', 12);
ylabel('ME', 'FontSize', 12);
title('Mean Error (Bias)', 'FontSize', 14);
grid on;
yline(0, 'r--', 'LineWidth', 1);
set(gca, 'FontSize', 11);

% Variance comparison
subplot(2, 3, 6);
hold on;
plot(valTable.GoScenario, valTable.TrainVar, '-o', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Train');
plot(valTable.GoScenario, valTable.TestVar, '-s', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Test');
xlabel('GO Scenario', 'FontSize', 12);
ylabel('Residual Variance', 'FontSize', 12);
title('Residual Variance', 'FontSize', 14);
legend('Location', 'best');
grid on;
set(gca, 'FontSize', 11);

sgtitle('TOAR Global Offset Validation Results', 'FontSize', 16, 'FontWeight', 'bold');

end