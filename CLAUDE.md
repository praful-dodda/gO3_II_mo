# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TOAR-II BME Ozone Data Fusion - A MATLAB framework for spatiotemporal analysis of tropospheric ozone using Bayesian Maximum Entropy (BME). Fuses TOAR-II observational data with RAMP-corrected Chemical Transport Model (CTM) outputs to produce gap-free global ozone maps with uncertainty quantification.

**Key workflow**: Data Loading → Global Offset → Covariance Model → Knowledge Base → BME Estimation → Validation

## Requirements

- MATLAB R2019b+ with Statistics and Machine Learning Toolbox
- [BMELIB](https://github.com/wiesnerfriedman/BMELIB) - must be added to MATLAB path

## Architecture

### Core Pipeline Functions

| Stage | Function | Purpose |
|-------|----------|---------|
| Data | `getTOARobservationalData.m` | Load TOAR-II CSV with caching |
| Global Offset | `getTOARglobalOffset.m` | Remove spatiotemporal trend (7 scenarios) |
| Covariance | `getTOARautoCov.m` | Fit exponential/holecos models |
| Knowledge Base | `getTOARknowledgeBase.m` | Create BME KG/KS structures |
| Estimation | `estTOARsBME.m` | Main spatial BME estimation |
| Validation | `runCBV_toar.m`, `validateTOAR_loocv.m` | CBV and LOOCV methods |

### Data Formats

- **STV**: Space-Time Vector - most flexible, slower
- **STG**: Space-Time Grid - regular CTM grids
- **STUG**: Space-Time Unstructured Grid - fastest, preferred for large datasets

### BME Method Codes (8-digit format)

```
Format: ABCDEFGH

A: Estimation type (1=BME probabilities, 2=kriging)
B: Soft data (0=hard only, 1=hard+soft, 3=hard+multi-CTM)
C-E: Reserved (000)
F: Hard neighbors (0-4 → 0/100/200/300/400)
G: Soft neighbors (0-6 → 0/3/4/10/50/100/200)
H: Probability type (2=kriging, 3=kriging multi-soft)

Examples:
  '10000132' - Hard data only, 100 neighbors, kriging
  '13000313' - Hard + multi-CTM, 100 hard, kriging multi-soft
```

### Global Offset Scenarios

- **Scenario 3 (Recommended)**: Regional (~90°), 20-year temporal scale
- **Scenario 6**: Local S/T (~45°), 10-year scale for urban analysis
- **Scenario 7**: Super-local (~10°), 2-year scale for high-resolution

### Area Codes

| Code | Region | Code | Region |
|------|--------|------|--------|
| 0 | Global | 1 | CONUS |
| 2 | Europe | 3 | East Asia |

## Directory Structure

```
1data/           # TOAR-II CSVs and CTM parquet files
2globalOffset/   # Cached global offset results
2softdata/       # RAMP-corrected CTM structures
3covariance/     # Cached covariance models
5BMEspatialPlots/ # BME estimation output
7validation/     # LOOCV and CBV results
  └── CBV/       # Checker-board validation
hpc_cbv/         # HPC job scripts for CBV
hpc_validation/  # HPC scripts for LOOCV
```

## Key Implementation Patterns

### Global Offset Integration
Always subtract GO before BME estimation, add back afterward:
```matlab
% After BME estimation
gok = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, sk, unique(tk));
YkBMEm = XkBMEm + gok;
```

### STUG Format Conversion
```matlab
BMEparam.dataFormat = 'stug';
soft_data_stug = reformat_stg_to_stug(KS.softdata);
[XkBMEm, XkBMEv] = krigingME_stug(pk, ...);
```

### Soft Data Verification
```matlab
[status, report] = verifySoftDataFiles(BMEmethod, years);
```

## Running Tests

```matlab
% Test global offset scenarios
test_gos

% Test BME coding system
test_BME_coding_system

% Test method name generation
test_getBMEmethodName
```

## Common Workflows

### Quick Estimation (minutes)
```matlab
obs = getTOARobservationalData('all', [2015 2020]);
go = getTOARglobalOffset(obs, 3, 0);
cov = getTOARautoCov(obs, go, [], 0);
results = estimateBME_AtRepSites(obs, go, cov, estParam);
```

### Full Spatial Estimation (hours)
```matlab
obs = getTOARobservationalData('all', [2015 2020]);
go = getTOARglobalOffset(obs, 3, 1);
cov = getTOARautoCov(obs, go, [], 1);
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, [], '10000133');
estTOARsBME(obs, go, cov, KG, KS, BMEparam, estParam);
```

### Checker-Board Validation
```matlab
valParam.valYears = [2015:2019];
valParam.boxSizes = [5.0];
valParam.BMEmethod = '10000133';
valParam.goScenario = 3;
runCBV_toar(valParam);
```

### HPC Validation
```bash
cd hpc_cbv
bash submit_cbv_jobs.sh
bash monitor_cbv_jobs.sh
```

## Validation Metrics

- **R²**: Variance explained (0-1, higher better)
- **RMSE/MAE**: Error in ppb (lower better)
- **NMB**: Normalized mean bias (%, closer to 0 better)
- **IOA**: Index of agreement (0-1, higher better)
- **FAC2**: Fraction within factor of 2

## Troubleshooting

### Vertical lines in uncertainty maps
- Try different data format (stg ↔ stug)
- Adjust `BMEparam.dmax` search radius
- Check soft data grid consistency

### neighbours_stg crash (empty neighbors)
- Increase `dmax` parameters
- Check spatial/temporal constraints

### Missing soft data
```matlab
[status, report] = verifySoftDataFiles(BMEmethod, years);
```

## Documentation

- `README.md` - Main project documentation
- `DOCUMENTATION_INDEX.md` - Navigation hub
- `FILE_CATALOG.md` - All 89+ MATLAB files documented
- `BME_WORKFLOWS.md` - Spatial vs temporal workflow details
- `SESSION_CONTEXT_CBV_IMPLEMENTATION.md` - Recent CBV implementation details
