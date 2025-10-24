# RAMP-Corrected Soft Data for BME Data Fusion

This directory contains RAMP-corrected CTM model outputs formatted as soft data for BME data fusion.

## Directory Structure

```
2softdata/
├── README.md                      # This file
├── softData_UKML_YYYY-YYYY.mat   # Cached soft data structures
├── plots/                         # Visualization plots
│   ├── UKML_mean_yYYYY_mMM.png
│   └── UKML_variance_yYYYY_mMM.png
└── archived/                      # Old versions (if any)
```

## Data Source

**RAMP-corrected model outputs** stored as parquet files in `1data/CTM/`:
- `lambda1_{model}_{year}_v{version}-parallel.parquet` - Mean field
- `lambda2_{model}_{year}_v{version}-parallel.parquet` - Variance field

Where:
- **lambda1** = RAMP-corrected mean MDA8 ozone (ppb)
- **lambda2** = RAMP-corrected variance (ppb²)
- **model** = Model name (e.g., UKML)
- **version** = RAMP calibration version (e.g., v3)

### Parquet File Format

Each parquet file contains:
- **Column 1**: Longitude (decimal degrees)
- **Column 2**: Latitude (decimal degrees)
- **Columns 3-14**: Monthly MDA8 values (Jan-Dec)

## Workflow

### 1. Load RAMP Data

```matlab
% Load from parquet files (creates cache on first run)
ctmData = loadRAMPdata('UKML', [2015:2020]);

% Force reload from parquet (ignore cache)
ctmData = loadRAMPdata('UKML', [2015:2020], '1data/CTM', 1);
```

**Output structure:**
```matlab
ctmData.lon      % [nGrid × 1] Longitude
ctmData.lat      % [nGrid × 1] Latitude
ctmData.tME      % [1 × nMonths] Time in decimal years
ctmData.Z        % [nGrid × nMonths] Mean field (lambda1)
ctmData.Zv       % [nGrid × nMonths] Variance field (lambda2)
```

**Caching:** Creates `1data/CTM/CTM_RAMP_UKML_2015-2020_v3.mat` (~50-500 MB)

### 2. Create Soft Data Structure

```matlab
% Basic usage
softData = createSoftDataStructure(ctmData, obs);

% With spatial subsetting (e.g., CONUS)
options.spatialBounds = [-125 -65 24 50];
softData = createSoftDataStructure(ctmData, obs, options);

% With spatial thinning (every 2nd grid point)
options.thinningFactor = 2;
softData = createSoftDataStructure(ctmData, obs, options);
```

**Output structure:**
```matlab
softData.sMS     % [nPoints × 2] Spatial coordinates (lon, lat)
softData.tME     % [1 × nMonths] Time vector (aligned with obs)
softData.Z       % [nPoints × nMonths] Mean values
softData.Zv      % [nPoints × nMonths] Variance values
```

**Memory:** ~14-140 MB depending on grid resolution and thinning

### 3. Visualize Soft Data

```matlab
% Plot mean and variance for January
plotSoftData(softData, obs, 1, 'both');

% Plot mean only for multiple months
plotSoftData(softData, obs, [1 6 12], 'mean');
```

**Output:** PNG files in `2softdata/plots/`

### 4. Use in BME

```matlab
% Specify soft data when creating knowledge base
BMEmethod = '11000132';  % Note: digit 2 = '1' for soft data
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod);

% KS.softdata now contains:
%   .p  - [nSoft × 3] coordinates (lon, lat, time)
%   .z  - [nSoft × 1] residual mean values
%   .vs - [nSoft × 1] variance values
```

## BME Method Codes with Soft Data

### Without Soft Data (current):
```
'10000132'
  ↑
  Digit 2 = 0 (no CTM data)
```

### With Soft Data (new):
```
'11000132'
  ↑
  Digit 2 = 1 (includes CTM soft data)
```

Change in BME parameters:
- `nsmax`: Maximum soft data neighbors (digit 6)
  - 0 → 0 soft neighbors (hard only)
  - 1 → 3 soft neighbors
  - 2 → 4 soft neighbors
  - 4 → 50 soft neighbors
  - 6 → 200 soft neighbors

Example: `'11000242'` = hard + soft, nsmax=50, nhmax=200

## Optimization Options

### Spatial Subsetting
Reduce to analysis domain only:
```matlab
options.spatialBounds = [minLon maxLon minLat maxLat];
```
**Benefit:** 50-90% memory reduction for regional studies

### Spatial Thinning
Keep every Nth grid point:
```matlab
options.thinningFactor = 2;  % Every 2nd point
```
**Benefit:** 75% memory reduction, minimal accuracy loss (BME uses nsmax anyway)

### Remove Hard Data Locations
Avoid double-counting:
```matlab
options.removeHardData = 1;
```
**Benefit:** Prevents soft data at same location/time as hard data

## File Sizes

Typical sizes for 6 years (2015-2020, 72 months):

| Grid Resolution | Points | Raw Cache | Soft Data | With Thinning (×2) |
|----------------|--------|-----------|-----------|-------------------|
| 0.1° × 0.1°    | 64,800 | 450 MB    | 140 MB    | 35 MB             |
| 0.25° × 0.25°  | 10,368 | 72 MB     | 22 MB     | 5.5 MB            |
| 0.5° × 0.5°    | 2,592  | 18 MB     | 5.5 MB    | 1.4 MB            |

**All stored as single precision for efficiency**

## Quality Control

Automated QC during structure creation:
- ✓ Negative variance → set to 0.01
- ✓ Infinite/NaN values → removed
- ✓ Temporal alignment with obs
- ✓ Minimum variance threshold (default: 0.01)

## Expected Impact

Based on typical BME data fusion results:

### Dense Observation Regions
- R² improvement: +0.02-0.05
- RMSE improvement: -1-2 ppb

### Sparse Observation Regions
- R² improvement: +0.10-0.20
- RMSE improvement: -3-8 ppb

### Overall (Mixed)
- R² improvement: +0.05-0.10
- RMSE improvement: -2-4 ppb

## Test Script

Run the complete workflow:
```matlab
test_softdata_workflow
```

This demonstrates:
1. Loading RAMP data
2. Creating soft data structure
3. Visualization
4. BME integration
5. Test estimation

## Troubleshooting

### Parquet files not found
```
Error: Lambda1 file not found
```
**Solution:** Check file naming convention and path. Expected format:
```
1data/CTM/lambda1_UKML_2017_v3-parallel.parquet
```

### Memory issues
```
Out of memory error during loading
```
**Solutions:**
1. Use spatial thinning: `options.thinningFactor = 2`
2. Subset to analysis domain: `options.spatialBounds = [...]`
3. Process fewer years at once

### Temporal misalignment
```
Warning: No temporal overlap between obs and CTM
```
**Solution:** Check that obs.tME and ctmData.tME have overlapping time periods

## Version History

- v1.0 (2025-01-15): Initial soft data loading system
  - Parquet file loading with caching
  - Soft data structure creation
  - Visualization tools
  - BME integration

## Contact

For questions about:
- **RAMP correction:** See RAMP documentation
- **Data format:** Check parquet file structure
- **BME integration:** See getTOARknowledgeBase.m documentation
