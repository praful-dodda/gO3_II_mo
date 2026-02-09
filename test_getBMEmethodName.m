% test_getBMEmethodName.m
% Test script for getBMEmethodName function
%
% Tests the function with all examples from example_plotCBV_Phase3.m
% to ensure correct mapping of BME method codes and GO scenarios

fprintf('\n========================================\n');
fprintf('Testing getBMEmethodName Function\n');
fprintf('========================================\n\n');

% Test cases from example_plotCBV_Phase3.m
testCases = {
    % BMEmethod,      goScenario,  Expected Name
    '10000133',       0,           'Obs. only (flat GO)';
    '10000133',       3,           'Obs. only (fine GO)';
    '13000313-01',    3,           'Obs. + MERRA2-GMI';
    '13000313-02',    3,           'Obs. + M3fusion';
    '13000313-10',    3,           'Obs. + UKML';
    '13000313-04',    3,           'Obs. + OMI-MLS';
    '13000313-20',    3,           'Obs. + NJML';
    '13000313-05',    3,           'Obs. + MERRA2-GMI + OMI-MLS';
    '13000313-06',    3,           'Obs. + M3fusion + OMI-MLS';
    '13000313-08',    3,           'Obs. + IASI-GOME2';
};

% Additional test cases for comprehensive coverage
additionalTests = {
    '13000313-03',    3,           'Obs. + MERRA2-GMI + M3fusion';
    '13000313-09',    3,           'Obs. + MERRA2-GMI + IASI-GOME2';
    '13000313-0A',    3,           'Obs. + M3fusion + IASI-GOME2';
    '13000313-12',    3,           'Obs. + M3fusion + UKML';
    '13000313-16',    3,           'Obs. + M3fusion + OMI-MLS + UKML';
    '13000313-22',    3,           'Obs. + M3fusion + NJML';
    '13000313-11',    3,           'Obs. + MERRA2-GMI + UKML';
    '13000313-21',    3,           'Obs. + MERRA2-GMI + NJML';
    '13000313-15',    3,           'Obs. + MERRA2-GMI + OMI-MLS + UKML';
    '10000133',       2,           'Obs. only (domain GO)';
    '10000133',       6,           'Obs. only (local GO)';
};

% Combine all test cases
allTests = [testCases; additionalTests];

% Run tests
nPassed = 0;
nFailed = 0;
failedTests = {};

fprintf('Running %d tests...\n\n', size(allTests, 1));

for i = 1:size(allTests, 1)
    BMEmethod = allTests{i, 1};
    goScenario = allTests{i, 2};
    expectedName = allTests{i, 3};

    try
        actualName = getBMEmethodName(BMEmethod, goScenario);

        % Compare results
        if strcmp(actualName, expectedName)
            fprintf('✓ PASS: getBMEmethodName(''%s'', %d)\n', BMEmethod, goScenario);
            fprintf('        → %s\n\n', actualName);
            nPassed = nPassed + 1;
        else
            fprintf('✗ FAIL: getBMEmethodName(''%s'', %d)\n', BMEmethod, goScenario);
            fprintf('        Expected: %s\n', expectedName);
            fprintf('        Got:      %s\n\n', actualName);
            nFailed = nFailed + 1;
            failedTests{end+1} = sprintf('%s, GO=%d: Expected "%s", Got "%s"', ...
                BMEmethod, goScenario, expectedName, actualName);
        end
    catch ME
        fprintf('✗ ERROR: getBMEmethodName(''%s'', %d)\n', BMEmethod, goScenario);
        fprintf('         %s\n\n', ME.message);
        nFailed = nFailed + 1;
        failedTests{end+1} = sprintf('%s, GO=%d: Error - %s', ...
            BMEmethod, goScenario, ME.message);
    end
end

% Summary
fprintf('========================================\n');
fprintf('Test Summary\n');
fprintf('========================================\n');
fprintf('Total tests:  %d\n', size(allTests, 1));
fprintf('Passed:       %d\n', nPassed);
fprintf('Failed:       %d\n', nFailed);

if nFailed > 0
    fprintf('\nFailed Tests:\n');
    for i = 1:length(failedTests)
        fprintf('  %d. %s\n', i, failedTests{i});
    end
else
    fprintf('\n✓ All tests passed!\n');
end

fprintf('========================================\n\n');

%% Example usage in a real scenario
fprintf('========================================\n');
fprintf('Example Usage\n');
fprintf('========================================\n\n');

fprintf('Example 1: Generating config names from patterns\n');
fprintf('--------------------------------------------------\n');

configPatterns = {
    'CBV_BME10000133_go0*.mat', ...
    'CBV_BME10000133_go3*.mat', ...
    'CBV_BME13000313-01_go3*.mat', ...
    'CBV_BME13000313-02_go3*.mat', ...
    'CBV_BME13000313-06_go3*.mat'
};

fprintf('Input patterns:\n');
for i = 1:length(configPatterns)
    fprintf('  %s\n', configPatterns{i});
end

fprintf('\nGenerated names:\n');
configNames = {};
for i = 1:length(configPatterns)
    % Extract BME method and GO scenario from pattern
    % Pattern format: CBV_BME{method}_go{scenario}*.mat
    pattern = configPatterns{i};

    % Extract BME method
    bmeStart = strfind(pattern, 'BME') + 3;
    bmeEnd = strfind(pattern, '_go') - 1;
    bmeMethod = pattern(bmeStart:bmeEnd);

    % Extract GO scenario
    goStart = strfind(pattern, '_go') + 3;
    goEnd = strfind(pattern, '*') - 1;
    goScenario = str2double(pattern(goStart:goEnd));

    % Generate name
    configNames{i} = getBMEmethodName(bmeMethod, goScenario);
    fprintf('  %s\n', configNames{i});
end

fprintf('\n');
fprintf('Example 2: Using with runCBV results\n');
fprintf('-------------------------------------\n');

valParam.BMEmethod = {'10000133', '13000313-02', '13000313-06'};
valParam.goScenario = 3;

fprintf('BME methods: {');
for i = 1:length(valParam.BMEmethod)
    fprintf('''%s''', valParam.BMEmethod{i});
    if i < length(valParam.BMEmethod)
        fprintf(', ');
    end
end
fprintf('}\n');
fprintf('GO scenario: %d\n\n', valParam.goScenario);

fprintf('Method names for plotting:\n');
for i = 1:length(valParam.BMEmethod)
    methodName = getBMEmethodName(valParam.BMEmethod{i}, valParam.goScenario);
    fprintf('  %d. %s\n', i, methodName);
end

fprintf('\n========================================\n\n');
