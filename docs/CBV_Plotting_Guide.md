# Checker-Board Validation (CBV) Plotting Guide

## Overview

The CBV plotting system is organized into **three phases**, each serving a distinct purpose in evaluating and understanding the performance of BME ozone estimation:

- **Phase 1**: Core enhanced visualizations (scatter plots, metrics trends, regional overview)
- **Phase 2**: Advanced diagnostics (residual analysis, uncertainty quantification)
- **Phase 3**: Configuration comparison (comparing multiple soft data configurations)

This guide provides detailed information on what each plot represents and how to interpret the results.

---

## Phase 1: Enhanced CBV Plotting

**Purpose**: Provide comprehensive overview of validation performance across years, box sizes, and regions.

**Usage**:
```matlab
figPaths = plotCBVresults_Phase1('./7validation/CBV', 'visible', 'on');
```

### Plot 1.1: Multi-Panel Scatter Plots by Year

**File**: `CBV_scatter_by_year.png`

**What it shows**: Side-by-side scatter plots of observed vs. estimated ozone values for each validation year, aggregated across all folds and box sizes.

**Interpretation**:
- **X-axis**: Observed ozone concentration (ppb)
- **Y-axis**: Estimated ozone concentration (ppb)
- **Diagonal line**: Perfect 1:1 agreement (ideal case)
- **Point cloud**: Each point represents one validation location
- **Statistics box**: Shows R² (correlation), RMSE (root mean square error), and N (sample size)

**What to look for**:
- ✅ **Good performance**: Points cluster tightly around the 1:1 line (R² > 0.7)
- ⚠️ **Systematic bias**: Points systematically above/below 1:1 line (over/under-estimation)
- ⚠️ **Heteroscedasticity**: Scatter increases at high or low values (non-constant variance)
- ⚠️ **Outliers**: Points far from the main cluster (potential data quality issues)
- 📊 **Year-to-year consistency**: Similar R² and RMSE across years indicates stable performance

**Example interpretation**:
> "Year 2016 shows R² = 0.85, RMSE = 3.2 ppb with tight clustering around 1:1 line, indicating excellent performance. Year 2018 shows slightly lower R² = 0.78 with more scatter at high concentrations, suggesting the model has more difficulty during high-ozone events that year."

---

### Plot 1.2: Combined Fold/Average Metrics by Box Size

**File**: `CBV_metrics_by_boxsize.png`

**What it shows**: Four subplots showing how validation metrics (R², RMSE, MAE, NMB) vary with box size, displaying individual folds and cross-fold averages.

**Subplots**:
1. **R² (top-left)**: Coefficient of determination (higher is better, 0-1)
2. **RMSE (top-right)**: Root mean square error in ppb (lower is better)
3. **MAE (bottom-left)**: Mean absolute error in ppb (lower is better)
4. **NMB (bottom-right)**: Normalized mean bias in % (closer to 0 is better)

**Interpretation**:
- **X-axis**: Box size in degrees (spatial extent of withheld data)
- **Colored lines**: Individual fold performance (shows fold-to-fold variability)
- **Black line with error bars**: Average across all folds ± standard deviation
- **Box size effect**: Shows how estimation difficulty changes with spatial gap size

**What to look for**:
- ✅ **Stable performance**: Metrics remain relatively flat across box sizes (spatially consistent model)
- ⚠️ **Degradation at large boxes**: R² drops or RMSE increases at larger box sizes (model struggles with large data gaps)
- ✅ **Small error bars**: Low fold-to-fold variability indicates robust, consistent performance
- ⚠️ **Large error bars**: High variability suggests performance depends on which data is withheld
- ⚠️ **Systematic bias**: NMB consistently positive (over-estimation) or negative (under-estimation)

**Example interpretation**:
> "R² remains stable at ~0.80 for box sizes 5-15°, then drops to 0.70 at 20°, indicating the model maintains accuracy for moderate data gaps but struggles with larger gaps. Error bars are small (std < 0.03), showing consistent performance across all folds. NMB stays near 0% across all box sizes, confirming no systematic bias."

---

### Plot 1.3: Regional Performance Heatmap

**File**: `CBV_regional_performance.png`

**What it shows**: Heatmap showing R² values for different geographic regions (rows) and box sizes (columns).

**Interpretation**:
- **Rows**: Geographic regions (e.g., North America, Europe, East Asia, etc.)
- **Columns**: Box sizes tested (e.g., 5°, 10°, 15°, 20°)
- **Color intensity**: R² value (darker blue = better performance)
- **Cell annotations**: R² value and sample size (n=...)

**What to look for**:
- ✅ **Consistently dark cells**: R² > 0.75 across regions indicates globally reliable model
- ⚠️ **Light cells**: R² < 0.6 in specific regions indicates poor performance there
- 📊 **Regional patterns**: Some regions may perform consistently worse (sparse data, complex terrain)
- 📊 **Sample size effect**: Very small n (<50) may give unreliable statistics
- ⚠️ **Box size effect by region**: Some regions may degrade faster at large box sizes

**Example interpretation**:
> "North America and Europe show consistently high R² (0.82-0.88) across all box sizes with large sample sizes (n>500), indicating excellent data coverage and model performance. East Asia shows lower R² (0.65-0.72) and drops more sharply at large box sizes, suggesting the model has more difficulty there, possibly due to complex terrain or different emission patterns."

---

## Phase 2: Advanced CBV Diagnostics

**Purpose**: Deep-dive analysis of model residuals and uncertainty quantification to identify systematic errors and assess reliability of prediction intervals.

**Usage**:
```matlab
figPaths = plotCBVresults_Phase2('./7validation/CBV', 'visible', 'on');
```

---

### Analysis 2.1: Residual Analysis

Residual = Observed - Predicted. Residuals should be random, normally distributed, and show no patterns if the model is well-specified.

#### Plot 2.1a: Residuals vs Predicted Values

**File**: `residuals/residuals_vs_predicted.png`

**What it shows**: Scatter plot of residuals (y-axis) against predicted values (x-axis).

**Interpretation**:
- **Horizontal dashed line at 0**: Zero residual (perfect prediction)
- **Red dashed lines**: ±2σ bounds (95% of points should fall within these)
- **Red solid line**: LOWESS smooth trend line
- **Point cloud**: Each validation location's residual

**What to look for**:
- ✅ **Random scatter around 0**: No systematic pattern = well-specified model
- ⚠️ **Funnel shape**: Variance increases with predicted value = heteroscedasticity
- ⚠️ **Curved trend line**: Systematic bias at high or low values = model mis-specification
- ⚠️ **Horizontal offset**: Trend line away from 0 = overall bias
- ⚠️ **Points outside ±2σ**: >5% outside bounds = underestimated uncertainty

**Example interpretation**:
> "Residuals show random scatter around zero with no clear pattern, confirming the model is well-specified. The LOWESS trend line stays near zero across the full range of predicted values, indicating no systematic bias. ~95% of points fall within ±2σ bounds as expected. A slight funnel shape at high values suggests slightly higher uncertainty for high-ozone events."

---

#### Plot 2.1b: Residual Histogram with Normality Test

**File**: `residuals/residual_histogram.png`

**What it shows**: Histogram of residuals with overlaid normal distribution curve and normality test results.

**Interpretation**:
- **Bars**: Frequency distribution of residuals
- **Red curve**: Theoretical normal distribution with same mean and std
- **Statistics box**: Shapiro-Wilk test p-value and skewness/kurtosis

**What to look for**:
- ✅ **Bell-shaped distribution**: Residuals approximately normally distributed
- ✅ **Centered at zero**: No systematic bias
- ⚠️ **Skewed distribution**: Long tail to right (under-prediction bias) or left (over-prediction bias)
- ⚠️ **Heavy tails**: More extreme values than expected (fat tails, kurtosis > 3)
- 📊 **Shapiro-Wilk p-value**: p > 0.05 suggests residuals are approximately normal

**Example interpretation**:
> "Residuals are approximately normally distributed (Shapiro-Wilk p = 0.12) with mean near zero (-0.05 ppb), confirming minimal bias. Distribution is symmetric (skewness = 0.08) with slightly heavier tails than expected (kurtosis = 3.4), suggesting the model occasionally produces larger errors than a purely Gaussian model would predict."

---

#### Plot 2.1c: Q-Q Plot (Quantile-Quantile)

**File**: `residuals/qq_plot.png`

**What it shows**: Quantiles of residuals vs. quantiles of theoretical normal distribution.

**Interpretation**:
- **Diagonal line**: Perfect normal distribution
- **Points**: Actual residual quantiles

**What to look for**:
- ✅ **Points on diagonal**: Residuals are normally distributed
- ⚠️ **S-shaped curve**: Heavy tails (more extreme values than normal)
- ⚠️ **Deviation at extremes**: Light tails (fewer extreme values)
- ⚠️ **Systematic offset**: Non-zero mean

**Example interpretation**:
> "Q-Q plot shows points closely following the diagonal line in the central range (-1σ to +1σ), confirming normality for typical errors. Slight upward deviation at positive extreme (>2σ) indicates occasional larger positive residuals than expected from normal distribution, consistent with the slightly heavy right tail seen in histogram."

---

#### Plot 2.1d: Spatial Residual Map

**File**: `residuals/spatial_residuals.png`

**What it shows**: Geographic map showing residual magnitude and sign at each validation location.

**Interpretation**:
- **Point color**: Blue (under-estimation), Red (over-estimation)
- **Point size**: Proportional to |residual| magnitude
- **Geographic patterns**: Reveals if errors cluster spatially

**What to look for**:
- ✅ **Random spatial distribution**: Errors uniformly distributed across map
- ⚠️ **Clustered colors**: Systematic over/under-estimation in specific regions
- ⚠️ **Systematic gradients**: Errors increase with latitude, proximity to coast, etc.
- ⚠️ **Large points clustered**: Multiple large errors in same area = model struggles there

**Example interpretation**:
> "Residuals show no clear spatial pattern, with blue and red points randomly distributed. Largest residuals (|r| > 5 ppb) appear scattered across the domain rather than clustered, suggesting errors are due to local factors rather than systematic regional biases. Slight concentration of red points in urban areas may indicate the model slightly over-estimates in high-emission regions."

---

#### Plot 2.1e: Residual Boxplot by Region

**File**: `residuals/residuals_by_region.png`

**What it shows**: Box-and-whisker plots showing residual distribution for each geographic region.

**Interpretation**:
- **Box**: Interquartile range (25th-75th percentile)
- **Center line**: Median residual
- **Whiskers**: Extend to 1.5×IQR
- **Outliers**: Points beyond whiskers

**What to look for**:
- ✅ **Boxes centered at 0**: No regional bias
- ⚠️ **Offset boxes**: Systematic over/under-estimation in specific regions
- ⚠️ **Wide boxes**: High variability in some regions
- ⚠️ **Many outliers**: Model struggles with extreme values in certain regions

**Example interpretation**:
> "All regions show median residuals near zero, confirming no systematic regional bias. Europe and North America have narrow boxes (IQR ~4 ppb) with few outliers, indicating consistent performance. East Asia shows wider box (IQR ~7 ppb) and more outliers, suggesting higher variability and occasional large errors in that region."

---

#### Plot 2.1f: Temporal Residual Trend

**File**: `residuals/temporal_residuals.png`

**What it shows**: How residuals evolve over time (monthly or seasonal patterns).

**Interpretation**:
- **X-axis**: Time (month of year or date)
- **Y-axis**: Residuals
- **Box plots or scatter**: Residual distribution at each time point
- **Trend line**: Seasonal or long-term pattern

**What to look for**:
- ✅ **Flat trend**: No temporal bias
- ⚠️ **Seasonal pattern**: Systematic over/under-estimation in certain months
- ⚠️ **Long-term trend**: Performance degrading or improving over time
- ⚠️ **Higher variance in certain seasons**: Model less reliable in specific months

**Example interpretation**:
> "Residuals show a slight seasonal pattern: median residuals are near zero in winter (DJF) but slightly positive in summer (JJA), suggesting the model tends to over-estimate by ~1-2 ppb during summer months. This could be due to under-represented summertime chemical mechanisms or biogenic emissions. Residual variance is larger in summer (σ ~4.5 ppb) than winter (σ ~3.2 ppb)."

---

### Analysis 2.2: Uncertainty Analysis

Examines whether the BME estimation variance (XkBMEv) provides reliable uncertainty estimates.

#### Plot 2.2a: Uncertainty vs Absolute Error

**File**: `uncertainty/uncertainty_vs_error.png`

**What it shows**: Scatter plot comparing predicted uncertainty (σ from XkBMEv) with actual absolute errors.

**Interpretation**:
- **X-axis**: Predicted standard deviation (√XkBMEv) in ppb
- **Y-axis**: Actual absolute error |obs - est| in ppb
- **1:1 line**: Perfect calibration (predicted uncertainty = actual error)
- **Red trend line**: Actual relationship between uncertainty and error
- **Correlation**: Quantifies how well uncertainty predicts error magnitude

**What to look for**:
- ✅ **Points clustered near 1:1**: Well-calibrated uncertainties
- ✅ **High correlation (R > 0.6)**: Uncertainty is informative about error magnitude
- ⚠️ **Points above 1:1**: Under-estimated uncertainty (actual errors larger than predicted)
- ⚠️ **Points below 1:1**: Over-estimated uncertainty (being too cautious)
- ⚠️ **Low correlation (R < 0.4)**: Uncertainty estimates not informative

**Example interpretation**:
> "Uncertainty vs error plot shows moderate positive correlation (R = 0.62), indicating the BME variance provides useful information about error magnitude. Points cluster slightly above the 1:1 line, suggesting uncertainties are slightly under-estimated: actual errors are ~10% larger than predicted. Trend line suggests that when predicted σ = 3 ppb, actual |error| ≈ 3.3 ppb."

---

#### Plot 2.2b: Calibration Plot

**File**: `uncertainty/calibration.png`

**What it shows**: Binned comparison of predicted uncertainty vs actual RMSE within each uncertainty bin.

**Interpretation**:
- **X-axis**: Predicted uncertainty (bin centers)
- **Y-axis**: Observed RMSE within each bin
- **Diagonal line**: Perfect calibration
- **Bars**: Actual RMSE ± standard error in each bin

**What to look for**:
- ✅ **Bars follow diagonal**: Well-calibrated across full uncertainty range
- ⚠️ **Bars above diagonal**: Systematic under-estimation of uncertainty
- ⚠️ **Bars below diagonal**: Systematic over-estimation of uncertainty
- ⚠️ **Divergence at high uncertainty**: Calibration breaks down for high-uncertainty locations

**Example interpretation**:
> "Calibration plot shows good agreement with diagonal for low-to-moderate uncertainties (σ < 4 ppb). At high uncertainties (σ > 5 ppb), bars fall below the diagonal, indicating the model is too conservative for high-uncertainty locations—actual errors are smaller than predicted. This suggests the covariance model may be over-estimating variance in data-sparse regions."

---

#### Plot 2.2c: Spatial Uncertainty Map

**File**: `uncertainty/spatial_uncertainty.png`

**What it shows**: Geographic map of predicted uncertainty (√XkBMEv) at validation locations.

**Interpretation**:
- **Point color/size**: Predicted uncertainty magnitude
- **Geographic patterns**: Shows where model is most/least confident

**What to look for**:
- 📊 **Higher uncertainty in data-sparse regions**: Expected behavior
- 📊 **Lower uncertainty near observations**: Expected behavior
- ⚠️ **Uniformly low uncertainty**: May indicate under-estimated variance (nugget too small)
- ⚠️ **Extremely high uncertainty clusters**: Potential covariance model issues

**Example interpretation**:
> "Uncertainty map shows expected spatial pattern: lowest uncertainty (σ < 2 ppb, blue) in North America and Europe where station density is highest, and highest uncertainty (σ > 5 ppb, red) in Africa and South Pacific where stations are sparse. This confirms the BME variance reflects data availability as expected."

---

#### Plot 2.2d: Coverage Probability Plot

**File**: `uncertainty/coverage_probability.png`

**What it shows**: Empirical coverage probability of prediction intervals vs. nominal confidence level.

**Interpretation**:
- **X-axis**: Nominal confidence level (e.g., 50%, 68%, 95%)
- **Y-axis**: Observed fraction of observations within predicted interval
- **Diagonal line**: Perfect calibration (e.g., 95% of obs fall in 95% interval)

**What to look for**:
- ✅ **Curve on diagonal**: Prediction intervals are well-calibrated
- ⚠️ **Curve below diagonal**: Over-confident (intervals too narrow)
- ⚠️ **Curve above diagonal**: Under-confident (intervals too wide)

**Example interpretation**:
> "Coverage probability follows diagonal closely: 68% prediction intervals contain 67% of observations (very close to nominal), and 95% intervals contain 93% (slightly under-confident). This indicates BME uncertainty estimates are well-calibrated and can be trusted for constructing prediction intervals."

---

#### Plot 2.2e: Uncertainty Distribution

**File**: `uncertainty/uncertainty_distribution.png`

**What it shows**: Histogram comparing distribution of predicted uncertainties with distribution of actual absolute errors.

**Interpretation**:
- **Blue bars**: Distribution of predicted σ
- **Red bars**: Distribution of actual |errors|
- **Overlap**: Agreement between distributions indicates calibration

**What to look for**:
- ✅ **Overlapping distributions**: Good calibration
- ⚠️ **Red shifted right of blue**: Under-estimated uncertainties
- ⚠️ **Red shifted left of blue**: Over-estimated uncertainties

**Example interpretation**:
> "Predicted uncertainty distribution (blue) has median = 3.2 ppb, while actual |error| distribution (red) has median = 3.5 ppb. Distributions overlap substantially but red distribution has a slightly heavier right tail, confirming the finding that uncertainties are slightly under-estimated, particularly for large errors."

---

### Analysis 2.3: Regional Breakdown

Detailed regional performance analysis (same types of plots as Phase 2.1 and 2.2, but stratified by region).

---

## Phase 3: Configuration Comparison Analysis

**Purpose**: Compare performance across different BME soft data configurations (e.g., observations-only vs. observations + CTM models vs. observations + satellites).

**Usage**:
```matlab
configDirs = {
    './7validation/CBV_obs_only',
    './7validation/CBV_with_M3fusion',
    './7validation/CBV_with_all_sources'
};
configNames = {
    'Observations only',
    'Obs + M3fusion',
    'Obs + All sources'
};
figPaths = plotCBVresults_Phase3(configDirs, configNames, ...
    'baselineConfig', 1, 'saveDir', './figs_comparison');
```

---

### Plot 3.1: Bar Chart Comparison by Year

**File**: `config_comparison_by_year.png`

**What it shows**: Multi-panel bar charts showing each metric (R², RMSE, MAE, NMB) by year, with bars for each configuration side-by-side.

**Interpretation**:
- **Panels**: Each row = one metric, each column = one year
- **Bars**: Each configuration's performance
- **Green bar**: Best performer for that metric/year
- **Value labels**: Exact metric values on each bar

**What to look for**:
- ✅ **Consistent best performer**: One configuration always wins = clear winner
- 📊 **Variable winner**: Different configs win different years = year-dependent
- ✅ **Additive improvements**: Each added data source improves metrics progressively
- ⚠️ **No improvement or degradation**: Added data doesn't help or hurts = data quality issues
- 📊 **Magnitude of improvement**: Large improvements (ΔR² > 0.05) = substantial value added

**Example interpretation**:
> "Observations-only shows R² = 0.75-0.78 across all years. Adding M3fusion increases R² to 0.80-0.83 (improvement of 0.05), and adding all sources further increases to 0.83-0.86 (total improvement of 0.08 over baseline). RMSE decreases from ~4.5 ppb (baseline) to ~3.8 ppb (M3fusion) to ~3.2 ppb (all sources). This demonstrates clear, consistent value from soft data integration, with CTM models providing the largest benefit."

---

### Plot 3.2: Spider/Radar Plot for Multi-Metric Comparison

**File**: `config_comparison_spider.png`

**What it shows**: Radar plot showing normalized performance across all metrics simultaneously for each configuration.

**Interpretation**:
- **Axes**: Each spoke represents one metric (normalized 0-1, higher = better)
- **Polygons**: Each configuration's overall performance profile
- **Polygon area**: Overall performance (larger = better)

**What to look for**:
- ✅ **Larger polygon**: Better overall performance
- 📊 **Balanced polygon**: Consistent performance across all metrics
- ⚠️ **Irregular polygon**: Excels in some metrics but poor in others
- 📊 **Overlapping polygons**: Configurations perform similarly
- ✅ **Clear separation**: One configuration dominates across all metrics

**Example interpretation**:
> "Spider plot shows 'Obs + All sources' (blue) has the largest polygon, dominating all metrics. Its polygon is well-balanced, indicating consistent improvement across R², RMSE, MAE, and NMB. 'Obs + M3fusion' (green) polygon is intermediate, showing that CTM models provide most of the benefit, while satellites and ML models provide incremental gains. 'Obs only' (red) has smallest polygon, especially weak in RMSE and MAE dimensions."

---

### Plot 3.3: Temporal Trend Analysis

**File**: `temporal_trends_by_config.png`

**What it shows**: Line plots showing how each configuration's metrics evolve over time (year-by-year stability).

**Interpretation**:
- **X-axis**: Year
- **Y-axis**: Metric value
- **Lines**: Each configuration's trajectory
- **Shaded regions**: ±1σ confidence intervals

**What to look for**:
- ✅ **Parallel lines**: Relative performance is stable over time
- ⚠️ **Converging lines**: Performance gap closing (baseline improving or soft data degrading)
- ⚠️ **Diverging lines**: Performance gap widening (soft data increasingly valuable)
- ⚠️ **Crossing lines**: Relative ranking changes = configuration-specific to year
- ✅ **Narrow confidence bands**: Performance is consistent and reliable

**Example interpretation**:
> "R² trends show all configurations improving slightly from 2015 to 2020 (0.75→0.82 for baseline, 0.82→0.87 for all sources), likely due to increased station density. Lines remain parallel throughout the period, indicating the benefit of soft data (~0.05 R² units) is stable across time. RMSE shows similar pattern with slightly wider confidence bands in 2017-2018, possibly due to anomalous meteorology those years."

---

### Plot 3.4: Soft Data Contribution Analysis

**File**: `soft_data_contribution.png`

**What it shows**: Quantifies incremental value of each soft data source relative to baseline.

**Interpretation**:
- **Stacked bars**: Baseline performance + incremental contribution of each data source
- **Colors**: Each data source (CTM, satellite, ML models)
- **Height**: Total performance improvement

**What to look for**:
- 📊 **Largest stack**: Identify which data source contributes most
- ✅ **Positive contributions**: All sources add value
- ⚠️ **Negative contribution**: Adding that source hurts performance (data quality issues)
- 📊 **Diminishing returns**: Each added source contributes less than previous

**Example interpretation**:
> "Baseline R² = 0.76. Adding M3fusion CTM increases R² by +0.05 (to 0.81), representing 62% of total improvement. Adding satellite products (OMI-MLS, IASI-GOME2) increases R² by additional +0.02 (to 0.83), representing 25% of improvement. Adding ML models (UKML, NJML) increases R² by final +0.01 (to 0.84), representing 13% of improvement. This shows CTM models provide the largest benefit, satellites provide moderate benefit, and ML models provide marginal benefit in this dataset."

---

### Tables: Summary Statistics

**Files**:
- `config_comparison_summary.csv`: Overall statistics for each configuration
- `config_comparison_by_year.csv`: Statistics broken down by configuration and year

**Contents**:
- Configuration name
- Sample size (N)
- R², RMSE, MAE, NMB
- Mean observed and estimated values

**Use case**: Quantitative comparison for publications, identifying best configuration, tracking improvement magnitude.

---

## Summary: Interpretation Workflow

### Step 1: Start with Phase 1
- Check **scatter plots** for overall fit quality (looking for R² > 0.7, tight 1:1 clustering)
- Examine **metrics by box size** to ensure stable performance (flat lines, small error bars)
- Review **regional heatmap** to identify problem regions (light colors = poor performance)

### Step 2: Diagnose Issues with Phase 2
- If scatter shows bias patterns → check **residual plots** for systematic errors
- If regional performance varies → check **regional residual boxplots** for spatial bias
- If uncertainty is a concern → check **calibration plots** to assess reliability
- Check **spatial residual map** for geographic error patterns

### Step 3: Compare Configurations with Phase 3
- Compare **bar charts** to quantify improvement from soft data
- Use **spider plots** for multi-metric overview
- Check **temporal trends** to ensure improvements are stable over time
- Review **contribution analysis** to identify most valuable data sources

---

## Common Interpretation Patterns

### Pattern 1: Good Model Performance
- R² > 0.75, RMSE < 4 ppb, |NMB| < 5%
- Scatter tightly clustered around 1:1 line
- Metrics stable across box sizes and years
- Residuals random, normally distributed, no spatial patterns
- Uncertainties well-calibrated (coverage probability follows diagonal)

### Pattern 2: Regional Bias
- Good overall R² but some regions show R² < 0.6
- Regional residual boxplots show systematic offsets
- Spatial residual map shows clustered colors in problem regions
- **Possible causes**: Sparse data, complex terrain, different emission patterns, seasonality

### Pattern 3: Under-Estimated Uncertainty
- Coverage probability below diagonal (intervals too narrow)
- Uncertainty vs error points above 1:1 line
- **Possible causes**: Nugget too small, covariance range too long, ignoring non-stationary variance

### Pattern 4: Soft Data Not Helping
- Adding soft data doesn't improve R² or RMSE
- Bar charts show minimal difference between configurations
- **Possible causes**: Soft data has large errors, soft data not independent of observations, insufficient soft data coverage

### Pattern 5: Temporal Instability
- Performance varies substantially across years
- Temporal trend plots show non-parallel lines or crossing
- **Possible causes**: Network changes, instrument drift, inter-annual climate variability

---

## Best Practices

1. **Always view Phase 1 first**: Get overall picture before deep-diving
2. **Don't over-interpret single plots**: Look for consistent patterns across multiple diagnostics
3. **Consider sample size**: Statistics from n < 50 are unreliable
4. **Compare to baseline**: Improvements should be evaluated relative to observations-only
5. **Check all years**: A model that works well in one year but poorly in others is not robust
6. **Validate calibration**: Well-calibrated uncertainties are essential for risk assessment
7. **Document findings**: Save plots and write interpretation notes for future reference

---

## Quick Reference: Plot Types by Purpose

| **Purpose** | **Recommended Plots** |
|-------------|----------------------|
| Overall model quality | Phase 1: Scatter by year, Metrics by box size |
| Identify systematic bias | Phase 2: Residuals vs predicted, Residual histogram |
| Find problem regions | Phase 1: Regional heatmap; Phase 2: Spatial residual map |
| Assess uncertainty reliability | Phase 2: Uncertainty vs error, Calibration, Coverage probability |
| Compare configurations | Phase 3: Bar charts, Spider plot, Contribution analysis |
| Check temporal stability | Phase 3: Temporal trends |
| Identify spatial error patterns | Phase 2: Spatial residual map, Regional boxplots |
| Diagnose model mis-specification | Phase 2: Residuals vs predicted, Q-Q plot |

---

## Questions to Ask Your Plots

1. **Is the model accurate?** → Check R² and RMSE (Phase 1)
2. **Is the model biased?** → Check NMB and residual histogram (Phase 1 & 2)
3. **Is performance consistent?** → Check metrics by box size, temporal trends (Phase 1 & 3)
4. **Where does the model struggle?** → Check regional heatmap, spatial residual map (Phase 1 & 2)
5. **Are uncertainties reliable?** → Check calibration and coverage probability (Phase 2)
6. **Does soft data help?** → Check configuration comparison (Phase 3)
7. **Is the model well-specified?** → Check residual patterns and Q-Q plot (Phase 2)
8. **Are there outliers or data quality issues?** → Check scatter plots and spatial maps (Phase 1 & 2)

---

## Technical Notes

### Metric Definitions

- **R²**: Coefficient of determination, measures fraction of variance explained (0-1, higher better)
- **RMSE**: Root mean square error, measures typical prediction error magnitude (ppb, lower better)
- **MAE**: Mean absolute error, robust measure of error magnitude (ppb, lower better)
- **NMB**: Normalized mean bias, measures systematic over/under-estimation (%, closer to 0 better)
- **Coverage Probability**: Fraction of observations within predicted confidence interval

### Statistical Tests

- **Shapiro-Wilk test**: Tests normality of residuals (p > 0.05 = approximately normal)
- **Correlation (R)**: Measures linear relationship strength (-1 to +1)

### Color Conventions

- **Blue**: Under-estimation (obs > est), negative residuals, low uncertainty
- **Red**: Over-estimation (obs < est), positive residuals, high uncertainty
- **Green**: Best performer in comparison plots
- **Black**: Average/consensus across folds or configurations

---

## Contact & Support

For questions about interpreting specific plots or adding new diagnostics:
1. Review this guide first
2. Check the code comments in `plotCBVresults_Phase*.m`
3. Examine example outputs in `./7validation/CBV/figs_*`

Last updated: 2026-02-03
