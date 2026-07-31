%% runBME_estimation_parallel.m
% Parallel re-run of spatial BME estimation across (method, year) jobs.
%
% Drop-in parallel companion to runBME_estimation.m. It parallelizes ACROSS
% (method, year) jobs with parfor, calling the SAME proven analyzeTOAR ->
% estTOARsBMEoptim pipeline unchanged. runBME_estimation.m is NOT modified.
%
% WHY (method, year)-LEVEL PARALLELISM IS SAFE:
%   The Global Offset / Covariance / observation / STUG-soft caches are keyed by
%   the YEAR WINDOW ([year +/- temporalPadding]) and are METHOD-INDEPENDENT
%   (e.g. OZONE-TOARgo_3_2014-2016.mat, Cov_go3_lt0_exponential_2014-2016.mat,
%   stug_<model>_..._y2014-2016_*.mat). Each job's year window is unique, so every
%   worker reads/writes a DISJOINT set of caches and writes disjoint monthly files
%   BME<method>_..._time<YYYY.YY>.mat. No locks, no races -- the same isolation
%   runCBV_parallel.m and the hpc_cbv/ job-array design rely on. Shared reads
%   (map-grid cache, parquet inputs) already exist and are read-only.
%
% DEFAULT JOB SET = the multi-soft map eras corrupted by the soft-data variance
% mis-indexing bug (now fixed in estTOARsBMEoptim/estTOARsBME), re-run with
% forceEstimation=1 to overwrite the bad maps:
%     13000313-06 : 2005-2016 and 2021
%     13000313-0E : 2017-2020   (also fixes the 2020 Nov/Dec patch)
%     13000313-42 : 2022
% (Single-soft 13000313-02 for 1990-2004 and all CBV results are correct -> excluded.)
%
% USAGE:
%   1. Edit the CONFIGURATION block (jobsByMethod / numWorkers / bmelibDir).
%   2. Run:  >> runBME_estimation_parallel
%   3. Maps overwrite ./5BMEspatialPlots/ ; a completeness audit prints at the end.
%
% NOTES:
%   - RAM-bound: each 3-model (-0E) worker holds ~3 GB of soft data. Set
%     parParam.numWorkers to fit memory (numWorkers * ~3 GB).
%   - Each job re-runs a FULL year so soft-load/GO/Cov/KB amortize over its 12
%     months. Do not parallelize per-month (it would reload soft data 12x).
%   - If the Parallel Computing Toolbox is unavailable, parfor runs SERIALLY
%     (script still works, just no speedup).
%
% SEE ALSO: runBME_estimation, runCBV_parallel, analyzeTOAR, estTOARsBMEoptim,
%           inventoryBMEestimates

clear; close all;

fprintf('\n');
fprintf('========================================================================\n');
fprintf('            PARALLEL BME DATA-FUSION ESTIMATION (re-run)\n');
fprintf('========================================================================\n');

%% ====================================================================
%                    JOB CONFIGURATION (what to re-run)
% ====================================================================
% One row per method: {BMEcode, yearVector}. Each (method, year) becomes a job.
jobsByMethod = { ...
    '13000313-06', [2005:2016, 2021]; ...
    '13000313-0E', 2017:2020; ...
    '13000313-42', 2022 };

%% ====================================================================
%                    DATA CONFIGURATION  (mirror runBME_estimation.m)
% ====================================================================
analyzeParam.stationTypes = 'all';      % 'all', 'rural', 'urban'
analyzeParam.logTransf    = 0;          % 0=no transform, 1=log transform
analyzeParam.softDataDir  = fullfile('d:\Users\praful\Documents\Data\ramp_data\');

% Temporal padding for observations (years before/after for edge effects)
temporalPadding = 1;   % obs/GO/Cov/soft use [year-1, year+1]
estMonths       = 1:12;

analyzeParam.dataFormat = 'stug';

%% GLOBAL OFFSET / COVARIANCE
analyzeParam.goScenario    = 3;
analyzeParam.forceGO       = 0;     % use cached GO (year-disjoint -> safe)
analyzeParam.goPlot        = 0;
analyzeParam.temporalModel = 'exponential';
analyzeParam.forceCov      = 0;     % use cached Cov (year-disjoint -> safe)

%% ESTIMATION GRID
analyzeParam.areaCode         = 0;
analyzeParam.mapResolution    = 1;
analyzeParam.keepOnlyLand     = true;
analyzeParam.includeAntarctica= false;
analyzeParam.coastBuffer      = 0.5;
analyzeParam.popCoverFile     = fullfile('Population-Data', 'PopulationData2019.csv');
analyzeParam.gridOffset       = 0.1;    % offset grid to avoid stripes

% Force re-estimation: THIS is the point -- overwrite the buggy multi-soft maps.
analyzeParam.forceEstimation  = 1;

%% PLOTTING (all OFF -- never plot inside parallel workers)
analyzeParam.plotResults     = 0;
analyzeParam.plotVariance    = 0;
analyzeParam.plotTemporal    = 0;
analyzeParam.plotSpatialStats= 0;
analyzeParam.parallelPlotting= 0;
analyzeParam.plotSoftData    = false;
analyzeParam.obsMatchRadius  = 0.01;
analyzeParam.nxpix = 150; analyzeParam.nypix = 100;
analyzeParam.bufferDist = 0.5; analyzeParam.bufferType = 'soft';
analyzeParam.interpMethod = 'natural';
analyzeParam.dxRes = 0.1; analyzeParam.dyRes = 0.1;

%% WORKFLOW CONTROL
analyzeParam.runExplore = 0;
analyzeParam.runGO      = 1;
analyzeParam.runCov     = 1;
analyzeParam.runBME     = 1;

%% ====================================================================
%                    PARALLEL CONFIGURATION
% ====================================================================
parParam.numWorkers = [];   % [] => MATLAB default pool size; else e.g. 6 (mind RAM ~3GB/worker)
bmelibDir = 'E:\packages\BMELIB2.0c_MATLAB2009a';   % used only if BMELIB not already on path
dryRun = false;             % true => print jobs + per-job params, do NOT estimate

%% ====================================================================
%                    BUILD FLAT JOB LIST
% ====================================================================
jobs = struct('method', {}, 'year', {});
for r = 1:size(jobsByMethod, 1)
    yrs = jobsByMethod{r, 2};
    for y = yrs(:).'
        jobs(end+1) = struct('method', jobsByMethod{r, 1}, 'year', y); %#ok<SAGROW>
    end
end
nJobs = numel(jobs);

fprintf('\nConfiguration:\n');
fprintf('  GO scenario %d | %s | area %d | res %.2f deg | %s | land %d\n', ...
    analyzeParam.goScenario, analyzeParam.temporalModel, analyzeParam.areaCode, ...
    analyzeParam.mapResolution, analyzeParam.dataFormat, analyzeParam.keepOnlyLand);
fprintf('  forceEstimation = %d | temporalPadding = +/-%d yr\n', ...
    analyzeParam.forceEstimation, temporalPadding);
fprintf('  Jobs (method, year): %d total\n', nJobs);
for k = 1:nJobs
    fprintf('     %-14s %d\n', jobs(k).method, jobs(k).year);
end

%% ====================================================================
%                    ENSURE BMELIB ON CLIENT PATH
% ====================================================================
projRoot = fileparts(mfilename('fullpath'));
if isempty(projRoot); projRoot = pwd; end
cd(projRoot);
if exist('stmeaninterp', 'file') ~= 2
    startupFile = fullfile(bmelibDir, 'startup.m');
    if exist(startupFile, 'file') == 2
        fprintf('\nBMELIB not on path -- running %s\n', startupFile);
        run(startupFile);
    else
        warning(['BMELIB function stmeaninterp not found and bmelibDir startup.m ' ...
            'missing (%s). Estimation will fail until BMELIB is on the path.'], startupFile);
    end
end

if dryRun
    fprintf('\n[dryRun] Job list built; estimation skipped.\n'); %#ok<UNRCH>
    return;
end

%% ====================================================================
%                    START PARALLEL POOL (graceful fallback)
% ====================================================================
haveParallel = ~isempty(ver('parallel'));
if haveParallel
    pool = gcp('nocreate');
    if isempty(pool)
        if isempty(parParam.numWorkers)
            pool = parpool();
        else
            pool = parpool(parParam.numWorkers);
        end
    end
    fprintf('\nParallel pool active: %d workers.\n', pool.NumWorkers);
    % Make project root available + correct on every worker so relative writes
    % (5BMEspatialPlots/, caches) land in the right place. Local pools inherit
    % the client BMELIB path; re-assert project root to be safe.
    pctRunOnAll(sprintf('cd(''%s'')', projRoot));
    pctRunOnAll(sprintf('addpath(''%s'')', projRoot));
else
    warning(['Parallel Computing Toolbox not found - parfor will run SERIALLY ' ...
        '(no speedup).']);
end

%% ====================================================================
%                    PARALLEL LOOP OVER (method, year) JOBS
% ====================================================================
fprintf('\n========================================================================\n');
fprintf('         STARTING PARALLEL ESTIMATION (%d jobs)\n', nJobs);
fprintf('========================================================================\n\n');

status = cell(nJobs, 1);   % sliced output: one status struct per job
baseParam = analyzeParam;  % broadcast (read-only inside parfor)
tStart = tic;

parfor k = 1:nJobs
    method = jobs(k).method;
    yr     = jobs(k).year;

    ap = baseParam;                              % per-worker copy
    ap.BMEmethod = method;
    ap.timeRange = [yr - temporalPadding, yr + temporalPadding];
    ap.tkVec     = yr + (estMonths - 1) / 12;
    ap.forceEstimation = 1;

    jobTic = tic;
    s = struct('method', method, 'year', yr, 'ok', false, 'msg', '', 'minutes', NaN);
    try
        fprintf('[job %d/%d] %s %d : loading soft data...\n', k, nJobs, method, yr);
        ap.softData = getTOARSoftData(ap.BMEmethod, ap, ...
            'spatialBuffer', 2, 'temporalPadding', 1, ...
            'thinningFactor', 0, 'forceReload', 0);

        fprintf('[job %d/%d] %s %d : running analyzeTOAR...\n', k, nJobs, method, yr);
        analyzeTOAR(ap);     % GO -> Cov -> KB -> estTOARsBMEoptim (writes 12 month files)

        s.ok = true;
    catch ME
        s.msg = ME.message;
        warning('Job %d (%s %d) FAILED: %s', k, method, yr, ME.message);
    end
    s.minutes = toc(jobTic) / 60;
    fprintf('[job %d/%d] %s %d : %s (%.1f min)\n', k, nJobs, method, yr, ...
        ternary(s.ok, 'OK', 'FAILED'), s.minutes);
    status{k} = s;
end

totalMin = toc(tStart) / 60;

%% ====================================================================
%                    SUMMARY (serial)
% ====================================================================
fprintf('\n========================================================================\n');
fprintf('                   PARALLEL ESTIMATION COMPLETE\n');
fprintf('========================================================================\n');
fprintf('Wall-clock time: %.1f minutes (%.1f h)\n', totalMin, totalMin/60);

nOk = 0; nFail = 0;
fprintf('%-14s %-6s %-8s %-8s %s\n', 'Method', 'Year', 'Status', 'Minutes', 'Message');
for k = 1:nJobs
    s = status{k};
    if isempty(s); continue; end
    if s.ok, nOk = nOk + 1; else, nFail = nFail + 1; end
    fprintf('%-14s %-6d %-8s %-8.1f %s\n', s.method, s.year, ...
        ternary(s.ok, 'OK', 'FAILED'), s.minutes, s.msg);
end
fprintf('\n%d job(s) OK, %d job(s) FAILED.\n', nOk, nFail);

%% ---- Completeness audit ----
fprintf('\nRunning estimate inventory to confirm completeness...\n');
try
    inventoryBMEestimates();
catch ME
    warning('inventoryBMEestimates failed: %s', ME.message);
end

fprintf('\n========================================================================\n\n');

%% ---- local helper -------------------------------------------------------
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
