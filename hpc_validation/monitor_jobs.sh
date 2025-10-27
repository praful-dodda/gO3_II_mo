#!/bin/bash
#
# monitor_jobs.sh - Monitor TOAR validation jobs
#
# Usage:
#   bash monitor_jobs.sh [watch]
#
# Options:
#   watch  - Continuously monitor (refresh every 30 seconds)

WATCH_MODE=0
if [[ "$1" == "watch" ]]; then
    WATCH_MODE=1
fi

function show_status() {
    clear
    echo "=========================================="
    echo "  TOAR Validation Job Monitor"
    echo "  $(date)"
    echo "=========================================="
    echo ""

    # Show SLURM queue for this user's TOAR jobs
    echo "Current Jobs:"
    echo "----------------------------------------"
    if command -v squeue &> /dev/null; then
        squeue -u $USER -o "%.18i %.12j %.8T %.10M %.6D %R" | grep -E "(JOBID|TOAR_val)" || echo "  No active jobs found"
    else
        echo "  squeue not available (not on HPC cluster?)"
    fi

    echo ""
    echo "Job Status Summary:"
    echo "----------------------------------------"

    # Count jobs by state
    if command -v squeue &> /dev/null; then
        RUNNING=$(squeue -u $USER | grep "TOAR_val" | grep -c " R " || true)
        PENDING=$(squeue -u $USER | grep "TOAR_val" | grep -c " PD " || true)
        echo "  Running:  $RUNNING"
        echo "  Pending:  $PENDING"
    fi

    # Check for completed jobs (by looking for output files)
    echo ""
    echo "Completed Jobs (with output files):"
    echo "----------------------------------------"
    if ls logs/val_go*.out 2>/dev/null | head -10; then
        echo "  (showing first 10)"
    else
        echo "  No output files found yet"
    fi

    # Check for errors
    echo ""
    echo "Recent Errors:"
    echo "----------------------------------------"
    if ls logs/val_go*.err 2>/dev/null; then
        for errfile in logs/val_go*.err; do
            if [[ -s "$errfile" ]]; then
                echo "  ERROR in: $errfile"
                echo "    $(tail -1 $errfile)"
            fi
        done
    else
        echo "  No error files"
    fi

    # Check validation results
    echo ""
    echo "Validation Results:"
    echo "----------------------------------------"
    RESULTS_DIR="../7validation/hpc_results"
    if [[ -d "$RESULTS_DIR" ]]; then
        RESULT_COUNT=$(ls -1 $RESULTS_DIR/validation_summary_*.mat 2>/dev/null | wc -l || echo "0")
        echo "  Completed validations: $RESULT_COUNT / 4"
        if [[ $RESULT_COUNT -gt 0 ]]; then
            echo ""
            ls -lh $RESULTS_DIR/validation_summary_*.mat 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}'
        fi
    else
        echo "  Results directory not created yet"
    fi

    echo ""
    echo "=========================================="
}

if [[ $WATCH_MODE -eq 1 ]]; then
    echo "Entering watch mode (Ctrl+C to exit)..."
    echo "Refreshing every 30 seconds"
    sleep 2

    while true; do
        show_status
        echo ""
        echo "Press Ctrl+C to exit watch mode..."
        sleep 30
    done
else
    show_status
    echo ""
    echo "To continuously monitor, run:"
    echo "  bash monitor_jobs.sh watch"
    echo ""
fi
