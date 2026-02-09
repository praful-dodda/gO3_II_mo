% example_getBMEmethodName.m
% Practical examples of using getBMEmethodName function
%
% This script demonstrates how to use getBMEmethodName in common scenarios
% such as generating configuration names for plots, legends, and tables.

%% Example 1: Basic usage - Single BME method
% =====================================================
fprintf('\n=== Example 1: Basic Usage ===\n\n');

% Get name for observation-only method with flat GO
methodName1 = getBMEmethodName('10000133', 0);
fprintf('Method: 10000133, GO: 0 → %s\n', methodName1);

% Get name for observation-only method with fine GO
methodName2 = getBMEmethodName('10000133', 3);
fprintf('Method: 10000133, GO: 3 → %s\n', methodName2);

% Get name for obs + single CTM model
methodName3 = getBMEmethodName('13000313-02', 3);
fprintf('Method: 13000313-02, GO: 3 → %s\n', methodName3);

% Get name for obs + multiple CTM models
methodName4 = getBMEmethodName('13000313-06', 3);
fprintf('Method: 13000313-06, GO: 3 → %s\n', methodName4);

%% Example 2: Generating config names from file patterns
% =====================================================
fprintf('\n=== Example 2: Auto-generate Config Names ===\n\n');

% Define file patterns (from runCBV results)
configPatterns = {
    'CBV_BME10000133_go0*.mat', ...
    'CBV_BME10000133_go3*.mat', ...
    'CBV_BME13000313-01_go3*.mat', ...
    'CBV_BME13000313-02_go3*.mat', ...
    'CBV_BME13000313-04_go3*.mat', ...
    'CBV_BME13000313-06_go3*.mat', ...
    'CBV_BME13000313-16_go3*.mat'
};

% Auto-generate config names
configNames = cell(size(configPatterns));
for i = 1:length(configPatterns)
    % Parse pattern to extract BME method and GO scenario
    pattern = configPatterns{i};

    % Extract BME method (between 'BME' and '_go')
    bmeStart = strfind(pattern, 'BME') + 3;
    bmeEnd = strfind(pattern, '_go') - 1;
    bmeMethod = pattern(bmeStart:bmeEnd);

    % Extract GO scenario (between '_go' and '*')
    goStart = strfind(pattern, '_go') + 3;
    goEnd = strfind(pattern, '*') - 1;
    goScenario = str2double(pattern(goStart:goEnd));

    % Generate descriptive name
    configNames{i} = getBMEmethodName(bmeMethod, goScenario);

    fprintf('Pattern: %s\n', pattern);
    fprintf('  → Name: %s\n\n', configNames{i});
end

%% Example 3: Use in runCBV workflow
% =====================================================
fprintf('\n=== Example 3: Integration with runCBV ===\n\n');

% Define validation parameters (from runCBV.m)
valParam.BMEmethod = {'10000133', '13000313-02', '13000313-06', '13000313-16'};
valParam.goScenario = 3;

fprintf('Running CBV with:\n');
fprintf('  GO scenario: %d\n', valParam.goScenario);
fprintf('  BME methods:\n');

% Generate method names for each configuration
methodNames = cell(size(valParam.BMEmethod));
for i = 1:length(valParam.BMEmethod)
    methodNames{i} = getBMEmethodName(valParam.BMEmethod{i}, valParam.goScenario);
    fprintf('    %d. %s → %s\n', i, valParam.BMEmethod{i}, methodNames{i});
end

%% Example 4: Creating legends for comparison plots
% =====================================================
fprintf('\n=== Example 4: Plot Legends ===\n\n');

% Simulate results from multiple configurations
configs = struct();
configs(1).BMEmethod = '10000133';
configs(1).goScenario = 3;
configs(2).BMEmethod = '13000313-01';
configs(2).goScenario = 3;
configs(3).BMEmethod = '13000313-02';
configs(3).goScenario = 3;
configs(4).BMEmethod = '13000313-06';
configs(4).goScenario = 3;

% Generate legend entries
legendEntries = cell(length(configs), 1);
for i = 1:length(configs)
    legendEntries{i} = getBMEmethodName(configs(i).BMEmethod, configs(i).goScenario);
end

fprintf('Legend entries for comparison plot:\n');
for i = 1:length(legendEntries)
    fprintf('  %d. %s\n', i, legendEntries{i});
end

% Use in plotting (pseudo-code)
fprintf('\nUsage in plot:\n');
fprintf('  legend(legendEntries, ''Location'', ''best'');\n');

%% Example 5: Creating tables with method names
% =====================================================
fprintf('\n=== Example 5: Results Table ===\n\n');

% Simulate validation results
results = struct();
results(1).BMEmethod = '10000133';
results(1).goScenario = 3;
results(1).R2 = 0.75;
results(1).RMSE = 8.5;

results(2).BMEmethod = '13000313-02';
results(2).goScenario = 3;
results(2).R2 = 0.82;
results(2).RMSE = 7.2;

results(3).BMEmethod = '13000313-06';
results(3).goScenario = 3;
results(3).R2 = 0.85;
results(3).RMSE = 6.8;

% Create table with descriptive names
fprintf('Validation Results Summary:\n');
fprintf('%-35s  %6s  %6s\n', 'Method', 'R²', 'RMSE');
fprintf('%s\n', repmat('-', 1, 50));

for i = 1:length(results)
    methodName = getBMEmethodName(results(i).BMEmethod, results(i).goScenario);
    fprintf('%-35s  %.3f  %.2f\n', methodName, results(i).R2, results(i).RMSE);
end

%% Example 6: Batch processing for plotCBVresults_Phase3
% =====================================================
fprintf('\n=== Example 6: Batch Generation for Phase 3 Plotting ===\n\n');

% Define all configurations from example_plotCBV_Phase3.m
configPatterns_phase3 = {
    'CBV_BME10000133_go0*.mat', ...
    'CBV_BME10000133_go3*.mat', ...
    'CBV_BME13000313-01_go3*.mat', ...
    'CBV_BME13000313-02_go3*.mat', ...
    'CBV_BME13000313-10_go3*.mat', ...
    'CBV_BME13000313-04_go3*.mat', ...
    'CBV_BME13000313-20_go3*.mat', ...
    'CBV_BME13000313-05_go3*.mat', ...
    'CBV_BME13000313-06_go3*.mat', ...
    'CBV_BME13000313-08_go3*.mat'
};

% Generate all names at once
configNames_phase3 = cell(size(configPatterns_phase3));
for i = 1:length(configPatterns_phase3)
    % Parse pattern
    pattern = configPatterns_phase3{i};
    bmeStart = strfind(pattern, 'BME') + 3;
    bmeEnd = strfind(pattern, '_go') - 1;
    bmeMethod = pattern(bmeStart:bmeEnd);

    goStart = strfind(pattern, '_go') + 3;
    goEnd = strfind(pattern, '*') - 1;
    goScenario = str2double(pattern(goStart:goEnd));

    configNames_phase3{i} = getBMEmethodName(bmeMethod, goScenario);
end

fprintf('Generated %d configuration names:\n', length(configNames_phase3));
for i = 1:length(configNames_phase3)
    fprintf('  %2d. %s\n', i, configNames_phase3{i});
end

fprintf('\nReady to use with:\n');
fprintf('  plotCBVresults_Phase3(configDirs, configNames_phase3, ...)\n');

%% Example 7: Helper function for parsing patterns
% =====================================================
fprintf('\n=== Example 7: Helper Function ===\n\n');

fprintf('You can create a helper function like:\n\n');
fprintf('function configNames = parseConfigPatterns(patterns)\n');
fprintf('    configNames = cell(size(patterns));\n');
fprintf('    for i = 1:length(patterns)\n');
fprintf('        [bme, go] = extractBMEandGO(patterns{i});\n');
fprintf('        configNames{i} = getBMEmethodName(bme, go);\n');
fprintf('    end\n');
fprintf('end\n\n');

%% Summary
fprintf('\n=== Summary ===\n\n');
fprintf('The getBMEmethodName function provides:\n');
fprintf('  • Automatic generation of descriptive method names\n');
fprintf('  • Consistent naming across all plots and tables\n');
fprintf('  • Easy integration with existing CBV workflows\n');
fprintf('  • Support for all BME method codes and GO scenarios\n\n');

fprintf('Common use cases:\n');
fprintf('  1. Plot legends and titles\n');
fprintf('  2. Table column headers\n');
fprintf('  3. File naming and organization\n');
fprintf('  4. Configuration comparison reports\n');
fprintf('  5. Automated workflow documentation\n\n');

fprintf('See also:\n');
fprintf('  • parseBMEcode() - Parse BME method codes\n');
fprintf('  • decodeCTMmodels() - Decode CTM model bitmasks\n');
fprintf('  • describeBMEcode() - Detailed code descriptions\n');
fprintf('  • BME_MODEL_CODES.txt - Complete reference guide\n\n');
