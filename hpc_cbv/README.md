# HPC Scripts for Checker-Board Validation (CBV)

This directory contains SLURM batch scripts for running Checker-Board Validation on UNC Longleaf HPC cluster.

## Overview

The CBV process validates BME performance using spatial cross-validation:
- Divides domain into checker boxes
- Each fold holds out alternating boxes
- Tests BME prediction accuracy at held-out locations
- Tests multiple box sizes, years, and BME methods

## Directory Structure

```
hpc_cbv/
├── job_template_cbv.slurm     # SLURM job template
├── run_cbv_worker.m           # MATLAB worker for CBV
├── submit_cbv_jobs.sh         # Submit jobs for all methods
├── monitor_cbv_jobs.sh        # Monitor running jobs
├── cancel_cbv_jobs.sh         # Cancel all CBV jobs
├── README.md                  # This file
├── jobs/                      # Generated job scripts (created automatically)
└── logs/                      # Job output logs (created automatically)
```

## Key Design: Sequential per Method

**Important:** Each BME method runs in a **separate sequential job** to avoid file conflicts:

- **Problem:** GO and covariance files are method-independent
- **Solution:** One job per method, running all years/months/boxes sequentially
- **Benefit:** No race conditions on shared files
- **Trade-off:** Methods run in parallel (on different nodes), but each method is sequential

## Quick Start

### 1. Configure Methods and Years

Edit `submit_cbv_jobs.sh`:

```bash
# Methods to test (each gets its own job)
BME_METHODS=(
    "10000133"          # Hard data only
    "13000313-02"       # Hard + M3fusion
    "13000313-02-10"    # Hard + M3fusion + UKML
)

# Validation years
VAL_YEARS="2017 2018"

# Checker box sizes (degrees)
BOX_SIZES="4.0 5.0"
```

### 2. Test Configuration (Dry Run)

```bash
cd hpc_cbv
bash submit_cbv_jobs.sh dry-run
```

This generates job scripts in `jobs/` without submitting.

### 3. Submit Jobs

```bash
bash submit_cbv_jobs.sh
```

### 4. Monitor Progress

```bash
# Quick status
bash monitor_cbv_jobs.sh

# Watch queue
watch -n 60 'squeue -u $USER'

# Follow specific job log
tail -f logs/cbv_method_10000133_<jobid>.out
```

## Resource Requirements

### Recommended SLURM Settings

The template (`job_template_cbv.slurm`) uses:
- **Time:** 3 days (`--time=3-00:00:00`)
- **Memory:** 48 GB (`--mem=48G`)
- **Cores:** 1 (`-n 1`) - MATLAB single-threaded
- **Nodes:** 1 (`-N 1`)

### Adjust if Needed

For larger runs, edit the template:
```bash
#SBATCH --time=5-00:00:00    # Extend for more years
#SBATCH --mem=64G            # Increase for soft data
```

## Typical Runtime

Estimated time per job (one method, all years/months/boxes):

| Configuration | Runtime |
|--------------|---------|
| Hard data only, 1 year, 2 boxes | 6-8 hours |
| Hard data only, 2 years, 2 boxes | 12-16 hours |
| Hard + soft data, 1 year, 2 boxes | 12-18 hours |
| Hard + soft data, 2 years, 2 boxes | 24-36 hours |

**Note:** First run takes longer (creates GO/cov cache). Subsequent runs use cache.

## Output Files

### Logs
```
logs/
├── cbv_method_10000133_<jobid>.out     # Standard output
├── cbv_method_10000133_<jobid>.err     # Standard error
├── cbv_method_13000313_02_<jobid>.out
└── ...
```

### Results
```
../../7validation/CBV/hpc_results/
├── cbv_summary_10000133_y[2017_2018]_b[4.0_5.0].mat
├── cbv_summary_13000313_02_y[2017_2018]_b[4.0_5.0].mat
└── ...
```

Each `.mat` file contains:
- `summary` - Job metadata and timing
- `cbvSummary` - Performance statistics by box/fold
- `cbvPairsAll` - All obs-prediction pairs
- `valParam` - Validation configuration

## Workflow Integration

### Relationship to Other Scripts

```
PC (local development):
  runCBV.m              → Configure and test locally
  runBMETOAR.m          → Manual BME estimation

HPC (production runs):
  hpc_cbv/              → THIS directory
  ├── submit_cbv_jobs.sh   → Submit validation jobs
  └── run_cbv_worker.m     → Calls runCBV_toar()
```

### After Jobs Complete

1. **Download results** from HPC:
   ```bash
   scp -r longleaf:path/to/gO3_II_mo/7validation/CBV/hpc_results ./
   ```

2. **Analyze on PC** using existing tools:
   ```matlab
   % Load and analyze results
   load('hpc_results/cbv_summary_10000133_*.mat');
   evaluateCBVResults(cbvSummary);
   ```

## Troubleshooting

### Job Stuck or Failed

```bash
# Check job status
squeue -j <JOBID>

# View error log
tail -100 logs/cbv_method_*_<jobid>.err

# Check MATLAB errors in output
grep -A 10 "ERROR" logs/cbv_method_*_<jobid>.out
```

### Common Issues

1. **Out of Memory**
   - Increase `--mem` in template
   - Reduce box sizes or years

2. **Timeout**
   - Increase `--time` in template
   - Use cache (`forceEstimation=0`)

3. **BMELIB not found**
   - Check path in `run_cbv_worker.m` line 39
   - Ensure BMELIB is on HPC

4. **File conflicts**
   - Check that only one job per method is running
   - Don't run same method multiple times simultaneously

### Cancel and Restart

```bash
# Cancel all
bash cancel_cbv_jobs.sh confirm

# Resubmit after fixing issues
bash submit_cbv_jobs.sh
```

## Advanced Usage

### Run Subset of Methods

Edit `submit_cbv_jobs.sh` to only include desired methods:
```bash
BME_METHODS=(
    "10000133"    # Only this one
)
```

### Run Single Method Manually

```bash
# Create job for one method
sed -e "s|__BME_METHOD__|10000133|g" \
    -e "s|__METHOD_ID__|10000133|g" \
    -e "s|__VAL_YEARS__|2017|g" \
    -e "s|__BOX_SIZES__|5.0|g" \
    job_template_cbv.slurm > jobs/test.slurm

# Submit
sbatch jobs/test.slurm
```

### Interactive Testing

```bash
# Start interactive session
srun --pty -p interact -n 1 --mem=32G --time=4:00:00 bash

# Load MATLAB
module load matlab/2023b

# Run interactively
matlab -nodisplay -nosplash

>> run_cbv_worker('10000133', [2017], [5.0])
```

## File Organization on HPC

Recommended HPC directory structure:
```
~/gO3_II_mo/                           # Main project (cloned from git)
├── hpc_cbv/                           # This directory
│   ├── jobs/                          # Generated scripts
│   ├── logs/                          # Job logs
│   └── ...
├── 1data/
│   ├── TOAR-II/                       # Observation data
│   └── CTM/                           # Soft data (if needed)
├── 2globaloffset/                     # GO cache (created by jobs)
├── 3covariance/                       # Cov cache (created by jobs)
└── 7validation/
    └── CBV/
        ├── hpc_results/               # Final results
        └── <year_box_fold>/           # Intermediate monthly results
```

## Comparison to LOOCV Scripts

This CBV setup is similar to `hpc_validation/` but with key differences:

| Aspect | LOOCV (hpc_validation) | CBV (hpc_cbv) |
|--------|----------------------|---------------|
| **Validation type** | Leave-one-out | Checker-board |
| **Organization** | One job per GO scenario | One job per BME method |
| **File conflicts** | GO varies, less concern | GO same, more concern |
| **Typical runtime** | 1-2 days | 1-3 days |
| **Output size** | Smaller (point pairs) | Larger (box statistics) |

## Support

For issues:
1. Check this README
2. Review job logs in `logs/`
3. Test interactively on compute node
4. Check MATLAB error stack in output logs

## Updates

To update scripts from git:
```bash
cd ~/gO3_II_mo
git pull origin <branch>
cd hpc_cbv
# Review changes before resubmitting
bash submit_cbv_jobs.sh dry-run
```
