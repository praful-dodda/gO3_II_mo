% this is an aggregate script to run figure analysis at three different levels:
% 1. BME{bme_method}_GO{go_scenario}_year analysis
% 2. each year analysis
% 3. aggregate across years analysis

% config directory
cbvResultsDir = './7validation/CBV';

% get config patterns from the different BME and GO scenarios
all_methods = {'10000133_go0', '10000133_go3', '13000313-01', '13000313-02', ...
            '13000313-10', '13000313-04', '13000313-20', '13000313-05', ...
            '13000313-06'};

configNames = {
    'Obs. only (flat GO)', ...
    'Obs. only (fine GO)', ...
    'Obs. + MERRA2-GMI', ...
    'Obs. + M3fusion', ...
    'Obs. + UKML', ...
    'Obs. + OMI-MLS', ...
    'Obs. + NJML', ...
    'Obs. + MERRA2-GMI + OMI-MLS', ...
    'Obs. + M3fusion + OMI-MLS'
};

all_methods = {'10000133_go3', '13000313-01', '13000313-05'};

configNames = {
    'Obs. only (fine GO)', ...
    'Obs. + MERRA2-GMI', ...
    'Obs. + MERRA2-GMI + OMI-MLS'
};

allYears = [2007 2008]; % use [] for all years

boxSize = 5;  % only important in phase-3 plots. % use [] for all box sizes

goScenario = 3;

% in the all_methods, for the methods where go is not specified, we assume goScenario is 3. Change accordingly
for each_method = 1:length(all_methods)
    if contains(all_methods{each_method}, 'go')
        continue;
    else
        all_methods{each_method} = sprintf('%s_go%d', all_methods{each_method}, goScenario);
    end
end

% plotLevels = {'phase1', 'phase2', 'phase3'};
plotLevels = {'phase3'};

% example usage:
% phase 1
fprintf('\n=== Example 1: Phase 1 Plots ===\n');
% loop through each configuration to generate phase 1 plots in the corresponding directories
for eachYear = allYears
    fprintf('\n--- Processing Year: %d ---\n', eachYear);
    for i = 1:length(all_methods)
        configPattern = sprintf('CBV_BME%s*_box%d*_%d.mat', all_methods{i}, boxSize, eachYear);

        % search dir for files matching pattern
        fileNames = dir(fullfile(cbvResultsDir, configPattern));

        if isempty(fileNames)
            warning('No files found for pattern: %s', configPattern);
            continue;
        end

        figDir = fullfile(cbvResultsDir, 'figs', sprintf('%s_%d', all_methods{i}, eachYear));

        % if figDir already exists, skip
        if exist(figDir, 'dir')
            fprintf('Figures already exist for %s, skipping...\n', configPattern);
            continue;
        end
        
        fprintf('\n--- Processing Configuration: %s ---\n', configNames{i});

        if ismember('phase1', plotLevels)
            fprintf('Generating Phase 1 plots...\n');
        
            plotCBVresults_Phase1(cbvResultsDir, ...
                'filePattern', configPattern, ...
                'saveDir', figDir, ...
                'dpi', 300, ...
                'visible', 'on');
            close all;
        end

        if ismember('phase2', plotLevels)
            fprintf('Generating Phase 2 plots...\n');
        
            plotCBVresults_Phase2(cbvResultsDir, ...
                'filePattern', configPattern, ...
                'saveDir', figDir, ...
                'dpi', 300, ...
                'visible', 'on');
            close all;
        end
        
    end
end

configPatterns = cell(1, length(all_methods));

for i = 1:length(all_methods)
    configPatterns{i} = sprintf('CBV_BME%s*_box%d*.mat', all_methods{i}, boxSize);
end

% phase 3
fprintf('\n=== Example 2: Phase 3 Configuration Comparison ===\n');
if ismember('phase3', plotLevels)
    fprintf('Generating Phase 3 configuration comparison plots...\n');
    figPaths = plotCBVresults_Phase3(repmat({cbvResultsDir}, 1, length(configPatterns)), configNames, ...
        'filePattern', configPatterns, ...
        'baselineConfig', 1, ...
        'years', allYears, ...
        'boxSize', boxSize, ...
        'metrics', {'R2', 'RMSE', 'MAE', 'NMB'}, ...
        'saveDir', fullfile(cbvResultsDir, 'figs', sprintf('%d_%d', allYears(1), allYears(end))), ...
        'dpi', 300, ...
        'visible', 'on', ...
        'saveTables', true);
    % close all;
end