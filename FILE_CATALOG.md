# COMPREHENSIVE MATLAB FILES CATALOG
## TOAR Ozone BME Analysis Repository

**Repository:** `D:\Users\praful\proj\nasa\gO3_II_mo`
**Total Files:** 132 MATLAB (.m) files (repo root)
**Date:** May 30, 2026 (core catalog from Jan 17, 2026; see "Added Since Jan 2026" addendum at end)

---

## Table of Contents
1. [Data Loading & Processing](#data-loading--processing)
2. [Global Offset Computation](#global-offset-computation)
3. [Covariance Modeling](#covariance-modeling)
4. [Knowledge Base Creation](#knowledge-base-creation)
5. [BME Estimation & Kriging](#bme-estimation--kriging)
6. [Validation Methods](#validation-methods)
7. [Soft Data Management](#soft-data-management)
8. [Visualization & Plotting](#visualization--plotting)
9. [Diagnostic Tools](#diagnostic-tools)
10. [Utility & Helper Functions](#utility--helper-functions)
11. [Examples & Tests](#examples--tests)
12. [Cross-Reference & Dependencies](#cross-reference-key-function-dependencies)

---

## Data Loading & Processing

### 1. getTOARobservationalData.m
**Location:** `/home/user/gO3_II_mo/getTOARobservationalData.m`
**Purpose:** Load observational TOAR ozone data from database
**Function Signature:** `obs = getTOARobservationalData(iva, timeRange)`
**Key Inputs:**
- `iva`: Integer specifying variable (7=yearly ozone concentrations)
- `timeRange`: [startYear, endYear] optional time range

**Key Outputs:**
- `obs`: Structure containing observational data with fields:
  - `.Y`: Observations (n × tME)
  - `.sMS`: Station coordinates [lon, lat]
  - `.tME`: Time vector in decimal years
  - `.stationID`, `.stationType`: Station metadata

**Description:** Loads TOAR (Tropospheric Ozone Assessment Report) observational data from the database. Handles multiple variable types and time ranges.

---

### 2. subsetTOARdata.m
**Location:** `/home/user/gO3_II_mo/subsetTOARdata.m`
**Purpose:** Subset TOAR data by spatial region and/or time period
**Function Signature:** `obsSubset = subsetTOARdata(obs, regionCode, timeRange)`
**Key Inputs:**
- `obs`: Observational data structure
- `regionCode`: Integer code for geographic region
- `timeRange`: Optional [startYear, endYear]

**Key Outputs:**
- `obsSubset`: Subsetted observational data

**Description:** Spatially and temporally filters TOAR data based on region codes and time boundaries for focused analysis.

---

### 3. assessTOARdataQuality.m
**Location:** `/home/user/gO3_II_mo/assessTOARdataQuality.m`
**Purpose:** Evaluate data completeness and quality metrics
**Function Signature:** `qualityReport = assessTOARdataQuality(obs)`
**Key Inputs:**
- `obs`: Observational data structure

**Key Outputs:**
- `qualityReport`: Structure with quality metrics including data completeness, NaN patterns, outlier detection

**Description:** Analyzes TOAR data quality including missing value patterns, data completeness percentages, and statistical summaries.

---

### 4. analyzeGridUniformity.m
**Location:** `/home/user/gO3_II_mo/analyzeGridUniformity.m`
**Purpose:** Verify uniform spatial gridding of data
**Function Signature:** `gridInfo = analyzeGridUniformity(sMS, tolerance)`
**Key Inputs:**
- `sMS`: Spatial coordinates [n × 2]
- `tolerance`: Tolerance for uniformity check (default: 1e-6)

**Key Outputs:**
- `gridInfo`: Structure indicating grid uniformity status and spacing

**Description:** Validates that spatial data lies on a uniform grid with consistent spacing.

---

### 5. checkAllGridUniformity.m
**Location:** `/home/user/gO3_II_mo/checkAllGridUniformity.m`
**Purpose:** Batch check grid uniformity for multiple models
**Function Signature:** `checkAllGridUniformity()`
**Description:** Validates grid uniformity for all CTM models in the repository.

---

### 6. loadRAMPdata.m
**Location:** `/home/user/gO3_II_mo/loadRAMPdata.m`
**Purpose:** Load RAMP-corrected CTM data from parquet files
**Function Signature:** `ctmData = loadRAMPdata(modelName, years, dataDir, forceReload)`
**Key Inputs:**
- `modelName`: CTM model identifier (e.g., 'UKML', 'MERRA2-GMI')
- `years`: Vector of years to load
- `dataDir`: Directory containing parquet files
- `forceReload`: Force reload from parquet (1) or use cache (0)

**Key Outputs:**
- `ctmData`: Structure with fields:
  - `.modelName`, `.years`: Identification
  - `.lon`, `.lat`, `.sMS`: Spatial coordinates
  - `.tME`: Time vector (decimal years)
  - `.Z`: Mean field (lambda1)
  - `.Zv`: Variance field (lambda2)
  - `.gridInfo`: Metadata

**Description:** Loads RAMP-corrected CTM (Chemical Transport Model) data from parquet files with spatial grid information. Includes caching for performance.

---

### 7. extractModelSpatialInfo.m
**Location:** `/home/user/gO3_II_mo/extractModelSpatialInfo.m`
**Purpose:** Extract and save spatial grid information from CTM model outputs
**Function Signature:** `extractModelSpatialInfo(modelName, csvDir, outputDir)`
**Key Inputs:**
- `modelName`: CTM model name
- `csvDir`: Directory containing CSV model outputs
- `outputDir`: Directory for saved .mat files

**Key Outputs:**
- Saves .mat files with spatial grid information (lon, lat, nGridPoints, yearsChecked, isConsistent)

**Description:** Processes raw CTM model CSV outputs to extract consistent spatial grid information across years.

---

### 8. verifyGridAlignment.m
**Location:** `/home/user/gO3_II_mo/verifyGridAlignment.m`
**Purpose:** Verify alignment between different grids
**Function Signature:** `[isAligned, report] = verifyGridAlignment(grid1, grid2, tolerance)`
**Description:** Checks if two grids are properly aligned for data fusion.

---

### 9. exploreTOARdata.m
**Location:** `/home/user/gO3_II_mo/exploreTOARdata.m`
**Purpose:** Interactive data exploration tool
**Function Signature:** `exploreTOARdata(obs, go)`
**Description:** Interactive tool for exploring TOAR data structure and quality.

---

### 10. analyzeTOAR.m
**Location:** `/home/user/gO3_II_mo/analyzeTOAR.m`
**Purpose:** Comprehensive data analysis script
**Function Signature:** `analyzeTOAR(obs, options)`
**Description:** Performs comprehensive analysis of TOAR data including summary statistics and patterns.

---

### 11. analysisTOAR.m
**Location:** `/home/user/gO3_II_mo/analysisTOAR.m`
**Purpose:** Alternative analysis script
**Description:** Similar to analyzeTOAR.m with different focus areas.

---

### 12. analyzeTOARscenario.m
**Location:** `/home/user/gO3_II_mo/analyzeTOARscenario.m`
**Purpose:** Scenario-specific analysis
**Function Signature:** `analyzeTOARscenario(obs, scenario)`
**Description:** Analyzes data under specific scenarios or configurations.

---

## Global Offset Computation

### 13. getTOARglobalOffset.m
**Location:** `/home/user/gO3_II_mo/getTOARglobalOffset.m`
**Purpose:** Compute global offset (mean trend) from observations
**Function Signature:** `go = getTOARglobalOffset(obs, scenario, plotType, method)`
**Key Inputs:**
- `obs`: Observational data structure
- `scenario`: Integer (0-4) selecting offset method
  - 0: Raw spatial mean
  - 1: Temporal mean only
  - 2: Spatial-temporal separation
  - 3: Regional with smoothing
  - 4: Advanced smoothing
- `plotType`: Display level (0=none, 1=basic, 2=detailed, 3=full)
- `method`: Smoothing method ('spline', 'loess', etc.)

**Key Outputs:**
- `go`: Global offset structure with fields:
  - `.sMS`: Spatial locations
  - `.tME`: Time vector
  - `.ms`: Spatial mean trend
  - `.mt`: Temporal mean trend
  - `.sMSraw`, `.msRaw`: Raw spatial means
  - `.tMEraw`, `.mtRaw`: Raw temporal means
  - `.scenario`: Method code

**Description:** Computes global offset (mean trend component) from observational data using various smoothing scenarios.

---

### 14. valTOARglobalOffsets.m
**Location:** `/home/user/gO3_II_mo/valTOARglobalOffsets.m`
**Purpose:** Validate global offset estimates
**Function Signature:** `valResults = valTOARglobalOffsets(obs, go, valMethod, crossVal)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset structure
- `valMethod`: Validation method (1=holdout, 2=cross-validation)
- `crossVal`: Cross-validation parameters

**Key Outputs:**
- `valResults`: Validation statistics (RMSE, MAE, correlation, etc.)

**Description:** Validates global offset estimates using hold-out or cross-validation approaches.

---

### 15. plotTOARglobalOffset.m
**Location:** `/home/user/gO3_II_mo/plotTOARglobalOffset.m`
**Purpose:** Visualize global offset estimates (maps and time series)
**Function Signature:** `plotTOARglobalOffset(obs, go, goPlot, tMEplot, displayArea, plotBorders, yrange)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset structure or scenario code
- `goPlot`: Plot detail level (0-3)
- `tMEplot`: Years to plot
- `displayArea`: [lonmin lonmax latmin latmax]
- `plotBorders`: Plot country borders (1/0)
- `yrange`: Color scale range

**Key Outputs:**
- Multiple figures saved to `./2globalOffset/figs/`

**Description:** Creates publication-quality maps and time series plots of global offset with various visualization options.

---

### 16. test_gos.m
**Location:** `/home/user/gO3_II_mo/test_gos.m`
**Purpose:** Test global offset scenarios
**Description:** Test script for validating different global offset computation methods.

---

### 17. stCompositeMeanDensified.m
**Location:** `/home/user/gO3_II_mo/stCompositeMeanDensified.m`
**Purpose:** Composite space-time mean with densification
**Function Signature:** `meanField = stCompositeMeanDensified(obs, go, params)`
**Description:** Creates densified composite mean field from observations and global offset.

---

## Covariance Modeling

### 18. getTOARautoCov.m
**Location:** `/home/user/gO3_II_mo/getTOARautoCov.m`
**Purpose:** Compute experimental autocorrelation functions
**Function Signature:** `autoCov = getTOARautoCov(X, sMS, tME, rLag, tLag)`
**Key Inputs:**
- `X`: Residual field (n × t)
- `sMS`: Spatial coordinates
- `tME`: Time vector
- `rLag`: Spatial lags to compute
- `tLag`: Temporal lags to compute

**Key Outputs:**
- `autoCov`: Structure with experimental covariance values and parameters

**Description:** Computes experimental spatial and temporal autocorrelation functions for variogram/covariogram estimation.

---

### 19. getTOARcovariance.m
**Location:** `/home/user/gO3_II_mo/getTOARcovariance.m`
**Purpose:** Fit covariance model to experimental data
**Function Signature:** `cov = getTOARcovariance(obs, go, plotType)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset structure
- `plotType`: Display level

**Key Outputs:**
- `cov`: Covariance structure with fields:
  - `.covmodel`: Cell array of covariance model type
  - `.covparam`: Cell array of model parameters
  - `.Cr`, `.Ct`: Experimental covariance values
  - `.rLag`, `.tLag`: Lag values

**Description:** Fits parametric covariance models (e.g., exponential) to experimental covariance functions.

---

### 20. plotTOARcov.m
**Location:** `/home/user/gO3_II_mo/plotTOARcov.m`
**Purpose:** Plot covariance model with experimental values
**Function Signature:** `plotTOARcov(cov, covPlot)`
**Key Inputs:**
- `cov`: Covariance structure
- `covPlot`: Plot type (1=2D, 2=2D+3D)

**Key Outputs:**
- Figures with spatial and temporal covariance plots

**Description:** Creates publication-quality plots of spatial/temporal covariance with model fits.

---

### 21. calculateTOARseasonality.m
**Location:** `/home/user/gO3_II_mo/calculateTOARseasonality.m`
**Purpose:** Extract seasonal patterns from data
**Function Signature:** `seasonality = calculateTOARseasonality(obs, go)`
**Description:** Computes seasonal patterns and cycles from detrended data.

---

### 22. plotTOARseasonalPhase.m
**Location:** `/home/user/gO3_II_mo/plotTOARseasonalPhase.m`
**Purpose:** Plot seasonal phase patterns
**Function Signature:** `plotTOARseasonalPhase(seasonality, options)`
**Description:** Visualizes seasonal phase information.

---

## Knowledge Base Creation

### 23. getKB.m
**Location:** `/home/user/gO3_II_mo/getKB.m`
**Purpose:** Create knowledge base structures for BME estimation
**Function Signature:** `[KG, KS, BMEparam] = getKB(obs, go, cov, BMEmethod5digits)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset
- `cov`: Covariance model
- `BMEmethod5digits`: BME method code

**Key Outputs:**
- `KG`: General knowledge base (covariance structure)
- `KS`: Site-specific knowledge base (hard/soft data)
- `BMEparam`: BME estimation parameters

**Description:** Constructs knowledge bases required for Bayesian Maximum Entropy estimation.

---

### 24. getTOARknowledgeBase.m
**Location:** `/home/user/gO3_II_mo/getTOARknowledgeBase.m`
**Purpose:** Complete knowledge base creation workflow for TOAR data
**Function Signature:** `[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod, dataFormat)`
**Key Inputs:**
- `obs`: Observations
- `go`: Global offset
- `cov`: Covariance
- `softData`: Optional soft data structure or cell array
- `BMEmethod`: Method code (8-digit extended or legacy format)
- `dataFormat`: 'stv', 'stg', or 'stug'

**Key Outputs:**
- `KG`, `KS`, `BMEparam`: Knowledge bases and parameters

**Description:** Comprehensive knowledge base creation integrating observations, global offset, covariance, and optional soft data.

---

### 25. getBMEparam.m
**Location:** `/home/user/gO3_II_mo/getBMEparam.m`
**Purpose:** Extract BME parameters from method code
**Function Signature:** `BMEparam = getBMEparam(BMEmethod8digits, stmetric, dataFormat)`
**Key Inputs:**
- `BMEmethod8digits`: 8-digit method code
- `stmetric`: Space-time metric
- `dataFormat`: 'stv', 'stg', or 'stug'

**Key Outputs:**
- `BMEparam`: Structure with nhmax, nsmax, dmax, order, options

**Description:** Decodes BME method specification into specific parameter values.

---

### 26. createSoftDataStructure.m
**Location:** `/home/user/gO3_II_mo/createSoftDataStructure.m`
**Purpose:** Format CTM data into soft data structure for BME
**Function Signature:** `softData = createSoftDataStructure(ctmData, obs, options)`
**Key Inputs:**
- `ctmData`: RAMP-corrected CTM data
- `obs`: Observational data (for alignment)
- `options`: Optional parameters for subsetting/thinning

**Key Outputs:**
- `softData`: Structure compatible with BME with fields:
  - `.sMS`, `.tME`: Coordinates
  - `.Z`, `.Zv`: Mean and variance
  - `.Zname`, `.Zunit`: Metadata

**Description:** Converts CTM model outputs into soft data format suitable for BME knowledge base.

---

### 27. setData_val.m
**Location:** `/home/user/gO3_II_mo/setData_val.m`
**Purpose:** Set up data structures for validation
**Function Signature:** `valData = setData_val(obs, go, cov, valParams)`
**Description:** Prepares data structures for validation workflows.

---

## BME Estimation & Kriging

### 28. estTOARsBME.m
**Location:** `/home/user/gO3_II_mo/estTOARsBME.m`
**Purpose:** Perform BME spatial estimation
**Function Signature:** `BMEs = estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset
- `cov`: Covariance model
- `KG`, `KS`: Knowledge bases
- `BMEparam`: BME parameters
- `estParam`: Estimation parameters with fields:
  - `.areaCode`: Region to estimate
  - `.mapResolution`: Grid spacing
  - `.tkVec`: Time points
  - `.forceEstimation`: Cache control
  - `.plotResults`: Plotting level
  - `.keepOnlyLand`: Land masking flag

**Key Outputs:**
- `BMEs`: BME results structure with:
  - `.sk`, `.tk`: Estimation grid
  - `.YkBMEm`: BME mean estimates (with global offset)
  - `.XkBMEm`: Residual estimates (offset-removed)
  - `.XkBMEv`: Estimation variance

**Description:** Executes Bayesian Maximum Entropy estimation at specified locations/times with automatic caching.

---

### 29. estBMEs_stg.m
**Location:** `/home/user/gO3_II_mo/estBMEs_stg.m`
**Purpose:** Alternative BME estimation using STG format
**Function Signature:** `BMEs = estBMEs_stg(obs, go, KG, KS, sk, tk, BMEparam)`
**Description:** BME estimation specifically using space-time grid format.

---

### 30. krigingME_stg.m
**Location:** `/home/user/gO3_II_mo/krigingME_stg.m`
**Purpose:** Kriging with measurement errors (space-time grid format)
**Function Signature:** `[zk, vk] = krigingME_stg(ck, ch, zh, vh, covmodel, covparam, nhmax, nsmax, dmax, order, options, harddata, softdata)`
**Key Inputs:**
- `ck`: Estimation points
- `ch`: Hard data coordinates
- `zh`: Hard data values
- `vh`: Hard data variances
- `covmodel`, `covparam`: Covariance specification
- `nhmax`, `nsmax`: Neighbor limits
- `dmax`: Distance limits [spatial, temporal, metric]
- `order`: Mean trend order
- `options`: Algorithm options
- `harddata`, `softdata`: Data structures

**Key Outputs:**
- `zk`: Estimates at estimation points
- `vk`: Estimation variances

**Description:** Kriging with measurement errors for sparse space-time grid data.

---

### 31. krigingME_stug.m
**Location:** `/home/user/gO3_II_mo/krigingME_stug.m`
**Purpose:** Kriging for uniform space-time grids (optimized)
**Function Signature:** `[zk, vk] = krigingME_stug(ck, ch, zh, vh, covmodel, covparam, nhmax, nsmax, dmax, order, options, harddata, softdata)`
**Description:** Optimized kriging algorithm for uniform grids. Significantly faster than krigingME_stg for large regular grids.

---

### 32. krigingME_stug_multi.m
**Location:** `/home/user/gO3_II_mo/krigingME_stug_multi.m`
**Purpose:** Multi-dataset kriging with measurement errors
**Function Signature:** `[zk, vk] = krigingME_stug_multi(ck, ch, zh, vh, covmodel, covparam, nhmax, nsmax, dmax, order, options, harddata, softdata_cell)`
**Key Inputs:**
- Same as krigingME_stug but `softdata_cell` can be:
  - Single structure (backward compatible)
  - Cell array of soft data structures (multi-dataset)

**Key Outputs:**
- `zk`, `vk`: Estimates and variances

**Description:** Enhanced kriging supporting multiple soft datasets simultaneously. See README_krigingME_stug_multi.md for details.

---

### 33. krigingME_Xvalidation.m
**Location:** `/home/user/gO3_II_mo/krigingME_Xvalidation.m`
**Purpose:** Cross-validation wrapper for kriging
**Function Signature:** `[cvResults] = krigingME_Xvalidation(obs, KG, BMEparam, cvFolds)`
**Description:** Performs k-fold cross-validation for kriging methods.

---

### 34. neighbours_stg.m
**Location:** `/home/user/gO3_II_mo/neighbours_stg.m`
**Purpose:** Find neighbors in space-time grid data
**Function Signature:** `[psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax)`
**Key Inputs:**
- `p0`: Target point [lon, lat, time]
- `data`: Space-time data structure
- `nmax`: Maximum neighbors
- `dmax`: [spatial_max, temporal_max, metric]

**Key Outputs:**
- `psub`: Neighbor coordinates
- `zsub`: Neighbor values
- `dsub`: Distances
- `nsub`: Number of neighbors
- `index`: Indices into data

**Description:** Selects neighbors for kriging from sparse space-time data. **FIXED** to handle restrictive dmax values (see ANALYSIS_neighbours_stg_crash.md).

---

### 35. neighbours_stug_optimized.m
**Location:** `/home/user/gO3_II_mo/neighbours_stug_optimized.m`
**Purpose:** Optimized neighbor search for uniform grids
**Function Signature:** `[psub, zsub, dsub, nsub, index] = neighbours_stug_optimized(p0, grid_data, nmax, dmax)`
**Description:** Efficient neighbor selection using shell expansion for large uniformly gridded datasets. Much faster than neighbours_stg for regular grids.

---

### 36. stmeanDensified.m
**Location:** `/home/user/gO3_II_mo/stmeanDensified.m`
**Purpose:** Interpolate smoothed mean trend at arbitrary locations/times
**Function Signature:** `m = stmeanDensified(sMS, tME, ms, mt, sMS_est, tME_est)`
**Key Inputs:**
- `sMS`: Original spatial locations
- `tME`: Original time vector
- `ms`, `mt`: Spatial and temporal mean components
- `sMS_est`: Estimation locations
- `tME_est`: Estimation times

**Key Outputs:**
- `m`: Interpolated mean trend at estimation locations/times

**Description:** Interpolates smoothed mean field at arbitrary estimation points using bivariate spline fitting.

---

### 37. getTOARmapGrid.m
**Location:** `/home/user/gO3_II_mo/getTOARmapGrid.m`
**Purpose:** Create regular estimation grid for mapping
**Function Signature:** `[sk, tk] = getTOARmapGrid(areaCode, resolution, timeRange, landOnly)`
**Key Inputs:**
- `areaCode`: Region code (0=global, 1=N.America, 2=Europe, etc.)
- `resolution`: Grid spacing in degrees
- `timeRange`: [startYear, endYear] or time vector
- `landOnly`: Filter to land points only (1/0)

**Key Outputs:**
- `sk`: Spatial estimation grid [n × 2]
- `tk`: Time vector

**Description:** Generates regular estimation grids for specific regions at specified resolution.

---

### 38. getTOARareaBoundaries.m
**Location:** `/home/user/gO3_II_mo/getTOARareaBoundaries.m`
**Purpose:** Define estimation area boundaries
**Function Signature:** `[axMS_est, idxSoft] = getTOARareaBoundaries(areaEst, ps, axMS)`
**Key Inputs:**
- `areaEst`: Area code (0-10)
- `ps`: Soft data locations
- `axMS`: Default domain boundaries

**Key Outputs:**
- `axMS_est`: Adjusted boundaries [lonmin lonmax latmin latmax]
- `idxSoft`: Logical index for soft data within area

**Description:** Defines spatial boundaries for different geographic regions and filters soft data.

---

### 39. test_land_grid_filtering.m
**Location:** `/home/user/gO3_II_mo/test_land_grid_filtering.m`
**Purpose:** Test land masking functionality
**Description:** Validates land/ocean masking for estimation grids.

---

## Validation Methods

### 40. validateTOAR_monthly.m
**Location:** `/home/user/gO3_II_mo/validateTOAR_monthly.m`
**Purpose:** Monthly Leave-One-Out Cross-Validation (LOOCV)
**Function Signature:** `valResults = validateTOAR_monthly(obs, go, cov, valYear, valMonths, BMEparam, forceEstimation)`
**Key Inputs:**
- `obs`: Observational data
- `go`: Global offset
- `cov`: Covariance
- `valYear`: Year to validate
- `valMonths`: Months to validate (1-12)
- `BMEparam`: BME parameters
- `forceEstimation`: Cache control (0=use cache, 1=recompute)

**Key Outputs:**
- `valResults`: Structure with monthly validation results:
  - `.Y_obs`, `.Y_est`: Observed and estimated values
  - `.stats`: Validation metrics per month
  - `.annual_stats`: Aggregated annual statistics

**Description:** Performs Leave-One-Out Cross-Validation at monthly resolution. Uses caching for efficiency.

---

### 41. run_TOARvalidation.m
**Location:** `/home/user/gO3_II_mo/run_TOARvalidation.m`
**Purpose:** Master validation script
**Function Signature:** `run_TOARvalidation(scenarios, years, methods)`
**Description:** Orchestrates validation across multiple scenarios, years, and methods.

---

### 42. runCBCV_toar.m
**Location:** `/home/user/gO3_II_mo/runCBCV_toar.m`
**Purpose:** Checker-Board Cross-Validation (deprecated)
**Function Signature:** `[cbcvResults, cbcvStats] = runCBCV_toar(obs, go, cov, valParam)`
**Description:** Implements checker-board cross-validation. **DEPRECATED** - replaced by runCBV_toar.m.

---

### 43. runCBV_toar.m
**Location:** `/home/user/gO3_II_mo/runCBV_toar.m`
**Purpose:** Checker-Board Validation (CBV) with monthly processing
**Function Signature:** `[cbvResults, cbvStats] = runCBV_toar(obs, go, cov, valParam)`
**Key Inputs:**
- `obs`: Observations
- `go`: Global offset
- `cov`: Covariance
- `valParam`: Structure with:
  - `.valYears`: Years to validate
  - `.valMonths`: Months (1-12)
  - `.boxSizes`: Checker sizes in degrees
  - `.nFolds`: Number of folds (typically 2)
  - `.softData`: Optional soft data
  - `.BMEmethod`: Method code

**Key Outputs:**
- `cbvResults`: Cell array of monthly results
- `cbvStats`: Table with aggregated statistics per box size/fold/year

**Description:** Implements checker-board validation with monthly processing and STUG format. **NEW IMPLEMENTATION** (Jan 2026). Forces ±1 year temporal windows. Saves monthly results to disk.

---

### 44. evaluateFold_CBCV.m
**Location:** `/home/user/gO3_II_mo/evaluateFold_CBCV.m`
**Purpose:** Evaluate single fold for CBCV (deprecated)
**Description:** Helper for runCBCV_toar.m. **DEPRECATED**.

---

### 45. evaluateFold_CBV_monthly.m
**Location:** `/home/user/gO3_II_mo/evaluateFold_CBV_monthly.m`
**Purpose:** Evaluate single month for CBV
**Function Signature:** `monthResults = evaluateFold_CBV_monthly(obs, go, cov, KG, KS, BMEparam, trainMask, valMask, valYear, valMonth)`
**Key Inputs:**
- `obs`, `go`, `cov`: Data structures
- `KG`, `KS`: Knowledge bases
- `BMEparam`: BME parameters
- `trainMask`, `valMask`: Station masks
- `valYear`, `valMonth`: Target period

**Key Outputs:**
- `monthResults`: Structure with:
  - `.Y_obs`, `.Y_est`: Observed and estimated
  - `.XkBMEv`: Variances
  - `.nValid`: Number of valid pairs

**Description:** Core monthly CBV evaluation. Uses ±1 year temporal window. Filters to only s/t points with observations. Uses STUG format.

---

### 46. computeMetrics.m
**Location:** `/home/user/gO3_II_mo/computeMetrics.m`
**Purpose:** Compute validation statistics
**Function Signature:** `stats = computeMetrics(zHat, z, sigma_i)`
**Key Inputs:**
- `zHat`: Predicted/estimated values
- `z`: Observed values
- `sigma_i`: Optional uncertainties

**Key Outputs:**
- `stats`: Structure with metrics:
  - `.MSE`, `.RMSE`: Error metrics
  - `.MAE`, `.ME`: Absolute/mean errors
  - `.r2`, `.r2_QA`: R-squared (standard and quality-adjusted)
  - `.MS`, `.RMSS`: Standardized errors

**Description:** Comprehensive calculation of validation and error metrics. **FIXED** merge conflict (Jan 2026).

---

### 47. calculateValidationStats.m
**Location:** `/home/user/gO3_II_mo/calculateValidationStats.m`
**Purpose:** Extended validation statistics
**Function Signature:** `stats = calculateValidationStats(Y_obs, Y_est, obs)`
**Description:** Computes extended set of validation metrics including NMB, NME, IOA, FAC2.

---

### 48. getCheckerBoard.m
**Location:** `/home/user/gO3_II_mo/getCheckerBoard.m`
**Purpose:** Generate checker-board spatial pattern
**Function Signature:** `[trainMask, valMask] = getCheckerBoard(sMS, boxSize, fold, plotFlag)`
**Key Inputs:**
- `sMS`: Station locations [n × 2]
- `boxSize`: Box size in degrees
- `fold`: Fold number (1 or 2)
- `plotFlag`: Optional visualization (0/1)

**Key Outputs:**
- `trainMask`: Logical mask for training stations
- `valMask`: Logical mask for validation stations

**Description:** Generates checker-board pattern for spatial cross-validation. **UPDATED** (Jan 2026) to include optional visualization with `plotFlag=1`.

---

## Soft Data Management

### 49. fuseSoftData.m
**Location:** `/home/user/gO3_II_mo/fuseSoftData.m`
**Purpose:** Fuse multiple CTM soft datasets
**Function Signature:** `fusedData = fuseSoftData(softDataCell, method, varargin)`
**Key Inputs:**
- `softDataCell`: Cell array of soft data structures
- `method`: 'selection', 'bma', or 'concat'
  - 'selection': Choose best model per location (lowest variance)
  - 'bma': Bayesian Model Averaging
  - 'concat': Concatenate all datasets
- Optional name-value pairs: 'tolerance', 'verbose'

**Key Outputs:**
- `fusedData`: Fused soft data structure with:
  - `.Z`, `.Zv`: Fused mean and variance
  - `.fusionMethod`: Method used
  - `.sourceModels`: Original models
  - `.nModelsAvailable`: Data availability count

**Description:** Combines multiple CTM models using various fusion methods.

---

### 50. getModelatObs.m
**Location:** `/home/user/gO3_II_mo/getModelatObs.m`
**Purpose:** Extract model values at observation locations
**Function Signature:** `modelObsPairs = getModelatObs(model, obs)`
**Key Inputs:**
- `model`: CTM model structure
- `obs`: Observation structure

**Key Outputs:**
- `modelObsPairs`: Structure with:
  - `.sMS`: Observation locations
  - `.modelval`: Interpolated model values
  - `.obsval`: Observation values
  - `.nonNaNPairs`: Valid data mask

**Description:** Interpolates model values to observation locations for model-observation comparison.

---

### 51. plotSoftData.m
**Location:** `/home/user/gO3_II_mo/plotSoftData.m`
**Purpose:** Visualize RAMP-corrected soft data
**Function Signature:** `plotSoftData(softData, obs, timeIndex, plotType)`
**Key Inputs:**
- `softData`: RAMP-corrected CTM structure
- `obs`: Observational data (optional overlay)
- `timeIndex`: Time indices to plot
- `plotType`: 'mean', 'variance', or 'both'

**Key Outputs:**
- Figures saved to `./2softdata/plots/`

**Description:** Creates maps of soft data mean and variance fields with optional observation overlay.

---

### 52. subsetSoftData.m
**Location:** `/home/user/gO3_II_mo/subsetSoftData.m`
**Purpose:** Subset soft data by region/time
**Function Signature:** `softDataSubset = subsetSoftData(softData, spatialBounds, timeBounds)`
**Description:** Filters soft data to specified spatial and temporal bounds.

---

### 53. getCTMspatialGrid.m
**Location:** `/home/user/gO3_II_mo/getCTMspatialGrid.m`
**Purpose:** Extract CTM model spatial grid
**Function Signature:** `gridInfo = getCTMspatialGrid(modelName)`
**Description:** Retrieves spatial grid information for a specific CTM model.

---

### 54. stg_to_stug.m
**Location:** `/home/user/gO3_II_mo/stg_to_stug.m`
**Purpose:** Convert STG to STUG format (simple version)
**Function Signature:** `stug_data = stg_to_stug(stg_data)`
**Description:** Simple conversion from sparse to uniform grid format.

---

### 55. reformat_stg_to_stug.m
**Location:** `/home/user/gO3_II_mo/reformat_stg_to_stug.m`
**Purpose:** Reformat space-time grid with validation
**Function Signature:** `grid_data = reformat_stg_to_stug(stg_data, varargin)`
**Key Inputs:**
- `stg_data`: Sparse space-time grid structure
- Optional: 'tolerance', 'verbose'

**Key Outputs:**
- `grid_data`: Uniform space-time grid (STUG) structure with:
  - `.x`, `.y`: Grid vectors
  - `.time`: Time vector
  - `.Lon`, `.Lat`: Coordinate meshes
  - `.Z`: [nx × ny × nt] data array
  - `.Zv`: [nx × ny × nt] variance array

**Description:** Validates grid uniformity and reformats data for efficient neighborhood searches. Enhanced version with error checking.

---

### 56. example_reformat_usage.m
**Location:** `/home/user/gO3_II_mo/example_reformat_usage.m`
**Purpose:** Example script for STG to STUG conversion
**Description:** Demonstrates proper usage of reformat_stg_to_stug.m.

---

## Visualization & Plotting

### 57. plotField.m
**Location:** `/home/user/gO3_II_mo/plotField.m`
**Purpose:** Create color map of field values
**Function Signature:** `plotField(sk, zk, ax, maskcontour, nxpix, nypix)`
**Key Inputs:**
- `sk`: Grid points [n × 2]
- `zk`: Field values [n × 1]
- `ax`: Display area [xmin xmax ymin ymax]
- `maskcontour`: Polygon for masking (land/ocean)
- `nxpix`, `nypix`: Grid resolution for interpolation

**Key Outputs:**
- Figure with color map

**Description:** Utility function to create interpolated color maps with optional masking.

---

### 58. plotFieldTOAR.m
**Location:** `/home/user/gO3_II_mo/plotFieldTOAR.m`
**Purpose:** Enhanced field plotting
**Function Signature:** `plotFieldTOAR(sk, zk, ax, maskcontour, nxpix, nypix, options)`
**Description:** Improved version of plotField with efficient polygon masking and additional options.

---

### 59. plotTOARsBME.m
**Location:** `/home/user/gO3_II_mo/plotTOARsBME.m`
**Purpose:** Plot BME spatial estimates
**Function Signature:** `plotTOARsBME(obs, go, BMEs, BMEparam, estParam)`
**Key Inputs:**
- `obs`: Observations
- `go`: Global offset
- `BMEs`: BME results
- `BMEparam`: BME parameters
- `estParam`: Plot parameters with `.plotResults` field:
  - 1: BME estimates only
  - 2: BME + observations overlay
  - 3: + residuals
  - 4: + uncertainty maps

**Key Outputs:**
- Figures saved to `./5BMEspatialPlots/figs/`

**Description:** Creates publication-quality maps of BME estimates with observation overlay and residual plots.

---

### 60. plotTOARsBMEvar.m
**Location:** `/home/user/gO3_II_mo/plotTOARsBMEvar.m`
**Purpose:** Plot BME uncertainty/variance maps
**Function Signature:** `plotTOARsBMEvar(obs, go, BMEs, BMEparam, estParam)`
**Key Inputs:**
- `estParam.plotVariance`:
  - 1: Standard deviation
  - 2: Variance
  - 3: Coefficient of variation (%)
  - 4: All three

**Key Outputs:**
- Uncertainty maps saved to `./5BMEspatialPlots/figs/variance/`

**Description:** Visualizes BME estimation uncertainty in multiple formats.

---

### 61. plotTOARvalidation.m
**Location:** `/home/user/gO3_II_mo/plotTOARvalidation.m`
**Purpose:** Plot validation results
**Function Signature:** `plotTOARvalidation(valResults, options)`
**Description:** Creates scatter plots, Q-Q plots, and error distributions for validation results.

---

### 62. plotCBCVresults.m
**Location:** `/home/user/gO3_II_mo/plotCBCVresults.m`
**Purpose:** Plot CBCV results (deprecated)
**Description:** Visualization for deprecated CBCV method.

---

### 63. plotCBVresults.m
**Location:** `/home/user/gO3_II_mo/plotCBVresults.m`
**Purpose:** Plot CBV results with method comparison
**Function Signature:** `plotCBVresults(cbvResults, cbvStats, valParam, varargin)`
**Key Inputs:**
- `cbvResults`: CBV results structure
- `cbvStats`: Statistics table
- `valParam`: Validation parameters
- `varargin`: Additional cbvStats tables for comparison

**Key Outputs:**
- Figures saved to `./7validation/CBV/figures/`

**Description:** Creates comparison plots across methods and box sizes. Supports multiple method comparison via varargin. **NEW** (Jan 2026).

---

### 64. visualizeBMEdiagnostic.m
**Location:** `/home/user/gO3_II_mo/visualizeBMEdiagnostic.m`
**Purpose:** Diagnostic visualization for BME artifacts
**Function Signature:** `visualizeBMEdiagnostic(BMEresultFile, options)`
**Key Inputs:**
- `BMEresultFile`: Path to BME result .mat file
- `options`: Structure with:
  - `.metric`: 'mean', 'variance', or 'std'
  - `.display`: 'obs', 'grid', or 'both'
  - `.modelName`: CTM model for grid overlay
  - `.colormap`, `.clim`: Display options

**Key Outputs:**
- Diagnostic figures saved to `./5BMEspatialPlots/diagnostic/`

**Description:** Creates diagnostic plots for identifying artifacts (e.g., vertical lines) in BME results. See README_diagnostic_visualization.md.

---

### 65. example_diagnose_vertical_lines.m
**Location:** `/home/user/gO3_II_mo/example_diagnose_vertical_lines.m`
**Purpose:** Example diagnostic workflow
**Description:** Demonstrates usage of visualizeBMEdiagnostic for troubleshooting vertical line artifacts.

---

### 66. getLandContour.m
**Location:** `/home/user/gO3_II_mo/getLandContour.m`
**Purpose:** Load land boundary contours
**Function Signature:** `landContour = getLandContour(dataDir)`
**Key Inputs:**
- `dataDir`: Data directory (default: '1data')

**Key Outputs:**
- `landContour`: [n × 2] matrix of [lon, lat] coastline points

**Description:** Loads coastline data for masking ocean areas in maps.

---

### 67. getOverhangRAMPv6_updated.m
**Location:** `/home/user/gO3_II_mo/getOverhangRAMPv6_updated.m`
**Purpose:** Load updated RAMP overhang data
**Description:** Utility for handling RAMP data edge cases.

---

## Diagnostic Tools

### 68. diagnoseBMEinputs.m
**Location:** `/home/user/gO3_II_mo/diagnoseBMEinputs.m`
**Purpose:** Diagnose BME input data issues
**Function Signature:** `report = diagnoseBMEinputs(KG, KS, BMEparam)`
**Description:** Validates BME inputs and identifies potential issues.

---

### 69. diagnoseIssue.m
**Location:** `/home/user/gO3_II_mo/diagnoseIssue.m`
**Purpose:** General diagnostic tool
**Function Signature:** `diagnoseIssue(data, issueType)`
**Description:** Investigates various data and estimation issues.

---

### 70. parseBMEcode.m
**Location:** `/home/user/gO3_II_mo/parseBMEcode.m`
**Purpose:** Decode extended BME method codes
**Function Signature:** `parsedParams = parseBMEcode(BMEcode)`
**Key Inputs:**
- `BMEcode`: Extended BME code (e.g., '0100-3F-M-L-1')

**Key Outputs:**
- `parsedParams`: Structure with decoded parameters

**Description:** Decodes extended BME codes including hexadecimal CTM bitmask.

---

### 71. parseBMEmethod.m
**Location:** `/home/user/gO3_II_mo/parseBMEmethod.m`
**Purpose:** Parse 6-digit BME method code
**Function Signature:** `[obsUsed, probaType, localMean, nhmax, nsmax] = parseBMEmethod(BMEmethod6digits)`
**Description:** Extracts parameters from 6-digit legacy BME code.

---

### 72. parseTOARBMEmethod.m
**Location:** `/home/user/gO3_II_mo/parseTOARBMEmethod.m`
**Purpose:** Parse 8-digit TOAR BME method code
**Function Signature:** `[obsType, CTMtype, ...] = parseTOARBMEmethod(BMEmethod8digits)`
**Description:** Decodes 8-digit method code including RAMP parameters.

---

### 73. generateBMEcode.m
**Location:** `/home/user/gO3_II_mo/generateBMEcode.m`
**Purpose:** Generate extended BME method code
**Function Signature:** `code = generateBMEcode(methodType, CTMbitmask, nsmax, nhmax, order, duplicateHandling)`
**Key Inputs:**
- `methodType`: 4-digit base code
- `CTMbitmask`: Hexadecimal CTM model mask
- `nsmax`, `nhmax`: Neighbor codes
- `order`: Trend order
- `duplicateHandling`: Optional duplicate removal flag

**Key Outputs:**
- `code`: Extended BME code string (e.g., '0100-3F-M-L-1')

**Description:** Constructs extended BME codes from parameters. Inverse of parseBMEcode. **UPDATED** (Dec 2025).

---

### 74. decodeCTMmodels.m
**Location:** `/home/user/gO3_II_mo/decodeCTMmodels.m`
**Purpose:** Decode CTM model bitmask
**Function Signature:** `[models, modelIndices] = decodeCTMmodels(bitmask_hex)`
**Key Inputs:**
- `bitmask_hex`: Hex string (e.g., '3F') or numeric

**Key Outputs:**
- `models`: Cell array of model names
- `modelIndices`: Numeric indices

**CTM Models**:
- 0x01: MERRA2-GMI
- 0x02: M3fusion
- 0x04: OMI-MLS
- 0x08: IASI-GOME2
- 0x10: UKML
- 0x20: NJML

**Description:** Converts bitmask to list of CTM models. **CREATED** (Dec 2025).

---

### 75. getCTMneighborCount.m
**Location:** `/home/user/gO3_II_mo/getCTMneighborCount.m`
**Purpose:** Convert nsmax code to neighbor count
**Function Signature:** `nsmax = getCTMneighborCount(code)`
**Key Inputs:**
- `code`: Character code ('S'=small, 'M'=medium, 'L'=large, 'X'=extra-large)

**Key Outputs:**
- `nsmax`: Numeric neighbor count

**Description:** Decodes soft data neighbor limit from character code. **CREATED** (Dec 2025).

---

### 76. getHardNeighborCount.m
**Location:** `/home/user/gO3_II_mo/getHardNeighborCount.m`
**Purpose:** Convert nhmax code to neighbor count
**Function Signature:** `nhmax = getHardNeighborCount(code)`
**Description:** Decodes hard data neighbor limit from character code. **CREATED** (Dec 2025).

---

### 77. describeBMEcode.m
**Location:** `/home/user/gO3_II_mo/describeBMEcode.m`
**Purpose:** Human-readable BME code description
**Function Signature:** `description = describeBMEcode(BMEcode)`
**Key Outputs:**
- `description`: Formatted text description of BME method

**Description:** Generates human-readable interpretation of extended BME codes. **CREATED** (Dec 2025).

---

### 78. compareBMEcodes.m
**Location:** `/home/user/gO3_II_mo/compareBMEcodes.m`
**Purpose:** Side-by-side comparison of BME codes
**Function Signature:** `compareBMEcodes(code1, code2, ...)`
**Description:** Displays side-by-side comparison of multiple BME method codes. **CREATED** (Dec 2025).

---

### 79. BMEmethodType.m
**Location:** `/home/user/gO3_II_mo/BMEmethodType.m`
**Purpose:** Identify BME method type
**Function Signature:** `methodType = BMEmethodType(BMEmethodCode)`
**Description:** Returns descriptive method type from BME code.

---

## Utility & Helper Functions

### 80. datenum2decyear.m
**Location:** `/home/user/gO3_II_mo/datenum2decyear.m`
**Purpose:** Convert MATLAB datenum to decimal year
**Function Signature:** `decimalYear = datenum2decyear(datenumValue)`
**Description:** Time format conversion utility.

---

### 81. createTOARanalysisReport.m
**Location:** `/home/user/gO3_II_mo/createTOARanalysisReport.m`
**Purpose:** Generate analysis report
**Function Signature:** `createTOARanalysisReport(obs, go, cov, BMEs, valResults)`
**Description:** Creates comprehensive PDF/HTML report of TOAR analysis.

---

## Examples & Tests

### 82. example_fuseSoftData.m
**Location:** `/home/user/gO3_II_mo/example_fuseSoftData.m`
**Purpose:** Example soft data fusion
**Description:** Demonstrates fuseSoftData usage with multiple CTM models.

---

### 83. example_krigingME_stug_multi.m
**Location:** `/home/user/gO3_II_mo/example_krigingME_stug_multi.m`
**Purpose:** Example multi-dataset kriging
**Description:** Demonstrates krigingME_stug_multi with cell array of soft datasets. **CREATED** (Nov 2025).

---

### 84. test_softdata_workflow.m
**Location:** `/home/user/gO3_II_mo/test_softdata_workflow.m`
**Purpose:** Test soft data processing
**Description:** Comprehensive test of soft data creation, fusion, and integration.

---

### 85. test_BME_coding_system.m
**Location:** `/home/user/gO3_II_mo/test_BME_coding_system.m`
**Purpose:** Test BME coding functions
**Description:** Validates generateBMEcode, decodeCTMmodels, parseBMEcode, etc. **CREATED** (Dec 2025).

---

### 86. test_neighbours_stg_crash_fix.m
**Location:** `/home/user/gO3_II_mo/test_neighbours_stg_crash_fix.m`
**Purpose:** Test neighbours_stg edge cases
**Description:** Tests neighbours_stg.m with restrictive dmax values to verify crash fix. **CREATED** (Dec 2025).

---

### 87. example_CBCV.m
**Location:** `/home/user/gO3_II_mo/example_CBCV.m`
**Purpose:** Example CBCV workflow (deprecated)
**Description:** Demonstrates checker-board cross-validation. **DEPRECATED** - use CBV instead.

---

### 88. hpc_validation/scripts/run_validation_worker.m
**Location:** `/home/user/gO3_II_mo/hpc_validation/scripts/run_validation_worker.m`
**Purpose:** HPC validation worker script
**Description:** Worker script for parallel validation on HPC systems.

---

### 89. hpc_validation/aggregate_results.m
**Location:** `/home/user/gO3_II_mo/hpc_validation/aggregate_results.m`
**Purpose:** Aggregate HPC validation results
**Function Signature:** `aggregate_results(scenarios, years)`
**Description:** Collects and aggregates validation results from HPC jobs.

---

## Key Data Structures

### Observation Structure (obs)
```matlab
obs.Y              % [n_stations × n_times] observation matrix
obs.sMS            % [n_stations × 2] spatial coordinates [lon, lat]
obs.tME            % [1 × n_times] time vector (decimal years)
obs.stationID      % Cell array of station identifiers
obs.stationType    % Cell array of station types
obs.Yname          % Variable name
obs.Ylabel         % Variable label with units
obs.logTransf      % Log transformation flag
```

### Global Offset Structure (go)
```matlab
go.sMS             % [n_space × 2] spatial locations
go.tME             % [1 × n_times] time vector
go.ms              % [n_space × 1] spatial mean trend
go.mt              % [1 × n_times] temporal mean trend
go.sMSraw          % Raw spatial coordinates
go.msRaw           % Raw spatial means
go.tMEraw          % Raw time vector
go.mtRaw           % Raw temporal means
go.scenario        % Method code (0-4)
```

### Covariance Structure (cov)
```matlab
cov.covmodel       % Cell of model type strings
cov.covparam       % Cell of parameter vectors
cov.Cr             % Experimental spatial covariance
cov.rLag           % Spatial lag values
cov.Ct             % Experimental temporal covariance
cov.tLag           % Temporal lag values
cov.var            % Variance (sill)
```

### Knowledge Base Structures (KG, KS)
```matlab
% General Knowledge Base (KG)
KG.order           % Order of local mean (NaN or 0)
KG.covmodel        % Covariance model
KG.covparam        % Covariance parameters

% Site-specific Knowledge Base (KS)
KS.harddata.p      % Hard data locations [n × 3] [lon lat time]
KS.harddata.v      % Hard data values
KS.harddata.e      % Hard data uncertainties
KS.softdata        % Soft data structure (format-dependent)
```

### BME Results Structure (BMEs)
```matlab
BMEs.sk            % [n_est × 2] estimation points
BMEs.tk            % Estimation time
BMEs.YkBMEm        % [n_est × 1] BME mean estimates (with offset)
BMEs.XkBMEm        % [n_est × 1] Residual estimates (offset-removed)
BMEs.XkBMEv        % [n_est × 1] Estimation variance
BMEs.estGridArea   % [lon_min lon_max lat_min lat_max]
```

---

## Extended BME Method Code Format

### Structure: `[4 digits]-[2 hex]-[1 char]-[1 char]-[1 char]`

**Example:** `0100-3F-M-L-1`

**Components:**
1. **Method Type** (4 digits): e.g., 0100 = kriging with hard+soft data
2. **CTM Bitmask** (2 hex): Hexadecimal encoding of CTM models
   - 01 = MERRA2-GMI
   - 02 = M3fusion
   - 04 = OMI-MLS
   - 08 = IASI-GOME2
   - 10 = UKML
   - 20 = NJML
   - 3F = All 6 models
3. **Soft Neighbors** (1 char): S=small, M=medium, L=large, X=extra-large
4. **Hard Neighbors** (1 char): S=small (25), M=medium (50), L=large (75), X=extra-large (100)
5. **Order** (1 char): 0 or 1 (trend order)

---

## Cross-Reference: Key Function Dependencies

```
Main Estimation Workflow:
  getTOARobservationalData.m
  ↓
  getTOARglobalOffset.m
  ↓
  getTOARautoCov.m → getTOARcovariance.m
  ↓
  getTOARknowledgeBase.m
    ├── getKB.m
    ├── getBMEparam.m
    ├── getTOARmapGrid.m
    ├── getTOARareaBoundaries.m
    └── [optional: loadRAMPdata.m → createSoftDataStructure.m]
  ↓
  estTOARsBME.m
    ├── krigingME_stug.m or krigingME_stug_multi.m
    ├── neighbours_stug_optimized.m
    ├── reformat_stg_to_stug.m
    └── stmeanDensified.m
  ↓
  plotTOARsBME.m + plotTOARsBMEvar.m

Validation Workflows:
  LOOCV: validateTOAR_monthly.m → computeMetrics.m
  CBV: runCBV_toar.m → evaluateFold_CBV_monthly.m → computeMetrics.m

Diagnostic Tools:
  visualizeBMEdiagnostic.m
  diagnoseBMEinputs.m
  example_diagnose_vertical_lines.m

BME Code Management:
  generateBMEcode.m ↔ parseBMEcode.m
  decodeCTMmodels.m
  getCTMneighborCount.m, getHardNeighborCount.m
  describeBMEcode.m, compareBMEcodes.m
```

---

## Summary Statistics

| Category | File Count | Key Files |
|----------|------------|-----------|
| Data Loading & Processing | 12 | getTOARobservationalData, loadRAMPdata, extractModelSpatialInfo |
| Global Offset | 4 | getTOARglobalOffset, valTOARglobalOffsets, plotTOARglobalOffset |
| Covariance Modeling | 4 | getTOARautoCov, getTOARcovariance, plotTOARcov |
| Knowledge Base | 4 | getTOARknowledgeBase, getKB, getBMEparam, createSoftDataStructure |
| BME Estimation & Kriging | 13 | estTOARsBME, krigingME_stug*, neighbours_stug_optimized, stmeanDensified |
| Validation | 10 | validateTOAR_monthly, runCBV_toar, evaluateFold_CBV_monthly, computeMetrics |
| Soft Data Management | 7 | fuseSoftData, getModelatObs, plotSoftData, reformat_stg_to_stug |
| Visualization & Plotting | 11 | plotTOARsBME, plotTOARsBMEvar, visualizeBMEdiagnostic, plotCBVresults |
| Diagnostic Tools | 12 | parseBMEcode, decodeCTMmodels, describeBMEcode, diagnoseBMEinputs |
| Utilities & Helpers | 5 | datenum2decyear, getLandContour, BMEmethodType |
| Examples & Tests | 7 | example_*, test_* |
| **TOTAL** | **89 detailed** | *+ addendum below; 132 `.m` files total in repo root* |

---

## Recent Updates (2025-2026)

### December 2025
- **BME Coding System**: Created extended BME code format with hexadecimal CTM bitmask
- Created: `generateBMEcode.m`, `decodeCTMmodels.m`, `parseBMEcode.m`, `getCTMneighborCount.m`, `getHardNeighborCount.m`, `describeBMEcode.m`, `compareBMEcodes.m`
- Created: `test_BME_coding_system.m`
- **neighbours_stg fix**: Fixed crash with restrictive dmax values
- Created: `test_neighbours_stg_crash_fix.m`, `ANALYSIS_neighbours_stg_crash.md`

### November 2025
- **Multi-dataset kriging**: Created `krigingME_stug_multi.m` for multiple soft datasets
- Created: `example_krigingME_stug_multi.m`, `README_krigingME_stug_multi.md`

### January 2026
- **Checker-Board Validation**: Converted from cross-validation to validation with monthly processing
- **Updated**: `runCBV_toar.m` - monthly loop, STUG format, ±1 year windows
- **Created**: `evaluateFold_CBV_monthly.m` - monthly CBV core function
- **Created**: `plotCBVresults.m` - multi-method comparison plotting
- **Updated**: `getCheckerBoard.m` - added optional visualization (plotFlag parameter)
- **Fixed**: `computeMetrics.m` - resolved merge conflict
- **Created**: `SESSION_CONTEXT_CBV_IMPLEMENTATION.md`

---

## File Organization by Directory

```
/home/user/gO3_II_mo/
├── [Root] - 83 MATLAB files
├── hpc_validation/
│   ├── scripts/run_validation_worker.m
│   └── aggregate_results.m
└── 2softdata/
    └── (CTM soft data files)
```

---

## Added Since Jan 2026 (addendum — May 30, 2026)

The core catalog above was written at 89 files; the repo root now holds **132 `.m` files**.
The notable additions below are grouped by purpose. For the authoritative, current
high-level map, see **CLAUDE.md** (entry points, diagnostics, BME-code parsing, CBV phases).

**Entry-point scripts** (edit CONFIGURATION block, then run):
- `runBME_estimation.m` — production spatial BME estimation → `5BMEspatialPlots/`
- `runBME_temporal.m` — fast temporal series at representative sites → `6BMEtemporalSeries/`

**Temporal workflow:**
- `selectRepresentativeSites.m` — pick one representative station per region
- `estimateBME_AtRepSites.m` — BME at exact site locations (powers temporal workflow)
- `plotBME_TemporalSeries.m` — temporal series plots + `temporal_statistics.csv`

**Estimators / diagnostics:**
- `estTOARsBMEoptim.m` — optimized estimator (variance smoothing, grid offset, STUG)
- `estTOARsBME_diag.m` — diagnostic-instrumented estimator
- `diagnoseBMEinputs.m`, `visualizeBMEdiagnostic.m` — singular-matrix / vertical-line debugging

**BME-code handling (extended `-XX` hex CTM bitmask):**
- `parseBMEcode.m` — **canonical** parser (legacy: `parseTOARBMEmethod.m`, `parseBMEmethod.m`)
- `decodeCTMmodels.m` — hex bitmask → model list; `generateBMEcode.m` — build extended codes

**Phased CBV plotting:**
- `plotCBVresults_Phase1.m` (overview), `_Phase2.m` (residual/uncertainty diagnostics),
  `_Phase3.m` (config comparison), `_Phase4.m` (cross-config time series)
- Helpers: `plotResidualAnalysis.m`, `plotUncertaintyAnalysis.m`, `plotRegionalBreakdown.m`,
  `plotConfigComparison.m`, `plotSoftDataContribution.m`, `plotTemporalTrends.m`

**Removed since Jan 2026** (entries #42, #44, #62 above are stale — files no longer exist):
`runCBCV_toar.m`, `evaluateFold_CBCV.m`, `plotCBCVresults.m` (the "CBCV" spelling was
superseded by the `CBV` / `runCBV_toar` implementation).

---

**End of Catalog**

*Core catalog documents 89 MATLAB files as of January 17, 2026; addendum covers additions through May 30, 2026.*
