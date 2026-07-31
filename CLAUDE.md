# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TOAR-II BME Ozone Data Fusion - A MATLAB framework for spatiotemporal analysis of tropospheric ozone using Bayesian Maximum Entropy (BME). Fuses TOAR-II observational data with RAMP-corrected Chemical Transport Model (CTM) outputs to produce gap-free global ozone maps with uncertainty quantification.

**Key workflow**: Data Loading → Global Offset → Covariance Model → Knowledge Base → BME Estimation → Validation

## Requirements

- MATLAB R2019b+ with Statistics and Machine Learning Toolbox
- [BMELIB](https://github.com/wiesnerfriedman/BMELIB) - must be added to MATLAB path

## Architecture

### Entry-Point Scripts (start here)

These are the user-facing drivers. Edit their CONFIGURATION block, then run. All three build on the `analyzeTOAR.m` orchestrator (obs → GO → Cov → KB → BME).

| Script | Purpose | Output |
|--------|---------|--------|
| `runBME_estimation.m` | Production spatial BME estimation on a grid (maps + uncertainty) | `5BMEspatialPlots/` |
| `runBME_temporal.m` | Fast temporal series at representative sites only (no grid, 10–100× faster) | `6BMEtemporalSeries/` |
| `runCBV.m` | Configure + launch checker-board validation (wraps `runCBV_toar`) | `7validation/CBV/` |

Tip: type `/run-cbv <intent>` to generate a ready-to-paste CBV `valParam` block.

### Core Pipeline Functions (library, called by the orchestrator)

| Stage | Function | Purpose |
|-------|----------|---------|
| Orchestrator | `analyzeTOAR.m` | Chains the full pipeline (obs → GO → Cov → KB → BME) |
| Data | `getTOARobservationalData.m` | Load TOAR-II CSV with caching |
| Global Offset | `getTOARglobalOffset.m` | Remove spatiotemporal trend (7 scenarios) |
| Covariance | `getTOARautoCov.m` | Fit exponential/holecos models |
| Knowledge Base | `getTOARknowledgeBase.m` | Create BME KG/KS structures |
| Estimation | `estTOARsBME.m` | Main spatial BME estimation (STG) |
| Estimation (opt) | `estTOARsBMEoptim.m` | Optimized estimator: variance smoothing, grid offset, STUG neighbor search |
| Site Estimation | `estimateBME_AtRepSites.m` | BME at exact site locations (powers temporal workflow) |
| Validation | `runCBV_toar.m`, `validateTOAR_loocv.m` | CBV and LOOCV methods |

### BME Diagnostics (vertical-line / singular-matrix debugging)

| Function | Purpose |
|----------|---------|
| `diagnoseBMEinputs.m` | Analyze saved `5BMEspatialPlots/debug/debug_*.mat` for singular matrices, duplicates, NaNs |
| `visualizeBMEdiagnostic.m` | Visualize a BME result file to investigate artifacts; can overlay CTM grid |

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
F: Soft neighbors  nsmax (0-6 → 0/3/4/10/50/100/200)
G: Hard neighbors  nhmax (1-3 → 50/100/200)
H: Probability type (2=kriging, 3=kriging multi-soft)

Examples:
  '10000132' - Hard data only, nhmax=200, kriging
  '13000313' - Hard + multi-CTM, nsmax=10 soft / nhmax=50 hard, kriging multi-soft
```

> Digit order is **nsmax then nhmax** — verified against `parseBMEcode.m:96-97` and the
> switch blocks in `getBMEparam.m:41-57`. (An earlier version of this table had F/G
> swapped and listed hard-neighbour values of 0/100/200/300/400, which do not exist.)

**Extended format** `BASECODE-XX[-YY...]`: append a hyphen + hex CTM bitmask to pick
specific soft-data sources (e.g. `'13000313-02'` = M3fusion, `'13000313-02-10'` = M3fusion + UKML).
Common masks: `01`=MERRA2-GMI, `02`=M3fusion, `04`=OMI-MLS, `08`=IASI-GOME2, `40`=CrIS.

**Canonical parser**: `parseBMEcode.m` (decodes base + extended `-XX` masks; used by
`getTOARknowledgeBase` and `getBMEparam`). `parseTOARBMEmethod.m` and `parseBMEmethod.m`
are legacy — do not use for new code.

### Global Offset Scenarios

- **Scenario 3 (Recommended)**: Regional (~90°), 20-year temporal scale
- **Scenario 6**: Local S/T (~45°), 10-year scale for urban analysis
- **Scenario 7**: Super-local (~10°), 2-year scale for high-resolution

`getTOARglobalOffset` computes the separable space/time mean trend via the densified-grid
smoother. The production callers (`getTOARglobalOffset.m`, `createTOARanalysisReport.m`) use
**`stmeanDensified_withNaN.m`**, a NaN-safe variant that skips all-NaN sites/months in the
exponential smoothing. The original `stmeanDensified.m` is kept pristine as a reference (do
not edit it). For data with no entirely-empty site/month the two are bit-for-bit identical
(verified by `test_stmeanDensified_nan_safety.m`).

### Known data gaps

- **1989 has no TOAR data file.** Any window reaching into 1989 (e.g. the 1990 per-year
  estimation/CBV) produces all-NaN 1989 month columns. The NaN-safe GO kernel handles this;
  the *original* kernel would poison the whole mean field → all-NaN residuals → pure-nugget
  covariance. Before assuming a window is clean, confirm which `1data/TOAR-II-monthly-mda8-*.csv`
  files actually exist.

### Per-year observation window (runBME_estimation)

`runBME_estimation.m` sets `analyzeParam.timeRange = [eachYear-1, eachYear+1]` **inside** the
per-year loop, so each estimation year's obs, Global Offset, Covariance, and BME all use only
that ±1-yr window (GO/Cov cached per year, e.g. `O3go_3_1989-1991.mat`). Soft data is likewise
per-year (keyed off `tkVec`). After changing GO behavior, rerun once with `forceGO=1` to drop
stale cached offsets.

### Estimation grid coverage (getTOARmapGrid)

`getTOARmapGrid(resolution, keepOnlyLand, includeAntarctica, gridOffset, coastBuffer, popCoverFile)`
takes two coverage params (defaults off → legacy behavior, byte-identical cache names):
- `coastBuffer` (deg): dilates the land mask outward by this much to keep near-shore cells.
- `popCoverFile`: a population CSV (`Population-Data/PopulationData2019.csv`); every populated
  cell's nearest lattice node is force-included so no inhabited landmass is dropped.

`runBME_estimation.m` enables both by default (`coastBuffer=0.5`, the population CSV). Threaded
through via `estParam.coastBuffer`/`estParam.popCoverFile`. Grids cache to
`1data/grids/map_grid_*.mat` with all params in the filename. Verify with
`test_population_grid_coverage.m`.

### Area Codes

| Code | Region | Code | Region |
|------|--------|------|--------|
| 0 | Global | 1 | CONUS |
| 2 | Europe | 3 | East Asia |

## Directory Structure

```
1data/            # TOAR-II CSVs and CTM parquet files (~203 GB — Read-denied)
0cache/           # STUG cache .mat files (~137 GB — Read-denied)
2globalOffset/    # Cached global offset results
2softdata/        # RAMP-corrected CTM structures
3covariance/      # Cached covariance models
5BMEspatialPlots/ # Spatial BME estimation output (runBME_estimation)
6BMEtemporalSeries/ # Temporal series at rep. sites (runBME_temporal)
7validation/      # LOOCV and CBV results
  └── CBV/        # Checker-board validation (figs_phase1/2/3, monthly/)
hpc_cbv/          # HPC job scripts for CBV (has its own CLAUDE.md)
hpc_validation/   # HPC scripts for LOOCV (has its own CLAUDE.md)
f-RAMP-code/      # Python f-RAMP soft-data generation (has its own CLAUDE.md)
```

> Large data/output folders are in the `.claude/settings.json` deny list. Don't try to
> read `1data/`, `0cache/`, or `*.mat`/`*.nc`/`*.png` files directly.

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

## Soft-data provenance (f-RAMP) — and why it matters for validation

All soft data (`lambda1` = mean, `lambda2` = variance, in `1data/CTM/*.parquet`) is
produced by the **Python f-RAMP implementation in `f-RAMP-code/`, run on the UNC
Longleaf cluster via SLURM** — not by any MATLAB code in this repo. The MATLAB
`getOverhangRAMPv6_updated.m` at the repo root is a **historical reference
implementation** that did not generate the production files, and it is **not equivalent**
to the Python version (different kNN unit, collocation, and time-window edge handling).
See `f-RAMP-code/CLAUDE.md` before reasoning about soft data.

MATLAB only *consumes* these files, via `loadRAMPdata.m` (parquet + the matching
`{model}_spatial_grid.mat` for coordinates; row order must agree).

**Every soft source goes through f-RAMP**, including the satellite products (OMI-MLS,
IASI-GOME2, CrIS) — they are reformatted to the same wide `DMA8_1..12` layout by
`f-RAMP-code/reformat_satellite_data.py` and RAMP-corrected identically.

### The leakage consequence

f-RAMP sets λ1 = `E[obs | model]` and λ2 = `Var[obs | model]` from a **k-nearest-neighbour
fit against TOAR observations**. The soft data is therefore *not independent of the
observations*, which matters for any station hold-out validation (CBV, LOOCV):

- The dependency footprint is **adaptive kNN, never a fixed radius** — sub-degree in dense
  networks, many degrees where stations are sparse.
- It is **strong, not diluted**: the production `k=100` counts *station-months*, not
  stations (long-format `collocated_df`), so a local ramp uses ~9 stations / ~25 pairs
  across 10 decile bins — **2–3 observations per bin**.
- `technique_{model}_{year}_v3-parallel.parquet` records the actual per-cell footprint
  (`1`=local, `2–6`=escalated, `99`=global fallback). Cells marked `99` are contaminated
  by every station that month and **cannot** be cleaned by a local mask.

`maskSoftDataLeakage.m` + `getLeakTag.m` (`valParam.leakControl` / `.leakRadius` in
`runCBV_toar.m`) implement a **fixed-radius** approximation of this. The default 2.0°
comes from Chang et al. 2019's M3Fusion bias-correction range — a step that DeLang et al.
2021 **removed**, and which in any case sits upstream of f-RAMP rather than describing it.
Treat the fixed radius as a rough sensitivity knob for the *upstream M3fusion* channel,
not as leakage control for f-RAMP.

**The sources are not symmetric.** Leakage means dependence on TOAR-II, the hold-out set:
- **Satellites are clean upstream** — their prior BME correction used IAGOS and other
  non-TOAR-II data. Their only TOAR-II dependence is f-RAMP, so a per-fold f-RAMP refit
  **fully cleans them**. `leakRadius.OMIMLS = 0` is right only *after* that refit.
- **M3fusion is contaminated upstream** (composite built from TOAR-II), which a f-RAMP
  refit does **not** remove.

So after refitting f-RAMP, the **satellite increment** (`-02` → `-06`/`-0E`) is a
leakage-free comparison; the **M3fusion increment** (obs-only → `-02`) remains
optimistically biased. Whether the 2° M3fusion mask is the right upstream control depends
on which M3Fusion variant the input CSVs are — see `f-RAMP-code/CLAUDE.md`.

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

### Quick / Temporal Estimation (minutes)
Fastest path — BME only at representative sites, no spatial grid. Just edit the
CONFIGURATION block at the top of `runBME_temporal.m` and run it. Under the hood:
```matlab
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, [], '10000133');
repSites = selectRepresentativeSites(obs, areaCode);
siteEstimates = estimateBME_AtRepSites(repSites, obs, go, cov, KG, KS, BMEparam, tkVec);
plotBME_TemporalSeries(siteEstimates, obs, repSites, estConfig);
```

### Full Spatial Estimation (hours)
Edit the CONFIGURATION block at the top of `runBME_estimation.m` and run it. Under the hood:
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

## CBV Result Plotting (phased)

After a CBV run, results are visualized in tiers — start at Phase 1, dig deeper as
needed. See `docs/CBV_Plotting_Guide.md` for full details and `example_plotCBV_Phase1/2/3.m`.

| Phase | Function | Covers | Output |
|-------|----------|--------|--------|
| 1 | `plotCBVresults_Phase1.m` | Quick overview: scatter by year, metrics vs box size, regional R² heatmap | `7validation/CBV/figs_phase1/` |
| 2 | `plotCBVresults_Phase2.m` | Diagnostics: residuals, uncertainty calibration, regional breakdown | `7validation/CBV/figs_phase2/` |
| 3 | `plotCBVresults_Phase3.m` | Compare configs: soft-data contribution, spider, temporal trends | `7validation/CBV/figs_phase3/` |
| 4 | `plotCBVresults_Phase4.m` | Cross-config time-series (distinct colors/styles per method, NaN-gap handling) | `figs_phase4/` |

Phase 2/3 call the analysis helpers: `plotResidualAnalysis`, `plotUncertaintyAnalysis`,
`plotRegionalBreakdown`, `plotConfigComparison`, `plotSoftDataContribution`, `plotTemporalTrends`.

## Troubleshooting

### Vertical lines in uncertainty maps
- Run `diagnoseBMEinputs('5BMEspatialPlots/debug/debug_*.mat')` to find singular matrices
- Use `visualizeBMEdiagnostic(resultFile)` to inspect the artifact (overlay CTM grid)
- Try different data format (stg ↔ stug)
- Adjust `BMEparam.dmax` search radius
- Check soft data grid consistency
- Consider `estTOARsBMEoptim` (variance smoothing + grid offset mitigate vertical lines)

### neighbours_stg crash (empty neighbors)
- Increase `dmax` parameters
- Check spatial/temporal constraints

### Missing soft data
```matlab
[status, report] = verifySoftDataFiles(BMEmethod, years);
```

### "Residuals are empty or all NaN" → pure-nugget covariance (`Variance: 1.00`, `stmetric: NaN`)
- The Global Offset came back all-NaN, usually because the obs window contains an entirely
  empty month/site (e.g. a window reaching into **missing 1989** — see *Known data gaps*).
- Production GO already uses the NaN-safe kernel `stmeanDensified_withNaN.m`; ensure
  `getTOARglobalOffset.m` calls it (not the pristine `stmeanDensified.m`).
- If a stale degenerate GO was cached before the fix, rerun once with `forceGO=1`.

## Documentation

- `README.md` - Main project documentation
- `DOCUMENTATION_INDEX.md` - Navigation hub
- `FILE_CATALOG.md` - MATLAB file catalog (89 detailed entries + addendum; 132 files total)
- `BME_WORKFLOWS.md` - Spatial vs temporal workflow details
- `docs/CBV_Plotting_Guide.md` - CBV phased plotting (Phase 1/2/3) interpretation guide
- `hpc_cbv/CLAUDE.md`, `hpc_validation/CLAUDE.md` - HPC (SLURM) submission conventions
- `SESSION_CONTEXT_CBV_IMPLEMENTATION.md` - Recent CBV implementation details

## Claude Code Helpers

- `/run-cbv <intent>` - Generate a ready-to-paste CBV `valParam` config block
- Subdirectory `CLAUDE.md` files in `hpc_cbv/` and `hpc_validation/` carry local HPC conventions
