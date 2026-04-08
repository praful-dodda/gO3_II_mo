function monthlyStats = aggregateCBVmonthlyStats(valParam, opts)
% aggregateCBVmonthlyStats - Load existing monthly CBV .mat files and
%   compute per-month validation statistics.
%
% SYNTAX:
%   monthlyStats = aggregateCBVmonthlyStats(valParam)
%   monthlyStats = aggregateCBVmonthlyStats(valParam, opts)
%
% INPUTS:
%   valParam  - Validation parameters structure with fields:
%               .BMEmethod  - BME method code string (e.g. '10000132')
%               .goScenario - Global offset scenario integer
%               .valYears   - Years to aggregate (e.g. 2005:2019)
%               .valMonths  - Months to aggregate (default: 1:12)
%               .nFolds     - Number of CBV folds (default: 2)
%   opts      - (optional) Options structure:
%               .boxSize        - Canonical box size in degrees (default: 3.0)
%               .forceRecompute - Recompute even if cached (default: false)
%               .minN           - Min valid pairs to include a month (default: 5)
%
% OUTPUTS:
%   monthlyStats - Table with one row per (Year, Month, Fold), columns:
%                  Year, Month, Fold, nValid, nTrain, N, R2, RMSE, MAE,
%                  ME, MBE, NMB, NME, MeanObs, MeanEst, StdObs, StdEst,
%                  PearsonR, SpearmanR, MSE, VarError, IOA, IOAmod, FAC2,
%                  Slope, Intercept
%                  Properties.UserData: BMEmethod, goScenario, boxSize
%
% SAVES:
%   7validation/CBV/CBV_monthly_summary_BME[method]_go[scenario]_box[size].mat
%
% EXAMPLE:
%   valParam.BMEmethod  = '10000132';
%   valParam.goScenario = 3;
%   valParam.valYears   = 2005:2019;
%   T = aggregateCBVmonthlyStats(valParam);
%   % With options:
%   opts.boxSize = 3.0;
%   T = aggregateCBVmonthlyStats(valParam, opts);
%
% SEE ALSO:
%   runCBV_toar, plotCBVmonthly, calculateValidationStats

%% Defaults
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'boxSize'),        opts.boxSize        = 3.0;  end
if ~isfield(opts, 'forceRecompute'), opts.forceRecompute = false; end
if ~isfield(opts, 'minN'),           opts.minN           = 5;    end
if ~isfield(valParam, 'valMonths'),  valParam.valMonths  = 1:12; end
if ~isfield(valParam, 'nFolds'),     valParam.nFolds     = 2;    end

%% Paths
cbvDir     = fullfile('7validation', 'CBV');
monthlyDir = fullfile(cbvDir, 'monthly');
outFile    = fullfile(cbvDir, sprintf('CBV_monthly_summary_BME%s_go%d_box%.1f.mat', ...
                 valParam.BMEmethod, valParam.goScenario, opts.boxSize));

%% Cache check
if exist(outFile, 'file') && ~opts.forceRecompute
    fprintf('Loading cached monthly summary: %s\n', outFile);
    tmp = load(outFile, 'monthlyStats');
    monthlyStats = tmp.monthlyStats;
    return;
end

fprintf('aggregateCBVmonthlyStats: BME%s, GO%d, box=%.1f\n', ...
    valParam.BMEmethod, valParam.goScenario, opts.boxSize);

%% Loop and collect
statsData = [];
nMissing  = 0;
nLoaded   = 0;

for iYear = 1:length(valParam.valYears)
    valYear = valParam.valYears(iYear);

    for iMonth = 1:length(valParam.valMonths)
        valMonth = valParam.valMonths(iMonth);

        for iFold = 1:valParam.nFolds

            %% Build filename (same pattern as runCBV_toar.m lines 344-346)
            fname = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d_%02d.mat', ...
                valParam.BMEmethod, valParam.goScenario, ...
                opts.boxSize, iFold, valYear, valMonth);
            fpath = fullfile(monthlyDir, fname);

            if ~exist(fpath, 'file')
                nMissing = nMissing + 1;
                continue;
            end

            try
                tmp = load(fpath, 'monthResults');
            catch ME
                warning('aggregateCBVmonthlyStats:loadFail', ...
                    'Could not load %s: %s', fname, ME.message);
                nMissing = nMissing + 1;
                continue;
            end

            mr = tmp.monthResults;

            %% Check sufficient valid pairs
            if ~isfield(mr, 'nValid') || mr.nValid < opts.minN
                continue;
            end

            %% Compute metrics
            s = calculateValidationStats(mr.Y_obs, mr.Y_est);
            if isempty(fieldnames(s))
                continue;   % n < 2 triggered warning inside calculateValidationStats
            end

            %% Pack row (mirrors runCBV_toar.m lines 396-400)
            s.Year   = valYear;
            s.Month  = valMonth;
            s.Fold   = iFold;
            s.nValid = mr.nValid;
            s.nTrain = mr.nTrain;

            if isempty(statsData)
                statsData = s;
            else
                statsData(end+1) = s; %#ok<AGROW>
            end
            nLoaded = nLoaded + 1;

        end  % fold
    end  % month
end  % year

fprintf('  Loaded %d entries, %d files missing/skipped.\n', nLoaded, nMissing);

%% Handle no data
if isempty(statsData)
    warning('aggregateCBVmonthlyStats:noData', ...
        'No monthly files found for BME%s go%d box%.1f. Returning empty table.', ...
        valParam.BMEmethod, valParam.goScenario, opts.boxSize);
    monthlyStats = table();
    return;
end

%% Convert to table
monthlyStats = struct2table(statsData);

%% Attach identity metadata (same convention as plotCBVresults.m line 250)
monthlyStats.Properties.UserData = struct( ...
    'BMEmethod',  valParam.BMEmethod, ...
    'goScenario', valParam.goScenario, ...
    'boxSize',    opts.boxSize);

%% Save
if ~exist(cbvDir, 'dir'), mkdir(cbvDir); end
save(outFile, 'monthlyStats', 'valParam', '-v7.3');
fprintf('  Saved: %s\n', outFile);

end
