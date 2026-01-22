function go = getTOARglobalOffset_CBV(obs, goScenario, boxSize, foldIdx, yearRange, forceGO, goPlot, obsAll, trainMask, valMask)
% getTOARglobalOffset_CBV - Compute fold-specific global offset for CBV
%
% Wrapper around getTOARglobalOffset that caches results per fold to avoid
% data leakage in checker-board validation. Each fold uses only training
% stations to compute GO, ensuring validation stations don't influence the
% global offset estimation.
%
% SYNTAX:
%   go = getTOARglobalOffset_CBV(obs, goScenario, boxSize, foldIdx, yearRange, forceGO, goPlot)
%   go = getTOARglobalOffset_CBV(obs, goScenario, boxSize, foldIdx, yearRange, forceGO, goPlot, ...
%                                 obsAll, trainMask, valMask)
%
% INPUTS:
%   obs        - Observational data structure (should contain ONLY training stations)
%   goScenario - Global offset scenario (0-10)
%   boxSize    - Checker box size in degrees (used for cache naming)
%   foldIdx    - Fold index (1 or 2)
%   yearRange  - [startYear endYear] of obs data (e.g., [2016 2018] for val year 2017)
%   forceGO    - Force recomputation (default: 0)
%   goPlot     - Plotting level (default: 0)
%                -1 = no plotting, no saving
%                 0 = save figures, don't display
%                 1 = save figures and display
%   obsAll     - (Optional) Full obs structure with all stations (for diagnostic plots)
%   trainMask  - (Optional) Logical mask for training stations
%   valMask    - (Optional) Logical mask for validation stations
%
% OUTPUTS:
%   go - Global offset structure
%
% CACHING:
%   Cached files stored in: ./2globalOffset/CBV/
%   Filename format: {Zname}go_go{scenario}_CBV_box{size}_fold{fold}_{startYr}-{endYr}.mat
%   Figures stored in: ./2globalOffset/CBV/figs/box{size}/
%
% EXAMPLE:
%   % For fold 1 with 3-degree boxes, validation year 2017 (uses 2016-2018 data)
%   trainObs = getTrainingObservations(obs, trainMask);
%   go_fold1 = getTOARglobalOffset_CBV(trainObs, 3, 3.0, 1, [2016 2018], 0, 0, ...
%                                      obs, trainMask, valMask);
%
% SEE ALSO:
%   getTOARglobalOffset, getTOARautoCov_CBV, runCBV_toar, plotTOARglobalOffset_CBV

%% Input validation
if nargin < 5
    error('At least 5 inputs required: obs, goScenario, boxSize, foldIdx, yearRange');
end
if nargin < 6, forceGO = 0; end
if nargin < 7, goPlot = 0; end
if nargin < 8, obsAll = []; end
if nargin < 9, trainMask = []; end
if nargin < 10, valMask = []; end

%% Setup caching directory
goDir = './2globalOffset/CBV';
if ~exist(goDir, 'dir')
    mkdir(goDir);
    fid = fopen(fullfile(goDir, '0readme.txt'), 'w');
    fprintf(fid, 'Fold-specific global offsets for Checker-Board Validation\n');
    fprintf(fid, 'Created by getTOARglobalOffset_CBV.m\n');
    fprintf(fid, 'Each file contains GO computed using only training stations for that fold\n');
    fprintf(fid, '\nFilename format: {Zname}go_go{scenario}_CBV_box{size}_fold{fold}.mat\n');
    fclose(fid);
end

%% Create cache filename with year range
goFile = sprintf('%sgo_go%d_CBV_box%.1f_fold%d_%d-%d.mat', ...
    obs.Zname, goScenario, boxSize, foldIdx, yearRange(1), yearRange(2));
goPath = fullfile(goDir, goFile);

%% Check cache
if exist(goPath, 'file') && ~forceGO
    fprintf('      Loading cached fold-specific GO from: %s\n', goFile);
    load(goPath, 'go');
    return;
end

%% Compute fold-specific global offset
fprintf('      Computing fold-specific GO (scenario %d, box %.1f, fold %d, years %d-%d)...\n', ...
    goScenario, boxSize, foldIdx, yearRange(1), yearRange(2));
fprintf('        Training stations: %d\n', size(obs.sMS, 1));

% Call standard getTOARglobalOffset with training-only data
% Use inValidation=1 to suppress plotting and avoid confusion with main GO
go = getTOARglobalOffset(obs, goScenario, goPlot, 1, 1);

%% Save to cache
fprintf('        Saving fold-specific GO to cache...\n');
save(goPath, 'go', '-v7.3');

fprintf('        Fold-specific GO computed and cached.\n');

%% Create diagnostic plots if requested
if goPlot >= 0 && ~isempty(obsAll) && ~isempty(trainMask) && ~isempty(valMask)
    fprintf('        Creating diagnostic plots for fold %d...\n', foldIdx);
    try
        visible = 'off';
        if goPlot >= 1
            visible = 'on';
        end

        figPaths = plotTOARglobalOffset_CBV(obsAll, go, boxSize, foldIdx, yearRange, ...
            trainMask, valMask, 'visible', visible);
        fprintf('        Created %d diagnostic plots\n', length(figPaths));
    catch ME
        warning('Failed to create diagnostic plots: %s', ME.message);
    end
end

end
