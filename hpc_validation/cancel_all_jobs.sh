#!/bin/bash
#
# cancel_all_jobs.sh - Cancel all TOAR validation jobs
#
# Usage:
#   bash cancel_all_jobs.sh [confirm]
#
# Options:
#   confirm  - Skip confirmation prompt

CONFIRM=0
if [[ "$1" == "confirm" ]]; then
    CONFIRM=1
fi

echo "=========================================="
echo "  Cancel TOAR Validation Jobs"
echo "=========================================="
echo ""

# Find all TOAR validation jobs
if ! command -v squeue &> /dev/null; then
    echo "ERROR: squeue not available (not on HPC cluster?)"
    exit 1
fi

JOBS=$(squeue -u $USER -o "%.18i %.50j" | grep "TOAR_val" | awk '{print $1}')
NUM_JOBS=$(echo "$JOBS" | grep -c . || echo "0")

if [[ $NUM_JOBS -eq 0 ]]; then
    echo "No TOAR validation jobs found in queue."
    echo ""
    exit 0
fi

echo "Found $NUM_JOBS TOAR validation job(s):"
squeue -u $USER -o "%.18i %.50j %.8T %.10M" | grep "TOAR_val"
echo ""

if [[ $CONFIRM -eq 0 ]]; then
    read -p "Cancel all these jobs? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Cancelled. No jobs terminated."
        exit 0
    fi
fi

echo ""
echo "Cancelling jobs..."

for JOB_ID in $JOBS; do
    echo "  Cancelling job $JOB_ID..."
    scancel $JOB_ID
done

echo ""
echo "All TOAR validation jobs cancelled."
echo ""
