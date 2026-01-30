#!/bin/bash
set -e

# DELPHI-KK2f Pipeline Script
# Usage: ./run_kk2f_pipeline.sh [num_events] [job_id] [output_dir] [isr_mode]
#   isr_mode: "on" or "off" (default: on)

NUM_EVENTS=${1:-3000}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUTPUT_DIR=${3:-/work/output}
ISR_MODE=${4:-on}

# Select config file based on ISR mode
if [ "$ISR_MODE" = "off" ]; then
    CONFIG_FILE="kk2f_qq_ISR_off.tit"
    echo "ISR: OFF"
elif [ "$ISR_MODE" = "on" ]; then
    CONFIG_FILE="kk2f_qq_ISR_on.tit"
    echo "ISR: ON"
else
    echo "ERROR: ISR mode must be 'on' or 'off'"
    exit 1
fi

# DELPHI environment setup
export PATH="/root/.local/bin:/root/bin:/delphi/releases/almalinux-9-x86_64/latest/scripts:/delphi/scripts:/delphi/releases/almalinux-9-x86_64/latest/bin:/delphi/releases/almalinux-9-x86_64/latest/cern/pro/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:."
export DELPHI="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018"
export DELPHI_LIB="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/lib"
export CERN_ROOT="/delphi/releases/almalinux-9-x86_64/latest/cern/pro"
export CERN_LIB="/delphi/releases/almalinux-9-x86_64/latest/cern/pro/lib64"
# Add other env vars as needed

# Generate DELSIM run number from job ID
BASE_NRUN=3000
if [[ "$JOB_ID" =~ ^[0-9]+$ ]]; then
    DELSIM_NRUN=$((BASE_NRUN + JOB_ID % 88000))
else
    HASH_VALUE=$(echo "$JOB_ID" | cksum | cut -d' ' -f1)
    DELSIM_NRUN=$((BASE_NRUN + HASH_VALUE % 88000))
fi

echo "=== KK2f-DELSIM Pipeline ==="
echo "Events: $NUM_EVENTS"
echo "Job ID: $JOB_ID"
echo "Config: $CONFIG_FILE"
echo "DELSIM NRUN: $DELSIM_NRUN"
echo "=============================="

WORK_DIR="/tmp/kk2f_${JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Copy KK2f files
cp /work/kk2f_build/kk2f_qq.exe .
cp /work/kk2f_build/.KK2f_defaults .
cp -r /work/kk2f_build/input .
cp /work/kk2f_build/kk2f.inp DelKK.inp
cp /work/kk2f_build/kk2f.inp fort.5
cp /work/kk2f_build/${CONFIG_FILE} fort.19

# Set event count
sed -i "s/NEVT .*/NEVT $NUM_EVENTS/" fort.19

echo "Step 1: KK2f generation..."
./kk2f_qq.exe > kk2f.log 2>&1

echo "Step 2: Fixing FADGEN..."
/work/kk2f_fadgen_fixer lund.output fixed.fadgen

echo "Step 3: DELSIM..."
DELSIM_EVENTS=$((NUM_EVENTS * 90 / 100))
mv fixed.fadgen my_events.fadgen
runsim -VERSION v94c -LABO CERN -NRUN $DELSIM_NRUN -EBEAM 45.625 -NEVMAX $DELSIM_EVENTS -gext my_events.fadgen

if [ -f "simana.sdst" ]; then
    mkdir -p "${OUTPUT_DIR}"
    OUTPUT_FILE="${OUTPUT_DIR}/kk2f_ISR${ISR_MODE}_${JOB_ID}.sdst"
    mv simana.sdst "$OUTPUT_FILE"
    echo "✓ Complete: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
fi

# Cleanup
rm -f *.fadgen kk2f_qq.exe
