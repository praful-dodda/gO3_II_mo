#!/bin/bash
#SBATCH --job-name=TOAR_val_go__GO_SCENARIO__
#SBATCH --output=../logs/val_go__GO_SCENARIO___%j.out
#SBATCH --error=../logs/val_go__GO_SCENARIO___%j.err
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --partition=normal

# TOAR LOOCV Validation Job
# Global Offset Scenario: __GO_SCENARIO__
# Validation Years: __VAL_YEARS__

echo "=========================================="
echo "  TOAR LOOCV Validation Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo "GO Scenario: __GO_SCENARIO__"
echo "Years: __VAL_YEARS__"
echo ""

# Load required modules (adjust for your cluster)
# module purge
# module load matlab/R2023a
# module load gcc/11.2.0

# Set number of computational threads
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export MATLAB_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Navigate to project directory
cd $SLURM_SUBMIT_DIR/../..
echo "Working directory: $(pwd)"
echo ""

# Run MATLAB worker script
echo "Starting MATLAB validation worker..."
matlab -nodisplay -nosplash -nodesktop -r \
    "try; \
         run_validation_worker(__GO_SCENARIO__, [__VAL_YEARS__]); \
         exit(0); \
     catch ME; \
         fprintf('ERROR: %s\n', ME.message); \
         fprintf('Stack trace:\n'); \
         for k=1:length(ME.stack); \
             fprintf('  File: %s, Line: %d, Function: %s\n', ME.stack(k).file, ME.stack(k).line, ME.stack(k).name); \
         end; \
         exit(1); \
     end"

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Job completed with exit code: $EXIT_CODE"
echo "End time: $(date)"
echo "=========================================="

exit $EXIT_CODE
