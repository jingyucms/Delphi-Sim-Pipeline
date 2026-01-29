#!/bin/bash

# Wrapper to submit multiple batches of KK2f jobs
# Usage: ./submit_condor_kk2f.sh [ISR_mode]
# ISR_mode: "on" or "off" (default: "off")

ISR_MODE=${1:-"off"}
NUM_BATCHES=10
SUBMIT_FILE="condor_kk2f_ISR_${ISR_MODE}.sub"

if [ ! -f "$SUBMIT_FILE" ]; then
    echo "ERROR: Submission file $SUBMIT_FILE not found"
    exit 1
fi

echo "=== Submitting $NUM_BATCHES batches of KK2f ISR-${ISR_MODE} jobs ==="
echo "Submission file: $SUBMIT_FILE"

for batch in $(seq 1 $NUM_BATCHES); do
    echo "Submitting batch $batch/$NUM_BATCHES..."
    condor_submit $SUBMIT_FILE
    sleep 3  
    echo "Batch $batch submitted"
done

echo "=== All $NUM_BATCHES batches submitted ==="
echo "Total jobs: $((NUM_BATCHES * 25)) jobs"
echo "Check status: condor_q"
