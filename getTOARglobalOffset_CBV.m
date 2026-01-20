function go = getTOARglobalOffset_CBV(obs, goScenario, boxSize, foldIdx, forceGO, goPlot)
% getTOARglobalOffset_CBV - Compute fold-specific global offset for CBV
%
% Wrapper around getTOARglobalOffset that caches results per fold to avoid
% data leakage in checker-board validation. Each fold uses only training
% stations to compute GO, ensuring validation stations don't influence the
% global offset estimation.
%
% SYNTAX:
%   go = getTOARglobalOffset_CBV(obs, goScenario, boxSize, foldIdx, forceGO, goPlot)
%
% INPUTS:
%   obs        - Observational data structure (should contain ONLY training stations)
%   goScenario - Global offset scenario (0-10)
%   boxSize    - Checker box size in degrees (used for cache naming)
%   foldIdx    - Fold index (1 or 2)
%   forceGO    - Force recomputation (default: 0)
%   goPlot     - Plotting level (default: 0)
%
% OUTPUTS:
%   go - Global offset structure
%
% CACHING:
%   Cached files stored in: ./2globalOffset/CBV/
%   Filename format: {Zname}go_go{scenario}_CBV_box{size}_fold{fold}.mat
%
% EXAMPLE:
%   % For fold 1 with 3-degree boxes
%   trainObs = getTrainingObservations(obs, trainMask);
%   go_fold1 = getTOARglobalOffset_CBV(trainObs, 3, 3.0, 1, 0, 0);
%
% SEE ALSO:
%   getTOARglobalOffset, getTOARautoCov_CBV, runCBV_toar

%% Input validation
if nargin < 4
    error('At least 4 inputs required: obs, goScenario, boxSize, foldIdx');
end
if nargin < 5, forceGO = 0; end
if nargin < 6, goPlot = 0; end

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

%% Create cache filename
goFile = sprintf('%sgo_go%d_CBV_box%.1f_fold%d.mat', ...
    obs.Zname, goScenario, boxSize, foldIdx);
goPath = fullfile(goDir, goFile);

%% Check cache
if exist(goPath, 'file') && ~forceGO
    fprintf('      Loading cached fold-specific GO from: %s\n', goFile);
    load(goPath, 'go');
    return;
end

%% Compute fold-specific global offset
fprintf('      Computing fold-specific GO (scenario %d, box %.1f, fold %d)...\n', ...
    goScenario, boxSize, foldIdx);
fprintf('        Training stations: %d\n', size(obs.sMS, 1));

% Call standard getTOARglobalOffset with training-only data
% Use inValidation=1 to suppress plotting and avoid confusion with main GO
go = getTOARglobalOffset(obs, goScenario, goPlot, 1, 0);

%% Save to cache
fprintf('        Saving fold-specific GO to cache...\n');
save(goPath, 'go', '-v7.3');

fprintf('        Fold-specific GO computed and cached.\n');

end
