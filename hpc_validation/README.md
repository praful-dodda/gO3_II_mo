# TOAR LOOCV Validation - HPC Job Submission System

This directory contains scripts for running LOOCV validation across multiple global offset scenarios on HPC computing nodes.

## Directory Structure

```
hpc_validation/
├── submit_all_jobs.sh          # Master submission script
├── monitor_jobs.sh             # Job monitoring utility
├── aggregate_results.m         # Results aggregation and comparison
├── cancel_all_jobs.sh          # Cancel all running jobs
├── README.md                   # This file
├── scripts/
│   ├── run_validation_worker.m # MATLAB worker script
│   └── job_template.slurm      # SLURM job template
├── jobs/                       # Generated job scripts (created automatically)
└── logs/                       # Job output and error logs (created automatically)
```

## Configuration

### Validation Parameters

**Global Offset Scenarios:** 2, 3, 6, 7
- Scenario 2: Domain-wide S/T smoothing
- Scenario 3: Regional S/T smoothing (RECOMMENDED)
- Scenario 6: Spatial LUR + semi-local temporal
- Scenario 7: Spatial LUR + local temporal

**Validation Years:** 2016-2019 (4 years, 48 months total)

**BME Method:** `10000132`
- Hard data only, nhmax=100, krigingME

**Total Jobs:** 4 (one per GO scenario)

### Resource Allocation (per job)

```bash
Time:      24 hours
Nodes:     1
CPUs:      4
Memory:    32 GB
```

Adjust in `scripts/job_template.slurm` if needed for your cluster.

## Quick Start

### 1. Test Job Generation (Dry Run)

```bash
cd hpc_validation
bash submit_all_jobs.sh dry-run
```

This generates job scripts without submitting them. Check `jobs/` directory.

### 2. Submit All Jobs

```bash
bash submit_all_jobs.sh
```

This will:
- Generate 4 job scripts (one per GO scenario)
- Submit all jobs to SLURM scheduler
- Print job IDs for monitoring

### 3. Monitor Jobs

**One-time status check:**
```bash
bash monitor_jobs.sh
```

**Continuous monitoring (refreshes every 30 seconds):**
```bash
bash monitor_jobs.sh watch
```

**Using SLURM commands directly:**
```bash
# View queue
squeue -u $USER

# View specific job details
scontrol show job <JOB_ID>

# View job output in real-time
tail -f logs/val_go3_<JOB_ID>.out
```

### 4. Check Job Logs

**Standard output (progress):**
```bash
tail -f logs/val_go3_*.out
```

**Standard error (errors only):**
```bash
tail -f logs/val_go3_*.err
```

### 5. Aggregate Results

After all jobs complete:

```matlab
cd hpc_validation
matlab -nodisplay -r "aggregate_results([2 3 6 7], [2016 2017 2018 2019]); exit"
```

Or interactively:
```matlab
aggregate_results([2 3 6 7], [2016 2017 2018 2019])
```

This creates:
- Comparison table (CSV)
- Metrics bar charts
- Scatter plots for each scenario
- Timing summary

Results saved in: `../7validation/comparison_plots/`

## Workflow Details

### What Each Job Does

For each Global Offset scenario, the job:

1. **Loads data** (2015-2020 to allow GO/covariance calculation)
2. **Calculates global offset** for the scenario
3. **Fits covariance model**
4. **Runs LOOCV validation** for 48 months (2016-2019)
   - Each month processed separately
   - Results cached individually
   - Can resume if interrupted
5. **Saves summary results**

### Monthly Caching

Individual monthly results are cached in: `../7validation/`

Filename format:
```
TOAR_LOOCV_BME10000132_go3_y2016_m01.mat
```

This means if a job fails partway through, completed months don't need to be recomputed.

### Output Files

**Job scripts:** `jobs/job_go<scenario>.slurm`

**Logs:**
- `logs/val_go<scenario>_<jobid>.out` - Standard output
- `logs/val_go<scenario>_<jobid>.err` - Standard error

**Results:**
- `../7validation/hpc_results/validation_summary_go<scenario>_y[...].mat`

## Troubleshooting

### Job Fails Immediately

Check error log:
```bash
cat logs/val_go3_*.err
```

Common issues:
- MATLAB not loaded: Add `module load matlab` to job template
- Path issues: Check working directory in job script
- BMELIB not found: Update path in `run_validation_worker.m`

### Job Runs Out of Memory

Increase memory in `scripts/job_template.slurm`:
```bash
#SBATCH --mem=64G  # Instead of 32G
```

### Job Exceeds Time Limit

Increase time in `scripts/job_template.slurm`:
```bash
#SBATCH --time=48:00:00  # Instead of 24:00:00
```

Or use cached results (set `forceEstimation = 0` in worker script).

### Missing Months

Check which months completed:
```bash
ls ../7validation/TOAR_LOOCV_BME10000132_go3_*.mat | wc -l
```

Should be 48 files per scenario (12 months × 4 years).

To rerun only missing months, delete the summary file and resubmit:
```bash
rm ../7validation/hpc_results/validation_summary_go3_*.mat
# Then resubmit that job
```

### Cancel All Jobs

```bash
bash cancel_all_jobs.sh
```

Or manually:
```bash
scancel -u $USER -n TOAR_val_go
```

## Advanced Usage

### Submit Specific Scenario Only

Edit `submit_all_jobs.sh` to change:
```bash
GO_SCENARIOS=(3)  # Only run scenario 3
```

### Change Validation Years

Edit `submit_all_jobs.sh`:
```bash
VAL_YEARS="2017 2018"  # Only these years
```

### Adjust Resource Allocation

Edit `scripts/job_template.slurm`:
```bash
#SBATCH --cpus-per-task=8   # More CPUs
#SBATCH --mem=64G           # More memory
#SBATCH --partition=bigmem  # Different partition
```

### Add Email Notifications

Add to `scripts/job_template.slurm`:
```bash
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@university.edu
```

## Expected Runtime

Based on typical performance:

- **Data loading:** ~30 seconds
- **Global offset calculation:**
  - Scenario 2: ~5 minutes
  - Scenario 3: ~10 minutes
  - Scenario 6: ~15 minutes
  - Scenario 7: ~20 minutes
- **Covariance fitting:** ~2 minutes
- **Validation (48 months):** ~4-8 hours
  - Depends on data density
  - ~5-10 minutes per month

**Total per job:** 6-10 hours typically

**All jobs (parallel):** 6-10 hours wall time

## Validation Statistics

After aggregation, you'll get:

### Metrics Compared

- **Pearson R:** Correlation coefficient
- **R²:** Variance explained
- **RMSE:** Root mean square error
- **MAE:** Mean absolute error
- **ME:** Mean error (bias)
- **NMB:** Normalized mean bias (%)
- **NME:** Normalized mean error (%)
- **IOA:** Index of agreement
- **FAC2:** Fraction within factor of 2

### Recommended Scenario Selection

The "best" scenario depends on priorities:
- **Highest R²:** Best overall fit
- **Lowest RMSE:** Smallest typical error
- **Lowest |NMB|:** Least systematic bias
- **Highest IOA:** Best agreement

Typically, **GO Scenario 3** (regional smoothing) performs well for TOAR data.

## Contact

For questions about:
- **HPC setup:** Your cluster support team
- **MATLAB errors:** Check BMELIB documentation
- **Method questions:** See validation code documentation

## Version History

- v1.0 (2025-01-15): Initial HPC validation system
