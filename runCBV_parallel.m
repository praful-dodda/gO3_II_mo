%% runCBV_parallel.m
% Parallel launcher for Checker-Board Validation (CBV) - SAFE WRAPPER
%
% Drop-in faster alternative to runCBV.m that parallelizes the validation
% ACROSS VALIDATION YEARS using parfor, calling the existing runCBV_toar
% unchanged. runCBV.m and runCBV_toar.m are NOT modified.
%
% WHY YEAR-LEVEL PARALLELISM IS SAFE:
%   The fold-specific Global Offset / Covariance cache files written by
%   getTOARglobalOffset_CBV / getTOARautoCov_CBV are keyed by
%   (scenario, boxSize, fold, yearRange) and are METHOD-INDEPENDENT. The
%   yearRange = [valYear +/- yearsOverhang] is unique per validation year,
%   so each worker (one year) writes a DISJOINT set of GO/Cov caches and
%   disjoint monthly files (CBV_BME..._{year}_{MM}.mat). No locks, no races.
%   This mirrors the isolation the hpc_cbv/ job-array design relies on.
%
% USAGE:
%   1. Edit the CONFIGURATION block below (same fields as runCBV.m).
%   2. Run: >> runCBV_parallel
%   3. Results saved to ./7validation/CBV/ exactly as runCBV does, plus a
%      combined summary CBV_parallel_summary_go{scen}.csv/.mat.
%
% NOTES:
%   - Speedup is bounded by min(numWorkers, numel(valYears)). For a SINGLE
%     year with many methods, year-parallelism gives little speedup.
%   - If the Parallel Computing Toolbox is unavailable, parfor runs serially
%     (script still works, just no speedup).
%
% SEE ALSO: runCBV, runCBV_toar, verifySoftDataFiles, plotCBVresults

clear; close all;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('          PARALLEL CHECKER-BOARD VALIDATION (CBV) FOR TOAR\n');
fprintf('========================================================================\n');
fprintf('\n');

%% ====================================================================
%                    DATA CONFIGURATION
% ====================================================================

% Station types to include
valParam.stationTypes = 'all';  % 'all', 'urban', 'rural', or {'urban','rural'}

% Log transformation
valParam.logTransf = 0;  % 0=no, 1=yes (use 0 for regular concentrations)

%% ====================================================================
%                    VALIDATION CONFIGURATION
% ====================================================================

% Years to validate (parallelism is across these)
valParam.valYears = 2017:2020;  % e.g., 2017 or [2016 2017 2018]

% Months to validate (within each year)
valParam.valMonths = 1:12;  % All months, or specific: [6 7 8] for JJA

% Checker box sizes to test (degrees)
valParam.boxSizes = 5.0;  % e.g., [2.0, 3.0, 4.0, 5.0]

%% ====================================================================
%                    GLOBAL OFFSET CONFIGURATION
% ====================================================================

% Global offset scenario (0=Zero, 1=Flat, 2=Domain, 3=Regional[REC], 6=Local)
valParam.goScenario = 3;
valParam.forceGO = 0;  % 0=use cached, 1=force new estimation
valParam.goPlot = 0;   % 0=no plots (recommended during CBV)

%% ====================================================================
%                    COVARIANCE CONFIGURATION
% ====================================================================

valParam.temporalModel = 'exponential';  % 'exponential' or 'holecos'
valParam.forceCov = 0;  % 0=use cached, 1=force new estimation

%% ====================================================================
%                    BME METHOD CONFIGURATION
% ====================================================================

% 8-digit BME method code (see runCBV.m header for the digit legend).
% Single method or cell array for multiple methods.
valParam.BMEmethod = {'13000313-0E'};

%% ====================================================================
%                    EXECUTION CONTROL
% ====================================================================

valParam.forceEstimation = 0;  % 0=use cached monthly results, 1=recompute
valParam.yearsOverhang   = 1;  % +/- year data window (keeps GO/Cov caches year-disjoint)

% Soft-data leakage control (see runCBV.m). 0=OFF (legacy). When ON, all outputs
% are tagged '_lc<R>' so they never collide with legacy results.
valParam.leakControl = 0;          % 0=off, 1=on
valParam.leakRadius  = struct('M3fusion', 2.0, 'OMIMLS', 0);  % deg; per-source (0=not masked)

% Final (pooled) plotting is done ONCE after the parallel loop, never inside
% workers. Set 0 to skip.
plotResultsAfter = 1;

%% ====================================================================
%                    PARALLEL CONFIGURATION
% ====================================================================

parParam.numWorkers = [];  % [] => MATLAB default pool size; or e.g. 6
% Per-worker timeRange is set automatically to [valYear-1, valYear+1].

%% ====================================================================
%                    NORMALIZE / SUMMARIZE CONFIG
% ====================================================================

% Methods as a cell array for consistent looping
if ischar(valParam.BMEmethod)
    methodList = {valParam.BMEmethod};
else
    methodList = valParam.BMEmethod;
end

valYears = valParam.valYears(:).';   % row vector
nYears   = numel(valYears);

fprintf('========================================================================\n');
fprintf('                         CONFIGURATION SUMMARY\n');
fprintf('========================================================================\n');
fprintf('Validation years (%d): %s\n', nYears, mat2str(valYears));
fprintf('Validation months: %s\n', mat2str(valParam.valMonths));
fprintf('Box sizes: %s degrees\n', mat2str(valParam.boxSizes));
fprintf('BME methods (%d): %s\n', numel(methodList), strjoin(methodList, ', '));
fprintf('GO scenario: %d | Temporal model: %s\n', valParam.goScenario, valParam.temporalModel);
fprintf('Parallel dim: year  | Requested workers: %s\n', ...
    iif(isempty(parParam.numWorkers), 'default', num2str(parParam.numWorkers)));
fprintf('\n');

%% ====================================================================
%                    VERIFY SOFT DATA FILES (non-interactive)
% ====================================================================

allFilesPresent = true;
for iMethod = 1:numel(methodList)
    try
        [status, ~] = verifySoftDataFiles(methodList{iMethod}, valYears, ...
            'verbose', true, 'throwError', false);
        if ~status, allFilesPresent = false; end
    catch ME
        warning('verifySoftDataFiles failed for %s: %s', methodList{iMethod}, ME.message);
        allFilesPresent = false;
    end
end
if ~allFilesPresent
    warning(['Some soft-data files appear to be missing. Continuing anyway ' ...
        '(BME will use only available data). Review the report above.']);
end

%% ====================================================================
%                    START PARALLEL POOL (graceful fallback)
% ====================================================================

haveParallel = ~isempty(ver('parallel'));
if haveParallel
    pool = gcp('nocreate');
    if isempty(pool)
        if isempty(parParam.numWorkers)
            pool = parpool();                       % default profile size
        else
            pool = parpool(parParam.numWorkers);
        end
    end
    fprintf('Parallel pool active: %d workers.\n', pool.NumWorkers);

    % Ensure project + BMELIB are on the worker path. Local ("Processes")
    % pools inherit the client path, but make it explicit to be safe.
    projRoot = fileparts(mfilename('fullpath'));
    pctRunOnAll(sprintf('addpath(''%s'')', projRoot));
else
    warning(['Parallel Computing Toolbox not found - parfor will run ' ...
        'SERIALLY (no speedup).']);
end

%% ====================================================================
%                    PARALLEL LOOP OVER YEARS
% ====================================================================

fprintf('\n========================================================================\n');
fprintf('              STARTING PARALLEL VALIDATION (across %d years)\n', nYears);
fprintf('========================================================================\n\n');

statsCell = cell(nYears, 1);   % sliced output: one stats table per year
tStart = tic;

parfor iy = 1:nYears
    valYear = valYears(iy);

    % Per-year parameter struct (broadcast valParam is read-only).
    vp = valParam;
    vp.valYears    = valYear;
    vp.timeRange   = [valYear - valParam.yearsOverhang, valYear + valParam.yearsOverhang];
    vp.plotResults = 0;        % never plot inside workers
    vp.softData    = [];       % let runCBV_toar load soft data as needed

    yearStats = [];            % accumulate this year's stats across methods ([] drops cleanly on vertcat)

    for k = 1:numel(methodList)
        vp.BMEmethod = methodList{k};
        fprintf('[year %d] method %d/%d: %s\n', valYear, k, numel(methodList), methodList{k});

        try
            [~, st] = runCBV_toar(vp);
            if ~isempty(st)
                st.BMEmethod = repmat(methodList(k), height(st), 1);
                yearStats = [yearStats; st]; %#ok<AGROW>
            end
        catch ME
            warning('runCBV_toar failed for year %d, method %s: %s', ...
                valYear, methodList{k}, ME.message);
        end
    end

    statsCell{iy} = yearStats;
end

totalTime = toc(tStart);

%% ====================================================================
%                    AGGREGATE RESULTS (serial)
% ====================================================================

cbvStats = [];
for iy = 1:nYears
    if ~isempty(statsCell{iy})
        cbvStats = [cbvStats; statsCell{iy}]; %#ok<AGROW>
    end
end

fprintf('\n========================================================================\n');
fprintf('                      PARALLEL VALIDATION COMPLETE\n');
fprintf('========================================================================\n');
fprintf('Total wall-clock time: %.1f minutes\n', totalTime/60);

if ~isempty(cbvStats)
    cbvDir = fullfile('7validation', 'CBV');
    if ~exist(cbvDir, 'dir'); mkdir(cbvDir); end

    base = sprintf('CBV_parallel_summary_go%d', valParam.goScenario);
    csvPath = fullfile(cbvDir, [base '.csv']);
    matPath = fullfile(cbvDir, [base '.mat']);
    writetable(cbvStats, csvPath);
    save(matPath, 'cbvStats', 'valParam', 'methodList', 'valYears', '-v7.3');
    fprintf('\nCombined summary saved:\n  %s\n  %s\n', csvPath, matPath);

    % Quick per-method / per-year recap
    uMethods = unique(cbvStats.BMEmethod);
    uYears   = unique(cbvStats.Year);
    for im = 1:numel(uMethods)
        ms = cbvStats(strcmp(cbvStats.BMEmethod, uMethods{im}), :);
        fprintf('\n--- Method: %s ---\n', uMethods{im});
        for iyr = 1:numel(uYears)
            ys = ms(ms.Year == uYears(iyr), :);
            if ~isempty(ys)
                fprintf('  %d: R2=%.3f  RMSE=%.2f  MAE=%.2f  NMB=%.1f%%  (N=%d)\n', ...
                    uYears(iyr), mean(ys.R2), mean(ys.RMSE), mean(ys.MAE), ...
                    mean(ys.NMB), round(mean(ys.N)));
            end
        end
    end

    % Optional pooled plotting (once, after the parallel loop). Phase 1 reads
    % the per-year/method annual .mat files already written to cbvDir.
    if plotResultsAfter
        try
            fprintf('\nCreating pooled CBV plots (Phase 1)...\n');
            plotCBVresults_Phase1(cbvDir, 'years', valYears, 'visible', 'off');
        catch ME
            warning('Pooled plotting failed: %s', ME.message);
        end
    end
else
    warning('No validation statistics generated. Check worker warnings above.');
end

fprintf('\n========================================================================\n\n');

%% ---- local helper -------------------------------------------------------
function out = iif(cond, a, b)
% Inline if for compact display strings.
if cond, out = a; else, out = b; end
end
