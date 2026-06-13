function [summary, paperText] = summarizeOSDMA8forPaper(bmeMethod, yearRange, baseMethod, metrics, varargin)
% summarizeOSDMA8forPaper - Summarize OSDMA8 validation results for paper writing
%
% OSDMA8 counterpart to summarizeCBVforPaper. Loads the per-case OSDMA8 files
% written by runOSDMA8validation (OSDMA8_BME*_box*_fold*_YEAR.mat, each with a
% `caseRes` struct holding osRef/osTest/coords and a pre-computed stats struct),
% aggregates statistics across years (the grouped-years summary), computes
% improvement over a baseline method, and produces a regional breakdown. Returns
% structured data plus manuscript-ready text.
%
% SYNTAX:
%   [summary, paperText] = summarizeOSDMA8forPaper(bmeMethod, yearRange)
%   [summary, paperText] = summarizeOSDMA8forPaper(bmeMethod, yearRange, baseMethod, metrics)
%   [summary, paperText] = summarizeOSDMA8forPaper(..., 'boxSize', 5.0, 'regions', {'Europe'})
%
% INPUTS:
%   bmeMethod  - method code with GO suffix (e.g., '13000313-02_go3')
%   yearRange  - [startYear endYear]
%   baseMethod - baseline code (default: '10000133_go0')
%   metrics    - cell array of metric names (default: {'R2','RMSE'})
%
% OPTIONAL (Name-Value):
%   'boxSize'    - box size in degrees (default: 5.0)
%   'osdma8Dir'  - OSDMA8 results directory (default: './7validation/OSDMA8')
%   'regions'    - cell array of regions to analyze (default: all found)
%
% OUTPUTS: same shape as summarizeCBVforPaper (summary + paperText structs).
%
% SEE ALSO: summarizeCBVforPaper, runOSDMA8validation, plotOSDMA8results_Phase4,
%           calculateValidationStats, assignRegions, getBMEmethodName

%% Defaults
if nargin < 3 || isempty(baseMethod), baseMethod = '10000133_go0'; end
if nargin < 4 || isempty(metrics),    metrics = {'R2', 'RMSE'}; end

p = inputParser;
addParameter(p, 'boxSize', 5.0, @isnumeric);
addParameter(p, 'osdma8Dir', './7validation/OSDMA8', @ischar);
addParameter(p, 'regions', {}, @iscell);
addParameter(p, 'leakTag', '', @ischar);   % '' or '_lc<R>' to select leakage-controlled files
parse(p, varargin{:});
opts = p.Results;

[bmeCode, bmeGO]   = parseMethodAndGO(bmeMethod);
[baseCode, baseGO] = parseMethodAndGO(baseMethod);

summary = struct();
summary.method.code       = bmeCode;
summary.method.goScenario = bmeGO;
summary.method.fullCode   = bmeMethod;
summary.method.name       = getBMEmethodName(bmeCode, bmeGO);
summary.baseline.code       = baseCode;
summary.baseline.goScenario = baseGO;
summary.baseline.fullCode   = baseMethod;
summary.baseline.name       = getBMEmethodName(baseCode, baseGO);

fprintf('\n=== OSDMA8 Summary for Paper ===\n');
fprintf('Method:   %s  (%s)\n', summary.method.name, bmeMethod);
fprintf('Baseline: %s  (%s)\n', summary.baseline.name, baseMethod);
fprintf('Years:    %d-%d | Box: %.1f deg | Metrics: %s\n\n', ...
    yearRange(1), yearRange(2), opts.boxSize, strjoin(metrics, ', '));

%% Load OSDMA8 case files for method and baseline
fprintf('Loading method OSDMA8 files...\n');
[methStats, methResults, methYears] = loadOSDMA8files( ...
    bmeCode, bmeGO, opts.boxSize, yearRange, opts.osdma8Dir, opts.leakTag);
fprintf('Loading baseline OSDMA8 files...\n');
[baseStats, baseResults, ~] = loadOSDMA8files( ...
    baseCode, baseGO, opts.boxSize, yearRange, opts.osdma8Dir, opts.leakTag);

summary.years  = methYears;
summary.nYears = length(methYears);
summary.N      = 0;

if isempty(methYears)
    warning('No OSDMA8 data found for method %s in %d-%d', bmeMethod, yearRange(1), yearRange(2));
    paperText = struct('overallSummary', 'No data available.', ...
        'improvementSummary', '', 'regionalSummary', '', ...
        'regionalTable', '', 'yearRange', '');
    return;
end

%% Aggregate overall stats across years (grouped-years summary)
allYears = yearRange(1):yearRange(2);
nAllYears = length(allYears);
summary.yearly.years = allYears(:);

for m = 1:length(metrics)
    metricName = metrics{m};
    methYearly = NaN(nAllYears, 1);
    baseYearly = NaN(nAllYears, 1);
    for iY = 1:nAllYears
        yr = allYears(iY);
        methYearly(iY) = meanFoldMetric(methStats, yr, metricName);
        baseYearly(iY) = meanFoldMetric(baseStats, yr, metricName);
    end
    summary.yearly.(metricName)              = methYearly;
    summary.yearly.(['baseline_' metricName]) = baseYearly;
    summary.overall.(metricName)         = aggregateMetric(methYearly);
    summary.baselineOverall.(metricName) = aggregateMetric(baseYearly);
end

%% Improvement over baseline
for m = 1:length(metrics)
    metricName = metrics{m};
    methVal = summary.overall.(metricName).mean;
    baseVal = summary.baselineOverall.(metricName).mean;
    direction = getMetricDirection(metricName);
    if direction == 1
        absImprove = methVal - baseVal;
    elseif direction == -1
        absImprove = baseVal - methVal;
    else
        absImprove = abs(baseVal) - abs(methVal);
    end
    if abs(baseVal) > 1e-10, relImprove = absImprove / abs(baseVal) * 100; else, relImprove = NaN; end
    summary.improvement.(metricName).absolute     = absImprove;
    summary.improvement.(metricName).relative     = relImprove;
    summary.improvement.(metricName).methodMean   = methVal;
    summary.improvement.(metricName).baselineMean = baseVal;
    summary.improvement.(metricName).direction    = direction;
end

%% Regional breakdown (pooled across years/folds)
[methAllObs, methAllEst, methAllSk] = concatenateResults(methResults);
[baseAllObs, baseAllEst, baseAllSk] = concatenateResults(baseResults);
summary.N = sum(~isnan(methAllObs) & ~isnan(methAllEst));
summary.regional = struct();

if ~isempty(methAllSk)
    methRegions = assignRegions(methAllSk(:,1), methAllSk(:,2));
    uniqueRegions = unique(methRegions);
    if ~isempty(opts.regions), uniqueRegions = intersect(uniqueRegions, opts.regions); end
    otherIdx = strcmp(uniqueRegions, 'Other');
    if any(otherIdx) && sum(strcmp(methRegions, 'Other')) < 10
        uniqueRegions(otherIdx) = [];
    end

    for iR = 1:length(uniqueRegions)
        regName = uniqueRegions{iR};
        fieldName = matlab.lang.makeValidName(regName);
        mask = strcmp(methRegions, regName);
        if sum(mask) < 2, continue; end
        summary.regional.(fieldName).method = calculateValidationStats(methAllObs(mask), methAllEst(mask));
        summary.regional.(fieldName).N = sum(mask);

        summary.regional.(fieldName).baseline = struct();
        if ~isempty(baseAllSk)
            baseRegions = assignRegions(baseAllSk(:,1), baseAllSk(:,2));
            baseMask = strcmp(baseRegions, regName);
            if sum(baseMask) >= 2
                summary.regional.(fieldName).baseline = calculateValidationStats(baseAllObs(baseMask), baseAllEst(baseMask));
            end
        end

        summary.regional.(fieldName).improvement = struct();
        for m = 1:length(metrics)
            metricName = metrics{m};
            if isfield(summary.regional.(fieldName).method, metricName) && ...
               isfield(summary.regional.(fieldName).baseline, metricName)
                regMethVal = summary.regional.(fieldName).method.(metricName);
                regBaseVal = summary.regional.(fieldName).baseline.(metricName);
                direction = getMetricDirection(metricName);
                if direction == 1
                    regAbs = regMethVal - regBaseVal;
                elseif direction == -1
                    regAbs = regBaseVal - regMethVal;
                else
                    regAbs = abs(regBaseVal) - abs(regMethVal);
                end
                if abs(regBaseVal) > 1e-10, regRel = regAbs / abs(regBaseVal) * 100; else, regRel = NaN; end
                summary.regional.(fieldName).improvement.(metricName).absolute = regAbs;
                summary.regional.(fieldName).improvement.(metricName).relative = regRel;
            end
        end
        summary.regional.(fieldName).regionName = regName;
    end
end

%% Paper text + console print
paperText = generatePaperText(summary, metrics, yearRange, opts.boxSize);
fprintf('\n=== Results ===\n');
fprintf('%s\n\n', paperText.overallSummary);
fprintf('%s\n\n', paperText.improvementSummary);
fprintf('%s\n\n', paperText.regionalSummary);
fprintf('%s\n', paperText.regionalTable);
fprintf('%s\n', paperText.yearRange);
end

%% ========================================================================
%  LOCAL HELPERS
%  ========================================================================
function [code, goScenario] = parseMethodAndGO(methodStr)
    parts = regexp(methodStr, '^(.+)_go(\d+)$', 'tokens');
    if isempty(parts)
        error('Invalid method string: %s. Expected like 13000313-02_go3', methodStr);
    end
    code = parts{1}{1};
    goScenario = str2double(parts{1}{2});
end

function [allStats, allResults, yearsFound] = loadOSDMA8files(code, go, boxSize, yearRange, osdma8Dir, leakTag)
    if nargin < 6 || isempty(leakTag), leakTag = ''; end
    allStats = struct(); allResults = struct(); yearsFound = [];
    for yr = yearRange(1):yearRange(2)
        yearHasData = false;
        for iFold = 1:2
            fname = sprintf('OSDMA8_BME%s_go%d_box%.1f_fold%d_%d%s.mat', code, go, boxSize, iFold, yr, leakTag);
            fpath = fullfile(osdma8Dir, fname);
            if ~exist(fpath, 'file'), continue; end
            try
                d = load(fpath, 'caseRes');
                if ~isfield(d, 'caseRes'), continue; end
                cr = d.caseRes;
                key = sprintf('y%d_f%d', yr, iFold);
                if isfield(cr, 'stats'), allStats.(key) = cr.stats; end
                r = struct('Y_obs', cr.osRef, 'Y_est', cr.osTest);
                if isfield(cr, 'coords'), r.sk = cr.coords; else, r.sk = []; end
                allResults.(key) = r;
                yearHasData = true;
            catch ME
                warning('Failed to load %s: %s', fname, ME.message);
            end
        end
        if yearHasData, yearsFound(end+1) = yr; end %#ok<AGROW>
    end
    fprintf('  Found data for %d/%d years\n', length(yearsFound), yearRange(2)-yearRange(1)+1);
end

function v = meanFoldMetric(statsStruct, yr, metricName)
    foldVals = [];
    for iFold = 1:2
        key = sprintf('y%d_f%d', yr, iFold);
        if isfield(statsStruct, key) && isfield(statsStruct.(key), metricName)
            foldVals(end+1) = statsStruct.(key).(metricName); %#ok<AGROW>
        end
    end
    if isempty(foldVals), v = NaN; else, v = mean(foldVals); end
end

function [allObs, allEst, allSk] = concatenateResults(resultsStruct)
    allObs = []; allEst = []; allSk = [];
    if isempty(fieldnames(resultsStruct)), return; end
    keys = fieldnames(resultsStruct);
    for i = 1:length(keys)
        r = resultsStruct.(keys{i});
        if isfield(r, 'Y_obs') && isfield(r, 'Y_est')
            allObs = [allObs; r.Y_obs(:)]; %#ok<AGROW>
            allEst = [allEst; r.Y_est(:)]; %#ok<AGROW>
            if isfield(r, 'sk') && ~isempty(r.sk)
                allSk = [allSk; r.sk]; %#ok<AGROW>
            end
        end
    end
end

function agg = aggregateMetric(values)
    valid = values(~isnan(values));
    if isempty(valid)
        agg = struct('mean', NaN, 'std', NaN, 'median', NaN, 'min', NaN, 'max', NaN, 'nValid', 0);
        return;
    end
    agg.mean = mean(valid); agg.std = std(valid); agg.median = median(valid);
    agg.min = min(valid); agg.max = max(valid); agg.nValid = length(valid);
end

function direction = getMetricDirection(metricName)
    higherIsBetter = {'R2','IOA','IOAmod','FAC2','PearsonR','SpearmanR','r_QA','r2_QA'};
    lowerIsBetter  = {'RMSE','MAE','MSE','NME','VarError'};
    closerToZero   = {'NMB','ME','MBE'};
    if ismember(metricName, higherIsBetter), direction = 1;
    elseif ismember(metricName, lowerIsBetter), direction = -1;
    elseif ismember(metricName, closerToZero), direction = 0;
    else, direction = 1; end
end

function paperText = generatePaperText(summary, metrics, yearRange, boxSize)
    paperText = struct();
    methodName = summary.method.name; baselineName = summary.baseline.name;

    paperText.yearRange = sprintf( ...
        'Validated OSDMA8 over N=%d years (%d-%d) with %d station-year pairs (%.0f deg checker-board box).', ...
        summary.nYears, yearRange(1), yearRange(2), summary.N, boxSize);

    metricParts = {};
    for m = 1:length(metrics)
        name = metrics{m};
        if ~isfield(summary.overall, name), continue; end
        metricParts{end+1} = formatMetricValue(name, summary.overall.(name).mean, summary.overall.(name).std); %#ok<AGROW>
    end
    paperText.overallSummary = sprintf( ...
        'For OSDMA8, the method %s achieved a mean %s over %d-%d (N=%d).', ...
        methodName, strjoin(metricParts, ' and '), yearRange(1), yearRange(2), summary.N);

    improvParts = {};
    for m = 1:length(metrics)
        name = metrics{m};
        if ~isfield(summary.improvement, name), continue; end
        improvParts{end+1} = formatImprovementText(name, summary.improvement.(name)); %#ok<AGROW>
    end
    if ~isempty(improvParts)
        paperText.improvementSummary = sprintf('Compared to the baseline (%s), %s.', ...
            baselineName, strjoin(improvParts, '; '));
    else
        paperText.improvementSummary = 'Baseline data not available for comparison.';
    end

    paperText.regionalSummary = ''; paperText.regionalTable = '';
    if ~isempty(fieldnames(summary.regional))
        regFields = fieldnames(summary.regional);
        primaryMetric = metrics{1};
        tableLines = {};
        tableLines{end+1} = sprintf('%-20s %8s %10s %10s %10s %12s', 'Region', 'N', ...
            [primaryMetric ' (M)'], [primaryMetric ' (B)'], ['d' primaryMetric], ['d' primaryMetric ' (%)']);
        tableLines{end+1} = repmat('-', 1, 72);
        bestRegion = ''; bestDelta = -Inf; worstRegion = ''; worstDelta = Inf;
        for iR = 1:length(regFields)
            reg = summary.regional.(regFields{iR});
            if ~isfield(reg.improvement, primaryMetric), continue; end
            methVal = reg.method.(primaryMetric); baseVal = reg.baseline.(primaryMetric);
            absDelta = reg.improvement.(primaryMetric).absolute;
            relDelta = reg.improvement.(primaryMetric).relative;
            tableLines{end+1} = sprintf('%-20s %8d %10.3f %10.3f %+10.3f %+11.1f%%', ...
                reg.regionName, reg.N, methVal, baseVal, absDelta, relDelta); %#ok<AGROW>
            if absDelta > bestDelta, bestDelta = absDelta; bestRegion = reg.regionName; end
            if absDelta < worstDelta, worstDelta = absDelta; worstRegion = reg.regionName; end
        end
        paperText.regionalTable = strjoin(tableLines, '\n');
        if ~isempty(bestRegion) && ~isempty(worstRegion)
            if strcmp(bestRegion, worstRegion)
                paperText.regionalSummary = sprintf('Regional OSDMA8 analysis shows %s change of %+.3f in %s.', ...
                    primaryMetric, bestDelta, bestRegion);
            else
                paperText.regionalSummary = sprintf( ...
                    'The largest OSDMA8 improvement was in %s (d%s=%+.3f), while %s showed %s (d%s=%+.3f).', ...
                    bestRegion, primaryMetric, bestDelta, worstRegion, ...
                    conditionalStr(worstDelta > 0, 'more modest gains', 'a decrease'), primaryMetric, worstDelta);
            end
        end
    end
end

function str = formatMetricValue(name, val, sd)
    if ismember(name, {'R2','IOA','IOAmod','PearsonR','SpearmanR','r_QA','r2_QA'})
        str = sprintf('%s of %.3f (+/-%.3f)', name, val, sd);
    elseif ismember(name, {'NMB','NME','FAC2'})
        str = sprintf('%s of %.1f (+/-%.1f)%%', name, val, sd);
    else
        str = sprintf('%s of %.1f (+/-%.1f) ppb', name, val, sd);
    end
end

function str = formatImprovementText(name, imp)
    direction = imp.direction;
    if direction == 1
        if imp.absolute >= 0, verb = 'improved'; else, verb = 'decreased'; end
        str = sprintf('%s %s by %+.3f (%+.1f%%)', name, verb, imp.methodMean - imp.baselineMean, imp.relative);
    elseif direction == -1
        rawDiff = imp.methodMean - imp.baselineMean;
        if rawDiff <= 0, verb = 'decreased'; else, verb = 'increased'; end
        str = sprintf('%s %s by %.1f ppb (%+.1f%%)', name, verb, abs(rawDiff), -rawDiff/abs(imp.baselineMean)*100);
    else
        rawDiff = abs(imp.methodMean) - abs(imp.baselineMean);
        if rawDiff <= 0, verb = 'reduced'; else, verb = 'increased'; end
        str = sprintf('|%s| %s from %.1f to %.1f', name, verb, abs(imp.baselineMean), abs(imp.methodMean));
    end
end

function str = conditionalStr(cond, trueStr, falseStr)
    if cond, str = trueStr; else, str = falseStr; end
end
