#!/bin/bash
#
# submit_all_jobs.sh - Submit all TOAR LOOCV validation jobs
#
# This script creates and submits SLURM jobs for all combinations of:
#   - Global offset scenarios: 2, 3, 6, 7
#   - Validation years: 2016-2019
#
# Usage:
#   bash submit_all_jobs.sh [dry-run]
#
# Options:
#   dry-run  - Generate job scripts but don't submit (for testing)

set -e  # Exit on error

# Configuration
GO_SCENARIOS=(2 3 6 7)
VAL_YEARS="2016 2017 2018 2019"
TEMPLATE_FILE="scripts/job_template.slurm"
JOBS_DIR="jobs"
LOGS_DIR="logs"

# Parse arguments
DRY_RUN=0
if [[ "$1" == "dry-run" ]]; then
    DRY_RUN=1
    echo "DRY RUN MODE: Jobs will be generated but not submitted"
fi

# Create directories
mkdir -p "$JOBS_DIR" "$LOGS_DIR"

echo "=========================================="
echo "  TOAR LOOCV Validation Job Submission"
echo "=========================================="
echo "Configuration:"
echo "  Global Offset Scenarios: ${GO_SCENARIOS[@]}"
echo "  Validation Years: $VAL_YEARS"
echo "  Total jobs: ${#GO_SCENARIOS[@]}"
echo ""

# Check template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Array to store job IDs
declare -a JOB_IDS

# Generate and submit jobs
for GO in "${GO_SCENARIOS[@]}"; do
    echo "----------------------------------------"
    echo "Preparing job for GO scenario $GO"

    # Create job script from template
    JOB_FILE="${JOBS_DIR}/job_go${GO}.slurm"

    # Replace placeholders in template
    sed -e "s/__GO_SCENARIO__/${GO}/g" \
        -e "s/__VAL_YEARS__/${VAL_YEARS}/g" \
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
    echo "Submitted ${#JOB_IDS[@]} jobs:"
    for i in "${!JOB_IDS[@]}"; do
        echo "  GO Scenario ${GO_SCENARIOS[$i]}: Job ${JOB_IDS[$i]}"
    done

    echo ""
    echo "Monitor jobs with:"
    echo "  squeue -u \$USER"
    echo "  bash monitor_jobs.sh"
    echo ""
    echo "View logs in: $LOGS_DIR/"
    echo "Job scripts in: $JOBS_DIR/"
else
    echo "Generated ${#GO_SCENARIOS[@]} job scripts in: $JOBS_DIR/"
    echo ""
    echo "To submit, run without 'dry-run' argument:"
    echo "  bash submit_all_jobs.sh"
fi

echo ""
