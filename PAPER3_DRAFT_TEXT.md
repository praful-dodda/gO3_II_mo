# Paper-3 draft text: post-processing analysis

> **How to use this file.** The paragraphs below are drop-in drafts for the
> **Methods**, **Results & Discussion**, and **Supporting Information (SI)** sections.
> All numbers are from the **1990–2004 test run** of the post-processing pipeline using
> the multi-CTM method `13000313-02` (the per-year best-method composite reduces to this
> method over 1990–2004 because the other configurations do not yet have spatial
> estimates). **Update every number after the full 1990–2022 run.** Citation keys
> (`Author, year`), `[Figure N]`, and `[Table SN]` are placeholders. Preliminary values
> are flagged so they are not mistaken for final results.

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

> *(Preliminary — 1990–2004 test period; single method.)*

### Long-term global trends
Over 1990–2004, global land ozone increased. The area-weighted annual-mean MDA8 rose at
**+2.20 ppb decade⁻¹** (Mann–Kendall *p* = 0.018; Sen-fitted level ≈ 30.4 ppb in 1990 to
≈ 33.5 ppb in 2004) [Figure N]. The population-weighted trend was larger, at
**+2.65 ppb decade⁻¹** (*p* = 0.010), indicating that the average person experienced a
faster increase than the unweighted land surface — a consequence of population concentrating
in regions with stronger ozone growth [Figure N]. The peak-season metric (OSDMA8) showed a
consistent global increase of **+1.74 ppb decade⁻¹** (Theil–Sen) / **+1.72 ppb decade⁻¹**
(OLS), significant under the autocorrelation-adjusted test (*p* = 0.001) with weak residual
autocorrelation (φ = 0.13). The corresponding detection time was **n\* ≈ 6 years**, i.e. the
record is comfortably long enough to detect a global trend of this magnitude.

### Spatial pattern of trends
Trends were predominantly positive but spatially heterogeneous [Figure N]. **76%** of land
cells exhibited a rising annual-mean trend, with a median slope of **+1.75 ppb decade⁻¹**;
**31%** of cells were significant at *p* < 0.05 for the annual mean (**27%** for OSDMA8). The
strongest and most coherent increases occurred over [South/East Asia] (see regional results),
while parts of [Europe and eastern North America] showed weak or non-significant changes.

### Regional trends
Population-weighted OSDMA8 trends differed sharply among world regions (OLS with AR(1)
adjustment; [Table N], [Figure N]). **East Asia** rose fastest at **+6.15 ppb decade⁻¹**
(*p* < 0.001; n\* ≈ 5 yr), followed by **South-Central Asia** at **+4.11 ppb decade⁻¹**
(*p* = 0.009; n\* ≈ 8 yr) — both highly significant. **Oceania** showed a marginal increase
(+2.20 ppb decade⁻¹; *p* = 0.078). In contrast, **North America** (+0.57), **Africa**
(+0.87), and **Russia** (+1.17 ppb decade⁻¹) trends were small and not significant
(*p* > 0.4; n\* ≈ 17–21 yr), and **Europe** and **South America** were essentially flat
(+0.14 ppb decade⁻¹; *p* ≈ 0.93; n\* ≈ 75–79 yr). The very large n\* values for Europe and
South America indicate that, given the low signal and the noise, multi-decadal records would
be needed to detect any trend there — consistent with the plateau/decline of European ozone
following emission controls after ~2000 (cf. DeLang et al., 2021; Becker et al., 2023). This
regional contrast — rapid, significant Asian increases against flat western trends — is the
dominant feature of the global ozone evolution over this period and mirrors the spatial
pattern reported by [DeLang et al., 2021 / TOAR].

### Population exposure to WHO targets
Exposure to the most stringent exceedance rose markedly: the share of the global population
with peak-season ozone (OSDMA8) above the WHO interim target of **100 µg m⁻³ (50 ppb)**
increased from **5.4% in 1990 to 17.5% in 2004** [Figure N]. Exposure above the lower targets
remained very high and approximately stable over this short window (above 60 µg m⁻³:
94.0% → 91.5%; above 70 µg m⁻³: 81.5% → 78.7%), reflecting that most of the world already
exceeds the air-quality guideline while the upper tail of the distribution is worsening. The
rising high-end exposure is driven by the Asian increases identified above.

### Discussion points
- The divergence between population-weighted and area-weighted global trends
  (+2.65 vs +2.20 ppb decade⁻¹) shows that **exposure-relevant** ozone is rising faster than
  the area-mean, strengthening the public-health motivation for the data-fusion product.
- The autocorrelation-adjusted detection times (n\*) provide a transparent statement of which
  regional trends are robust (East/South-Central Asia: n\* ≈ 5–8 yr) versus which require
  longer records (Europe, South America: n\* ≈ 75–80 yr), following the standard ozone
  trend-detection framework (Weatherhead et al., 1998).
- *(For the full 1990–2022 product)* extending the record will (i) sharpen all regional
  trends and tighten n\*, (ii) likely resolve the post-2000 European decline in the two-period
  analysis, and (iii) enable per-year multi-method best-method compositing once the additional
  configurations are estimated.

---

## SUPPORTING INFORMATION (SI)

### S1. Post-processing data cube and grid
The monthly BME estimates were consolidated into a single space–time cube per method. Because
each monthly estimation grid appends that month's monitoring-site locations to the fixed map
lattice, the per-month grids differ; we therefore stacked all months onto their **common grid**
(the set of cells present in every month, recovered by coordinate matching to 10⁻⁴°), which
corresponds to the stable land lattice. For 1990–2004 this yielded **18,573 land cells × 180
monthly fields** at 1° resolution; fewer than 0.03% of cell-months were missing, and no month
was entirely missing. Per-year best-method compositing (selecting, for each year, the method
with the highest checkerboard cross-validation R²) was applied where multiple methods were
available; over 1990–2004 only `13000313-02` had spatial estimates, so the composite reduces to
that method.

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
to within ~0.1 ppb decade⁻¹ for the global series (e.g. global OSDMA8 +1.74 vs +1.72 ppb
decade⁻¹). Two-period trends split the record at [breakpoint year, e.g. 2000].

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
  1990–2004, [22%] of cells showed a significant shift with a near-zero global median.
- **Figure S[ ]** — Best-validating method by year.

### S7. Limitations
(i) The values above are for the 1990–2004 test period; trends and detection times will change
with the full 1990–2022 record. (ii) Population weighting uses a single (2019) distribution,
so population-weighted trends reflect ozone change for a fixed population, not demographic
change. (iii) World-region boundaries are approximate boxes. (iv) Over short records, AR(1)
estimates of φ and the derived n\* are uncertain and should be read as indicative. (v) Trends
are computed on the fused product and inherit its uncertainty (quantified per cell by the BME
estimation variance, Section [uncertainty]).

---

## SUGGESTED MAIN-TEXT FIGURE/TABLE SET
- **Figure** — Global annual-mean and OSDMA8 time series with trends (area- vs population-weighted).
- **Figure** — World-region population-weighted OSDMA8 series (Global as a black dashed line).
- **Figure** — Per-cell annual-mean (or OSDMA8) trend map with significance.
- **Figure** — Population exposure above WHO targets over time.
- **Table** — Regional OSDMA8 trends (slope, *p*, n\*) for the eight world regions + global.

*Citations to resolve: DeLang et al. (2021); Becker et al. (2023); Weatherhead et al. (1998);
Sen (1968); Mann (1945); Kendall (1975); WHO (2021); Christakos (2000).*
