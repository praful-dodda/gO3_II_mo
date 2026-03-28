function [summary, paperText] = summarizeCBVforPaper(bmeMethod, yearRange, baseMethod, metrics, varargin)
% summarizeCBVforPaper - Summarize CBV validation results for paper writing
%
% Loads existing CBV annual result files, aggregates pre-computed statistics
% across years, computes improvement over a baseline method, and produces
% regional breakdowns. Returns both structured data and formatted text
% ready for inclusion in a manuscript.
%
% SYNTAX:
%   [summary, paperText] = summarizeCBVforPaper(bmeMethod, yearRange)
%   [summary, paperText] = summarizeCBVforPaper(bmeMethod, yearRange, baseMethod, metrics)
%   [summary, paperText] = summarizeCBVforPaper(..., 'boxSize', 5.0, 'regions', {'Europe'})
%
% INPUTS:
%   bmeMethod  - BME method code with GO suffix (e.g., '13000313-01_go3')
%   yearRange  - [startYear endYear] (e.g., [2005 2020])
%   baseMethod - Baseline method code (default: '10000133_go0')
%   metrics    - Cell array of metric names (default: {'R2', 'RMSE'})
%
% OPTIONAL PARAMETERS (Name-Value):
%   'boxSize'  - CBV box size in degrees (default: 5.0)
%   'cbvDir'   - CBV results directory (default: './7validation/CBV')
%   'regions'  - Cell array of regions to analyze (default: all found)
%                Available: 'North America','Europe','East Asia','South Asia',
%                           'South America','Africa','Australia','Other'
%
% OUTPUTS:
%   summary   - Structure with:
%     .method/.baseline   - Method info (code, name, goScenario)
%     .years              - Years with data
%     .nYears             - Number of years with data
%     .N                  - Total validation points
%     .overall.<metric>   - .mean, .std, .median, .min, .max across years
%     .baselineOverall    - Same structure for baseline
%     .improvement.<metric> - .absolute, .relative, .methodMean, .baselineMean
%     .yearly             - Per-year metric values (.years, .<metric>, .baseline_<metric>)
%     .regional.<Region>  - .method, .baseline, .improvement, .N per region
%
%   paperText - Structure of formatted strings:
%     .overallSummary       - Overall performance description
%     .improvementSummary   - Improvement over baseline
%     .regionalSummary      - Regional improvement breakdown
%     .regionalTable        - Formatted table of regional stats
%     .yearRange            - Year range and validation setup description
%
% EXAMPLES:
%   % Basic usage
%   [s, t] = summarizeCBVforPaper('13000313-01_go3', [2005 2020]);
%   disp(t.overallSummary);
%
%   % Custom baseline and metrics
%   [s, t] = summarizeCBVforPaper('13000313-06_go3', [2005 2020], ...
%       '10000133_go3', {'R2', 'RMSE', 'MAE'});
%
%   % Specific regions
%   [s, t] = summarizeCBVforPaper('13000313-01_go3', [2005 2020], ...
%       [], [], 'regions', {'North America', 'Europe', 'East Asia'});
%
% SEE ALSO: calculateValidationStats, assignRegions, getBMEmethodName,
%           plotCBVresults_Phase4, runCBV_toar

%% Input defaults
if nargin < 3 || isempty(baseMethod), baseMethod = '10000133_go0'; end
if nargin < 4 || isempty(metrics),    metrics = {'R2', 'RMSE'}; end

%% Name-Value parsing
p = inputParser;
addParameter(p, 'boxSize', 5.0, @isnumeric);
addParameter(p, 'cbvDir', './7validation/CBV', @ischar);
addParameter(p, 'regions', {}, @iscell);
parse(p, varargin{:});
opts = p.Results;

%% Parse method codes
[bmeCode, bmeGO] = parseMethodAndGO(bmeMethod);
[baseCode, baseGO] = parseMethodAndGO(baseMethod);

%% Populate method info
summary = struct();
summary.method.code       = bmeCode;
summary.method.goScenario = bmeGO;
summary.method.fullCode   = bmeMethod;
summary.method.name       = getBMEmethodName(bmeCode, bmeGO);

summary.baseline.code       = baseCode;
summary.baseline.goScenario = baseGO;
summary.baseline.fullCode   = baseMethod;
summary.baseline.name       = getBMEmethodName(baseCode, baseGO);

fprintf('\n=== CBV Summary for Paper ===\n');
fprintf('Method:   %s  (%s)\n', summary.method.name, bmeMethod);
fprintf('Baseline: %s  (%s)\n', summary.baseline.name, baseMethod);
fprintf('Years:    %d-%d\n', yearRange(1), yearRange(2));
fprintf('Metrics:  %s\n', strjoin(metrics, ', '));
fprintf('Box size: %.1f deg\n\n', opts.boxSize);

%% Load CBV files for method and baseline
fprintf('Loading method CBV files...\n');
[methStats, methResults, methYears] = loadCBVannualFiles( ...
    bmeCode, bmeGO, opts.boxSize, yearRange, opts.cbvDir);

fprintf('Loading baseline CBV files...\n');
[baseStats, baseResults, baseYears] = loadCBVannualFiles( ...
    baseCode, baseGO, opts.boxSize, yearRange, opts.cbvDir);

% Common years with data
summary.years  = methYears;
summary.nYears = length(methYears);
summary.N      = 0;

if isempty(methYears)
    warning('No CBV data found for method %s in %d-%d', bmeMethod, yearRange(1), yearRange(2));
    paperText = struct('overallSummary', 'No data available.', ...
        'improvementSummary', '', 'regionalSummary', '', ...
        'regionalTable', '', 'yearRange', '');
    return;
end

%% Aggregate overall stats from pre-computed annualStats
fprintf('Aggregating overall statistics...\n');
allYears = yearRange(1):yearRange(2);
nAllYears = length(allYears);

summary.yearly.years = allYears(:);

for m = 1:length(metrics)
    metricName = metrics{m};

    % Method: per-year values (average across folds)
    methYearly = NaN(nAllYears, 1);
    baseYearly = NaN(nAllYears, 1);

    for iY = 1:nAllYears
        yr = allYears(iY);

        % Method
        foldVals = [];
        for iFold = 1:2
            key = sprintf('y%d_f%d', yr, iFold);
            if isfield(methStats, key) && isfield(methStats.(key), metricName)
                foldVals(end+1) = methStats.(key).(metricName); %#ok<AGROW>
            end
        end
        if ~isempty(foldVals)
            methYearly(iY) = mean(foldVals);
        end

        % Baseline
        foldVals = [];
        for iFold = 1:2
            key = sprintf('y%d_f%d', yr, iFold);
            if isfield(baseStats, key) && isfield(baseStats.(key), metricName)
                foldVals(end+1) = baseStats.(key).(metricName); %#ok<AGROW>
            end
        end
        if ~isempty(foldVals)
            baseYearly(iY) = mean(foldVals);
        end
    end

    summary.yearly.(metricName)                = methYearly;
    summary.yearly.(['baseline_' metricName])   = baseYearly;

    % Aggregate across years
    summary.overall.(metricName)         = aggregateMetric(methYearly);
    summary.baselineOverall.(metricName) = aggregateMetric(baseYearly);
end

%% Improvement computation
fprintf('Computing improvement over baseline...\n');
for m = 1:length(metrics)
    metricName = metrics{m};
    methVal = summary.overall.(metricName).mean;
    baseVal = summary.baselineOverall.(metricName).mean;

    direction = getMetricDirection(metricName);
    if direction == 1       % higher is better
        absImprove = methVal - baseVal;
    elseif direction == -1  % lower is better
        absImprove = baseVal - methVal;
    else                    % closer to zero is better
        absImprove = abs(baseVal) - abs(methVal);
    end

    if abs(baseVal) > 1e-10
        relImprove = absImprove / abs(baseVal) * 100;
    else
        relImprove = NaN;
    end

    summary.improvement.(metricName).absolute     = absImprove;
    summary.improvement.(metricName).relative     = relImprove;
    summary.improvement.(metricName).methodMean   = methVal;
    summary.improvement.(metricName).baselineMean = baseVal;
    summary.improvement.(metricName).direction    = direction;
end

%% Regional analysis
fprintf('Computing regional breakdown...\n');

% Concatenate raw data across years and folds for method
[methAllObs, methAllEst, methAllSk] = concatenateResults(methResults);
[baseAllObs, baseAllEst, baseAllSk] = concatenateResults(baseResults);

summary.N = sum(~isnan(methAllObs) & ~isnan(methAllEst));

summary.regional = struct();

if ~isempty(methAllSk)
    methRegions = assignRegions(methAllSk(:,1), methAllSk(:,2));
    uniqueRegions = unique(methRegions);

    % Filter to requested regions
    if ~isempty(opts.regions)
        uniqueRegions = intersect(uniqueRegions, opts.regions);
    end

    % Remove 'Other' if it has very few points
    otherIdx = strcmp(uniqueRegions, 'Other');
    if any(otherIdx)
        nOther = sum(strcmp(methRegions, 'Other'));
        if nOther < 10
            uniqueRegions(otherIdx) = [];
        end
    end

    for iR = 1:length(uniqueRegions)
        regName = uniqueRegions{iR};
        fieldName = matlab.lang.makeValidName(regName);

        % Method regional stats
        mask = strcmp(methRegions, regName);
        if sum(mask) < 2, continue; end
        regMethStats = calculateValidationStats( ...
            methAllObs(mask), methAllEst(mask));

        summary.regional.(fieldName).method = regMethStats;
        summary.regional.(fieldName).N = sum(mask);

        % Baseline regional stats (match by region in baseline data)
        if ~isempty(baseAllSk)
            baseRegions = assignRegions(baseAllSk(:,1), baseAllSk(:,2));
            baseMask = strcmp(baseRegions, regName);
            if sum(baseMask) >= 2
                regBaseStats = calculateValidationStats( ...
                    baseAllObs(baseMask), baseAllEst(baseMask));
                summary.regional.(fieldName).baseline = regBaseStats;
            else
                summary.regional.(fieldName).baseline = struct();
            end
        else
            summary.regional.(fieldName).baseline = struct();
        end

        % Regional improvement
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

                if abs(regBaseVal) > 1e-10
                    regRel = regAbs / abs(regBaseVal) * 100;
                else
                    regRel = NaN;
                end

                summary.regional.(fieldName).improvement.(metricName).absolute = regAbs;
                summary.regional.(fieldName).improvement.(metricName).relative = regRel;
            end
        end

        summary.regional.(fieldName).regionName = regName;
    end
end

%% Generate paper text
fprintf('Generating paper text...\n');
paperText = generatePaperText(summary, metrics, yearRange, opts.boxSize);

%% Print summary to console
fprintf('\n=== Results ===\n');
fprintf('%s\n\n', paperText.overallSummary);
fprintf('%s\n\n', paperText.improvementSummary);
fprintf('%s\n\n', paperText.regionalSummary);
fprintf('%s\n', paperText.regionalTable);
fprintf('%s\n', paperText.yearRange);

end

%% ========================================================================
%  LOCAL HELPER FUNCTIONS
%  ========================================================================

function [code, goScenario] = parseMethodAndGO(methodStr)
% Parse '13000313-01_go3' into code='13000313-01' and goScenario=3
    parts = regexp(methodStr, '^(.+)_go(\d+)$', 'tokens');
    if isempty(parts)
        error('Invalid method string: %s. Expected format like 13000313-01_go3', methodStr);
    end
    code = parts{1}{1};
    goScenario = str2double(parts{1}{2});
end

function [allStats, allResults, yearsFound] = loadCBVannualFiles(bmeCode, goScenario, boxSize, yearRange, cbvDir)
% Load CBV annual files for all years and folds, return stats and results
    allStats = struct();
    allResults = struct();
    yearsFound = [];

    allYears = yearRange(1):yearRange(2);
    for iY = 1:length(allYears)
        yr = allYears(iY);
        yearHasData = false;

        for iFold = 1:2
            fname = sprintf('CBV_BME%s_go%d_box%.1f_fold%d_%d.mat', ...
                bmeCode, goScenario, boxSize, iFold, yr);
            fpath = fullfile(cbvDir, fname);

            if ~exist(fpath, 'file')
                continue;
            end

            try
                data = load(fpath);
                key = sprintf('y%d_f%d', yr, iFold);

                if isfield(data, 'annualStats')
                    allStats.(key) = data.annualStats;
                end

                if isfield(data, 'annualResults')
                    allResults.(key) = data.annualResults;
                end

                yearHasData = true;
            catch ME
                warning('Failed to load %s: %s', fname, ME.message);
            end
        end

        if yearHasData
            yearsFound(end+1) = yr; %#ok<AGROW>
        end
    end

    fprintf('  Found data for %d/%d years\n', length(yearsFound), length(allYears));
end

function [allObs, allEst, allSk] = concatenateResults(resultsStruct)
% Concatenate Y_obs, Y_est, sk from all results entries
    allObs = [];
    allEst = [];
    allSk  = [];

    if isempty(fieldnames(resultsStruct))
        return;
    end

    keys = fieldnames(resultsStruct);
    for i = 1:length(keys)
        r = resultsStruct.(keys{i});
        if isfield(r, 'Y_obs') && isfield(r, 'Y_est') && isfield(r, 'sk')
            allObs = [allObs; r.Y_obs(:)]; %#ok<AGROW>
            allEst = [allEst; r.Y_est(:)]; %#ok<AGROW>
            allSk  = [allSk;  r.sk];       %#ok<AGROW>
        end
    end
end

function agg = aggregateMetric(values)
% Compute mean/std/median/min/max ignoring NaN
    valid = values(~isnan(values));
    agg.mean   = mean(valid);
    agg.std    = std(valid);
    agg.median = median(valid);
    agg.min    = min(valid);
    agg.max    = max(valid);
    agg.nValid = length(valid);
    if isempty(valid)
        agg.mean = NaN; agg.std = NaN; agg.median = NaN;
        agg.min = NaN;  agg.max = NaN; agg.nValid = 0;
    end
end

function direction = getMetricDirection(metricName)
% Return +1 if higher is better, -1 if lower is better, 0 if closer-to-zero
    higherIsBetter = {'R2', 'IOA', 'IOAmod', 'FAC2', 'PearsonR', 'SpearmanR', 'r_QA', 'r2_QA'};
    lowerIsBetter  = {'RMSE', 'MAE', 'MSE', 'NME', 'VarError'};
    closerToZero   = {'NMB', 'ME', 'MBE'};

    if ismember(metricName, higherIsBetter)
        direction = 1;
    elseif ismember(metricName, lowerIsBetter)
        direction = -1;
    elseif ismember(metricName, closerToZero)
        direction = 0;
    else
        direction = 1;  % default: higher is better
    end
end

function paperText = generatePaperText(summary, metrics, yearRange, boxSize)
% Generate formatted text strings for manuscript

    paperText = struct();
    methodName   = summary.method.name;
    baselineName = summary.baseline.name;

    %% Year range text
    paperText.yearRange = sprintf( ...
        'Validated over N=%d years (%d-%d) with %d validation points using checker-board validation (%.0f deg box size).', ...
        summary.nYears, yearRange(1), yearRange(2), summary.N, boxSize);

    %% Overall summary
    metricParts = {};
    for m = 1:length(metrics)
        name = metrics{m};
        if ~isfield(summary.overall, name), continue; end
        val = summary.overall.(name).mean;
        sd  = summary.overall.(name).std;
        metricParts{end+1} = formatMetricValue(name, val, sd); %#ok<AGROW>
    end

    paperText.overallSummary = sprintf( ...
        'The method %s achieved a mean %s over %d-%d (N=%d).', ...
        methodName, strjoin(metricParts, ' and '), ...
        yearRange(1), yearRange(2), summary.N);

    %% Improvement summary
    improvParts = {};
    for m = 1:length(metrics)
        name = metrics{m};
        if ~isfield(summary.improvement, name), continue; end
        imp = summary.improvement.(name);
        improvParts{end+1} = formatImprovementText(name, imp); %#ok<AGROW>
    end

    if ~isempty(improvParts)
        paperText.improvementSummary = sprintf( ...
            'Compared to the baseline (%s), %s.', ...
            baselineName, strjoin(improvParts, '; '));
    else
        paperText.improvementSummary = 'Baseline data not available for comparison.';
    end

    %% Regional summary and table
    paperText.regionalSummary = '';
    paperText.regionalTable = '';

    if ~isempty(fieldnames(summary.regional))
        regFields = fieldnames(summary.regional);
        primaryMetric = metrics{1};

        % Build regional table
        tableLines = {};
        tableLines{end+1} = sprintf('%-20s %8s %10s %10s %10s %12s', ...
            'Region', 'N', ...
            [primaryMetric ' (M)'], [primaryMetric ' (B)'], ...
            ['d' primaryMetric], ['d' primaryMetric ' (%)']);
        tableLines{end+1} = repmat('-', 1, 72);

        bestRegion = ''; bestDelta = -Inf;
        worstRegion = ''; worstDelta = Inf;

        for iR = 1:length(regFields)
            reg = summary.regional.(regFields{iR});
            regName = reg.regionName;

            if ~isfield(reg.improvement, primaryMetric), continue; end

            methVal  = reg.method.(primaryMetric);
            baseVal  = reg.baseline.(primaryMetric);
            absDelta = reg.improvement.(primaryMetric).absolute;
            relDelta = reg.improvement.(primaryMetric).relative;

            tableLines{end+1} = sprintf('%-20s %8d %10.3f %10.3f %+10.3f %+11.1f%%', ...
                regName, reg.N, methVal, baseVal, absDelta, relDelta); %#ok<AGROW>

            if absDelta > bestDelta
                bestDelta = absDelta; bestRegion = regName;
            end
            if absDelta < worstDelta
                worstDelta = absDelta; worstRegion = regName;
            end
        end

        paperText.regionalTable = strjoin(tableLines, '\n');

        % Prose summary
        if ~isempty(bestRegion) && ~isempty(worstRegion)
            if strcmp(bestRegion, worstRegion)
                paperText.regionalSummary = sprintf( ...
                    'Regional analysis shows %s improvement of %s %+.3f in %s.', ...
                    primaryMetric, getDeltaSymbol(primaryMetric), bestDelta, bestRegion);
            else
                paperText.regionalSummary = sprintf( ...
                    'The largest improvement was in %s (%s%s=%+.3f), while %s showed %s (%s%s=%+.3f).', ...
                    bestRegion, getDeltaSymbol(primaryMetric), primaryMetric, bestDelta, ...
                    worstRegion, conditionalStr(worstDelta > 0, 'more modest gains', 'a decrease'), ...
                    getDeltaSymbol(primaryMetric), primaryMetric, worstDelta);
            end
        end
    end
end

function str = formatMetricValue(name, val, sd)
% Format a metric value with appropriate precision and units
    if ismember(name, {'R2', 'IOA', 'IOAmod', 'PearsonR', 'SpearmanR', 'r_QA', 'r2_QA'})
        str = sprintf('%s of %.3f (+/-%.3f)', name, val, sd);
    elseif ismember(name, {'NMB', 'NME', 'FAC2'})
        str = sprintf('%s of %.1f (+/-%.1f)%%', name, val, sd);
    else  % RMSE, MAE, MSE, etc.
        str = sprintf('%s of %.1f (+/-%.1f) ppb', name, val, sd);
    end
end

function str = formatImprovementText(name, imp)
% Format improvement text with direction-appropriate language
    direction = imp.direction;
    absImp = imp.absolute;
    relImp = imp.relative;

    if direction == 1  % higher is better
        if absImp >= 0
            verb = 'improved';
        else
            verb = 'decreased';
        end
        str = sprintf('%s %s by %+.3f (%+.1f%%)', name, verb, ...
            imp.methodMean - imp.baselineMean, relImp);
    elseif direction == -1  % lower is better
        rawDiff = imp.methodMean - imp.baselineMean;
        if rawDiff <= 0
            verb = 'decreased';
        else
            verb = 'increased';
        end
        str = sprintf('%s %s by %.1f ppb (%+.1f%%)', name, verb, abs(rawDiff), ...
            -rawDiff / abs(imp.baselineMean) * 100);
    else  % closer to zero
        rawDiff = abs(imp.methodMean) - abs(imp.baselineMean);
        if rawDiff <= 0
            verb = 'reduced';
        else
            verb = 'increased';
        end
        str = sprintf('|%s| %s from %.1f to %.1f', name, verb, ...
            abs(imp.baselineMean), abs(imp.methodMean));
    end
end

function sym = getDeltaSymbol(~)
    sym = 'd';
end

function str = conditionalStr(cond, trueStr, falseStr)
    if cond
        str = trueStr;
    else
        str = falseStr;
    end
end
