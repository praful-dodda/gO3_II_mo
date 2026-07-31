# Paper-3 draft text: post-processing analysis

> **How to use this file.** The paragraphs below are drop-in drafts for the
> **Methods**, **Results & Discussion**, and **Supporting Information (SI)** sections.
> **Status: FINAL numbers — full 1990–2022 record.** All values come from the completed
> post-processing run over the per-year best-method composite (method by era:
> `13000313-02` for 1990–2004, `13000313-06` for 2005–2016 and 2021, `13000313-0E` for
> 2017–2020, obs-only `10000133` for 2022), consolidated onto the common global land
> lattice of **18,173 cells × 396 monthly fields (1990–2022)**. Citation keys
> (`Author, year`), `[Figure N]`, and `[Table SN]` are placeholders.
>
> *(Supersedes an earlier 1990–2004 test draft. Note: an initial full-record run was
> invalidated by a grid-assembly bug — stray out-of-era estimate files on a different
> lattice collapsed the composite to 680 network-biased cells; fixed by restricting each
> method cube to its selected composite years. All numbers below are from the corrected
> 18,173-cell run.)*

---

## METHODS

### Ozone metrics
From the gap-free monthly maximum daily 8-h average (MDA8) ozone fields produced by the
BME data fusion (Section [BME methods]), we derived two annual metrics at every grid cell.
The **annual mean** is the arithmetic mean of the twelve monthly MDA8 values. The
**peak-season metric (OSDMA8)** is the maximum, over all contiguous six-month running
windows of monthly MDA8 (January of year *Y* through March of year *Y*+1), of the
within-window mean; this is identical to the warm-season "6mDMA8" metric used in prior
global ozone data-fusion work (DeLang et al., 2021; Becker et al., 2023) and underlies the
World Health Organization peak-season ozone air-quality guideline (WHO, 2021). Computing
OSDMA8 for year *Y* therefore requires the fifteen month-slots Jan(*Y*)–Mar(*Y*+1).

### Spatial aggregation and weighting
Grid cells were aggregated to global and regional means using two weightings. **Area
weighting** uses the cosine of latitude, so that each cell contributes in proportion to its
surface area. **Population weighting** uses gridded population counts mapped from the
[year] population product (here the static 2019 distribution; *N* = 7.67 × 10⁹ persons),
assigned to the nearest estimation cell. Because the population field is held fixed across
years, population-weighted trends isolate the change in ozone experienced by the present-day
population rather than confounding it with demographic change. Regional means were computed
for (i) eight world regions defined by longitude–latitude boundaries (North America, South
America, Europe, Russia, South-Central Asia, East Asia, Africa, and Oceania; mutually
exclusive by a fixed priority order), (ii) the Global Burden of Disease and WHO regions
attached to each cell from the population product, and (iii) individual countries. All
spatial averages used available (non-missing) cells only.

### Trend estimation
Linear trends in each annual series were estimated with two complementary methods and are
reported in ppb decade⁻¹. First, the non-parametric **Theil–Sen slope** with the
**Mann–Kendall** test (Sen, 1968; Mann, 1945; Kendall, 1975) provides an outlier-robust
estimate and significance. Second, to match the trend-detection framework used in the global
ozone literature, we fit an **ordinary least-squares (OLS) linear trend with an AR(1)
autocorrelation correction** following Weatherhead et al. (1998): the white-noise slope
standard error is inflated by √[(1+φ)/(1−φ)], where φ is the lag-1 autocorrelation of the
regression residuals, yielding an autocorrelation-adjusted two-sided *p*-value. From the same
framework we report **n\***, the number of years of data required to detect the observed
trend with 90% probability at the 5% significance level. To characterise changing rates, we
additionally fit OLS+AR(1) trends separately on two sub-periods split at a breakpoint year.
Per-cell trends were mapped over all land cells, with cells significant at *p* < 0.05 marked.

### Population exposure to air-quality guidelines
Population exposure was evaluated against the WHO 2021 peak-season ozone targets of 60, 70,
and 100 µg m⁻³ (the air-quality guideline level and interim targets), applied to OSDMA8 and
converted to mixing ratio at 2.0 µg m⁻³ ppb⁻¹ (i.e. 30, 35, and 50 ppb). For each year we
computed the fraction of the population, and of land area, in cells whose OSDMA8 exceeded each
target, and the trend in those fractions.

*(Optional, if the peak-month analysis is included)* **Timing of the seasonal maximum.** For
each cell and year we identified the calendar month of maximum MDA8 and summarised its drift
over the record with circular statistics (phase-unwrapped so that a December-to-January shift
reads as continuous), reporting the trend in days decade⁻¹.

---

## RESULTS & DISCUSSION

### Long-term global trends
Over the full 1990–2022 record, global land ozone increased, and the increase was
substantially larger for the population than for the land surface as a whole. The
area-weighted annual-mean MDA8 rose at **+0.80 ppb decade⁻¹** (OLS with AR(1) adjustment,
*p* = 0.002; Theil–Sen +0.78, *p* < 0.001; fitted 33.9 ppb in 1990 to 36.2 ppb in 2022)
[Figure N]. The **population-weighted** annual-mean trend was more than twice as large, at
**+1.70 ppb decade⁻¹** (*p* = 5 × 10⁻⁸; 35.4 → 41.1 ppb), showing that the average person
experienced a much faster increase than the unweighted land surface — because population
concentrates in the regions with the strongest ozone growth. The peak-season metric (OSDMA8)
tells the same story more sharply: **+0.56 ppb decade⁻¹** area-weighted (*p* = 0.008) but
**+2.07 ppb decade⁻¹** population-weighted (*p* = 8 × 10⁻¹⁶; 38.7 → 46.5 ppb). The
autocorrelation-adjusted detection times are short for the population-weighted series
(**n\* ≈ 8 yr** for OSDMA8, **≈ 10 yr** for the annual mean), i.e. these global trends are
robustly detectable within the record, whereas the weaker area-weighted signals need longer
(n\* ≈ 15–17 yr).

### Spatial pattern of trends
Trends were predominantly positive but spatially heterogeneous [Figure N]. Across all land
cells the **median per-cell trend was +0.89 ppb decade⁻¹** for the annual mean (**62%** of
cells significant at *p* < 0.05) and **+0.70 ppb decade⁻¹** for OSDMA8 (**60%** significant).
The strongest, most coherent increases occurred over East, South-Central and South-East Asia
and over Africa, while eastern North America and much of Europe showed significant *decreases*
in peak-season ozone (see regional and country results).

### Regional trends
Population-weighted OSDMA8 trends diverged sharply among the eight world regions (OLS with
AR(1) adjustment; [Table N], [Figure N]). Ozone rose fastest over **East Asia**
(**+5.38 ppb decade⁻¹**, *p* = 1 × 10⁻¹⁷, n\* ≈ 8 yr) and **South-Central Asia**
(**+3.08 ppb decade⁻¹**, *p* = 4 × 10⁻⁸, n\* ≈ 10 yr), with a further significant increase
over **Africa** (+1.06 ppb decade⁻¹, *p* < 10⁻³, n\* ≈ 14 yr). In stark contrast, the two
regions with the longest histories of ozone-precursor emission controls both *declined*
significantly: **North America** at **−1.05 ppb decade⁻¹** (*p* = 0.002, n\* ≈ 15 yr) and
**Europe** at **−0.82 ppb decade⁻¹** (*p* = 0.042, n\* ≈ 20 yr). **South America** showed a
marginal decline (−0.76 ppb decade⁻¹, *p* = 0.059), while **Russia** and **Oceania** were not
significant. This East/South-Asia-and-Africa rise against a North-American and European
decline is the dominant feature of the global ozone evolution and is consistent with the
regional patterns reported from surface networks and prior fusion products (DeLang et al.,
2021; Becker et al., 2023). The annual-mean regional trends show the same ranking (East Asia
+3.62, South-Central Asia +2.34, Africa +1.44 ppb decade⁻¹ population-weighted; all
*p* < 10⁻³), with North America and Europe essentially flat in the annual mean but declining
in the warm-season peak — indicating that western improvements are concentrated in the
high-ozone season that the peak metric captures.

### Changing rates: two-period analysis
Splitting the record at 2006 (1990–2006 vs 2007–2022; [Table SN]) shows the global
population-weighted OSDMA8 rise was **sustained** across both halves (+2.42 then
+2.46 ppb decade⁻¹), whereas the area-weighted rise **slowed** (+1.40 → +0.79 ppb decade⁻¹).
Regionally, the East Asian increase **accelerated** (population-weighted OSDMA8 +5.63 → +7.39
ppb decade⁻¹), and the North-American and European declines are a **recent-period
phenomenon**: both were flat or slightly rising in 1990–2006 and turned significantly negative
in 2007–2022 (North America population-weighted OSDMA8 +0.56 → −1.69 ppb decade⁻¹,
*p* = 6 × 10⁻⁴; Europe +0.31 → −1.25 ppb decade⁻¹, *p* = 0.023). This timing is consistent
with the maturation of NOₓ/VOC controls in the West after ~2005 and continued precursor growth
in Asia.

### Population exposure to WHO targets
Exposure to peak-season ozone above the WHO targets rose markedly, driven by the Asian and
African increases. The population share with OSDMA8 above the interim target of
**100 µg m⁻³ (50 ppb)** increased from **5.6% in 1990 to 40.7% in 2022** — a trend of
**+8.5 percentage-points decade⁻¹** (*p* = 1 × 10⁻⁶) [Figure N]. Exposure above
**70 µg m⁻³ (35 ppb)** rose from 81.6% to 86.5% (+4.5 pp decade⁻¹, *p* = 2 × 10⁻⁶), while
exposure above the air-quality-guideline level **60 µg m⁻³ (30 ppb)** stayed near-universal
(94.1% → 90.5%; no significant trend). Thus most of the world already exceeded the guideline
throughout the record, and the *upper tail* of the exposure distribution worsened
dramatically: the fraction of humanity experiencing high peak-season ozone (>50 ppb) grew
roughly seven-fold over three decades.

### Country-level picture
The per-country roll-up (219 countries; [Table SN]) localises these patterns. The largest
peak-season increases are in East and South Asia — **China +5.91 ppb decade⁻¹** (mean recent
OSDMA8 ≈ 54 ppb over ~1000 cells), Mongolia +5.12, Republic of Korea +4.14, DPR Korea +3.65,
Thailand +3.63 and Pakistan +3.56 ppb decade⁻¹ — while the steepest declines cluster in
south-eastern Europe and Central America (Serbia −3.92, Bosnia and Herzegovina −3.17, Ukraine
−3.13, Hungary −2.98; Costa Rica −3.89, Nicaragua −3.00 ppb decade⁻¹).

### Discussion points
- The divergence between population- and area-weighted global trends (OSDMA8 +2.07 vs
  +0.56 ppb decade⁻¹) shows that **exposure-relevant** ozone is rising several times faster
  than the area-mean, strengthening the public-health motivation for the data-fusion product.
- The autocorrelation-adjusted detection times (n\*) transparently separate robust trends
  (population-weighted global and Asian series, n\* ≈ 8–10 yr) from marginal ones (area-mean
  and western regions, n\* ≈ 15–20 yr), following Weatherhead et al. (1998).
- The two-period analysis resolves the **timing** of the western turnaround: North-American
  and European peak-season ozone only began to decline significantly after ~2006, so the
  full-record regional trends understate the pace of recent western improvement while the
  Asian increase has, if anything, accelerated.

---

## SUPPORTING INFORMATION (SI)

### S1. Post-processing data cube and grid
The monthly BME estimates were consolidated into a single space–time cube per method. Because
each monthly estimation grid appends that month's monitoring-site locations to the fixed map
lattice, the per-month grids differ; we therefore stacked all months onto their **common grid**
(the set of cells present in every contributing month, recovered by coordinate matching to
10⁻⁴°), which corresponds to the stable land lattice. Each method cube was restricted to the
years that method is actually selected for in the per-year composite, so that estimate files
produced for other eras on a slightly different lattice do not contract the common grid. The
five contributing per-method/era grids (18,573–24,235 cells; pairwise overlaps > 18,000 cells)
reconcile to a full-record composite of **18,173 land cells × 396 monthly fields (1990–2022)**
at 1° resolution, with no entirely-missing months. Per-year best-method compositing selects,
for each year, the best-validating method for its era (`13000313-02` for 1990–2004;
`13000313-06`, i.e. +OMI-MLS, for 2005–2016 and 2021; `13000313-0E`, +IASI-GOME2, for
2017–2020; obs-only `10000133` for 2022), the per-year skill being taken from the checkerboard
cross-validation (Section [validation]).

### S2. Metric and weighting details
OSDMA8 was computed with `computeOSDMA8`: ten six-month windows (starting Jan–Oct) are formed
from the fifteen month-slots Jan(*Y*)–Mar(*Y*+1); each window mean requires all six months
present (strict completeness), and OSDMA8 is the maximum window mean. Area weights are
cos(latitude); population weights are the sum of [year] population assigned to each cell by
nearest neighbour. Population-weighted and area-weighted means of a field *x* over a region are
Σwᵢxᵢ / Σwᵢ with wᵢ the population or area weight, respectively, over non-missing cells.

### S3. Trend-detection statistics
For an annual series *yₜ* on year *t*, the OLS slope ω̂ and intercept were obtained by least
squares; σ_N is the residual standard deviation (n−2 d.o.f.) and S_xx = Σ(t − t̄)². The
white-noise slope standard error is σ_N / √S_xx. The lag-1 autocorrelation of the residuals,
φ = Σeₜeₜ₋₁ / Σeₜ², inflates the standard error by √[(1+φ⁺)/(1−φ⁺)] with φ⁺ = min(max(φ,0),0.99)
(Weatherhead et al., 1998); the adjusted two-sided *p*-value uses the normal approximation
*p* = erfc(|ω̂/σ_ω| / √2). The number of years to detect the observed trend (90% power, 5%
significance) is n\* = [ (3.3 σ_N / |ω̂|) √((1+φ⁺)/(1−φ⁺)) ]^(2/3). Theil–Sen slopes and the
tie-corrected Mann–Kendall test are reported alongside for robustness; the two estimates agree
closely for the global series (e.g. global area-weighted OSDMA8 +0.545 (Theil–Sen) vs +0.555
(OLS) ppb decade⁻¹). Two-period trends split the record at **2006** (1990–2006 vs 2007–2022).

### S4. World-region definitions
World regions are mutually-exclusive longitude–latitude boxes assigned in priority order
[Table S1]: North America [−170,−52]×[15,84]; South America [−82,−34]×[−56,13];
Europe [−12,40]×[35,72]; Russia [30,180]×[50,78]; South-Central Asia [46,98]×[5,45];
East Asia [98,150]×[18,54]; Africa [−20,52]×[−36,38]; Oceania [110,180]×[−50,0]. Boxes are
approximate continental extents; cells outside all boxes are unassigned. Results are also
provided for Global Burden of Disease regions, WHO regions, and individual countries.

### S5. Supplementary tables (machine-readable CSVs provided)
- **Table S[ ] — Regional trends (Theil–Sen):** slope (ppb decade⁻¹), *p*-value, start/end
  fitted level, for every region, metric (annual mean, OSDMA8, four seasons, seasonal
  amplitude) and weighting. *(file: `regional_trends.csv`)*
- **Table S[ ] — Regional OLS + AR(1) trends:** slope, adjusted standard error, lag-1 φ,
  adjusted *p*, and n\*, per region/metric/weighting. *(file: `trend_ols_regional.csv`)*
- **Table S[ ] — Two-period (breakpoint) trends:** early- and late-period slopes and their
  difference. *(file: `trend_twoperiod_regional.csv`)*
- **Table S[ ] — Population exposure:** percentage of population and of land area above each WHO
  target, by year, and trends. *(files: `exposure_by_threshold.csv`, `exposure_trends.csv`)*
- **Table S[ ] — Country-level summary:** recent mean annual MDA8 and OSDMA8 and trends for 219
  countries. *(file: `country_trends.csv`)*
- **Table S[ ] — Method skill:** best-validating method per year and median CBV skill per
  method/year. *(files: `best_method_by_year.csv`, `method_year_skill.csv`)*

### S6. Supplementary figures
- **Figure S[ ]** — Regional population-weighted annual ozone time series by world region.
- **Figure S[ ]** — Seasonal-mean ozone time series and per-region seasonal trends.
- **Figure S[ ]** — Per-cell OSDMA8 trend map (Theil–Sen and OLS+AR(1)), with *p* < 0.05 marked.
- **Figure S[ ]** — Period-difference map (late minus early sub-period).
- **Figure S[ ]** — Two-period regional trends.
- **Figure S[ ]** — Latitude–time Hovmöller of zonal-mean annual ozone.
- **Figure S[ ]** *(optional)* — Mean peak-ozone month and its shift (days decade⁻¹); over
  1990–2022 the per-cell median shift is ≈ 0 with **43%** of cells significant at *p* < 0.05,
  but regional aggregates indicate an earlier warm-season peak over CONUS (≈ −15 days
  decade⁻¹) and East Asia (≈ −22 days decade⁻¹). The global circular-mean aggregate is
  sensitive to averaging across a spatially heterogeneous, shifting seasonal cycle and should
  be read cautiously.
- **Figure S[ ]** — Best-validating method by year.

### S7. Limitations
(i) Population weighting uses a single (2019) distribution, so population-weighted trends
reflect ozone change for a fixed population, not demographic change. (ii) World-region
boundaries are approximate boxes. (iii) The composite draws each year from a single
best-validating method; skill differences between the candidate methods within an era are
modest but non-zero (Section [validation]). (iv) The common-grid reconciliation keeps the
cells present across the contributing eras (18,173 of up to ~24,000); a small number of
recently-added near-shore/high-latitude cells present only in later years are therefore
excluded from the trend record. (v) Trends are computed on the fused product and inherit its
uncertainty (quantified per cell by the BME estimation variance, Section [uncertainty]).

---

## SUGGESTED MAIN-TEXT FIGURE/TABLE SET
- **Figure** — Global annual-mean and OSDMA8 time series with trends (area- vs population-weighted).
- **Figure** — World-region population-weighted OSDMA8 series (Global as a black dashed line).
- **Figure** — Per-cell annual-mean (or OSDMA8) trend map with significance.
- **Figure** — Population exposure above WHO targets over time.
- **Table** — Regional OSDMA8 trends (slope, *p*, n\*) for the eight world regions + global.

*Citations to resolve: DeLang et al. (2021); Becker et al. (2023); Weatherhead et al. (1998);
Sen (1968); Mann (1945); Kendall (1975); WHO (2021); Christakos (2000).*

---
---

# NEW SECTION — VALUE OF SATELLITE DATA IN THE BME FUSION (SATELLITE ERA)

> **Status: final numbers.** Values below are computed directly from the cached
> checker-board cross-validation (CBV) results in `7validation/CBV/` (they do **not**
> depend on the post-processing composite cube). Skill for each method/year is the mean
> over the two CBV folds; period skill is the mean over the matched years. Global-offset
> scenario 3, GO removed on training data only. Two checker-board box sizes are reported:
> **5°** (dense withholding) and **20°** (sparse withholding, larger gaps to fill).

## METHODS (addendum)

To isolate the contribution of *satellite* soft data, we compared the obs-only BME estimate
(hard TOAR-II data only; method `10000133`) against fusions that add a **single
satellite-derived** ozone product as soft data, holding the covariance model, global-offset
scenario, and neighbourhood settings fixed. The added products are OMI-MLS (method
`13000313-04`), IASI-GOME2 (`13000313-08`), and CrIS (`13000313-40`); each carries its
RAMP-corrected mean and variance. Because both the baseline and the satellite fusions use
identical global-offset (scenario 3) and covariance treatment, the difference in
cross-validation skill measures the *marginal* value of the satellite constraint alone —
independent of any chemical-transport model. Skill was assessed by checker-board
cross-validation (CBV), which withholds entire spatial blocks and therefore tests the
gap-filling performance that matters for mapping (in contrast to leave-one-out, which tests
only interpolation between nearby stations). We report the coefficient of determination
(R²) and the root-mean-square error (RMSE, ppb) at two block sizes, 5° and 20°, over the
satellite era (2005 onward, set by OMI-MLS availability).

## RESULTS & DISCUSSION

### Satellite soft data improves cross-validated skill over the obs-only baseline
Adding a single satellite product to the obs-only BME estimate raised cross-validated R² and
lowered RMSE in almost every year of the satellite era ([Table N], [Figure N]). For the
longest satellite record, **OMI-MLS (2005–2022, 18 years)**, fusion improved R² from
**0.722 to 0.771** (ΔR² = +0.049, +6.8%) and reduced RMSE from **6.78 to 6.21 ppb**
(−0.56 ppb, −8.3%) at the 5° block size; skill improved in **17 of 18 years** for both
metrics. **IASI-GOME2 (2017–2020)** gave a consistent lift (R² 0.777 → 0.811, +0.034;
RMSE 6.22 → 5.84 ppb, −0.38 ppb; 4 of 4 years). These gains are obtained using only
observation-derived data: the satellite retrievals provide an independent, spatially
continuous constraint that is neither the ground network nor a chemistry model.

### The benefit grows where the monitoring network is sparse
The value of satellite data increased sharply with the withholding block size. At the **20°**
block size — which forces the estimator to bridge much larger observational gaps, mimicking
data-sparse regions — the OMI-MLS improvement roughly doubled to **ΔR² = +0.109 (0.619 →
0.728, +17.6%)** and **ΔRMSE = −1.24 ppb (7.98 → 6.74, −15.5%)**, again in 17 of 18 years;
IASI-GOME2 showed the same amplification (ΔR² = +0.095, ΔRMSE = −1.15 ppb). Because the
obs-only baseline degrades faster than the fusion as gaps widen (R² falls from 0.722 at 5°
to 0.619 at 20°, whereas the OMI-MLS fusion falls only from 0.771 to 0.728), the satellite
constraint contributes *most* precisely where a global mapping product needs it most: over
regions and periods with few surface monitors. This is the central argument for including
satellite data in the operational fusion.

### Robustness across independent satellite systems, and one caveat
That two independent satellite systems (OMI-MLS and IASI-GOME2, based on different
instruments and retrieval physics) both improve skill indicates the benefit is a genuine
information gain rather than a product-specific artefact. The exception is **CrIS, available
only for 2022 (1 year)**, which slightly *reduced* skill relative to obs-only (R² 0.817 →
0.791 at 5°; 0.691 → 0.653 at 20°). We treat this as inconclusive: it rests on a single year
in which the obs-only baseline was itself unusually skillful (R² ≈ 0.82, the highest of the
record), and CrIS surface-ozone sensitivity is weaker than that of the tropospheric-column
products. A multi-year CrIS record is needed before drawing conclusions.

### Placing satellite-alone fusion in context
Single-satellite fusion recovers most, but not all, of the skill of the model-based fusion:
over 2005–2021 (5° block) the obs-only baseline (GO scenario 3) scores R² ≈ 0.72
(RMSE ≈ 6.8 ppb), single-satellite OMI-MLS fusion R² ≈ 0.77 (≈ 6.2 ppb), and the
multi-model Obs+M3fusion product R² ≈ 0.80 (≈ 5.7 ppb). Thus satellite data alone closes
roughly two-thirds of the obs-only→model-fusion skill gap using purely observational inputs,
while providing an independent cross-check on the model product. Consistent with this, the
per-year best-validating configuration in the satellite era combines the model and satellite
constraints (Obs+M3fusion+OMI-MLS, `13000313-06`, for 2005–2016 and 2021; additionally
+IASI-GOME2, `13000313-0E`, for 2017–2020; see `best_method_by_year.csv`), i.e. model and
satellite information are complementary rather than redundant.

### Table N — Satellite soft data vs. obs-only baseline (checker-board cross-validation)

*Obs-only baseline = `10000133`, GO scenario 3. Fusion adds one satellite product as soft
data. Skill = fold-mean, year-averaged over the matched satellite-era years. "Yrs↑" = years
in which the fusion improved that metric.*

| Added satellite source | Years (n) | Box | Obs-only R² | +Sat R² | ΔR² | Obs-only RMSE | +Sat RMSE | ΔRMSE (ppb) | Yrs↑ |
|---|---|---|---|---|---|---|---|---|---|
| OMI-MLS (`-04`)     | 2005–2022 (18) | 5°  | 0.722 | 0.771 | **+0.049** (+6.8%)  | 6.78 | 6.21 | **−0.56** (−8.3%)  | 17/18 |
| OMI-MLS (`-04`)     | 2005–2022 (18) | 20° | 0.619 | 0.728 | **+0.109** (+17.6%) | 7.98 | 6.74 | **−1.24** (−15.5%) | 17/18 |
| IASI-GOME2 (`-08`)  | 2017–2020 (4)  | 5°  | 0.777 | 0.811 | **+0.034** (+4.4%)  | 6.22 | 5.84 | **−0.38** (−6.2%)  | 4/4   |
| IASI-GOME2 (`-08`)  | 2017–2020 (4)  | 20° | 0.665 | 0.759 | **+0.095** (+14.2%) | 7.59 | 6.44 | **−1.15** (−15.2%) | 4/4   |
| CrIS (`-40`)        | 2022 (1)       | 5°  | 0.817 | 0.791 | −0.026 (n=1)        | 5.95 | 6.60 | +0.65 (n=1)        | 0/1   |
| CrIS (`-40`)        | 2022 (1)       | 20° | 0.691 | 0.653 | −0.038 (n=1)        | 7.76 | 8.48 | +0.72 (n=1)        | 0/1   |

### Suggested figures for this section
- **Figure** — Per-year CBV R² (and RMSE) for obs-only vs Obs+OMI-MLS, 2005–2022, at 5° and
  20° blocks (paired lines; shows the near-universal per-year improvement and the widening
  gap at 20°).
- **Figure** — Skill ladder at a fixed box: obs-only → +satellite (OMI-MLS) → +model
  (M3fusion) → model+satellite best-method, in R² and RMSE.

*Provenance: `7validation/CBV/CBV_BME<code>_go3_box{5.0,20.0}_fold{1,2}_<year>.mat`; skill
fields `annualStats.R2`, `annualStats.RMSE`. Recomputable via `fillPaperTables` (ranking
sheets include the single-satellite codes `-04`, `-08`, `-40`).*
