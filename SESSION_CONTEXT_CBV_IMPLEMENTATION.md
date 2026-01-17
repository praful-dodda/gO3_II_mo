# Session Context: TOAR-II BME Checker-Board Validation Implementation

**Date**: 2026-01-17
**Branch**: `claude/review-codebase-01WkRHYz215aooREUrKMP4rh`
**Last Commit**: 169da14 - "Convert CBV to monthly processing with STUG format"

---

## Project Overview

**TOAR-II BME Ozone Data Fusion Framework**
- Statistical data fusion for global tropospheric ozone using Bayesian Maximum Entropy (BME)
- Combines in-situ observations with Chemical Transport Model (CTM) outputs
- Produces gap-free gridded ozone fields at 0.1° resolution
- Temporal coverage: 2005-2019
- Validation methods: LOOCV, Checker-Board Validation (CBV), temporal holdout

---

## Recent Session Work Summary

### Major Implementation: Checker-Board Validation (CBV) Monthly Processing

**User Request**: Convert checker-board cross-validation to monthly checker-board validation with:
1. Use STUG format for estimations (following `estTOARsBME.m` pattern)
2. Process monthly with ±1 year temporal windows
3. Filter validation points to only s/t locations with observations
4. Save monthly results and aggregate annually
5. Support multiple method comparisons in plotting
6. Add checkerboard pattern visualization to `getCheckerBoard`

**Status**: ✅ COMPLETED and COMMITTED

---

## Files Created/Modified in This Session

### New Files Created

#### 1. `evaluateFold_CBV_monthly.m` (7,075 bytes)
**Purpose**: Core monthly CBV evaluation function

**Key Features**:
- Uses ±1 year temporal window around validation year
- Filters to only s/t locations with observational data
- Uses STUG format for estimation
- Adds global offset within function
- Returns monthly results structure

**Function Signature**:
```matlab
function monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, BMEparam, ...
                                                 trainMask, valMask, valYear, valMonth)
```

**Key Implementation Details**:
```matlab
% Temporal window (±1 year)
temporalWindow = 1.0;
windowStart = valYear - temporalWindow;
windowEnd = valYear + temporalWindow + 1/12;

% Filter training data
trainTimeIdx = (KS.harddata.t >= windowStart) & (KS.harddata.t < windowEnd);
trainStationIdx = ismember(KS.harddata.stnid, trainStations);
trainIdx = trainTimeIdx & trainStationIdx;

% Filter to only validation points WITH observations
hasObs = ~isnan(Y_obs_all);
pk = pk_all(hasObs, :);

% Use STUG format
soft_data_stug = reformat_stg_to_stug(KS_train.softdata);
[XkBMEm, XkBMEv] = krigingME_stug(pk, ...);

% Add global offset
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, unique(tk));
YkBMEm = XkBMEm + gok;
```

**Returns**:
```matlab
monthResults.Y_obs      % Observed values at validation points
monthResults.Y_est      % Estimated values (with global offset)
monthResults.Y_estNoGo  % Estimates without global offset
monthResults.sk         % Spatial coordinates
monthResults.tk         % Time coordinates
monthResults.XkBMEv     % Estimation variances
monthResults.gok        % Global offset values
monthResults.nValid     % Number of valid pairs
```

---

#### 2. `runCBV_toar.m` (10,001 bytes)
**Purpose**: Orchestrates monthly CBV processing across box sizes, folds, years, and months

**Key Features**:
- Forces STUG format: `BMEparam.dataFormat = 'stug'`
- Four nested loops: box sizes → folds → years → months
- Saves individual monthly results to disk
- Aggregates annual statistics
- Creates comprehensive results table

**Main Loop Structure**:
```matlab
% Force STUG format
BMEparam.dataFormat = 'stug';

% Prepare knowledge base once
[KG, KS, ~] = getTOARknowledgeBase(obs, go, cov, valParam.softData, ...
    valParam.BMEmethod, BMEparam.dataFormat);

% Main processing loop
for iBox = 1:nBoxSizes
    boxSize = valParam.boxSizes(iBox);
    fprintf('\n=== Box Size: %.1f° ===\n', boxSize);

    for iFold = 1:nFolds
        [trainMask, valMask] = getCheckerBoard(obs.sMS, boxSize, iFold);

        for iYear = 1:nYears
            valYear = valParam.valYears(iYear);

            % Initialize annual accumulators
            Y_obs_all = [];
            Y_est_all = [];
            XkBMEv_all = [];

            for iMonth = 1:length(valParam.valMonths)
                valMonth = valParam.valMonths(iMonth);

                % Evaluate monthly
                monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, ...
                    BMEparam, trainMask, valMask, valYear, valMonth);

                % Save monthly results
                save(resultPath, 'monthResults', 'valParam', '-v7.3');

                % Accumulate for annual stats
                Y_obs_all = [Y_obs_all; monthResults.Y_obs];
                Y_est_all = [Y_est_all; monthResults.Y_est];
                XkBMEv_all = [XkBMEv_all; monthResults.XkBMEv];
            end

            % Compute annual statistics
            stats = computeMetrics(Y_est_all, Y_obs_all, sqrt(XkBMEv_all));
        end
    end
end
```

**Output Files**:
- Monthly results: `7validation/CBV/results/monthly/CBV_box{size}_fold{fold}_{year}_{month:02d}.mat`
- Annual results: `7validation/CBV/results/CBV_box{size}_fold{fold}_{year}.mat`
- Summary stats: `7validation/CBV/results/cbv_all_results.mat`

---

#### 3. `plotCBVresults.m` (8,834 bytes)
**Purpose**: Enhanced visualization supporting multiple method comparisons

**Key Features**:
- Accepts `varargin` for multiple cbvStats tables
- Creates comparison plots across methods and box sizes
- Shows R², RMSE, MAE, ME with different colors per method

**Function Signature**:
```matlab
function plotCBVresults(cbvResults, cbvStats, valParam, varargin)
% USAGE:
%   plotCBVresults(cbvResults, cbvStats, valParam)              % Single method
%   plotCBVresults(results1, stats1, valParam, stats2, stats3)  % Multiple methods
```

**Multiple Method Support**:
```matlab
if ~isempty(varargin)
    multipleMethod = true;
    nMethods = 1 + length(varargin);
    allStats = cell(1, nMethods);
    allStats{1} = cbvStats;
    for i = 1:length(varargin)
        allStats{i+1} = varargin{i};
    end

    % Create comparison plots
    metrics = {'r2', 'RMSE', 'MAE', 'ME'};
    for each metric:
        for each method:
            Average across folds/years for each box size
            Plot with different color per method
```

**Generated Plots**:
1. Performance vs Box Size (comparison across methods)
2. Box plot distributions per box size
3. Year-wise performance comparison
4. Scatter plots (Obs vs Est) per box size

---

### Modified Files

#### 4. `getCheckerBoard.m`
**Changes**: Added optional checkerboard pattern visualization

**New Parameter**:
```matlab
function [trainMask, valMask] = getCheckerBoard(sMS, boxSize, fold, plotFlag)
% plotFlag - (optional, default: 0) If 1, plots checkerboard pattern
```

**Visualization Features** (when `plotFlag=1`):
- Training boxes: light blue (`[0.8 0.9 1.0]`)
- Validation boxes: light orange (`[1.0 0.9 0.8]`)
- Station locations overlaid (blue = train, red = validation)
- Grid boundaries shown
- Summary statistics displayed

**Implementation**:
```matlab
if nargin > 3 && plotFlag == 1
    figure;

    % Draw checkerboard boxes
    for iLon = 1:length(lonGridLines)-1
        for iLat = 1:length(latGridLines)-1
            boxIsBlack = mod(iLon + iLat, 2) == 0;

            if (fold == 1 && boxIsBlack) || (fold == 2 && ~boxIsBlack)
                faceColor = [0.8 0.9 1.0];  % Training (light blue)
            else
                faceColor = [1.0 0.9 0.8];  % Validation (light orange)
            end

            rectangle('Position', [lonGridLines(iLon), latGridLines(iLat), ...
                boxSizeLon, boxSizeLat], 'FaceColor', faceColor, ...);
        end
    end

    % Plot stations
    scatter(lon(trainMask), lat(trainMask), 30, 'b', 'filled', ...);
    scatter(lon(valMask), lat(valMask), 30, 'r', 'filled', ...);

    % Add summary text
    text(0.02, 0.98, sprintf('Training: %d (%.1f%%)\nValidation: %d (%.1f%%)', ...
        sum(trainMask), 100*sum(trainMask)/nPoints, ...
        sum(valMask), 100*sum(valMask)/nPoints), ...);
end
```

---

#### 5. `computeMetrics.m`
**Changes**: Fixed merge conflict, using simpler direct implementation

**Before**: Had merge conflict with duplicate content (`=======` markers)

**After**: Clean implementation
```matlab
function [stats] = computeMetrics(zHat, z, sigma_i)
% computeMetrics - Computes a standard set of validation statistics

    if nargin < 3 || isempty(sigma_i)
        sigma_i = nan(size(z));
    end

    e = zHat(:) - z(:);

    stats.MSE  = mean(e.^2);
    stats.RMSE = sqrt(stats.MSE);
    stats.MAE  = mean(abs(e));
    stats.ME   = mean(e);
    stats.VE   = var(e);
    stats.SE   = std(e);
    stats.r2   = corr(z, zHat)^2;

    % Quality-adjusted metrics
    obs_variance = var(z);
    if obs_variance > 0
        stats.r_QA = sqrt(max(0, 1 - mean(e.^2) / obs_variance));
        stats.r2_QA = stats.r_QA^2;
    else
        stats.r_QA = NaN;
        stats.r2_QA = NaN;
    end

    % Standardized error metrics (if sigma_i provided)
    validSigma = ~isnan(sigma_i) & sigma_i > 0;
    if any(validSigma)
        es = e(validSigma) ./ sigma_i(validSigma);
        stats.MS = mean(es);
        stats.RMSS = sqrt(mean(es.^2));
        stats.MR = mean(sigma_i(validSigma));
    else
        stats.MS = NaN;
        stats.RMSS = NaN;
        stats.MR = NaN;
    end
end
```

---

## Key Technical Concepts

### BME (Bayesian Maximum Entropy)
- Statistical data fusion method for ozone concentration estimation
- Combines hard data (observations) with soft data (CTM model outputs)
- Accounts for measurement errors in both data types

### Data Formats

**STG (Space-Time Grid)**:
```matlab
harddata.p  = [s1 s2 t]  % Coordinates
harddata.v  = [z]         % Values
harddata.e  = [epsilon]   % Uncertainties

softdata.p  = [s1 s2 t]
softdata.limi = [lower upper]  % Soft limits
softdata.probdens = @(z) ...    % Probability density
```

**STUG (Space-Time Unstructured Grid)** - Optimized for large grids:
```matlab
soft_data_stug = reformat_stg_to_stug(softdata_stg);
% More efficient for krigingME_stug estimation
```

### Global Offset
- Spatiotemporal mean trend removed before BME estimation
- Added back after estimation for final values
```matlab
% Remove global offset from observations
X = Z - go.val;

% Perform BME estimation on X
[XkBMEm, XkBMEv] = krigingME_stug(...);

% Add global offset back
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk);
YkBMEm = XkBMEm + gok;
```

### Covariance Models
Nested separable space-time models:
```matlab
% Model 1: Exponential
covmodel{1} = 'exponentialC/exponentialC';
covparam{1} = [sill1, ar1, at1];

% Model 2: Hole-effect cosine (for seasonality)
covmodel{2} = 'holesinexpC/holesinexpC';
covparam{2} = [sill2, ar2, at2, w];

% Nugget
covmodel{end} = 'nuggetC/nuggetC';
covparam{end} = [nugget, 0, 0];
```

### Checker-Board Validation (CBV)
- Spatial cross-validation using alternating grid squares
- Two folds: black squares vs white squares
- Box sizes tested: 2.0°, 2.5°, 3.0°, 3.5°, 4.0°, 4.5°, 5.0°

**Pattern Generation**:
```matlab
% Divide domain into grid boxes
lonGridLines = min(lon):boxSize:max(lon);
latGridLines = min(lat):boxSize:max(lat);

% Assign stations to boxes
for each station:
    boxLonIdx = find(lon(i) >= lonGridLines & lon(i) < lonGridLines+boxSize);
    boxLatIdx = find(lat(i) >= latGridLines & lat(i) < latGridLines+boxSize);

    % Checkerboard pattern
    boxIsBlack = mod(boxLonIdx + boxLatIdx, 2) == 0;

    if fold == 1:
        trainMask(i) = boxIsBlack;
        valMask(i) = ~boxIsBlack;
    else:
        trainMask(i) = ~boxIsBlack;
        valMask(i) = boxIsBlack;
```

### Temporal Windows
- For 2017 validation: **±1 year** of data
- Prevents using distant past/future data
- Implemented in `evaluateFold_CBV_monthly.m`:
```matlab
temporalWindow = 1.0;  % years
windowStart = valYear - temporalWindow;
windowEnd = valYear + temporalWindow + 1/12;
```

---

## Previous Work (Earlier in Session)

### 1. BME Coding System (COMPLETED)
Created helper functions for extended BME method codes using hexadecimal bitmask:

**Files Created**:
- `decodeCTMmodels.m` - Decode hex bitmask to model names
- `parseBMEcode.m` - Parse extended BME codes
- `getCTMneighborCount.m` - Convert nsmax code to neighbor count
- `getHardNeighborCount.m` - Convert nhmax code to neighbor count
- `describeBMEcode.m` - Human-readable code description
- `compareBMEcodes.m` - Side-by-side comparison
- `test_BME_coding_system.m` - Comprehensive tests

**Encoding System**:
```
[4 digits][1 hex][1 char][1 char][1 char]
  BCVA     CTMs    nsmax   nhmax   order

CTM bitmask (6 models):
0x01 = MERRA2-GMI
0x02 = M3fusion
0x04 = OMI-MLS
0x08 = IASI-GOME2
0x10 = UKML
0x20 = NJML

Example: '0100-3F-M-L-1'
- Method: 0100 (kriging with hard+soft)
- CTMs: 0x3F (all 6 models)
- nsmax: M (medium, 250)
- nhmax: L (large, 75)
- order: 1 (linear trend)
```

### 2. Debug `neighbours_stg.m` Crash (COMPLETED)
**Problem**: Crash with restrictive dmax values at line 169

**Root Cause**: `max(find(...))` returns empty array when no neighbors satisfy constraint

**Three Crash Scenarios**:
1. No spatial neighbors (dmax(1) too small)
2. Space-time constraint too restrictive (dmax(3) too large)
3. No temporal neighbors (dmax(2) too small)

**Fix Applied** (`neighbours_stg.m` lines 170-199):
```matlab
% Check if we have spatial neighbors
if isempty(dMSsubReduced) || nMSsubReduced == 0
    warning('No spatial neighbors within dmax(1)=%.2f', dmax(1));
    idx = [];
    d = [];
    return;
end

nMEsubReduced=max(find(dmax(3)*dMEsub<=dMSsubReduced(end)));

% Check if temporal constraint was satisfied
if isempty(nMEsubReduced) || nMEsubReduced == 0
    if nMEsub > 0
        warning('Space-time constraint too restrictive, using closest time');
        nMEsubReduced = 1;
    else
        warning('No temporal neighbors within dmax(2)=%.2f', dmax(2));
        idx = [];
        d = [];
        return;
    end
end
```

### 3. Multi-Dataset Kriging (COMPLETED)
Created `krigingME_stug_multi.m` for multiple soft datasets

**Features**:
- Backward compatible: single structure or cell array
- Intelligent neighbor selection across all datasets
- Combined soft data handling

**Usage**:
```matlab
% Single dataset (backward compatible)
[zk, vk] = krigingME_stug_multi(pk, ph, covmodel, covparam, nhmax, nsmax, ...
    dmax, order, options, harddata, soft_data_struct);

% Multiple datasets
soft_data_cell = {soft1, soft2, soft3};
[zk, vk] = krigingME_stug_multi(pk, ph, covmodel, covparam, nhmax, nsmax, ...
    dmax, order, options, harddata, soft_data_cell);
```

---

## Important File Paths and Patterns

### Directory Structure
```
/home/user/gO3_II_mo/
├── 0setupBME/              # BME setup scripts
├── 1data/                  # Input data
│   ├── observations/       # In-situ TOAR data
│   └── ctm/               # CTM model outputs
├── 2preprocessing/         # Data processing scripts
├── 3covariance/           # Covariance model fitting
├── 4knowledgebase/        # BME knowledge base creation
├── 5globaloffset/         # Global offset computation
├── 6estimation/           # BME estimation scripts
├── 7validation/           # Validation methods
│   ├── LOOCV/            # Leave-one-out cross-validation
│   │   ├── results/
│   │   └── figures/
│   └── CBV/              # Checker-board validation
│       ├── results/
│       │   └── monthly/  # Monthly CBV results
│       └── figures/
└── utils/                 # Utility functions
```

### Key Data Files
```matlab
% Observations
obs = load('1data/observations/TOAR_ozone_2005_2019.mat');
% Fields: sMS (stations), tME (times), Z (ozone), Zstd (uncertainty)

% Global offset
go = load('5globaloffset/global_offset.mat');
% Fields: sMS, tME, ms (spatial mean), mt (temporal mean)

% Covariance
cov = load('3covariance/covariance_model.mat');
% Fields: covmodel, covparam, order

% CTM data
KS.softdata = load('1data/ctm/processed_ctm_data.mat');
```

### Naming Conventions
```matlab
% Variables
sMS   % Spatial coordinates (stations) [nStations × 2]
tME   % Temporal coordinates (decimal years) [nTimes × 1]
Z     % Ozone values (ppbv) [nObs × 1]
pk    % Estimation points [nEst × 3] = [lon lat time]

% Functions
getTOAR*           % Data loading/processing
prepare*           % Setup functions
estimate*          % BME estimation
validate*          % Validation methods
compute*           % Metric computation
plot*              % Visualization
reformat_*_to_*    % Data format conversion

% File naming
*_stg.m    % Space-Time Grid format
*_stug.m   % Space-Time Unstructured Grid format
*_monthly.m % Monthly processing version
```

---

## Git Information

### Current Branch
```bash
Branch: claude/review-codebase-01WkRHYz215aooREUrKMP4rh
Remote: origin/claude/review-codebase-01WkRHYz215aooREUrKMP4rh
Status: Up to date with remote
```

### Recent Commits
```
169da14 Convert CBV to monthly processing with STUG format
dfebbe0 Merge branch 'main' into claude/review-codebase-01WkRHYz215aooREUrKMP4rh
607d99b Remove code to overcome the stashing error
e5ec636 Add Checker-Board Cross-Validation (CBCV) system for TOAR BME
e4d64fd Add computeMetrics and getCheckerboard utilities
```

### Important Git Notes
- **ALWAYS** develop on branch starting with `claude/` and ending with session ID
- **ALWAYS** use `git push -u origin <branch-name>`
- Branch naming pattern: `claude/review-codebase-01WkRHYz215aooREUrKMP4rh`
- Push will fail with 403 if branch doesn't match pattern
- Retry network failures up to 4 times with exponential backoff (2s, 4s, 8s, 16s)

---

## Key Implementation Patterns

### Monthly Processing Loop
```matlab
for iYear = 1:nYears
    valYear = valParam.valYears(iYear);

    % Initialize annual accumulators
    Y_obs_all = [];
    Y_est_all = [];

    for iMonth = 1:12
        % Define target month
        monthStart = valYear + (iMonth - 1) / 12;
        monthEnd = valYear + iMonth / 12;

        % Filter to target month
        targetMonthIdx = (tME >= monthStart) & (tME < monthEnd);

        % Do monthly estimation
        [estimates] = estimate_monthly(...);

        % Accumulate
        Y_obs_all = [Y_obs_all; obs_month];
        Y_est_all = [Y_est_all; est_month];
    end

    % Compute annual statistics
    stats = computeMetrics(Y_est_all, Y_obs_all);
end
```

### BME Estimation with STUG
```matlab
% Force STUG format
BMEparam.dataFormat = 'stug';

% Prepare knowledge base
[KG, KS, ~] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod, 'stug');

% Convert soft data to STUG format
soft_data_stug = reformat_stg_to_stug(KS.softdata);

% Perform estimation
[XkBMEm, XkBMEv] = krigingME_stug(pk, ...
    KS.harddata.p, KS.harddata.v, KS.harddata.e, ...
    KG.covmodel, KG.covparam, ...
    BMEparam.nhmax, BMEparam.nsmax, BMEparam.dmax, ...
    KG.order, 0, KS.harddata, soft_data_stug);

% Add global offset
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, tk);
YkBMEm = XkBMEm + gok;
```

### Filtering to Observed Locations Only
```matlab
% Get all potential validation points
pk_all = [repmat(sk_val, length(tk_val), 1), repelem(tk_val, length(sk_val))];

% Get observations at those points
Y_obs_all = interp_observations(obs, pk_all);

% Filter to only points WITH observations
hasObs = ~isnan(Y_obs_all);
pk = pk_all(hasObs, :);
Y_obs = Y_obs_all(hasObs);

% Perform estimation only at these filtered points
[Y_est, variances] = krigingME_stug(pk, ...);
```

---

## Parameter Settings

### BME Parameters (from runCBV_toar.m)
```matlab
BMEparam.nhmax = 75;              % Max hard data neighbors
BMEparam.nsmax = 250;             % Max soft data neighbors
BMEparam.dmax = [1000 1 Inf];    % [space(km) time(years) space-time]
BMEparam.order = 1;               % Trend order (0=mean, 1=linear)
BMEparam.dataFormat = 'stug';    % FORCED for CBV
```

### Validation Parameters
```matlab
valParam.valYears = 2017;                           % Validation year
valParam.valMonths = 1:12;                          % All months
valParam.boxSizes = [2.0 2.5 3.0 3.5 4.0 4.5 5.0]; % Degrees
valParam.nFolds = 2;                                % Checkerboard folds
valParam.softData = 'MERRA2-GMI';                   % CTM model
valParam.BMEmethod = '0100-01-M-L-1';               % BME code
```

---

## Testing and Verification

### Test CBV Implementation
```matlab
% 1. Generate checkerboard pattern with visualization
[trainMask, valMask] = getCheckerBoard(obs.sMS, 3.0, 1, 1);
% Should show blue (training) and orange (validation) boxes

% 2. Run CBV for one configuration
valParam.valYears = 2017;
valParam.valMonths = 1:3;  % Test with Q1 only
valParam.boxSizes = 3.0;
valParam.nFolds = 1;
[cbvResults, cbvStats] = runCBV_toar(obs, go, cov, valParam);

% 3. Check monthly results exist
ls 7validation/CBV/results/monthly/CBV_box3.0_fold1_2017_*.mat

% 4. Plot results
plotCBVresults(cbvResults, cbvStats, valParam);

% 5. Compare multiple methods (if available)
% stats2 = load('other_method_stats.mat');
% plotCBVresults(cbvResults, cbvStats, valParam, stats2.cbvStats);
```

### Expected Outputs
```matlab
% cbvStats table columns:
- BoxSize, Fold, Year
- N (number of valid pairs)
- MeanObs, MeanEst
- r2, RMSE, MAE, ME
- r2_QA, MS, RMSS

% Typical values for good performance:
- r2 > 0.7
- RMSE < 10 ppbv
- MAE < 7 ppbv
- |ME| < 2 ppbv
```

---

## Common Issues and Solutions

### Issue 1: "Array indices must be positive integers"
**Location**: `neighbours_stg.m:169`
**Cause**: Restrictive dmax values, no neighbors found
**Solution**: Already fixed with safety checks (see section 2 above)

### Issue 2: Out of Memory
**Cause**: Processing too many estimation points at once
**Solution**: Monthly processing implemented - processes one month at a time

### Issue 3: Merge Conflicts
**Location**: `computeMetrics.m`
**Cause**: Concurrent modifications
**Solution**: Already resolved - using direct implementation

### Issue 4: STUG Format Not Used
**Check**: Look for `BMEparam.dataFormat = 'stug'` in main script
**Solution**: Forced in `runCBV_toar.m` line 71

### Issue 5: Validation Points Without Observations
**Cause**: Grid points may not have measurements
**Solution**: Filter before estimation in `evaluateFold_CBV_monthly.m`:
```matlab
hasObs = ~isnan(Y_obs_all);
pk = pk_all(hasObs, :);
```

---

## Related Functions Reference

### Core BME Functions
```matlab
krigingME_stg(pk, ph, ...)          % STG format kriging
krigingME_stug(pk, ph, ...)         % STUG format kriging (faster)
krigingME_stug_multi(pk, ph, ...)   % Multi-dataset version
neighbours_stg(pk, ph, ...)         % Find neighbors in STG
BMEprobaMom(...)                    % BME probability moment estimation
```

### Data Processing
```matlab
getTOARknowledgeBase(...)           % Prepare BME knowledge base
getTOARobservations(...)            % Load observations
reformat_stg_to_stug(...)          % Convert STG → STUG
stmeaninterp(...)                   % Interpolate global offset
```

### Validation
```matlab
validateTOAR_LOOCV(...)            % Leave-one-out cross-validation
validateTOAR_monthly(...)          % Monthly LOOCV
runCBV_toar(...)                   % Checker-board validation (NEW)
evaluateFold_CBV_monthly(...)      % Monthly CBV evaluation (NEW)
```

### Utilities
```matlab
computeMetrics(...)                 % Compute validation metrics
getCheckerBoard(...)               % Generate CB pattern + plot
plotCBVresults(...)                % Plot CBV results (NEW)
describeBMEcode(...)               % Decode BME method code
```

---

## Next Steps / Pending Tasks

### Immediate (If Needed)
1. Test CBV implementation with small dataset
2. Verify monthly results are saved correctly
3. Check memory usage during full run

### Future Enhancements (Not Requested)
1. Parallel processing for months (parfor loop)
2. Adaptive box sizes based on station density
3. Uncertainty-weighted metrics
4. Spatial maps of validation residuals
5. Temporal evolution plots

---

## Quick Reference Commands

### Run CBV
```matlab
% Load data
obs = load('1data/observations/TOAR_ozone_2005_2019.mat');
go = load('5globaloffset/global_offset.mat');
cov = load('3covariance/covariance_model.mat');

% Set parameters
valParam.valYears = 2017;
valParam.valMonths = 1:12;
valParam.boxSizes = [2.0 2.5 3.0 3.5 4.0 4.5 5.0];
valParam.nFolds = 2;
valParam.softData = 'MERRA2-GMI';
valParam.BMEmethod = '0100-01-M-L-1';

% Run CBV
[cbvResults, cbvStats] = runCBV_toar(obs, go, cov, valParam);

% Plot results
plotCBVresults(cbvResults, cbvStats, valParam);
```

### Visualize Checkerboard
```matlab
[trainMask, valMask] = getCheckerBoard(obs.sMS, 3.0, 1, 1);
```

### Load Monthly Results
```matlab
monthFile = '7validation/CBV/results/monthly/CBV_box3.0_fold1_2017_01.mat';
load(monthFile);  % Loads: monthResults, valParam
```

### Compare Methods
```matlab
% Load different methods
stats1 = cbvStats;  % From runCBV_toar
stats2 = load('other_method_stats.mat').cbvStats;
stats3 = load('third_method_stats.mat').cbvStats;

% Plot comparison
plotCBVresults(cbvResults, stats1, valParam, stats2, stats3);
```

---

## Important Notes for Next Session

1. **All CBV code is COMPLETE and COMMITTED** to branch `claude/review-codebase-01WkRHYz215aooREUrKMP4rh`

2. **User's specific requirements ALL IMPLEMENTED**:
   - ✅ STUG format for estimations
   - ✅ Monthly processing with ±1 year temporal windows
   - ✅ Filter to only s/t locations with observations
   - ✅ Save monthly results, aggregate annually
   - ✅ Multiple method comparison plots
   - ✅ Checkerboard pattern visualization

3. **Files created**: `evaluateFold_CBV_monthly.m`, `runCBV_toar.m`, `plotCBVresults.m`

4. **Files modified**: `computeMetrics.m` (merge conflict fixed), `getCheckerBoard.m` (plotting added)

5. **Testing**: Not yet run with real data - implementation is complete but untested

6. **No pending tasks** - all requested features implemented

---

## Session Metadata

**Agent**: Claude Code (Sonnet 4.5)
**Session Start**: 2026-01-17
**Context Budget**: 200,000 tokens
**Last Update**: After commit 169da14
**Files in Repo**: ~150 MATLAB files + data
**Primary Language**: MATLAB
**Working Directory**: `/home/user/gO3_II_mo/`

---

## Contact/Documentation

- BME Toolbox: http://faculty.sites.uci.edu/tbmeehan/
- TOAR Database: https://toar-data.org/
- Project PI: User (praful-dodda)

---

*END OF SESSION CONTEXT*
