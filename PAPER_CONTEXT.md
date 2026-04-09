# TOAR-II BME Ozone Data Fusion: Comprehensive Project Summary

This document provides comprehensive context for writing a scientific paper about this project. Use this as context when working with an LLM to draft paper sections.

---

## 1. Scientific Overview

This framework implements **Bayesian Maximum Entropy (BME)** methods for spatiotemporal data fusion of tropospheric ozone concentrations. It combines **hard data** (TOAR-II ground-based observations) with **soft data** (RAMP-corrected Chemical Transport Model outputs) to produce gap-free, uncertainty-quantified global ozone maps.

**Core Innovation**: A flexible multi-source data fusion system that integrates observational monitoring networks with multiple bias-corrected CTM outputs using advanced geostatistical techniques, while providing rigorous uncertainty quantification.

---

## 2. Data Sources

### 2.1 Hard Data: TOAR-II Observations
- **Source**: Tropospheric Ozone Assessment Report II (TOAR-II) global database
- **Variable**: Monthly Maximum Daily 8-hour Average (MDA8) ozone
- **Units**: ppb (parts per billion)
- **Temporal Coverage**: 2015-2020 (72 months)
- **Spatial Coverage**: Global network of ~1,000-1,500 monitoring stations
- **Data Format**: CSV files with station coordinates, timestamps, and ozone concentrations

### 2.2 Soft Data: RAMP-Corrected CTM Outputs
Six Chemical Transport Models are available for fusion:

| Model | Description |
|-------|-------------|
| MERRA2-GMI | MERRA-2 reanalysis with GMI chemistry |
| M3fusion | Multi-model ensemble fusion product |
| OMI-MLS | Satellite-based (OMI + MLS) observations |
| IASI-GOME2 | Satellite-based (IASI + GOME2) retrieval |
| UKML | UK Met Office machine learning product |
| NJML | Neural network-based model |

**RAMP Correction (v3)**: Regression Adjusted Model Prediction correction removes systematic CTM biases including:
- Non-linearity
- Heteroscedasticity
- Non-stationarity

Each soft data point includes both corrected mean (λ₁) and variance (λ₂) fields.

---

## 3. Methodology

### 3.1 Three-Stage BME Framework

**Stage 1: Global Offset Removal**
- Removes large-scale spatiotemporal mean trends from observations
- 11 configurable scenarios with different spatial (10°-180°) and temporal (2-50 months) smoothing scales
- Recommended: Scenario 3 (regional, 90° spatial, 20-month temporal)
- Uses exponential distance-weighted smoothing on densified Voronoi grids

**Stage 2: Covariance-Based Kriging**
Fits composite space-time covariance models with four nested components:

```
C(r,τ) = c₀₁·exp(-3r/aᵣ₁)·exp(-3τ/aₜ₁)     [short-range spatial, short-range temporal]
       + c₀₂·exp(-3r/aᵣ₁)·Cₜ(τ)             [short-range spatial, long-range temporal]
       + c₀₃·exp(-3r/aᵣ₂)·exp(-3τ/aₜ₁)     [long-range spatial, short-range temporal]
       + c₀₄·exp(-3r/aᵣ₂)·Cₜ(τ)            [long-range spatial, long-range temporal]
```

Where:
- r = spatial lag (degrees)
- τ = temporal lag (years)
- aᵣ₁, aᵣ₂ = short/long range spatial correlation lengths
- aₜ₁ = temporal correlation length
- Cₜ(τ) = exponential or hole-cosine (for seasonality) temporal model

**Stage 3: BME Estimation with Soft Data Integration**
- Hard data: Point observations with measurement uncertainty
- Soft data: Gridded CTM fields as probabilistic constraints (Gaussian PDFs)
- Kriging with measurement error (KrigingME) for optimal estimation
- Automatic neighbor selection (typically 100 hard, 50 soft neighbors)
- Global offset restored after estimation

### 3.2 Data Format Optimization

Three formats for computational efficiency:

| Format | Description | Speed | Use Case |
|--------|-------------|-------|----------|
| STV | Space-Time Vector | Slowest | Irregular data, maximum flexibility |
| STG | Space-Time Grid | Fast | Regular CTM grids |
| STUG | Space-Time Unstructured Grid | **Fastest** | Large-scale multi-CTM fusion |

STUG provides 10-100× speedup for global-scale estimations while supporting multiple soft data sources.

### 3.3 Multi-CTM Fusion

Novel capability to simultaneously fuse multiple CTM datasets:
- Bitmask selection system (6 models = 2⁶ = 64 combinations)
- Automatic variance-weighted combination
- Preserves model-specific uncertainty information
- Example: Code `13000313` = hard data + all 6 CTMs, 100 hard neighbors, 10 soft neighbors

---

## 4. Validation Framework

### 4.1 Leave-One-Out Cross-Validation (LOOCV)
- Sequentially removes each observation, estimates at that location, compares to held-out value
- Monthly processing with ±1 year temporal window
- Provides unbiased performance estimates at observed locations

### 4.2 Checker-Board Validation (CBV)
- Divides domain into alternating grid squares (checkerboard pattern)
- Two folds: black squares for training, white for validation (then reversed)
- Tests performance at spatially separated locations (more realistic for mapping applications)
- Multiple box sizes tested: 2.0°, 2.5°, 3.0°, 3.5°, 4.0°, 4.5°, 5.0°
- Prevents data leakage: global offset and covariance computed using training data only

### 4.3 Validation Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| R² | Coefficient of determination | > 0.7 |
| RMSE | Root mean square error (ppb) | < 10 |
| MAE | Mean absolute error (ppb) | < 7 |
| ME | Mean error/bias (ppb) | ~ 0 |
| NMB | Normalized mean bias (%) | ~ 0 |
| IOA | Index of agreement | > 0.8 |
| FAC2 | Fraction within factor of 2 | > 0.9 |

---

## 5. Output Products

### 5.1 Gridded Ozone Fields
- **Variable**: Monthly MDA8 ozone concentration
- **Spatial Resolution**: Configurable (0.5° to 2.0°, typically 1.0°)
- **Temporal Resolution**: Monthly (2015-2020)
- **Coverage**: Global or regional (10 predefined area codes: CONUS, Europe, East Asia, etc.)
- **Format**: MATLAB .mat files per timestep

### 5.2 Uncertainty Quantification
Each estimation point includes:
- **Mean estimate** (ppb): Best estimate of ozone concentration
- **Variance** (ppb²): Estimation uncertainty from kriging system
- **Standard deviation** (ppb): √variance for confidence intervals

Confidence intervals:
- 68% CI: mean ± 1σ
- 95% CI: mean ± 2σ

---

## 6. Key Scientific Contributions

1. **Multi-Source Data Fusion**: First framework to simultaneously integrate TOAR-II observations with multiple RAMP-corrected CTM outputs using BME

2. **Flexible Spatiotemporal Detrending**: 11 global offset scenarios enabling scale-appropriate trend removal from urban (10°) to global (180°) applications

3. **Computational Innovation**: STUG data format providing 10-100× speedup for large-scale geostatistical estimation

4. **Rigorous Uncertainty Quantification**: Full variance propagation from observations through CTM bias correction to final estimates

5. **Comprehensive Validation**: Dual validation strategy (LOOCV + CBV) providing performance assessment at both observed and unobserved locations

6. **Reproducible Framework**: Complete MATLAB codebase with caching, HPC support, and extensive documentation

---

## 7. Technical Specifications

**Software Requirements**:
- MATLAB R2019b+ with Statistics and Machine Learning Toolbox
- BMELIB (Bayesian Maximum Entropy library)

**Computational Performance** (typical):
- Global offset estimation: 5-10 seconds (cached)
- Covariance fitting: 10-30 seconds (cached)
- Single month BME estimation (1° grid): 30-60 seconds
- Full annual estimation (12 months): 6-12 minutes
- LOOCV (full year): 2-4 hours
- CBV (7 box sizes × 2 folds × 5 years): 24-72 hours (HPC)

---

## 8. Study Domain and Period

- **Temporal**: 2015-2020 (6 years, 72 months)
- **Spatial**: Global coverage with focus regions:
  - CONUS: [-125°, -65°] × [24°, 50°]
  - Europe: [-10°, 45°] × [35°, 72°]
  - East Asia: [90°, 150°] × [5°, 60°]
- **Vertical**: Surface layer (~10m above ground level)

---

## 9. Global Offset Scenarios (Detailed)

| Scenario | Name | Spatial Scale | Temporal Scale | Use Case |
|----------|------|---------------|----------------|----------|
| 0 | Zero | None | None | Residual analysis only |
| 1 | Flat | Very large | Very long | Constant mean only |
| 2 | Domain-wide | 180° | 50 months | Global smoothing |
| 3 | Regional | 90° (~10,000 km) | 20 months (~1.7 yrs) | **Recommended default** |
| 4 | Local | 45° (~5,000 km) | 10 months | Urban-scale |
| 5 | Regional S/T | 90° | 10 months | Regional with seasonal |
| 6 | Local S/T | 45° | 5 months | High-resolution |
| 7 | Super-Local | 10° (~1,100 km) | 2 months | Very high-resolution |
| 8 | Regional (balanced) | 90° | 20 months (cyclic) | Enhanced temporal |
| 9 | Sub-regional | 60° (~6,600 km) | 15 months (cyclic) | Intermediate |
| 10 | Local (seasonal) | 45° | 10 months (cyclic) | Local with seasonality |

---

## 10. BME Method Code System

8-digit codes control estimation behavior:

```
Format: ABCDEFGH

A: Estimation type
   1 = BME with probabilistic soft data
   2 = Direct kriging
   3 = Kriging with multi-soft (STUG format)

B: Soft data type
   0 = Hard data only
   1 = Single CTM soft dataset
   3 = Multiple CTM soft datasets (multi-fusion)

C-E: Reserved (000)

F: Soft data neighbors
   0 = 0, 1 = 3, 2 = 4, 3 = 10, 4 = 50, 5 = 100, 6 = 200

G: Hard data neighbors
   1 = 50, 2 = 100, 3 = 200, 4 = 300

H: Probability type
   2 = KrigingME
   3 = KrigingME_multi
```

**Common configurations**:
- `10000132`: Hard data only, 100 neighbors, kriging (baseline)
- `11000142`: Hard + single CTM, 100 hard, 50 soft neighbors
- `13000313`: Hard + multi-CTM fusion, 100 hard, 10 soft neighbors

---

## 11. Mathematical Formulation

### BME Estimation Equation

For estimation point **p**ₖ = (sₖ, tₖ):

```
Ẑ(pₖ) = μ(pₖ) + Σᵢ λᵢ·[Z(pᵢ) - μ(pᵢ)]
```

Where:
- Ẑ(pₖ) = estimated ozone at point k
- μ(pₖ) = global offset (mean trend) at point k
- λᵢ = kriging weights (from covariance system)
- Z(pᵢ) = observed/soft data at neighbor point i

### Kriging Variance

```
σ²ₖ = C(0,0) - Σᵢ λᵢ·C(pₖ, pᵢ)
```

Where C(·,·) is the fitted covariance function.

### Soft Data Integration

Soft data enters as Gaussian probability constraints:

```
P(Zₛ) ~ N(λ₁, λ₂)
```

Where λ₁ = RAMP-corrected mean, λ₂ = RAMP-corrected variance.

---

## 12. Key References

- **BME Theory**: Christakos, G. (2000). Modern Spatiotemporal Geostatistics. Oxford University Press.
- **BMELIB**: Serre, M.L., et al. BME library for MATLAB.
- **TOAR-II**: Schultz, M.G., et al. Tropospheric Ozone Assessment Report.
- **RAMP**: Bias correction methodology for CTM outputs.

---

## 13. Suggested Paper Structure

1. **Introduction**: Importance of ozone monitoring, limitations of sparse networks, need for data fusion
2. **Data**: TOAR-II observations, CTM models, RAMP correction
3. **Methods**: BME framework, global offset, covariance modeling, soft data integration
4. **Validation**: LOOCV and CBV methodology and results
5. **Results**: Gridded ozone fields, uncertainty maps, regional analysis
6. **Discussion**: Comparison with existing products, limitations, future work
7. **Conclusions**: Key findings and contributions

---

*Last updated: 2026-03-06*
