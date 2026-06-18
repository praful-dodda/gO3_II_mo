# TOAR-II BME Ozone Data Fusion

A MATLAB-based framework for spatiotemporal analysis and estimation of tropospheric ozone concentrations using Bayesian Maximum Entropy (BME) methods. This codebase processes TOAR-II (Tropospheric Ozone Assessment Report) observational data and performs data fusion with RAMP-corrected chemical transport model (CTM) outputs to generate high-resolution ozone maps.

## Overview

This framework implements a comprehensive spatiotemporal data fusion system that:

- **Processes multi-source ozone data**: Integrates TOAR-II observational monitoring data with CTM model outputs
- **Applies advanced statistical methods**: Uses BME and kriging techniques for optimal spatial estimation
- **Handles large-scale datasets**: Processes global ozone data with efficient caching and HPC support
- **Provides uncertainty quantification**: Generates both mean predictions and variance estimates
- **Supports multiple estimation strategies**: Offers different global offset scenarios, covariance models, and data formats

### Key Features

- **Global coverage**: Analyzes ozone data across multiple regions (CONUS, Europe, East Asia, etc.)
- **Temporal analysis**: Monthly time resolution from 2015-2020
- **Soft data integration**: Incorporates RAMP-corrected CTM model outputs as probabilistic constraints
- **Validation framework**: Leave-one-out cross-validation (LOOCV) with HPC parallelization
- **Diagnostic tools**: Comprehensive visualization and quality control utilities
- **Multiple kriging formats**: Optimized algorithms for vector (STV), grid (STG), and unstructured grid (STUG) data

## Project Structure

```
.
├── README.md                           # This file
├── README_diagnostic_visualization.md  # Diagnostic tools documentation
├── 2softdata/                          # RAMP-corrected CTM soft data
│   └── README.md                       # Soft data integration guide
├── hpc_validation/                     # HPC validation system
│   └── README.md                       # HPC job submission guide
│
├── Core Data Processing
│   ├── getTOARobservationalData.m      # Load and QC observational data
│   ├── getTOARglobalOffset.m           # Estimate global offset (7 scenarios)
│   ├── getTOARautoCov.m                # Fit spatiotemporal covariance model
│   └── getTOARknowledgeBase.m          # Create BME knowledge base
│
├── BME Estimation
│   ├── estTOARsBME.m                   # Main BME spatial estimation
│   ├── krigingME_stg.m                 # STG format kriging
│   ├── krigingME_stug.m                # STUG format kriging (optimized)
│   └── estBMEs_stg.m                   # Alternative BME interface
│
├── Validation
│   ├── validateTOAR_LOOCV.m            # Leave-one-out cross-validation
│   ├── validateTOAR_monthly.m          # Monthly validation statistics
│   ├── validateTOARsBME.m              # BME estimation validation
│   └── calculateValidationStats.m      # Compute performance metrics
│
├── Soft Data System
│   ├── loadRAMPdata.m                  # Load RAMP-corrected parquet files
│   ├── createSoftDataStructure.m       # Create BME-compatible soft data
│   ├── plotSoftData.m                  # Visualize soft data fields
│   └── subsetSoftData.m                # Spatial/temporal subsetting
│
├── Visualization & Diagnostics
│   ├── plotTOARsBME.m                  # Plot BME mean estimates
│   ├── plotTOARsBMEvar.m               # Plot BME variance/uncertainty
│   ├── visualizeBMEdiagnostic.m        # Diagnostic tool for artifacts
│   ├── plotTOARvalidation.m            # Validation scatter plots
│   └── createTOARanalysisReport.m      # Generate analysis reports
│
├── Utilities
│   ├── getTOARmapGrid.m                # Generate estimation grids
│   ├── getTOARareaBoundaries.m         # Define regional boundaries
│   ├── getCTMspatialGrid.m             # Extract CTM model grids
│   ├── extractModelSpatialInfo.m       # Process model spatial info
│   ├── parseBMEmethod.m                # Parse BME method codes
│   └── BMEmethodType.m                 # BME method configuration
│
├── Analysis & Exploration
│   ├── analyzeTOAR.m                   # Data exploration and QC
│   ├── exploreTOARdata.m               # Interactive data exploration
│   ├── assessTOARdataQuality.m         # Quality assessment
│   └── calculateTOARseasonality.m      # Seasonal pattern analysis
│
└── Examples & Tests
    ├── example_diagnose_vertical_lines.m  # Diagnostic workflow example
    ├── test_softdata_workflow.m           # Soft data integration test
    └── test_gos.m                         # Global offset testing
```

## Installation

### Prerequisites

**Required Software:**
- MATLAB R2019b or later
- Statistics and Machine Learning Toolbox
- Mapping Toolbox (optional, for enhanced visualization)

**Required Libraries:**
- [BMELIB](https://github.com/wiesnerfriedman/BMELIB) - Bayesian Maximum Entropy library
- Parquet file reader (included in MATLAB R2019a+)

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd gO3_II_mo
   ```

2. **Install BMELIB:**
   ```bash
   # Download and add to MATLAB path
   git clone https://github.com/wiesnerfriedman/BMELIB.git
   ```

   In MATLAB:
   ```matlab
   addpath(genpath('/path/to/BMELIB'));
   savepath;
   ```

3. **Prepare data directories:**
   ```matlab
   % Create required directories
   mkdir('1data/TOAR-II');
   mkdir('1data/CTM');
   mkdir('1data/CTM/model_output_data/spatial_grids');
   mkdir('2globalOffset');
   mkdir('3covariance');
   mkdir('4knowledgeBase');
   mkdir('5BMEspatialPlots');
   mkdir('7validation');
   ```

4. **Download TOAR-II data:**
   Place TOAR-II monthly MDA8 CSV files in `1data/TOAR-II/`:
   ```
   TOAR-II-monthly-mda8-2015.csv
   TOAR-II-monthly-mda8-2016.csv
   ...
   TOAR-II-monthly-mda8-2020.csv
   ```

5. **Prepare CTM model data** (optional, for soft data):
   - Place RAMP-corrected parquet files in `1data/CTM/`
   - Run `extractModelSpatialInfo.m` to generate spatial grid files

## Quick Start

> **Easiest path:** instead of calling the library functions by hand (below), use one of the
> ready-made driver scripts — edit the CONFIGURATION block at the top of each, then run:
> - `runBME_estimation.m` — spatial BME estimation on a grid → `5BMEspatialPlots/`
> - `runBME_temporal.m` — fast temporal series at representative sites (no grid) → `6BMEtemporalSeries/`
> - `runCBV.m` — checker-board validation → `7validation/CBV/`
>
> All three build on the `analyzeTOAR.m` orchestrator, which chains the manual steps shown below.

### Basic Workflow

Here's a complete example for estimating ozone over Europe in 2016:

```matlab
%% 1. Load observational data
obs = getTOARobservationalData('all', [2015 2020], 0);
% 'all' = all station types, [2015 2020] = years, 0 = no log transform

%% 2. Estimate global offset
go = getTOARglobalOffset(obs, 3, 1);
% Scenario 3 = regional smoothing (recommended)
% Plot level 1 = basic plots

%% 3. Fit covariance model
cov = getTOARautoCov(obs, go, [], 1);
% Auto-fit exponential covariance model with plotting

%% 4. Create BME knowledge base
BMEmethod = '10000132';  % Hard data only, nhmax=100
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, [], BMEmethod);

%% 5. Set up estimation parameters
estParam.areaCode = 2;              % Europe
estParam.mapResolution = 1.0;       % 1 degree grid
estParam.tkVec = 2016:1/12:2017;    % Monthly for 2016
estParam.forceEstimation = 0;       % Use cache if available
estParam.plotResults = 1;           % Create plots
estParam.keepOnlyLand = 1;          % Land points only
estParam.includeAntarctica = 0;     % Exclude Antarctica

%% 6. Run BME estimation
estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam);

% Results saved to: 5BMEspatialPlots/BME10000132_go3_lt0_area2_res1.00_*.mat
```

### With Soft Data (CTM Models)

To incorporate RAMP-corrected CTM model outputs:

```matlab
%% Load RAMP-corrected CTM data
ctmData = loadRAMPdata('MERRA2-GMI', [2015:2020]);

%% Create soft data structure
options.spatialBounds = [-125 -65 24 50];  % CONUS
options.thinningFactor = 2;                 % Use every 2nd grid point
softData = createSoftDataStructure(ctmData, obs, options);

%% Create knowledge base with soft data
BMEmethod = '11000142';  % Soft data enabled, nsmax=50
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod);

%% Proceed with estimation as above
estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam);
```

### Validation

Run leave-one-out cross-validation:

```matlab
%% Single year validation
validationYears = 2016;
validationMonths = 1:12;  % All months
forceEstimation = 0;      % Use cache

results = validateTOAR_LOOCV(obs, go, cov, BMEparam, ...
    validationYears, validationMonths, forceEstimation);

%% View validation statistics
fprintf('R² = %.3f\n', results.R2);
fprintf('RMSE = %.2f ppb\n', results.RMSE);
fprintf('MAE = %.2f ppb\n', results.MAE);
```

## BME Method Codes

The 8-digit BME method code controls estimation behavior:

```
Format: ABCDEFGH

A (Estimation Type):
  1 = BME probabilities (BMEprobaMoments)
  2 = Kriging with measurement error (krigingME)

B (Soft Data):
  0 = Hard data only
  1 = Hard + soft data (CTM models)

C-E: Reserved (use 000)

F (Hard Data Neighbors):
  0 = 0 neighbors
  1 = 100 neighbors
  2 = 200 neighbors
  3 = 300 neighbors
  4 = 400 neighbors

G (Soft Data Neighbors):
  0 = 0 neighbors
  1 = 3 neighbors
  2 = 4 neighbors
  4 = 50 neighbors
  6 = 200 neighbors

H (Probability Type):
  1 = BME probabilities
  2 = Kriging
```

**Common configurations:**
- `10000132`: Hard data only, nhmax=100, kriging (default)
- `11000142`: Hard + soft, nhmax=100, nsmax=50, kriging (recommended with CTM)
- `20000132`: BME probabilities, hard data only, nhmax=100

### Extended Format (multi-CTM soft data)

Append a hyphen + hex CTM bitmask to a base code to select specific soft-data sources:

```
BASECODE-XX[-YY...]
  '13000313-02'    = base '13000313' + M3fusion
  '13000313-02-10' = base + M3fusion + UKML
```

Common masks: `01`=MERRA2-GMI, `02`=M3fusion, `04`=OMI-MLS, `08`=IASI-GOME2, `40`=CrIS.

Codes are decoded by **`parseBMEcode.m`** (canonical; `parseTOARBMEmethod.m` and
`parseBMEmethod.m` are legacy). Build codes with `generateBMEcode.m`; expand a mask to a
model list with `decodeCTMmodels.m`.

## Global Offset Scenarios

| Scenario | Type | Spatial Scale | Temporal Scale | Use Case |
|----------|------|---------------|----------------|----------|
| 0 | Zero | None | None | Testing/debugging |
| 1 | Flat | None | None | Constant offset |
| 2 | Domain-wide | Global (180°) | Long (50 years) | Continental patterns |
| 3 | Regional | Regional (90°) | Medium (20 years) | **Recommended** |
| 4 | Local | Local (45°) | Short (10 years) | Urban-scale |
| 5 | Regional S/T | Regional (90°) | Short (10 years) | Seasonal regional |
| 6 | Local S/T | Local (45°) | Very short (5 years) | Urban seasonal |
| 7 | Super-local | Very local (10°) | Ultra-short (2 years) | High-resolution |

**Recommendation**: Start with Scenario 3 (regional) for most applications.

## Area Codes

Pre-defined regional boundaries:

| Code | Region | Longitude | Latitude |
|------|--------|-----------|----------|
| 0 | Global | -180 to 180 | -60 to 75 |
| 1 | CONUS | -125 to -65 | 24 to 50 |
| 2 | Europe | -12 to 45 | 35 to 72 |
| 3 | East Asia | 95 to 145 | 18 to 55 |
| 4 | South Asia | 60 to 95 | 5 to 40 |
| 5 | Africa | -20 to 52 | -35 to 38 |
| 6 | South America | -82 to -34 | -56 to 13 |
| 7 | Australia | 112 to 154 | -44 to -10 |
| 8 | North America | -168 to -50 | 15 to 75 |
| 9 | Middle East | 25 to 65 | 10 to 42 |
| 10 | Arctic | -180 to 180 | 60 to 75 |

## Data Formats

### STG (Space-Time Grid)
Optimized for regularly-gridded soft data (CTM models):
```matlab
BMEparam.dataFormat = 'stg';
```
- **Best for**: Regular CTM model grids
- **Performance**: Fast for grid-aligned data
- **Function**: `krigingME_stg.m`

### STUG (Space-Time Unstructured Grid)
Fastest for large uniform grids:
```matlab
BMEparam.dataFormat = 'stug';
```
- **Best for**: Large-scale estimation with uniform CTM grids
- **Performance**: Fastest overall
- **Function**: `krigingME_stug.m`

### STV (Space-Time Vector)
Standard vector format:
```matlab
BMEparam.dataFormat = 'stv';
```
- **Best for**: Hard data only or small datasets
- **Performance**: Slower but most flexible
- **Function**: `krigingME.m`

## Diagnostics & Troubleshooting

### Vertical Lines in Uncertainty Maps

If you observe vertical lines or artifacts in BME standard deviation maps:

```matlab
% Use diagnostic visualization tool
opts.metric = 'std';
opts.display = 'grid';
opts.modelName = 'MERRA2-GMI';  % Overlay model grid
visualizeBMEdiagnostic('5BMEspatialPlots/BME*.mat', opts);
```

See [README_diagnostic_visualization.md](README_diagnostic_visualization.md) for detailed troubleshooting.

**Common solutions:**
1. Try different data format: `stg` ↔ `stug`
2. Adjust search radius: Increase `BMEparam.dmax`
3. Check covariance parameters
4. Verify soft data grid consistency

### Data Quality Issues

Run data quality assessment:
```matlab
assessTOARdataQuality(obs, 1);  % 1 = create plots
```

Explore data interactively:
```matlab
exploreTOARdata(obs, go);
```

## HPC Validation

For large-scale validation across multiple scenarios, use the HPC system:

```bash
cd hpc_validation
bash submit_all_jobs.sh  # Submit LOOCV jobs for all scenarios
bash monitor_jobs.sh watch  # Monitor progress
```

After completion:
```matlab
cd hpc_validation
aggregate_results([2 3 6 7], [2016:2019]);
```

See [hpc_validation/README.md](hpc_validation/README.md) for details.

## Validation Metrics

The framework computes comprehensive validation statistics:

- **R² (R-squared)**: Variance explained (0-1, higher is better)
- **RMSE (Root Mean Square Error)**: Overall prediction error (ppb, lower is better)
- **MAE (Mean Absolute Error)**: Average absolute error (ppb, lower is better)
- **ME (Mean Error)**: Systematic bias (ppb, closer to 0 is better)
- **NMB (Normalized Mean Bias)**: Percentage bias (%, closer to 0 is better)
- **NME (Normalized Mean Error)**: Percentage error (%, lower is better)
- **IOA (Index of Agreement)**: Overall agreement (0-1, higher is better)
- **FAC2 (Factor of 2)**: Fraction within factor of 2 (0-1, higher is better)

## Output Files

### BME Estimation Results
Location: `5BMEspatialPlots/`

Filename format:
```
BME{method}_go{scenario}_lt{logtransf}_area{code}_res{resolution}_{format}_land{flag}_time{YYYY.YY}.mat
```

Example:
```
BME10000132_go3_lt0_area2_res1.00_stg_land1_time2016.50.mat
```

**Contents:**
- `sk`: Estimation grid coordinates [nGrid × 2]
- `tk`: Estimation time (decimal year)
- `XkBMEm`: Residual mean estimates [nGrid × 1]
- `XkBMEv`: Residual variance estimates [nGrid × 1]
- `gok`: Global offset at estimation points [nGrid × 1]
- `YkBMEm`: Final predictions (XkBMEm + gok) [nGrid × 1]
- `sMSobs`: Observation locations [nObs × 2]
- `Yobs`: Observation values [nObs × 1]

### Validation Results
Location: `7validation/`

Monthly cached results:
```
TOAR_LOOCV_BME{method}_go{scenario}_y{year}_m{month}.mat
```

Summary results:
```
validation_summary_go{scenario}_y{years}.mat
```

## Performance Tips

1. **Use caching**: Set `forceEstimation = 0` to reuse cached results
2. **Optimize data format**: Use `stug` for large grids, `stg` for regular CTM grids
3. **Adjust neighbor limits**: Balance accuracy vs speed with `nhmax` and `nsmax`
4. **Spatial thinning**: For soft data, use `thinningFactor = 2` or higher
5. **Regional subsetting**: Limit `spatialBounds` to area of interest
6. **Parallel validation**: Use HPC system for multi-scenario validation

## Citation

If you use this code in your research, please cite:

```
[Citation information to be added]
```

## Related Documentation

- **[Soft Data Integration](2softdata/README.md)**: RAMP-corrected CTM model data fusion
- **[Diagnostic Tools](README_diagnostic_visualization.md)**: Troubleshooting BME artifacts
- **[HPC Validation](hpc_validation/README.md)**: Large-scale parallel validation

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear documentation
4. Submit a pull request

## License

[License information to be added]

## Contact

For questions or issues:
- Open an issue on GitHub
- [Contact information to be added]

## Acknowledgments

- TOAR-II project for providing observational data
- BMELIB developers for the BME framework
- RAMP team for bias-corrected CTM outputs
