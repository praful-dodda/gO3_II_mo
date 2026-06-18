# BME Estimation Workflows: Spatial vs Temporal

This document explains the separation of BME spatial estimation from BME temporal series analysis, providing two independent workflows optimized for different use cases.

---

## Table of Contents

1. [Overview](#overview)
2. [Workflow Comparison](#workflow-comparison)
3. [Spatial Workflow](#spatial-workflow)
4. [Temporal Workflow](#temporal-workflow)
5. [When to Use Each Workflow](#when-to-use-each-workflow)
6. [Architecture Details](#architecture-details)
7. [Migration Guide](#migration-guide)

---

## Overview

### The Problem

Previously, generating temporal series plots required:
1. **Full spatial BME estimation** on dense grids (`estTOARsBME.m`)
2. **Extracting** time series from grid results
3. **Plotting** temporal analysis

This was inefficient when you only needed temporal analysis at a few representative sites.

### The Solution

We now provide **two independent workflows**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     SPATIAL WORKFLOW                            │
│  Purpose: Create spatial maps of BME estimates                 │
│  Script: runBME_estimation.m                                    │
│  Speed: Slower (full grid estimation)                           │
│  Output: Spatial maps + temporal series                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     TEMPORAL WORKFLOW                            │
│  Purpose: Analyze temporal patterns at key sites                │
│  Script: runBME_temporal.m                                       │
│  Speed: Much faster (site-only estimation)                       │
│  Output: Temporal series plots + statistics                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Workflow Comparison

| Feature | Spatial Workflow | Temporal Workflow |
|---------|-----------------|-------------------|
| **Main Script** | `runBME_estimation.m` | `runBME_temporal.m` |
| **Estimation Function** | `estTOARsBME.m` | `estimateBME_AtRepSites.m` |
| **Estimation Points** | Dense spatial grid | Representative sites only |
| **Speed** | Slower (minutes to hours) | Fast (seconds to minutes) |
| **Memory Usage** | High (full grids) | Low (sites only) |
| **Spatial Maps** | ✓ Yes | ✗ No |
| **Temporal Plots** | ✓ Yes (from grids) | ✓ Yes (exact sites) |
| **Leave-One-Out CV** | Optional | Built-in |
| **Best For** | Spatial analysis, maps | Temporal validation, model comparison |
| **Typical Use** | Final production maps | Quick analysis, testing, validation |

---

## Spatial Workflow

### Purpose
Generate comprehensive spatial maps of BME estimates across a geographic domain.

### Main Script
```matlab
runBME_estimation.m
```

### Key Steps
1. Load soft data (CTM/satellite)
2. Run `analyzeTOAR` pipeline (obs → GO → cov → KB)
3. **Grid-based BME estimation** via `estTOARsBME.m`
   - Estimates at all grid points
   - Creates spatial maps
4. Optional: Generate temporal plots from grids
5. Optional: Enhanced spatial statistics

### Configuration Example
```matlab
% In runBME_estimation.m

% Grid configuration
analyzeParam.areaCode = 2;           % Europe
analyzeParam.mapResolution = 1.0;    % 1 degree grid
analyzeParam.keepOnlyLand = true;    % Land points only

% BME method
analyzeParam.BMEmethod = '13000313-02';  % Obs + M3fusion

% Estimation years
estYears = [2017];
analyzeParam.tkVec = (2017):(1/12):(2017 + 11/12);  % Monthly

% Run full workflow
[obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);
```

### Outputs
```
5BMEspatialPlots/
├── BME{method}_{params}_time{tk}.mat    # Spatial estimates (one per time)
├── figs/spatial/                        # Spatial maps
│   ├── BME_mean_*.png
│   ├── BME_std_*.png
│   └── BME_CV_*.png
└── figs_temporal/{method}/              # Temporal plots (if enabled)
    ├── temporal_full_{region}.png
    └── temporal_statistics.csv
```

### Typical Runtime
- **Small domain** (e.g., Europe, 1° res): 5-15 minutes per year
- **Large domain** (e.g., Global, 1° res): 30-120 minutes per year
- **High resolution** (e.g., 0.5° res): 2-8x longer

---

## Temporal Workflow

### Purpose
Fast temporal analysis at representative sites **without** full spatial grid estimation.

### Main Script
```matlab
runBME_temporal.m
```

### Key Steps
1. Load soft data (CTM/satellite)
2. Load observational data
3. **Select representative sites** (`selectRepresentativeSites`)
   - One site per geographic region
   - Based on data completeness
4. Prepare BME components (obs → GO → cov → KB)
5. **Site-only BME estimation** via `estimateBME_AtRepSites.m`
   - Estimates ONLY at representative sites
   - Leave-one-out cross-validation (excludes nearby obs)
6. Generate temporal series plots

### Configuration Example
```matlab
% In runBME_temporal.m

% Site selection
analyzeParam.areaCode = 0;                    % Global
analyzeParam.minCompleteness = 0.70;          % ≥70% data coverage
analyzeParam.minObservations = 24;            % ≥24 observations
analyzeParam.selectionMethod = 'completeness'; % Selection criterion

% Leave-one-out configuration
analyzeParam.exclusionRadius = 0.5;           % Exclude obs within 0.5°

% BME method
analyzeParam.BMEmethod = '10000133';          % Obs-only (for speed)

% Estimation years
estYears = [2017];
analyzeParam.tkVec = (2017):(1/12):(2017 + 11/12);  % Monthly

% Run temporal-only workflow
siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, ...
    KG, KS, BMEparam, analyzeParam.tkVec, ...
    'exclusionRadius', 0.5, 'verbose', true);
```

### Outputs
```
5BMEspatialPlots/
├── representative_sites.mat             # Selected sites
├── site_estimates_{method}_year{year}.mat  # Site estimates
└── figs_temporal/{method}_temporal_only/   # Temporal plots
    ├── temporal_full_{region}.png       # 6-panel plots
    ├── temporal_simple_{region}.png     # Simple time series
    ├── temporal_all_regions.png         # Multi-region comparison
    └── temporal_statistics.csv          # Validation metrics
```

### Typical Runtime
- **10 sites × 12 months**: 10-30 seconds
- **20 sites × 12 months**: 20-60 seconds
- **50 sites × 12 months**: 1-3 minutes

**Speedup**: **10-100x faster** than spatial workflow!

---

## When to Use Each Workflow

### Use Spatial Workflow When:

✓ You need **spatial maps** for visualization or analysis
✓ Creating **final production results**
✓ Analyzing **spatial patterns** (gradients, hot spots, etc.)
✓ Interpolating to **arbitrary locations** (not just specific sites)
✓ Publishing **spatial distribution figures**
✓ Comparing **spatial coverage** across methods

**Example Use Cases:**
- Publication-quality spatial maps
- Air quality assessment across a region
- Policy analysis requiring spatial coverage
- Identifying spatial patterns and trends

---

### Use Temporal Workflow When:

✓ You need **temporal validation** at representative sites
✓ Comparing **multiple BME methods** quickly
✓ Analyzing **temporal patterns** (trends, seasonality, anomalies)
✓ Computing **validation statistics** (R², RMSE, bias)
✓ **Testing** different covariance models or parameters
✓ **Exploratory analysis** before committing to full spatial run
✓ Working with **limited computational resources**

**Example Use Cases:**
- Model comparison and selection
- Temporal trend analysis
- Leave-one-out cross-validation
- Quick sanity checks
- Method testing and parameter tuning
- Temporal uncertainty quantification

---

### Hybrid Approach

You can use **both workflows** in sequence:

```matlab
% 1. Run temporal workflow first (fast!)
%    - Select best method based on temporal validation
%    - Test parameters and configurations
runBME_temporal;  % Takes minutes

% 2. Run spatial workflow for final results
%    - Use best method from temporal analysis
%    - Generate publication-quality maps
runBME_estimation;  % Takes hours
```

---

## Architecture Details

### Data Flow Comparison

#### Spatial Workflow
```
┌──────────────────────────────────────────────────────────────┐
│ 1. getTOARobservationalData → obs                            │
│ 2. getTOARSoftData → softData                                │
│ 3. analyzeTOAR Pipeline:                                     │
│    ├─ getTOARglobalOffset → go                               │
│    ├─ getTOARautoCov → cov                                   │
│    ├─ getTOARknowledgeBase → KG, KS                          │
│    └─ getBMEparam → BMEparam                                 │
│ 4. estTOARsBME (for each time period):                       │
│    ├─ Create estimation grid (nGrid points)                  │
│    ├─ Run BME at all grid points                             │
│    ├─ Save results: BME{method}_time{tk}.mat                 │
│    └─ Generate spatial plots                                 │
│ 5. Optional Phase 1 Plotting:                                │
│    ├─ selectRepresentativeSites → repSites                   │
│    ├─ Load all BME results                                   │
│    ├─ Extract time series from grids                         │
│    └─ plotBME_TemporalSeries → figures                       │
└──────────────────────────────────────────────────────────────┘
```

#### Temporal Workflow
```
┌──────────────────────────────────────────────────────────────┐
│ 1. getTOARobservationalData → obs                            │
│ 2. getTOARSoftData → softData                                │
│ 3. selectRepresentativeSites → repSites (nSites << nGrid)   │
│ 4. Prepare BME Components:                                   │
│    ├─ getTOARglobalOffset → go                               │
│    ├─ getTOARautoCov → cov                                   │
│    ├─ getTOARknowledgeBase → KG, KS                          │
│    └─ getBMEparam → BMEparam                                 │
│ 5. estimateBME_AtRepSites:                                   │
│    ├─ Create estimation points (nSites × nTimes)             │
│    ├─ For each site: Leave-one-out BME                       │
│    ├─ Save results: site_estimates_{method}_year{year}.mat   │
│    └─ Store metadata                                         │
│ 6. plotBME_TemporalSeries:                                   │
│    ├─ Load siteEstimates                                     │
│    ├─ Match observations                                     │
│    ├─ Compute statistics                                     │
│    └─ Generate temporal plots                                │
└──────────────────────────────────────────────────────────────┘
```

### Key Functions by Workflow

#### Shared Functions (Both Workflows)
- `getTOARobservationalData.m` - Load observations
- `getTOARSoftData.m` - Load CTM/satellite data
- `getTOARglobalOffset.m` - Compute global offset
- `getTOARautoCov.m` - Estimate covariance
- `getTOARknowledgeBase.m` - Prepare knowledge bases
- `getBMEparam.m` - Get BME parameters
- `selectRepresentativeSites.m` - Select temporal sites

#### Spatial-Specific Functions
- `runBME_estimation.m` - Main spatial workflow script
- `analyzeTOAR.m` - Orchestrator (calls estTOARsBME)
- `estTOARsBME.m` - Grid-based BME estimation
- `estTOARsBMEoptim.m` - Optimized drop-in for estTOARsBME (variance smoothing, grid offset, STUG neighbor search; helps with vertical-line artifacts)
- `KrigingME_stug.m` - Kriging engine (grid format)
- `plotBME_SpatialStats.m` - Spatial summary plots
- `diagnoseBMEinputs.m`, `visualizeBMEdiagnostic.m` - Debug singular matrices / artifacts

#### Temporal-Specific Functions
- `runBME_temporal.m` - Main temporal workflow script
- `estimateBME_AtRepSites.m` - Site-based BME estimation
- `plotBME_TemporalSeries.m` - Temporal plotting (enhanced)

---

## Migration Guide

### If You Were Using `runBME_estimation.m` for Temporal Analysis

**Before:**
```matlab
% Had to run full spatial estimation just to get temporal plots
runBME_estimation;
% Wait 30-60 minutes...
% Get both spatial maps AND temporal plots
```

**After (Temporal-Only):**
```matlab
% Run fast temporal-only workflow
runBME_temporal;
% Wait 1-2 minutes...
% Get temporal plots only (no spatial maps)
```

**After (Both):**
```matlab
% For comprehensive analysis:
runBME_temporal;    % Quick temporal validation (minutes)
runBME_estimation;  % Full spatial maps (hours)
```

### Key Configuration Differences

| Parameter | Spatial Workflow | Temporal Workflow |
|-----------|-----------------|-------------------|
| `mapResolution` | Required (e.g., 1.0) | Not used |
| `keepOnlyLand` | Controls grid points | Not used |
| `exclusionRadius` | Not used | Controls leave-one-out (e.g., 0.5) |
| `minCompleteness` | Not used | Controls site selection (e.g., 0.70) |
| `selectionMethod` | Not used | Controls site selection (e.g., 'completeness') |

### Function Call Changes

#### Old Way (Extract from Grids)
```matlab
% Required full spatial estimation first
[obs, go, cov, KG, KS, BMEparam] = analyzeTOAR(analyzeParam);

% Load all grid results
allBMEs = cell(length(tkVec), 1);
for iTime = 1:length(tkVec)
    load(sprintf('BME%s_time%.2f.mat', method, tkVec(iTime)));
    allBMEs{iTime} = BMEs;
end

% Extract temporal series from grids
figPaths = plotBME_TemporalSeries(allBMEs, obs, repSites, estConfig);
```

#### New Way (Direct Site Estimation)
```matlab
% Prepare components (no full spatial estimation)
obs = getTOARobservationalData(analyzeParam);
repSites = selectRepresentativeSites(obs, analyzeParam.areaCode);
go = getTOARglobalOffset(obs, analyzeParam);
cov = getTOARautoCov(obs, go, analyzeParam);
[KG, KS] = getTOARknowledgeBase(obs, go, cov, analyzeParam);
BMEparam = getBMEparam(analyzeParam.BMEmethod);

% Estimate directly at sites (fast!)
siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, ...
    KG, KS, BMEparam, tkVec, 'exclusionRadius', 0.5);

% Plot temporal series
figPaths = plotBME_TemporalSeries([], obs, repSites, analyzeParam, ...
    'siteEstimates', siteEstimates);  % Pass empty allBMEs
```

---

## Best Practices

### 1. Start with Temporal Workflow
Always begin with `runBME_temporal.m` to:
- Validate your configuration
- Compare methods quickly
- Identify issues early
- Select optimal parameters

### 2. Use Appropriate Methods
```matlab
% Fast testing (temporal workflow)
BMEmethods = {'10000133'};  % Obs-only

% Production (spatial workflow)
BMEmethods = {'13000313-02', '13000313-06', '13000313-08'};  % With soft data
```

### 3. Cache and Reuse Components
Both workflows cache:
- Global offset (`go_*.mat`)
- Covariance (`cov_*.mat`)
- Representative sites (`representative_sites.mat`)

Set `forceGO = 0`, `forceCov = 0`, `forceRepSites = 0` to reuse.

### 4. Parallel Processing
For multiple methods:
```matlab
% Temporal workflow: Fast enough to run sequentially
% Spatial workflow: Consider parallel processing if available
```

### 5. Directory Organization
```
5BMEspatialPlots/
├── BME*.mat                    # Spatial results (spatial workflow)
├── site_estimates_*.mat        # Site results (temporal workflow)
├── representative_sites.mat    # Shared
├── figs/spatial/               # Spatial plots
└── figs_temporal/
    ├── {method}_go{go}_areaCode{area}_year{year}/  # Spatial workflow output
    └── {method}_temporal_only/                     # Temporal workflow output
```

---

## Summary

### Spatial Workflow (`runBME_estimation.m`)
- **Purpose**: Comprehensive spatial analysis with maps
- **Speed**: Slower (full grids)
- **Output**: Spatial maps + optional temporal plots
- **Use for**: Final production, spatial analysis, publication

### Temporal Workflow (`runBME_temporal.m`)
- **Purpose**: Fast temporal validation at key sites
- **Speed**: Much faster (sites only)
- **Output**: Temporal plots + statistics
- **Use for**: Model comparison, testing, validation, exploration

### Key Benefits of Separation
✓ **Efficiency**: 10-100x speedup for temporal analysis
✓ **Flexibility**: Choose the right tool for your needs
✓ **Independence**: No spatial grids required for temporal analysis
✓ **Scalability**: Test many methods quickly before full spatial run
✓ **Clarity**: Clear separation of spatial vs temporal concerns

---

## Questions?

For issues or questions:
- Check function documentation (type `help functionName`)
- Review configuration examples in scripts
- Compare spatial vs temporal workflow sections above
- Open an issue on GitHub

---

**Last Updated**: 2026-02-09
**Version**: 1.0
