% example_plotOSDMA8 - Driver for OSDMA8 validation visualization & summary
%
% OSDMA8 counterpart to example_plotCBV. It:
%   1. Ensures the per-case OSDMA8 files exist (runs runOSDMA8validation per
%      method by aggregating the monthly CBV files into OSDMA8 - READ-ONLY on
%      the CBV pipeline; writes only to 7validation/OSDMA8).
%   2. Generates Phase-4 time-series plots across configurations & years
%      (plotOSDMA8results_Phase4), including a grouped-years summary table.
%   3. Prints/collects paper-ready summaries (summarizeOSDMA8forPaper).
%
% Edit the CONFIG block, then Run.

%% ===================== CONFIG =====================
osdma8Dir = './7validation/OSDMA8';

% Methods (mirror example_plotCBV). Methods without an explicit _goN get goScenario.
% for 1991-2004
% all_methods = {'10000133_go0', ...   % baseline: obs only, flat GO
%                '10000133_go3', ...   % obs only, fine GO
%                '13000313-02'};       % obs + M3fusion
clear;
% For 2005-2022,
all_methods = {'10000133_go0' , ...
'10000133_go3', ...
'13000313-02', ...
'13000313-04', ...   
'13000313-06'}; % 5 deg.; for 2005 - 2022

% all_methods = {'10000133_go0', '10000133_go3', '13000313-02'};

goScenario = 3;                       % default GO for methods without _goN

allYears = 2005:2022;                 % year(s) to analyze (e.g. 2016:2018)
boxSize  = 20.0;                       % checker-board box size (deg)
metrics  = {'R2', 'RMSE'};            % {'R2','RMSE','MAE','NMB'}
picture_dpi = 600;

% OSDMA8-specific options
refSource    = 'toar_osdma8';         % truth = official TOAR OSDMA8 CSVs
testSource   = 'cbv_est';             % estimated OSDMA8 source (BME)
osdma8RefDir = fullfile('1data', 'TOAR-OSDMA8'); % official OSDMA8 CSV folder
crossCheck   = true;                  % also report official vs obs-recompute (QA)
completeness = 'partial';              % 'strict' | 'partial' | 'any'
regenerate   = false;                 % if true, recompute OSDMA8 even if files exist

% Soft-data leakage control (must match the CBV run being scored).
leakControl  = 0;                     % 0=legacy CBV files, 1=leakage-controlled (_lc)
leakRadius   = 2.0;                   % scalar deg or per-source struct (must match run)
leakTag = getLeakTag(struct('leakControl', leakControl, 'leakRadius', leakRadius));

baselineMethod = '10000133_go0';      % for summarizeOSDMA8forPaper
%% ==================================================

% Normalize method strings: append _go{goScenario} where missing.
for i = 1:length(all_methods)
    if ~contains(all_methods{i}, 'go')
        all_methods{i} = sprintf('%s_go%d', all_methods{i}, goScenario);
    end
end

% Human-readable config names from method codes + GO.
configNames = cell(1, length(all_methods));
methodCodes = cell(1, length(all_methods));
goScenarios = zeros(1, length(all_methods));
for i = 1:length(all_methods)
    tok = regexp(all_methods{i}, '^(.+)_go(\d+)$', 'tokens');
    methodCodes{i}  = tok{1}{1};
    goScenarios(i)  = str2double(tok{1}{2});
    configNames{i}  = getBMEmethodName(methodCodes{i}, goScenarios(i));
end

%% Step 1: ensure OSDMA8 per-case files exist
fprintf('\n=== Step 1: Ensure OSDMA8 case files exist ===\n');
for i = 1:length(all_methods)
    code = methodCodes{i}; go = goScenarios(i);

    % Are case files already present for all requested years (either fold)?
    needRun = regenerate;
    if ~needRun
        for yr = allYears
            f1 = fullfile(osdma8Dir, sprintf('OSDMA8_BME%s_go%d_box%.1f_fold1_%d%s.mat', code, go, boxSize, yr, leakTag));
            f2 = fullfile(osdma8Dir, sprintf('OSDMA8_BME%s_go%d_box%.1f_fold2_%d%s.mat', code, go, boxSize, yr, leakTag));
            if ~exist(f1, 'file') && ~exist(f2, 'file')
                needRun = true; break;
            end
        end
    end

    if needRun
        fprintf('  Computing OSDMA8 for %s (go%d)...\n', code, go);
        cfg = struct('BMEmethod', code, 'goScenario', go, 'boxSizes', boxSize, ...
            'valYears', allYears, 'folds', [1 2], 'refSource', refSource, ...
            'testSource', testSource, 'completeness', completeness, ...
            'osdma8RefDir', osdma8RefDir, 'crossCheck', crossCheck, ...
            'leakControl', leakControl, 'leakRadius', leakRadius, ...
            'outDir', osdma8Dir, 'makePlots', false);
        try
            runOSDMA8validation(cfg);
        catch ME
            warning('OSDMA8 computation failed for %s: %s', code, ME.message);
        end
    else
        fprintf('  OSDMA8 files already present for %s (go%d) - skipping.\n', code, go);
    end
end

%% Step 2: Phase-4 time-series plots across configs & years
fprintf('\n=== Step 2: Phase 4 OSDMA8 time-series ===\n');
configPatterns = cell(1, length(all_methods));
for i = 1:length(all_methods)
    configPatterns{i} = sprintf('OSDMA8_BME%s_go%d_box%.1f*%s.mat', methodCodes{i}, goScenarios(i), boxSize, leakTag);
end

saveDir = fullfile(osdma8Dir, 'figs', sprintf('phase4_box%g%s_%d_%d', boxSize, leakTag, allYears(1), allYears(end)));
figPaths = plotOSDMA8results_Phase4( ...
    repmat({osdma8Dir}, 1, length(configPatterns)), configNames, ...
    'filePattern', configPatterns, ...
    'methodCodes', methodCodes, ...
    'years', allYears, ...
    'boxSize', boxSize, ...
    'metrics', metrics, ...
    'saveDir', saveDir, ...
    'dpi', picture_dpi, ...
    'leakTag', leakTag, ...
    'visible', 'on', ...
    'saveTables', true);
fprintf('Phase 4 figures -> %s\n', saveDir);

%% Step 3: Paper-ready summaries (each method vs baseline)
fprintf('\n=== Step 3: Paper summaries ===\n');
summaries = struct();
yearRange = [allYears(1) allYears(end)];
for i = 1:length(all_methods)
    if strcmp(all_methods{i}, baselineMethod), continue; end
    fld = matlab.lang.makeValidName(all_methods{i});
    try
        [summaries.(fld).summary, summaries.(fld).text] = summarizeOSDMA8forPaper( ...
            all_methods{i}, yearRange, baselineMethod, metrics, ...
            'boxSize', boxSize, 'osdma8Dir', osdma8Dir, 'leakTag', leakTag);
    catch ME
        warning('Summary failed for %s: %s', all_methods{i}, ME.message);
    end
end

fprintf('\n=== example_plotOSDMA8 complete ===\n');
