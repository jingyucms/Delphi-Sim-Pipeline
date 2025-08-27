#!/bin/bash

# Simple wrapper to submit multiple batches of your existing condor script
# Usage: ./submit_batches.sh

NUM_BATCHES=10
SUBMIT_FILE="condor_delphi.sub"

echo "=== Submitting $NUM_BATCHES batches of $JOBS_PER_BATCH jobs each ==="

for batch in $(seq 1 $NUM_BATCHES); do
    echo "Submitting batch $batch/$NUM_BATCHES..."
    condor_submit $SUBMIT_FILE
    sleep 3  
    echo "Batch $batch submitted"
done
