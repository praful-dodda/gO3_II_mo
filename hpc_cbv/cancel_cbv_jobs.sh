#!/bin/bash
#
# cancel_cbv_jobs.sh - Cancel all running CBV jobs
#
# Usage:
#   bash cancel_cbv_jobs.sh [confirm]
#
# Without 'confirm': Shows jobs that would be canceled
# With 'confirm': Actually cancels the jobs

# Get list of CBV job IDs
JOB_IDS=$(squeue -u $USER -h -o "%i" -n CBV_method 2>/dev/null)

if [ -z "$JOB_IDS" ]; then
    echo "No CBV jobs found to cancel"
    exit 0
fi

echo "=========================================="
echo "  CBV Job Cancellation"
echo "=========================================="
echo ""

# Count jobs
NUM_JOBS=$(echo "$JOB_IDS" | wc -l)

if [[ "$1" != "confirm" ]]; then
    echo "Found $NUM_JOBS CBV job(s):"
    echo ""
    squeue -u $USER -o "%.18i %.30j %.8T %.10M" | grep -E "CBV|JOBID"
    echo ""
    echo "To cancel these jobs, run:"
    echo "  bash cancel_cbv_jobs.sh confirm"
    echo ""
else
    echo "Canceling $NUM_JOBS CBV job(s)..."
    echo ""

    for JOB_ID in $JOB_IDS; do
        echo "  Canceling job $JOB_ID..."
        scancel $JOB_ID
    done

    echo ""
    echo "All CBV jobs canceled"
    echo ""
fi

echo "=========================================="
echo ""
