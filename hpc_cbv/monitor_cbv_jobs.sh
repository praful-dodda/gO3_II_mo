#!/bin/bash
#
# monitor_cbv_jobs.sh - Monitor running CBV jobs
#
# Usage:
#   bash monitor_cbv_jobs.sh

echo "=========================================="
echo "  TOAR CBV Job Monitor"
echo "=========================================="
echo "Current time: $(date)"
echo ""

# Check for running jobs
echo "Running/Pending Jobs:"
echo "--------------------"
squeue -u $USER -o "%.18i %.9P %.30j %.8T %.10M %.6D %R" | grep -E "CBV|JOBID"

if [ $? -ne 0 ]; then
    echo "No CBV jobs found"
fi

echo ""
echo "Recent Job Completions:"
echo "----------------------"
sacct -u $USER --format=JobID,JobName%30,State,Elapsed,MaxRSS,End -S $(date -d '7 days ago' +%Y-%m-%d) | grep "CBV"

echo ""
echo "=========================================="
echo "  Latest Log Previews"
echo "=========================================="

# Show last few lines of most recent logs
LOGS_DIR="logs"
if [ -d "$LOGS_DIR" ]; then
    LATEST_OUT=$(ls -t $LOGS_DIR/cbv_*.out 2>/dev/null | head -1)
    LATEST_ERR=$(ls -t $LOGS_DIR/cbv_*.err 2>/dev/null | head -1)

    if [ -n "$LATEST_OUT" ]; then
        echo ""
        echo "Latest output log: $LATEST_OUT"
        echo "----------------------------------------"
        tail -20 "$LATEST_OUT"
    fi

    if [ -n "$LATEST_ERR" ] && [ -s "$LATEST_ERR" ]; then
        echo ""
        echo "Latest error log: $LATEST_ERR"
        echo "----------------------------------------"
        tail -20 "$LATEST_ERR"
    fi
else
    echo "No logs directory found"
fi

echo ""
echo "=========================================="
echo "  Results Summary"
echo "=========================================="

RESULTS_DIR="../../7validation/CBV/hpc_results"
if [ -d "$RESULTS_DIR" ]; then
    echo "Results directory: $RESULTS_DIR"
    echo ""
    echo "Completed validation files:"
    ls -lh "$RESULTS_DIR"/cbv_summary_*.mat 2>/dev/null | awk '{print $9, "("$5")"}'

    if [ $? -ne 0 ]; then
        echo "No completed results yet"
    fi
else
    echo "Results directory not yet created"
fi

echo ""
echo "=========================================="
echo ""
echo "Commands:"
echo "  Cancel all jobs:  bash cancel_cbv_jobs.sh"
echo "  Resubmit jobs:    bash submit_cbv_jobs.sh"
echo "  Check specific:   squeue -j <JOBID>"
echo "  Follow log:       tail -f logs/cbv_method_<id>_<jobid>.out"
echo ""
