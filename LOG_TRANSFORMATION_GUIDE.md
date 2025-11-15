# Log-Transformation Implementation Guide

## Overview

This guide explains the complete log-transformation workflow for TOAR ozone BME analysis. The implementation allows modeling in log space while ensuring all final outputs (plots, validation results, saved estimates) are in the original concentration space.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Workflow Overview](#workflow-overview)
3. [Functions Reference](#functions-reference)
4. [File Naming Convention](#file-naming-convention)
5. [Plot Title Convention](#plot-title-convention)
6. [Modified Files](#modified-files)
7. [Data Flow](#data-flow)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Enabling Log-Transformation

In `analysisTOAR.m`, set:

```matlab
analyzeParam.logTransf = 1;  % 1=yes (log transform), 0=no (raw concentrations)
```

### What Happens

1. **Data Loading**: Log transformation applied (`obs.Z` → `obs.Y = log(obs.Z)`)
2. **Modeling**: Global offset, covariance, and BME estimation performed in log space
3. **Back-Transformation**: Results automatically converted back to original space before saving/plotting
4. **File Naming**: All files include `_lt1` suffix (e.g., `BME10000132_go3_lt1_area5_res1.00_stg_land1_time2016.50.mat`)
5. **Plot Titles**: All titles include `, lt=1` or `(lt=1)` indicator

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│  1. Data Loading (getTOARobservationalData.m)               │
│     Input: Raw concentrations (obs.Z in ppb)                │
│     Output: Log-transformed data (obs.Y = log(obs.Z))       │
│     Files: TOAR_obs_all_y2015_2020_lt1_QC.mat              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Global Offset Estimation (getTOARglobalOffset.m)        │
│     Input: obs.Y (log space)                                │
│     Output: go.ms, go.mt (log space)                        │
│     Files: OZONE-TOARgo_go3.mat                            │
│     Plots: Titles include "(lt=1)"                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Covariance Estimation (getTOARautoCov.m)                │
│     Input: Residuals = obs.Y - GO (log space)               │
│     Output: cov.covmodel, cov.covparam (log space)          │
│     Files: Cov_go3_lt1.mat                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  4. Knowledge Base Preparation (getTOARknowledgeBase.m)     │
│     Input: obs.Y - GO (log space residuals)                 │
│     Output: KS.harddata.z (log space)                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  5. BME Estimation (estTOARsBME.m)                         │
│     Input: Residuals (log space)                            │
│     Modeling: BME in log space                              │
│     ⭐ Back-Transformation: exp(YkBMEm) → ZkBMEm            │
│     Output: Both log-space AND original-space results       │
│     Files: BME10000132_go3_lt1_area5_res1.00_..._time*.mat │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  6. Plotting (plotTOARsBME.m, plotTOARsBMEvar.m)           │
│     Input: ZkBMEm, Zobs (original concentration space)      │
│     Output: Plots with original concentrations              │
│     Files: BME10000132_go3_lt1_area5_..._time*.png         │
│     Titles: Include ", lt=1" indicator                      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  7. Validation (validateTOARsBME.m, plotTOARvalidation.m)  │
│     ⭐ Back-Transformation: exp(Y_obs), exp(Y_est)         │
│     Metrics: Computed in original concentration space       │
│     Files: TOAR_LOOCV_scatter_BME*_go3_lt1_*.png           │
│     Titles: Include ", lt=1" indicator                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Functions Reference

### Core Transformation Functions

#### `applyLogTransform(Z)`

**Purpose**: Apply forward log transformation with safety checks

**Location**: `/home/user/gO3_II_mo/applyLogTransform.m`

**Inputs**:
- `Z`: Original concentrations (any dimensions)

**Outputs**:
- `Y_log`: Log-transformed values (log(Z))
- `is_valid`: Logical mask of valid values

**Features**:
- Handles non-positive values (Z ≤ 0) by converting to NaN
- Provides warnings for data quality issues
- Preserves array dimensions

**Example**:
```matlab
Z = [10, 20, 0, -5, NaN, 50];  % ppb
[Y_log, is_valid] = applyLogTransform(Z);
% Y_log = [2.30, 3.00, NaN, NaN, NaN, 3.91]
% is_valid = [true, true, false, false, false, true]
```

---

#### `applyBackLogTransform(Y_log, Y_var, method)`

**Purpose**: Apply back log transformation (exponential)

**Location**: `/home/user/gO3_II_mo/applyBackLogTransform.m`

**Inputs**:
- `Y_log`: Log-transformed values
- `Y_var`: Variance in log space (optional)
- `method`: 'simple' (default) or 'bias_corrected'

**Outputs**:
- `Z`: Back-transformed concentrations
- `Z_var`: Variance in original space (if Y_var provided)

**Methods**:
1. **'simple'**: Direct exponential (default)
   - `Z = exp(Y_log)`
   - Best for predictions at specific locations

2. **'bias_corrected'**: Accounts for Jensen's inequality
   - `Z = exp(Y_log + Y_var/2)`
   - Best for computing expected values (lognormal mean)

**Variance Transformation**:
- Uses delta method: `Var(Z) ≈ exp(2*Y_log) * Var(Y_log)`
- Valid for small to moderate variances

**Example**:
```matlab
% Simple back-transformation
Y_log = 3.0;
Z = applyBackLogTransform(Y_log);
% Z = 20.09 ppb

% With variance
Y_log = 3.0;
Y_var = 0.1;
[Z, Z_var] = applyBackLogTransform(Y_log, Y_var, 'simple');
% Z = 20.09 ppb, Z_var = 80.7 ppb²

% Bias-corrected
[Z_bc, ~] = applyBackLogTransform(Y_log, Y_var, 'bias_corrected');
% Z_bc = 21.03 ppb (slightly higher due to bias correction)
```

---

### Modified Core Functions

#### `getTOARobservationalData(stationTypes, timeRange, logTransf)`

**Changes**:
- **Line 280**: Uses `applyLogTransform()` for forward transformation
- **Behavior**: When `logTransf=1`, converts `obs.Z` to `obs.Y = log(obs.Z)`

**Cache Files**:
- `TOAR_obs_all_y2015_2020_lt0_QC.mat` (raw concentrations)
- `TOAR_obs_all_y2015_2020_lt1_QC.mat` (log-transformed)

---

#### `estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam)`

**Changes**:
- **Lines 237-249**: Back-transformation logic after BME estimation
  ```matlab
  if obs.logTransf == 1
      [ZkBMEm, ZkBMEv] = applyBackLogTransform(YkBMEm, XkBMEv, 'simple');
  else
      ZkBMEm = YkBMEm;
      ZkBMEv = XkBMEv;
  end
  ```

- **Lines 252-259**: Store BOTH log-space and original-space results
  ```matlab
  BMEs.YkBMEm = YkBMEm;  % Log space (if logTransf=1)
  BMEs.ZkBMEm = ZkBMEm;  % Original space (always)
  BMEs.XkBMEv = XkBMEv;  % Variance in log space
  BMEs.ZkBMEv = ZkBMEv;  % Variance in original space
  ```

- **Lines 272-277**: Back-transform observations
  ```matlab
  if obs.logTransf == 1
      BMEs.Zobs = exp(BMEs.Yobs);
  else
      BMEs.Zobs = BMEs.Yobs;
  end
  ```

- **Lines 149-161**: Backward compatibility for loading old results

**Result Files**:
- `BME10000132_go3_lt0_area5_res1.00_stg_land1_time2016.50.mat` (raw)
- `BME10000132_go3_lt1_area5_res1.00_stg_land1_time2016.50.mat` (log-transformed)

---

#### `plotTOARsBME(obs, go, BMEs, BMEparam, estParam)`

**Changes**:
- **Lines 53-64**: Use back-transformed data for plotting
  ```matlab
  if isfield(BMEs, 'ZkBMEm') && ~isempty(BMEs.ZkBMEm)
      plotData = BMEs.ZkBMEm;  % Original space
      obsData = BMEs.Zobs;
  else
      plotData = BMEs.YkBMEm;  % Fallback to log space
      obsData = BMEs.Yobs;
  end
  ```

- **Line 196**: Title includes `, lt=0` or `, lt=1`
- **Line 226**: Filename includes `_lt0` or `_lt1`

**Plot Files**:
- `BME10000132_go3_lt0_area5_res1.00_stg_time2016.50_BME.png`
- `BME10000132_go3_lt1_area5_res1.00_stg_time2016.50_BME.png`

---

#### `plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam)`

**Changes**:
- **Lines 57-64**: Use back-transformed variance
  ```matlab
  if isfield(BMEs, 'ZkBMEv') && ~isempty(BMEs.ZkBMEv)
      XkBMEv = BMEs.ZkBMEv;  % Original space variance
      usePlotData = BMEs.ZkBMEm;  % For CV calculation
  else
      XkBMEv = BMEs.XkBMEv;  % Fallback
      usePlotData = BMEs.YkBMEm;
  end
  ```

- **Lines 125-126**: Title and filename indicators
- All 4 plot types updated (std dev, variance, CV, multi-panel)

---

#### `validateTOARsBME(obs, go, cov, BMEparam, valParam)`

**Changes**:
- **Lines 107-117**: Back-transform validation results before accumulation
  ```matlab
  if obs.logTransf == 1
      Y_obs_all = [Y_obs_all; exp(valResults.Y_obs)];
      Y_est_all = [Y_est_all; exp(valResults.Y_est)];
  else
      Y_obs_all = [Y_obs_all; valResults.Y_obs];
      Y_est_all = [Y_est_all; valResults.Y_est];
  end
  ```

**Validation Files**:
- `TOAR_LOOCV_BME10000132_go3_y2016_m01.mat` (monthly results, stored in log space)
- Final statistics computed in original concentration space

---

#### `plotTOARvalidation(valPairOut, valStats, valParam, obs, go, BMEparam)`

**Changes**:
- **Lines 18-19**: Title and filename indicators updated
  ```matlab
  ltStr = sprintf(', lt=%d', obs.logTransf);
  ltSuffix = sprintf('_lt%d', obs.logTransf);
  ```

**Validation Plot Files**:
- `TOAR_LOOCV_scatter_BME10000132_go3_lt0_stg_y[2016].png`
- `TOAR_LOOCV_scatter_BME10000132_go3_lt1_stg_y[2016].png`

---

#### `plotTOARglobalOffset(obs, go, goPlot)`

**Changes**:
- **Line 74**: Title indicator
  ```matlab
  ltStr = sprintf(' (lt=%d)', obs.logTransf);
  ```
- **Lines 87, 103, 131**: Applied to all plot titles

**Note**: Global offset plots always show log-space data (when `logTransf=1`) because the global offset is computed in log space.

---

## File Naming Convention

### General Pattern

All files include log-transformation indicator:

```
{prefix}_{parameters}_lt{0|1}_{additional_params}.{ext}
```

Where:
- `lt0` = Raw concentrations (no transformation)
- `lt1` = Log-transformed concentrations

### Specific Examples

#### 1. BME Results (`.mat` files)

**Pattern**:
```
BME{method}_go{scenario}_lt{0|1}_area{code}_res{resolution}_{format}_land{flag}_time{YYYY.YY}.mat
```

**Examples**:
```
BME10000132_go3_lt0_area5_res1.00_stg_land1_time2016.50.mat  (raw)
BME10000132_go3_lt1_area5_res1.00_stg_land1_time2016.50.mat  (log)
```

**Structure**:
```matlab
BMEs.sk        % [N×2] Estimation grid coordinates
BMEs.tk        % Estimation time
BMEs.XkBMEm    % [N×1] Residual mean (log space if lt1)
BMEs.XkBMEv    % [N×1] Residual variance (log space if lt1)
BMEs.gok       % [N×1] Global offset (log space if lt1)
BMEs.YkBMEm    % [N×1] Prediction with GO (log space if lt1)
BMEs.ZkBMEm    % [N×1] Back-transformed prediction (ALWAYS original space)
BMEs.ZkBMEv    % [N×1] Back-transformed variance (ALWAYS original space)
BMEs.Yobs      % Observations (log space if lt1)
BMEs.Zobs      % Observations (ALWAYS original space)
```

#### 2. BME Plots (`.png` files)

**Pattern**:
```
BME{method}_go{scenario}_lt{0|1}_area{code}_res{resolution}_{format}_time{YYYY.YY}_{type}.png
```

**Examples**:
```
BME10000132_go3_lt0_area5_res1.00_stg_time2016.50_BME.png
BME10000132_go3_lt1_area5_res1.00_stg_time2016.50_BME.png
BME10000132_go3_lt0_area5_res1.00_stg_time2016.50_BME_obs.png
BME10000132_go3_lt1_area5_res1.00_stg_time2016.50_BME_obs.png
```

#### 3. Variance Plots (`.png` files)

**Pattern**:
```
BME{method}_go{scenario}_lt{0|1}_area{code}_res{resolution}_{format}_time{YYYY.YY}_{variance_type}.png
```

**Types**: `stddev`, `variance`, `CV`, `uncertainty_all`

**Examples**:
```
BME10000132_go3_lt0_area5_res1.00_stg_time2016.50_stddev.png
BME10000132_go3_lt1_area5_res1.00_stg_time2016.50_variance.png
```

#### 4. Validation Plots (`.png` files)

**Pattern**:
```
TOAR_LOOCV_scatter_BME{method}_go{scenario}_lt{0|1}_{format}_y{years}.png
```

**Examples**:
```
TOAR_LOOCV_scatter_BME10000132_go3_lt0_stg_y[2016].png
TOAR_LOOCV_scatter_BME10000132_go3_lt1_stg_y[2016].png
```

#### 5. Global Offset Files (`.mat` files)

**Pattern**:
```
{Zname}go_go{scenario}.mat
```

**Note**: These files do NOT include `lt` indicator in filename (for backward compatibility), but the data inside is in log space when appropriate.

**Example**:
```
OZONE-TOARgo_go3.mat
```

#### 6. Covariance Files (`.mat` files)

**Pattern**:
```
Cov_go{scenario}_lt{0|1}.mat
```

**Examples**:
```
Cov_go3_lt0.mat  (raw concentrations)
Cov_go3_lt1.mat  (log-transformed)
```

#### 7. Cached Observational Data (`.mat` files)

**Pattern**:
```
TOAR_obs_{types}_y{start}_{end}_lt{0|1}_QC.mat
```

**Examples**:
```
TOAR_obs_all_y2015_2020_lt0_QC.mat
TOAR_obs_all_y2015_2020_lt1_QC.mat
```

---

## Plot Title Convention

### BME Estimation Plots

**Format**:
```
{Plot Title}
{Time Information}
BME Method: {method}, GO Scenario: {scenario}, Area: {code}, Resolution: {res}°, Format: {format}, lt={0|1}
```

**Example**:
```
OZONE-TOAR BME Estimate + Observations
Year: 2016, Month: 6
BME Method: 10000132, GO Scenario: 3, Area: 5, Resolution: 1.00°, Format: stg, lt=1
```

### Variance Plots

**Same format as BME plots**, with appropriate variance-related title:
```
OZONE-TOAR BME Standard Deviation
Year: 2016, Month: 6
BME Method: 10000132, GO Scenario: 3, Area: 5, Resolution: 1.00°, Format: stg, lt=1
```

### Validation Plots

**Format**:
```
TOAR BME Leave-One-Out Cross Validation
BME Method: {method}, GO Scenario: {scenario}, Format: {format}, lt={0|1}
```

**Example**:
```
TOAR BME Leave-One-Out Cross Validation
BME Method: 10000132, GO Scenario: 3, Format: stg, lt=1
```

### Global Offset Plots

**Format**:
```
{Plot Description} (lt={0|1})
```

**Examples**:
```
Raw and smoothed temporal mean trend of log(OZONE-TOAR) (lt=1)
Smoothed spatial trend of log OZONE TOAR-II (ppb) (lt=0)
```

---

## Modified Files

### Summary Table

| File | Priority | Type | Changes |
|------|----------|------|---------|
| `applyLogTransform.m` | ⭐⭐⭐ | NEW | Forward log transformation with safety checks |
| `applyBackLogTransform.m` | ⭐⭐⭐ | NEW | Back log transformation with variance handling |
| `estTOARsBME.m` | ⭐⭐⭐ | CORE | Back-transforms BME results, stores both log/original space |
| `plotTOARsBME.m` | ⭐⭐⭐ | PLOT | Uses back-transformed data, updates titles/filenames |
| `plotTOARsBMEvar.m` | ⭐⭐⭐ | PLOT | Uses back-transformed variance, updates titles/filenames |
| `validateTOARsBME.m` | ⭐⭐ | VALID | Back-transforms validation results |
| `plotTOARvalidation.m` | ⭐⭐ | PLOT | Updates titles/filenames with lt indicator |
| `plotTOARglobalOffset.m` | ⭐⭐ | PLOT | Adds lt indicator to plot titles |
| `getTOARobservationalData.m` | ⭐ | DATA | Uses applyLogTransform() function |

**Total**: 2 new files + 7 modified files

---

## Data Flow

### Log Space vs Original Space

| Stage | Data Space | Variables | Files |
|-------|------------|-----------|-------|
| **Raw Data** | Original (ppb) | `obs.Z` | CSV files |
| **After Loading** | Log space (if lt=1) | `obs.Y = log(obs.Z)` | `*_lt1_QC.mat` |
| **Global Offset** | Log space | `go.ms`, `go.mt` | `*go_go3.mat` |
| **Covariance** | Log space | `cov.covmodel` | `Cov_go3_lt1.mat` |
| **BME Input** | Log space | `KS.harddata.z` | — |
| **BME Output (log)** | Log space | `YkBMEm`, `XkBMEv` | In `.mat` files |
| **BME Output (orig)** | Original (ppb) | `ZkBMEm`, `ZkBMEv` | In `.mat` files |
| **Plots** | Original (ppb) | Uses `ZkBMEm`, `Zobs` | `.png` files |
| **Validation** | Original (ppb) | exp(Y_obs), exp(Y_est) | `.png`, stats |

---

## Testing

### Test Case 1: Raw Concentrations (`logTransf=0`)

**Setup**:
```matlab
analyzeParam.logTransf = 0;
analyzeParam.goScenario = 3;
analyzeParam.areaCode = 5;
analyzeParam.mapResolution = 1.0;
analyzeParam.tkVec = 2016.5;  % July 2016
```

**Expected Behavior**:
- ✅ No log transformation applied (`obs.Y == obs.Z`)
- ✅ All filenames include `_lt0`
- ✅ All plot titles include `, lt=0` or `(lt=0)`
- ✅ Concentrations in ppb throughout
- ✅ `ZkBMEm == YkBMEm` (no transformation needed)

**Verification**:
```matlab
% Check that values are in original space
assert(all(obs.Y(:) == obs.Z(:), 'omitnan'));
assert(all(BMEs.ZkBMEm == BMEs.YkBMEm));
% Check filenames
assert(contains(BMEsFile, '_lt0'));
```

---

### Test Case 2: Log-Transformed Concentrations (`logTransf=1`)

**Setup**:
```matlab
analyzeParam.logTransf = 1;
analyzeParam.goScenario = 3;
analyzeParam.areaCode = 5;
analyzeParam.mapResolution = 1.0;
analyzeParam.tkVec = 2016.5;
```

**Expected Behavior**:
- ✅ Log transformation applied (`obs.Y == log(obs.Z)`)
- ✅ All filenames include `_lt1`
- ✅ All plot titles include `, lt=1` or `(lt=1)`
- ✅ Modeling happens in log space
- ✅ Final outputs (`ZkBMEm`) in original ppb space
- ✅ `ZkBMEm ≈ exp(YkBMEm)` (accounting for rounding)

**Verification**:
```matlab
% Check log transformation
assert(all(abs(obs.Y - log(obs.Z)) < 1e-6, 'omitnan'));
% Check back-transformation
assert(all(abs(BMEs.ZkBMEm - exp(BMEs.YkBMEm)) < 1e-3, 'omitnan'));
% Check positive concentrations
assert(all(BMEs.ZkBMEm > 0, 'omitnan'));
% Check filenames
assert(contains(BMEsFile, '_lt1'));
```

---

### Test Case 3: Edge Cases

**Test Non-Positive Values**:
```matlab
Z_test = [10, 0, -5, NaN, 20];
[Y_test, is_valid] = applyLogTransform(Z_test);
% Expected: Y_test = [2.30, NaN, NaN, NaN, 3.00]
% Expected: is_valid = [true, false, false, false, true]
```

**Test Variance Transformation**:
```matlab
Y_log = 3.0;  % log(20.09)
Y_var = 0.1;
[Z, Z_var] = applyBackLogTransform(Y_log, Y_var, 'simple');
% Expected: Z ≈ 20.09 ppb
% Expected: Z_var ≈ 80.7 ppb² (using delta method)
```

**Test Backward Compatibility**:
```matlab
% Load old results without ZkBMEm
load('old_BME_file.mat', 'BMEs');
% estTOARsBME should automatically recalculate ZkBMEm
% Check lines 149-161 in estTOARsBME.m
```

---

## Troubleshooting

### Issue 1: Plots Show Log Values Instead of Original Concentrations

**Symptoms**:
- Y-axis values are small (e.g., 2-4 instead of 20-60 ppb)
- Concentrations don't match expected range

**Diagnosis**:
```matlab
% Check if back-transformation was applied
if isfield(BMEs, 'ZkBMEm')
    fprintf('Back-transformed data available\n');
else
    fprintf('ERROR: ZkBMEm not found!\n');
end
```

**Solution**:
1. Check that `obs.logTransf == 1` is correctly set
2. Verify `estTOARsBME.m` lines 237-249 are present
3. Ensure `plotTOARsBME.m` lines 53-64 use `ZkBMEm` not `YkBMEm`
4. If loading old results, set `forceEstimation=1` to regenerate

---

### Issue 2: Negative or Zero Concentrations After Back-Transformation

**Symptoms**:
- Some `ZkBMEm` values are ≤ 0
- Warnings about invalid values

**Diagnosis**:
```matlab
% Check for negative values
negatives = sum(BMEs.ZkBMEm <= 0);
fprintf('Number of non-positive values: %d\n', negatives);

% Check input log values
fprintf('YkBMEm range: [%.2f, %.2f]\n', min(BMEs.YkBMEm), max(BMEs.YkBMEm));
```

**Solution**:
- Back-transformation should NEVER produce negatives (exp(x) > 0 for all x)
- If this occurs, check that `YkBMEm` is correctly computed
- Verify no corruption in saved `.mat` files
- Check lines 226-231 in `estTOARsBME.m` for debug output

---

### Issue 3: File Naming Inconsistent

**Symptoms**:
- Some files have `_lt1`, others don't
- Can't find expected files

**Diagnosis**:
```matlab
% List all BME files
dir('5BMEspatialPlots/BME*_lt*.mat')

% Check if lt indicator is in filename
BMEsFile = 'BME10000132_go3_area5_res1.00_stg_land1_time2016.50.mat';
if contains(BMEsFile, '_lt')
    fprintf('OK: File includes lt indicator\n');
else
    fprintf('ERROR: Old file format detected\n');
end
```

**Solution**:
1. Check `estTOARsBME.m` line 89 includes `obs.logTransf`
2. Ensure all plotting functions use `ltSuffix = sprintf('_lt%d', obs.logTransf)`
3. Delete old files without `_lt` indicator if needed
4. Re-run with `forceEstimation=1`

---

### Issue 4: Variance Values Seem Too Large

**Symptoms**:
- `ZkBMEv` >> `XkBMEv`
- Uncertainty plots show very large values

**Diagnosis**:
```matlab
% Compare variances
fprintf('Log space variance: mean=%.2f\n', mean(BMEs.XkBMEv, 'omitnan'));
fprintf('Original space variance: mean=%.2f\n', mean(BMEs.ZkBMEv, 'omitnan'));
fprintf('Ratio: %.2f\n', mean(BMEs.ZkBMEv./BMEs.XkBMEv, 'omitnan'));

% Expected ratio ≈ exp(2*mean(YkBMEm))
expected_ratio = exp(2*mean(BMEs.YkBMEm, 'omitnan'));
fprintf('Expected ratio: %.2f\n', expected_ratio);
```

**Explanation**:
- This is EXPECTED behavior due to delta method transformation
- `Var(Z) ≈ exp(2*Y) * Var(Y)` amplifies variance
- For Y=3 (Z≈20 ppb), variance is amplified by factor of exp(6) ≈ 403

**If variance seems unreasonably large**:
1. Check that `XkBMEv` (log space variance) is reasonable (< 1.0 typically)
2. Verify back-transformation formula in `applyBackLogTransform.m` line ~67
3. Consider using bias-corrected method for mean estimates

---

### Issue 5: Validation Statistics Don't Match

**Symptoms**:
- Validation R² or RMSE different between lt=0 and lt=1
- Statistics seem incorrect

**Diagnosis**:
```matlab
% Check if back-transformation was applied in validation
fprintf('Y_obs range: [%.2f, %.2f]\n', min(Y_obs), max(Y_obs));
fprintf('Y_est range: [%.2f, %.2f]\n', min(Y_est), max(Y_est));

% If lt=1, these should be in ppb range (20-80), not log range (2-4)
if obs.logTransf == 1 && max(Y_obs) < 10
    fprintf('ERROR: Validation results still in log space!\n');
end
```

**Solution**:
1. Check `validateTOARsBME.m` lines 107-117 for back-transformation
2. Ensure `exp()` is applied to both `Y_obs` and `Y_est`
3. Verify `plotTOARvalidation.m` receives back-transformed data

---

### Issue 6: Plot Titles Missing lt Indicator

**Symptoms**:
- Plots don't show `, lt=0` or `, lt=1` in title
- Can't tell if log-transformed or not

**Solution**:
1. **BME Plots**: Check `plotTOARsBME.m` line 196
   ```matlab
   ltStr = sprintf(', lt=%d', obs.logTransf);
   ```

2. **Variance Plots**: Check `plotTOARsBMEvar.m` line 125
   ```matlab
   ltStr = sprintf(', lt=%d', obs.logTransf);
   ```

3. **Validation Plots**: Check `plotTOARvalidation.m` line 18
   ```matlab
   ltStr = sprintf(', lt=%d', obs.logTransf);
   ```

4. **Global Offset Plots**: Check `plotTOARglobalOffset.m` line 74
   ```matlab
   ltStr = sprintf(' (lt=%d)', obs.logTransf);
   ```

---

## Advanced Topics

### Bias Correction for Lognormal Distributions

When `Y ~ N(μ, σ²)` and `Z = exp(Y)`, the expected value is:

```
E[Z] = exp(μ + σ²/2)
```

**When to use bias-corrected method**:
- Computing spatial averages
- Temporal aggregations
- Any operation requiring expected values

**Example**:
```matlab
% Simple (what we use for point predictions)
Z_simple = exp(YkBMEm);

% Bias-corrected (for expected values)
Z_corrected = exp(YkBMEm + XkBMEv/2);

% Difference
bias = Z_corrected - Z_simple;
fprintf('Bias: %.2f ppb\n', mean(bias));
```

**Current Implementation**: Uses 'simple' method (conservative, no bias correction)

**Future Enhancement**: Could add option for bias-corrected spatial averages

---

### Variance Transformation Accuracy

The delta method approximation `Var(Z) ≈ exp(2*Y) * Var(Y)` is first-order.

**Accuracy depends on**:
1. Variance magnitude (better for smaller Var(Y))
2. Mean value (affects amplification factor)

**More accurate (but complex) formula**:
```matlab
% Second-order approximation
Z_var_accurate = exp(2*Y + Var_Y) * (exp(Var_Y) - 1);
```

**When first-order is sufficient**:
- `Var(Y) < 0.5`: Excellent approximation
- `Var(Y) < 1.0`: Good approximation
- `Var(Y) > 1.0`: Consider second-order

**Current Implementation**: Uses first-order delta method (appropriate for most applications)

---

## References

### Mathematical Background

1. **Log-Normal Distribution**:
   - If Y ~ N(μ, σ²), then Z = exp(Y) ~ LogNormal(μ, σ²)
   - E[Z] = exp(μ + σ²/2)
   - Var(Z) = exp(2μ + σ²) * (exp(σ²) - 1)

2. **Delta Method**:
   - For Y = g(X), Var(Y) ≈ [g'(X)]² * Var(X)
   - For Z = exp(Y), Var(Z) ≈ [exp(Y)]² * Var(Y) = exp(2Y) * Var(Y)

3. **Jensen's Inequality**:
   - For convex function f: E[f(X)] ≥ f(E[X])
   - For exp: E[exp(Y)] ≥ exp(E[Y])
   - Bias = E[exp(Y)] - exp(E[Y]) ≈ exp(E[Y]) * Var(Y) / 2

### Related Documentation

- `analysisTOAR.m`: Main analysis script
- `README.md`: General project documentation
- Function headers: Each `.m` file has detailed help

---

## Change Log

### Version 1.0 (Current)
- Initial implementation of complete log-transformation workflow
- Created `applyLogTransform.m` and `applyBackLogTransform.m`
- Modified 7 core files for back-transformation
- Updated all file naming to include `_lt0` or `_lt1`
- Updated all plot titles to include `, lt=0` or `, lt=1`
- Both log-space and original-space results stored in `.mat` files
- Backward compatible with existing code (`logTransf=0`)

### Future Enhancements
- [ ] Add bias-corrected option for spatial averages
- [ ] Implement second-order variance transformation
- [ ] Add diagnostic plots comparing log vs original space
- [ ] Create unit tests for transformation functions
- [ ] Add option to save plots in both spaces

---

## FAQ

**Q: Should I use `logTransf=1` for all analyses?**

A: Depends on your data:
- **Use lt=1 if**: Concentrations span wide range (e.g., 1-100 ppb), residuals heteroscedastic, want to stabilize variance
- **Use lt=0 if**: Concentrations relatively uniform, linear relationships expected, interpretability important

**Q: Can I switch between `logTransf=0` and `logTransf=1`?**

A: Yes, but:
- Global offset and covariance must be re-estimated
- Set `forceGO=1` and `forceCov=1`
- Results will differ (different models)
- Files kept separate by `_lt0` vs `_lt1`

**Q: Why do variance plots show larger values with `lt=1`?**

A: This is expected. Variance transformation amplifies by `exp(2*Y)`. For Y=3 (Z≈20 ppb), amplification factor ≈ 403.

**Q: How do I compare results between `lt=0` and `lt=1`?**

A: Load both result files and compare:
```matlab
load('BME..._lt0_...mat', 'BMEs'); BMEs_raw = BMEs;
load('BME..._lt1_...mat', 'BMEs'); BMEs_log = BMEs;

% Both ZkBMEm are in original space
correlation = corr(BMEs_raw.ZkBMEm, BMEs_log.ZkBMEm);
rmse = sqrt(mean((BMEs_raw.ZkBMEm - BMEs_log.ZkBMEm).^2));
fprintf('Correlation: %.3f, RMSE: %.2f ppb\n', correlation, rmse);
```

**Q: What if I have very small concentrations (< 1 ppb)?**

A: Log transformation may not be appropriate:
- log(0.1) = -2.3 (large negative values)
- Consider adding constant: Y = log(Z + c)
- Or use Box-Cox transformation instead
- Current implementation handles Z≤0 by converting to NaN

---

## Contact

For questions or issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review function help: `help applyLogTransform`
3. Check code comments in modified files
4. Contact: [your contact information]

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**Author**: [Your Name]
