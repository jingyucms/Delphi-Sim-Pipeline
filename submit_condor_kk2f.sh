#!/bin/bash

echo "=== Submitting KK2f Production Jobs ==="
echo "Total jobs: 1250 (625 ISR ON + 625 ISR OFF)"
echo "Events per job: 3000"
echo "Total events: ~3.75 million"
echo ""

# Submit in batches
for batch in {1..25}; do
    echo "Batch $batch/25: Submitting ISR ON..."
    #condor_submit condor_kk2f_ISR_on.sub
    sleep 2
    
    echo "Batch $batch/25: Submitting ISR OFF..."
    condor_submit condor_kk2f_ISR_off.sub
    sleep 2
done

echo ""
echo "✅ All jobs submitted!"
echo "Monitor with: condor_q"
