# hpc_validation — LOOCV Validation on Longleaf (SLURM)

## Overview
Runs LOOCV validation jobs on UNC Longleaf. One SLURM job per GO scenario; jobs run in parallel. BME method hardcoded to `10000132` (hard-data only, nhmax=100).

## Workflow
```bash
# Edit submit_all_jobs.sh to set GO_SCENARIOS and VAL_YEARS
bash submit_all_jobs.sh dry-run      # preview commands
bash submit_all_jobs.sh              # submit jobs
bash monitor_jobs.sh                 # check status
bash monitor_jobs.sh watch           # continuous monitoring
bash cancel_all_jobs.sh              # cancel all
# or: scancel -u $USER -n TOAR_val_go
```

## Key Configuration (edit submit_all_jobs.sh)
- `GO_SCENARIOS`: e.g. `(2 3 6 7)` — scenario 3 is recommended
- `VAL_YEARS`: e.g. `"2016 2017 2018 2019"`

## GO Scenario Reference
| Code | Description |
|------|-------------|
| 2 | Domain-wide S/T smoothing |
| 3 | Regional S/T smoothing **(recommended)** |
| 6 | Local S/T smoothing |
| 7 | Super-local S/T smoothing |

## Resource Template (scripts/job_template.slurm)
- Partition: `general` | Time: 2 days | Memory: 32 GB | Cores: 1

## Worker Script (scripts/run_validation_worker.m)
Steps: load obs → compute GO → fit covariance (holecos) → setup BME → run LOOCV

## Outputs
| Path | Contents |
|------|----------|
| `logs/val_go<scenario>_<jobid>.{out,err}` | SLURM job logs |
| `../7validation/TOAR_LOOCV_BME10000132_go<s>_y<year>_m<month>.mat` | Monthly cache (48 files per scenario) |
| `../7validation/hpc_results/validation_summary_go<scenario>_y<years>.mat` | Summary per scenario |

## Post-Processing (after all jobs complete)
```bash
matlab -nodisplay -r "aggregate_results([2 3 6 7], [2016 2017 2018 2019]); exit"
# Outputs: ../7validation/comparison_plots/
```

## Typical Runtime
- Data + GO + covariance: ~15–30 min | LOOCV (48 months): 4–8 h | **Total: 6–10 h**
- All scenarios run in parallel → **6–10 h wall time**

## MATLAB Module
```bash
module load matlab
```
