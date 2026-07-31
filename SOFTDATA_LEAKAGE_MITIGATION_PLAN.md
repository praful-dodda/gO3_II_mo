# Soft-Data Leakage Mitigation Plan (CBV / f-RAMP)

**Status:** proposal, nothing implemented yet.
**Written:** 2026-07-31
**Scope constraint:** M3fusion cannot be re-run. f-RAMP and CBV *can* be changed. Time budget is generous.

Companion docs: `f-RAMP-code/CLAUDE.md` (algorithm + provenance), root `CLAUDE.md`
(§ *Soft-data provenance*), `maskSoftDataLeakage.m` / `getLeakTag.m` (current control).

---

## 1. The leak, quantified

Traced end-to-end from `getBMEparam.m` + `ramp_correction_parallel_v3.py`.
For method `13000313`: **nsmax = 10** soft neighbours, nhmax = 50, `dmax = [20°, 0.5 yr, …]`.

For a held-out validation station *j* in month *t*:

1. BME pulls the **10 nearest soft cells**. On a 0.5° grid those all lie within ~1° of *j*.
2. Each cell's λ came from a local f-RAMP fit: `INITIAL_NEIGHBORS = 100` nearest **rows**
   ≈ 9 distinct stations (long format, ~12 rows/station), filtered to a 3-month window
   → **~27 obs/model pairs**.
3. Split into `TOTAL_BINS = 10` deciles → **~2.7 pairs per bin**.
4. Station *j* contributes **3 of the 27** — its own months *t−1, t, t+1*.
5. Those three are the same station in adjacent months, so their *model* values cluster and
   land in the same or adjacent bins. λ1 is read off at the cell's model value, which
   (cell ~0.5° away) is close to *j*'s own collocated model value → selects the bin *j* occupies.

**Net:** in the bin that matters, station *j* can supply most or all of the ~2.7 observations.
λ1 at the cells BME actually uses is close to station *j*'s own observed value.

**Amplification.** λ2 is `np.var(..., ddof=0)` over those same 2–3 points. When the bin is
dominated by one station's adjacent-month values — strongly autocorrelated — the variance
collapses toward zero (floored at 0.01). BME weights soft data by inverse variance. So the
held-out observation is handed back **and labelled near-certain**: mean and confidence are
corrupted in the same direction.

> This is an analytic expectation from reading the code, **not a measurement**. Plan F1 measures it.

### 1.1 Severity scales as 1/N — and `technique` already encodes N

| technique | rows | ≈ stations | ≈ pairs in window | ≈ pairs/bin | severity |
|---|---|---|---|---|---|
| 1 (local) | 100 | 9 | 27 | **2.7** | extreme |
| 2 | 350 | 29 | 87 | 8.7 | high |
| 3–4 | 600–850 | 50–71 | 150–213 | 15–21 | moderate |
| 5–6 | 1100–1350 | 92–113 | 276–340 | 28–34 | low |
| 99 (global) | all | all | 10³–10⁴ | 10²–10³ | negligible |

This inverts the intuition: **the most locally-refined soft data is the most leaked**, and
global-fallback cells are essentially clean. An earlier note in `f-RAMP-code/CLAUDE.md`
called technique-99 cells the unmaskable worst case — true that no local mask touches them,
but irrelevant, because at ~1000 pairs/bin a single station's contribution is negligible.
**They are the safe ones.** (That paragraph should be corrected.)

### 1.2 Source asymmetry (user-confirmed)

- **Satellites (OMI-MLS, IASI-GOME2, CrIS): clean upstream.** Their prior BME correction used
  IAGOS and other non-TOAR-II data. Their *only* TOAR-II dependence is f-RAMP → a refit
  **fully cleans them**.
- **M3fusion: contaminated upstream.** Composite built from TOAR-II. A f-RAMP refit does
  **not** remove this, and re-running M3fusion is out of scope.

⇒ post-fix, the **satellite increment** (`-02` → `-06`/`-0E`) is the defensible leakage-free
quantity; the **M3fusion increment** (obs-only → `-02`) stays optimistically biased and must
be *bounded* rather than cleaned (§F2).

---

## Tier A — zero cost, no reruns

### A1. Technique-stratified skill decomposition
**Do:** split CBV validation points by the technique code of their supporting soft cells;
report the fusion-vs-obs-only advantage separately per stratum.

**Why:** §1.1 predicts a specific gradient — a leakage artefact should be **large at
technique 1 and vanish at technique 99**; genuine skill should be flat, or *larger* at 99
(sparse regions, where soft data actually helps). Discriminating test, existing files only.

**Check:** the gradient itself. Monotone decline in advantage with increasing N = leakage
signature. Flat or inverted = evidence of real skill.

**Limit:** confounded with network density (technique 1 ⇔ dense network ⇔ hard data already
good). Control by comparing within region.

---

### A2. Reconstruct the dependency graph exactly ★ highest value
**Do:** f-RAMP's neighbour selection is **deterministic given station coordinates and k**.
The `technique_*.parquet` gives k per cell. So in MATLAB, rebuild for every soft cell the
exact set of stations that fed its ramp — then compute, per CBV fold, the **fraction of each
cell's supporting stations that are held out**.

**Why:** converts the whole problem from guesswork to exact accounting. Replaces the guessed
2° radius with the *actual* dependency footprint, per cell / per fold / per year, with
**zero f-RAMP reruns**. Everything downstream (masking, weighting, stratifying, and the
decision of whether a refit is even needed) becomes exact.

**Check:** validate the reconstruction against ground truth — the technique code *predicted*
from your own kNN must match the technique code *in the parquet*. Agreement over a few
thousand cells confirms the selection rule is replicated.

**Gotcha:** k counts **rows**, and rows-per-station varies with data availability (`dropna`).
Use the `obs.Z` NaN pattern for per-station valid-month counts. An approximate version
(assume 12 rows/station) is easy and probably sufficient for triage.

**Cost:** ~1 day MATLAB. No cluster time.

---

### A3. Reframe the estimand to the satellite increment
**Do:** lead with `-02 → -06`/`-0E` rather than absolute skill or obs-only → fusion.

**Why:** both arms carry the identical upstream M3fusion field, so its unfixable
contamination is common-mode and differences out. With a clean f-RAMP the satellite
contribution is clean at both stages. Turns the one unfixable confound into a nuisance
parameter.

**Check:** compute Δ with and without the M3fusion mask. Δ stable while absolute levels move
⇒ cancellation holds.

---

## Tier B — CBV reruns only, no f-RAMP

### B1. Radius "knee" test
**Do:** sweep `leakRadius.M3fusion` over 0 / 1 / 2 / 3 / 5° for `-02`; plot skill vs radius.

**Why:** settles the open M3Fusion-variant question empirically (Chang-v1 vs DeLang).
Chang-v1-style (field replaced by kriged TOAR-II within 2°) predicts a steep fall to 2° then
a **plateau** — past 2° you only delete uncontaminated model cells. DeLang-style predicts a
smooth monotone decline with **no knee**.

**Check:** run the identical sweep on a satellite source (known clean upstream). It must show
**no knee**. The *contrast* between the two curves is the evidence; either curve alone is
ambiguous.

---

### B2. λ2 small-sample correction
**Do:** inflate λ2 at load time using a technique-keyed factor. `np.var(ddof=0)` over N points
is biased low by (N−1)/N, and the predictive variance for a *new* observation is ≈ s²(1+1/N).
Combined ≈ **2.2× at technique 1**, ≈ **1.0× at technique 99**.

**Why:** attacks the amplification step of §1. The leaked value's *influence* scales with its
inverse variance, so correcting a ~2× understatement roughly halves its weight. Independently
worthwhile as a calibration fix — should push RMSS toward 1 and may help the over-confident
variance maps seen elsewhere.

**Check:** BME uncertainty calibration before/after (RMSS → 1); the near-zero-λ2 population
should shrink. If CBV skill *drops*, some of it was over-weighted soft data.

**Limit:** reduces leakage *weight*, does not remove leakage *bias*. Mitigation, not fix.

---

### B3. Graded masking instead of hard drops
**Do:** using A2's leaked-fraction map *f*, replace the current `Z(mask) = NaN` hard drop with
**variance inflation** proportional to *f* — as *f*→1 the cell becomes uninformative, as
*f*→0 it is untouched.

**Why:** the current mask deletes whole cells at a fixed radius, discarding clean information
in dense regions (where the validation points are) and thereby *understating* fusion skill.
Inflation is continuous, has no radius cliff, keeps partial information, and is the
statistically natural encoding of "this datum is partly contaminated".

**Check:** in the limit (inflate to ∞ wherever *f* > 0) it must reproduce the adaptive hard
mask. Verifying that limit validates the implementation.

---

## Tier C — one f-RAMP rerun per (model, year)

### C1. Fix the kNN unit
**Do:** build the KD-tree over **unique station coordinates**, query k *stations*, then gather
their rows in the window — instead of querying k rows over the duplicated long-format tree.

**Why:** root cause of everything in §1. It (a) fixes the near-certain porting bug,
(b) restores the ~100-station / ~30-pairs-per-bin sample the MATLAB reference intended,
(c) drops per-station leakage weight from ~1/3 to ~1/30, (d) caps any single station's
contribution so *j*'s three adjacent months can no longer dominate a bin. One change, four
benefits, and it improves the *shipped* product, not just the validation.

**Check:** dose–response — leakage should scale as 1/N. Run CBV at several k; skill should
decline predictably and saturate. A skill drop here is **confirmation, not regression**.

---

### C2. Reserved clean station set
**Do:** withhold a fixed 10–15% of TOAR-II stations from f-RAMP for **all** models and years;
keep that as a validation-only soft-data version alongside the operational all-station product.

**Why:** cheapest route to a genuinely clean test set. Crucially, a per-fold refit (D1) drops
~50% of stations from a ramp that only has ~9 — you would be validating a *materially worse*
product than you ship, penalising fusion for something that is not leakage. Dropping 15%
barely perturbs it. One rerun instead of four, and the clean set is reusable forever,
including for LOOCV.

**Check:** hard-assert reserved IDs are absent from `collocated_df` before the KD-tree build.
Then confirm λ fields *far from* reserved stations are near-identical to production — proving
the product was not degraded globally.

**Limit:** reserved stations are not a checkerboard, so box-size scaling (5° vs 20°) is lost.
Pair with D1 if that analysis stays central to the paper.

---

## Tier D — per-fold refit

### D1. `--exclude-stations` per (model, year, box, fold)
**Do:** add `--exclude-stations` to `ramp_analysis_parallel.py`, dropping held-out stations
from `collocated_df` **before** the KD-tree is built.

**Why:** the only route that makes f-RAMP exactly clean *under the existing checkerboard
design*, preserving box-size scaling. Necessary if 5°/20° stays in the paper. Apply C1's k fix
simultaneously or the halved station count will bite.

**Checks, in order:**
1. **Regression** — an empty exclusion list must reproduce production λ to tolerance. If not,
   stop; nothing downstream is interpretable.
2. **Invariance** — obs-only (`10000133`) CBV must be **bit-identical**, since it uses no soft
   data. Any movement means something unintended was perturbed.
3. **Effect size** — λ1 near held-out stations, production vs refit. That difference *is* the
   removed leakage; report it.

**Cost:** 4× per year per model (~10 h / ≥100 GB for M3fusion, ~4 h for satellites).

---

## Tier E — reusable analytic

### E1. Jackknife via saved bin membership
**Do:** emit, per (cell, month), the contributing station IDs and per-bin counts. Then remove
any station in closed form:

```
λ1₋ⱼ = (N·λ1 − obs_j) / (N−1)      # and the analogous variance update
```

**Why:** λ1 and λ2 are linear/quadratic in the observations, so removal is O(1) arithmetic,
not a refit. **One** f-RAMP run then serves every hold-out pattern — all box sizes, both
folds, and full LOOCV. Given the time budget, this is the option that scales furthest.

**Not exact because:** removal shifts decile *edges*, can flip `enforce_monotonicity`, and may
change which escalation branch fires.

**Check:** bound the second-order error — true-refit a sample of cells and compare. A small
discrepancy relative to the leakage removed justifies the approximation, and that comparison
is a strong methods paragraph.

---

## Tier F — verification (applies to all)

### F1. Spike / placebo test — the backbone
**Do:** add a known offset (+10 ppb) to a set of stations' observations, rerun f-RAMP, and
measure how much propagates into λ1 nearby and then into the BME prediction *at those stations*.

**Why:** every plan above is an *argument* that leakage fell. This **measures** it, yielding a
transfer coefficient that should be substantial under production and ~0 under the fix. It does
not depend on believing the §1 footprint analysis, and it is the figure that answers a referee.

**Bracket it:**
- production f-RAMP → upper bound
- the fix → lower bound
- maximal-leakage control (soft data built *only* from validation stations) → what
  fully-leaked looks like

### F2. Bounding what cannot be fixed (M3fusion upstream)
1. Compare `-01` (MERRA2-GMI, raw CTM, clean upstream) against `-02` after both are
   f-RAMP-clean. The gap is genuine quality **plus** upstream leakage → an upper bound.
2. If station first-appearance dates are available, validate on TOAR-II stations added
   *after* the M3fusion build vintage — clean on both channels, a true gold set.

---

## Recommended sequencing

1. **A2 first.** Converts the problem from guesswork to exact accounting for ~1 day of MATLAB,
   and tells you whether B3 suffices or D1 is required.
2. **A1 + B1 alongside** — cheap and discriminating.
3. **C1** (fix the bug, dilute the leak) and **B2** (kill the amplification).
4. **C2** for the clean headline number; add **D1** only if box-size scaling is needed.
5. **E1** if the machinery should be reusable (LOOCV, other hold-out patterns).
6. **F1** to prove whatever is landed on.
7. **A3** as the framing throughout; **F2** for the M3fusion caveat paragraph.

> Do **not** commit cluster time before A2 + A1 + B1 are done — they may change what the
> problem is understood to be.

---

## Open items feeding this plan

- Which M3Fusion variant are `M3fusion 1990-2023/yearlyFiles` CSVs — Chang-v1 (local 2° obs
  replacement, mask is right) or DeLang (regional weights + offset, no local mask helps)?
  Check `f-RAMP-code/combine_m3fusion_data.py` / `m3fusion_eda.py`. **Pivotal for B1.**
- `evaluateFold_CBV_monthly.m` is currently unreadable (blocked by settings deny list); it
  will need unblocking if A1/B3 changes land there.
- Correct the technique-99 paragraph in `f-RAMP-code/CLAUDE.md` per §1.1.
