% this is an aggregate script to run figure analysis at three different levels:
% 1. BME{bme_method}_GO{go_scenario}_year analysis
% 2. each year analysis
% 3. aggregate across years analysis

% config directory
cbvResultsDir = './7validation/CBV';

% get config patterns from the different BME and GO scenarios
all_methods = {'10000133_go0', '10000133_go3', '13000313-01', '13000313-02'}; % obs only (flat-GO), obs only(fine-GO), obs+MERRA2-GMI, obs+M3fusion

configPatterns = cell(1, length(all_methods));
for i = 1:length(all_methods)
    configPatterns{i} = sprintf('CBV_BME%s*.mat', all_methods{i});
end

configNames = {
    'Obs. only (flat GO)', ...
    'Obs. only (fine GO)', ...
    'Obs. + MERRA2-GMI', ...
    'Obs. + M3fusion'
};

allYears = [2013, 2014, 2016, 2017, 2018];

% example usage:
% phase 1
fprintf('\n=== Example 1: Phase 1 Plots ===\n');
% loop through each configuration to generate phase 1 plots in the corresponding directories
for eachYear = allYears
    fprintf('\n--- Processing Year: %d ---\n', eachYear);
    for i = 1:length(all_methods)
        configPattern = sprintf('CBV_BME%s*_%d.mat', all_methods{i}, eachYear);

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
        
        plotCBVresults_Phase1(cbvResultsDir, ...
            'filePattern', configPattern, ...
            'saveDir', figDir, ...
            'dpi', 300, ...
            'visible', 'on');

        plotCBVresults_Phase2(cbvResultsDir, ...
            'filePattern', configPattern, ...
            'saveDir', figDir, ...
            'dpi', 300, ...
            'visible', 'on');

        close all;
        
    end
end

figPaths = plotCBVresults_Phase3(repmat({cbvResultsDir}, 1, length(configPatterns)), configNames, ...
    'filePattern', configPatterns, ...
    'baselineConfig', 1, ...
    'years', allYears, ...
    'metrics', {'R2', 'RMSE', 'MAE', 'NMB'}, ...
    'saveDir', fullfile(cbvResultsDir, 'figs', sprintf('%d_%d', allYears(1), allYears(end))), ...
    'dpi', 300, ...
    'visible', 'on', ...
    'saveTables', true);