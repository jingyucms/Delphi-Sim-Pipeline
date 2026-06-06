#!/bin/bash

echo "=== Z Pole Production Submission ==="
echo "Energy: 91.187 GeV"
echo "Events per job: 3000"
echo "Jobs per batch: 25"
echo ""

NUM_BATCHES=25  

for batch in $(seq 1 "$NUM_BATCHES"); do   # NB: {1..$VAR} brace-expansion does NOT work with a variable
    echo "Batch $batch/${NUM_BATCHES}: Submitting ISR ON..."
    condor_submit condor_kk2f_zpole_ISR_on.sub
    sleep 2
    
    echo "Batch $batch/${NUM_BATCHES}: Submitting ISR OFF..."
    condor_submit condor_kk2f_zpole_ISR_off.sub
    sleep 2
done
