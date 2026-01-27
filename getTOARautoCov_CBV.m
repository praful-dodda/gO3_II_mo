function cov = getTOARautoCov_CBV(obs, go, temporalModelType, boxSize, foldIdx, yearRange, forceCov, covPlot, obsAll, trainMask, valMask)
% getTOARautoCov_CBV - Compute fold-specific covariance for CBV
%
% Wrapper around getTOARautoCov that caches results per fold to avoid data
% leakage in checker-board validation. Each fold uses only training stations
% to fit covariance parameters, ensuring validation stations don't influence
% the spatial correlation structure.
%
% SYNTAX:
%   cov = getTOARautoCov_CBV(obs, go, temporalModelType, boxSize, foldIdx, yearRange, forceCov)
%   cov = getTOARautoCov_CBV(obs, go, temporalModelType, boxSize, foldIdx, yearRange, forceCov, ...
%                            covPlot, obsAll, trainMask, valMask)
%
% INPUTS:
%   obs               - Observational data structure (should contain ONLY training stations)
%   go                - Fold-specific global offset structure from getTOARglobalOffset_CBV
%   temporalModelType - 'holecos' or 'exponentialC' (default: 'exponentialC')
%   boxSize           - Checker box size in degrees (used for cache naming)
%   foldIdx           - Fold index (1 or 2)
%   yearRange         - [startYear endYear] of obs data (e.g., [2016 2018] for val year 2017)
%   forceCov          - Force recomputation (default: 0)
%   covPlot           - Plotting level (default: 0)
%                       -1 = no plotting, no saving
%                        0 = save figures, don't display
%                        1 = save figures and display
%   obsAll            - (Optional) Full obs structure with all stations (for diagnostic plots)
%   trainMask         - (Optional) Logical mask for training stations
%   valMask           - (Optional) Logical mask for validation stations
%
% OUTPUTS:
%   cov - Covariance structure
%
% CACHING:
%   Cached files stored in: ./3covariance/CBV/
%   Filename format: Cov_go{scenario}_lt{logTransf}_{tempModel}_CBV_box{size}_fold{fold}_{startYr}-{endYr}.mat
%   Figures stored in: ./3covariance/CBV/figs/box{size}/
%
% EXAMPLE:
%   % For fold 1 with 3-degree boxes, validation year 2017 (uses 2016-2018 data)
%   trainObs = getTrainingObservations(obs, trainMask);
%   go_fold = getTOARglobalOffset_CBV(trainObs, 3, 3.0, 1, [2016 2018]);
%   cov_fold = getTOARautoCov_CBV(trainObs, go_fold, 'exponentialC', 3.0, 1, [2016 2018], 0, 0, ...
%                                  obs, trainMask, valMask);
%
% SEE ALSO:
%   getTOARautoCov, getTOARglobalOffset_CBV, runCBV_toar, plotTOARautoCov_CBV

%% Input validation
if nargin < 6
    error('At least 6 inputs required: obs, go, temporalModelType, boxSize, foldIdx, yearRange');
end
if nargin < 3 || isempty(temporalModelType), temporalModelType = 'exponentialC'; end
if nargin < 7, forceCov = 0; end
if nargin < 8, covPlot = 0; end
if nargin < 9, obsAll = []; end
if nargin < 10, trainMask = []; end
if nargin < 11, valMask = []; end

%% Setup caching directory
covDir = './3covariance/CBV';
if ~exist(covDir, 'dir')
    mkdir(covDir);
    fid = fopen(fullfile(covDir, '0readme.txt'), 'w');
    fprintf(fid, 'Fold-specific covariance models for Checker-Board Validation\n');
    fprintf(fid, 'Created by getTOARautoCov_CBV.m\n');
    fprintf(fid, 'Each file contains covariance computed using only training stations for that fold\n');
    fprintf(fid, '\nFilename format: Cov_go{scenario}_lt{logTransf}_{tempModel}_CBV_box{size}_fold{fold}.mat\n');
    fclose(fid);
end

%% Create cache filename with year range
% Include temporal model type in filename to distinguish different models
covFile = sprintf('Cov_go%d_lt%d_%s_CBV_box%.1f_fold%d_%d-%d.mat', ...
    go.scenario, obs.logTransf, temporalModelType, boxSize, foldIdx, yearRange(1), yearRange(2));
covPath = fullfile(covDir, covFile);

%% Check cache
if exist(covPath, 'file') && ~forceCov
    fprintf('      Loading cached fold-specific Cov from: %s\n', covFile);
    load(covPath, 'cov');
    return;
end

%% Compute fold-specific covariance
fprintf('      Computing fold-specific Cov (go %d, %s, box %.1f, fold %d, years %d-%d)...\n', ...
    go.scenario, temporalModelType, boxSize, foldIdx, yearRange(1), yearRange(2));
fprintf('        Training stations: %d\n', size(obs.sMS, 1));

% Call standard getTOARautoCov with training-only data
% cov = getTOARautoCov(obs, go, temporalModelType, 1, 1);
cov = getTOARautoCov_updated(obs, go, temporalModelType, 1, 1);

%% Save to cache
fprintf('        Saving fold-specific Cov to cache...\n');
save(covPath, 'cov', '-v7.3');

fprintf('        Fold-specific Cov computed and cached.\n');

%% Create diagnostic plots if requested
if covPlot >= 0 && ~isempty(obsAll) && ~isempty(trainMask) && ~isempty(valMask)
    fprintf('        Creating diagnostic plots for fold %d covariance...\n', foldIdx);
    try
        visible = 'off';
        if covPlot >= 1
            visible = 'on';
        end

        figPaths = plotTOARautoCov_CBV(obsAll, go, cov, boxSize, foldIdx, yearRange, ...
            trainMask, valMask, 'visible', visible);
        fprintf('        Created %d diagnostic plots\n', length(figPaths));
    catch ME
        warning('Failed to create diagnostic plots: %s', ME.message);
    end
end

end
