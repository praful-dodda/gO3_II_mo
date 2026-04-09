#!/bin/bash
#
# submit_cbv_jobs.sh - Submit TOAR Checker-Board Validation jobs
#
# This script creates and submits SLURM jobs for CBV across multiple BME methods.
# Each method runs SEQUENTIALLY in its own job to avoid file conflicts (GO, cov).
#
# Usage:
#   bash submit_cbv_jobs.sh [dry-run]
#
# Options:
#   dry-run  - Generate job scripts but don't submit (for testing)
#
# Configuration:
#   - Edit BME_METHODS array below for methods to test
#   - Edit VAL_YEARS for years to validate
#   - Edit BOX_SIZES for checker box sizes
#
# Output:
#   - Job scripts: jobs/cbv_method_*.slurm
#   - Logs: logs/cbv_method_*_<jobid>.{out,err}
#   - Results: ../../7validation/CBV/hpc_results/

set -e  # Exit on error

#=============================================================================
#                            CONFIGURATION
#=============================================================================

# BME Methods to test (each runs as separate job to avoid file conflicts)
# Add/remove methods as needed
BME_METHODS=(
    "10000133"          # Hard data only, nhmax=200, nsmax=5
    "13000313-02"       # Hard + M3fusion
    "13000313-02-10"    # Hard + M3fusion + UKML
)

# Validation years (space-separated)
VAL_YEARS="2017 2018"

# Checker box sizes in degrees (space-separated)
BOX_SIZES="4.0 5.0"

# Template and output directories
TEMPLATE_FILE="job_template_cbv.slurm"
JOBS_DIR="jobs"
LOGS_DIR="logs"

#=============================================================================
#                            SCRIPT START
#=============================================================================

# Parse arguments
DRY_RUN=0
if [[ "$1" == "dry-run" ]]; then
    DRY_RUN=1
    echo "DRY RUN MODE: Jobs will be generated but not submitted"
fi

# Create directories
mkdir -p "$JOBS_DIR" "$LOGS_DIR"

echo "=========================================="
echo "  TOAR CBV Job Submission"
echo "=========================================="
echo "Configuration:"
echo "  BME Methods: ${BME_METHODS[@]}"
echo "  Validation Years: $VAL_YEARS"
echo "  Box Sizes: $BOX_SIZES degrees"
echo "  Total jobs: ${#BME_METHODS[@]}"
echo ""

# Check template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Template file not found: $TEMPLATE_FILE"
    echo "Expected location: $(pwd)/$TEMPLATE_FILE"
    exit 1
fi

# Array to store job IDs
declare -a JOB_IDS

# Generate and submit jobs for each method
for BME_METHOD in "${BME_METHODS[@]}"; do
    echo "----------------------------------------"
    echo "Preparing job for BME method: $BME_METHOD"

    # Create safe method ID for filenames (replace special chars)
    METHOD_ID=$(echo "$BME_METHOD" | sed 's/-/_/g' | sed 's/:/_/g')

    # Create job script from template
    JOB_FILE="${JOBS_DIR}/cbv_method_${METHOD_ID}.slurm"

    # Replace placeholders in template
    sed -e "s|__BME_METHOD__|${BME_METHOD}|g" \
        -e "s|__METHOD_ID__|${METHOD_ID}|g" \
        -e "s|__VAL_YEARS__|${VAL_YEARS}|g" \
        -e "s|__BOX_SIZES__|${BOX_SIZES}|g" \
        "$TEMPLATE_FILE" > "$JOB_FILE"

    echo "  Job script created: $JOB_FILE"

    # Submit job
    if [[ $DRY_RUN -eq 0 ]]; then
        JOB_ID=$(sbatch "$JOB_FILE" | awk '{print $4}')
        JOB_IDS+=("$JOB_ID")
        echo "  Job submitted: $JOB_ID"
    else
        echo "  [DRY RUN] Would submit: sbatch $JOB_FILE"
    fi
done

echo ""
echo "=========================================="
echo "  Submission Complete"
echo "=========================================="

if [[ $DRY_RUN -eq 0 ]]; then
    echo "Submitted ${#JOB_IDS[@]} jobs (one per method):"
    for i in "${!JOB_IDS[@]}"; do
        echo "  Method ${BME_METHODS[$i]}: Job ${JOB_IDS[$i]}"
    done

    echo ""
    echo "Monitor jobs with:"
    echo "  squeue -u \$USER"
    echo "  bash monitor_cbv_jobs.sh"
    echo ""
    echo "View logs in: $LOGS_DIR/"
    echo "Job scripts in: $JOBS_DIR/"
    echo ""
    echo "Results will be saved to:"
    echo "  ../../7validation/CBV/hpc_results/"
else
    echo "Generated ${#BME_METHODS[@]} job scripts in: $JOBS_DIR/"
    echo ""
    echo "To submit, run without 'dry-run' argument:"
    echo "  bash submit_cbv_jobs.sh"
fi

echo ""
echo "=========================================="
echo "  Job Organization Strategy"
echo "=========================================="
echo "Each BME method runs in a separate job to prevent file conflicts:"
echo ""
echo "  - GO and covariance files are method-independent"
echo "  - Running methods sequentially avoids race conditions"
echo "  - Each job processes all years/months/boxes for that method"
echo "  - Jobs run in parallel across methods (on different nodes)"
echo ""
echo "Estimated runtime per job:"
echo "  - Hard data only: ~6-12 hours"
echo "  - With soft data: ~12-24 hours"
echo "  (depends on years, months, box sizes)"
echo "=========================================="
echo ""
