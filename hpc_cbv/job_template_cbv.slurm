#!/bin/bash
#SBATCH -p general
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --time=3-00:00:00
#SBATCH --mem=48G
#SBATCH --job-name=CBV_method__METHOD_ID__
#SBATCH --output=../logs/cbv_method__METHOD_ID___%j.out
#SBATCH --error=../logs/cbv_method__METHOD_ID___%j.err

# TOAR Checker-Board Validation Job
# BME Method: __BME_METHOD__
# Years: __VAL_YEARS__
# Box Sizes: __BOX_SIZES__

echo "=========================================="
echo "  TOAR Checker-Board Validation Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo "BME Method: __BME_METHOD__"
echo "Method ID: __METHOD_ID__"
echo "Years: __VAL_YEARS__"
echo "Box sizes: __BOX_SIZES__ degrees"
echo ""

# Load required modules for UNC Longleaf
module purge
module load matlab/2023b
# Add other modules as needed (e.g., gcc if required)

# Navigate to project directory
cd $SLURM_SUBMIT_DIR/../..
echo "Working directory: $(pwd)"
echo ""

# Run MATLAB worker script
echo "Starting MATLAB CBV worker..."
matlab -nodisplay -nosplash -nodesktop -r \
    "try; \
         run_cbv_worker('__BME_METHOD__', [__VAL_YEARS__], [__BOX_SIZES__]); \
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
