#!/bin/bash

# KK2f-DELSIM Pipeline Script
# Usage: ./run_kk2f_pipeline.sh [num_events] [job_id] [output_dir] [isr_mode]

set -e  # Exit on any error

# Parse arguments
NUM_EVENTS=${1:-3000}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUTPUT_DIR=${3:-/work/output}
ISR_MODE=${4:-"on"}  # "on" or "off"

# Convert OUTPUT_DIR to absolute path if relative
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

echo "=== KK2f-DELSIM Pipeline Starting ==="
echo "Events to generate: $NUM_EVENTS"
echo "Job ID: $JOB_ID"
echo "Output directory: $OUTPUT_DIR"
echo "ISR mode: $ISR_MODE"
echo "Working directory: $(pwd)"
echo "========================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Step 1: Prepare KK2f workspace in /tmp
TEMP_DIR="/tmp/kk2f_${JOB_ID}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "=== Setting up KK2f workspace ==="
cp /work/kk2f_build/kk2f_qq.exe .
cp /work/kk2f_build/.KK2f_defaults .
cp -r /work/kk2f_build/input .
cp /work/kk2f_fadgen_fixer .

# Select configuration based on ISR mode
if [ "$ISR_MODE" = "on" ]; then
    cp /work/kk2f_build/kk2f_qq_ISR_on.tit fort.19
    KEYISR_VALUE=2  # CEEX
else
    cp /work/kk2f_build/kk2f_qq_ISR_off.tit fort.19
    KEYISR_VALUE=0  # ISR OFF
fi

# Copy and modify fort.5
cp /work/kk2f_build/kk2f.inp DelKK.inp
cp /work/kk2f_build/kk2f.inp fort.5

# CRITICAL: Modify KeyISR in ALL .KK2f_defaults files (line 49)
echo "Setting KeyISR=$KEYISR_VALUE in all defaults files..."
for defaults_file in .KK2f_defaults input/KK2f_defaults input/KK2f_defaults_v4-13 input/KK2f_defaults_v4-14; do
    if [ -f "$defaults_file" ]; then
        sed -i "49s/              1/              ${KEYISR_VALUE}/" "$defaults_file"
        echo "  Updated $defaults_file"
    fi
done

# Verify KeyISR setting
echo "KeyISR setting in .KK2f_defaults:"
grep "KeyISR" .KK2f_defaults

# Update NEVT in fort.19 based on NUM_EVENTS
sed -i "s/NEVT [0-9]*/NEVT $NUM_EVENTS/" fort.19

echo "=== Running KK2f event generation ==="

# CRITICAL: Clean old outputs before running KK2f (prevents unit 51/61 errors)
rm -f lund.output fort.51 fort.52 fort.61 fort.62 kk2f.log

# Run KK2f
./kk2f_qq.exe > kk2f.log 2>&1

# Check if KK2f succeeded
if [ ! -f "lund.output" ] || [ ! -s "lund.output" ]; then
    echo "ERROR: KK2f failed to generate events"
    cat kk2f.log | tail -50
    exit 1
fi

EVENT_COUNT=$(grep -c "Event listing" kk2f.log || echo 0)
echo "✓ KK2f generated $EVENT_COUNT events"
ls -lh lund.output

# Step 2: Fix FADGEN format with kk2f_fadgen_fixer
echo "=== Fixing FADGEN format for DELSIM ==="
./kk2f_fadgen_fixer lund.output my_events.fadgen

if [ ! -f "my_events.fadgen" ] || [ ! -s "my_events.fadgen" ]; then
    echo "ERROR: FADGEN fixer failed"
    exit 1
fi

echo "✓ FADGEN format fixed"
ls -lh my_events.fadgen

# Step 3: Set up DELPHI environment
echo "=== Setting up DELPHI environment ==="
export PATH="/root/.local/bin:/root/bin:/delphi/releases/almalinux-9-x86_64/latest/scripts:/delphi/scripts:/delphi/releases/almalinux-9-x86_64/latest/bin:/delphi/releases/almalinux-9-x86_64/latest/cern/pro/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:."

export OPGS_RUN_TIME="/delphi/releases/almalinux-9-x86_64/latest/delgra/run_time"
export DELPHI_RELEASE="latest"
export CERN_ROOT="/delphi/releases/almalinux-9-x86_64/latest/cern/pro"
export DELPHI_PAM="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/src/car"
export DELPHI_DDB_BIN="/delphi/releases/almalinux-9-x86_64/latest/ddb/bin"
export DELPHI="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018"
export GROUPPATH="/delphi/releases/almalinux-9-x86_64/latest/bin"
export CERN_PAM="/delphi/releases/almalinux-9-x86_64/latest/cern/pro/src/car"
export DELPHI_LIB="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/lib"
export DES_HOME="/delphi/releases/almalinux-9-x86_64/latest/evserv"
export CERN="/delphi/releases/almalinux-9-x86_64/latest/cern"
export CERN_LIB="/delphi/releases/almalinux-9-x86_64/latest/cern/pro/lib"
export DELPHI_BATCAVE="/delphi/pdl"
export OPENPHIGS="/delphi/releases/almalinux-9-x86_64/latest/openphigs"
export DELPHI_BLKD="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/blkd"
export DELPHI_ZIP="on"
export DELPHI_XRD=""
export DELPHI_DATA_ROOT="/eos/opendata/delphi"
export GRA_PLACE="/delphi/releases/almalinux-9-x86_64/latest/delgra"
export DELPHI_CRA="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/src/car"
export DELSIM_ROOT="/delphi/releases/almalinux-9-x86_64/latest/simana"
export DELPHI_PATH="/delphi/releases/almalinux-9-x86_64/latest/bin"
export DELPHI_DAT="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/dat"
export GROUP_DIR="/delphi/releases/almalinux-9-x86_64/latest"
export DELPHI_DDB="/eos/opendata/delphi/condition-data"
export DELPHI_DDB_DIR="/delphi/releases/almalinux-9-x86_64/latest/ddb"
export ADDLIB="/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/blkd/delblkd.o"
export DELPHI_INSTALL_DIR="/delphi"
export DELPHI_BIN="/delphi/releases/almalinux-9-x86_64/latest/bin"
export LD_LIBRARY_PATH="/usr/lib64:/lib64:$LD_LIBRARY_PATH"

# Verify runsim is available
if ! command -v runsim &> /dev/null; then
    echo "ERROR: runsim not found"
    exit 1
fi
echo "✓ DELPHI environment configured"

# Generate DELSIM NRUN from job_id
BASE_NRUN=50000
if [[ "$JOB_ID" =~ job_([0-9]+)_([0-9]+) ]]; then
    CLUSTER_ID=${BASH_REMATCH[1]}
    PROCESS_ID=${BASH_REMATCH[2]}
    DELSIM_NRUN=$((BASE_NRUN + (CLUSTER_ID % 800)*100 + PROCESS_ID))
else
    HASH_VALUE=$(echo "$JOB_ID" | cksum | cut -d' ' -f1)
    DELSIM_NRUN=$((BASE_NRUN + HASH_VALUE % 88000))
fi

echo "DELSIM NRUN: $DELSIM_NRUN"

# Step 4: Run DELSIM simulation
echo "=== Running DELSIM simulation ==="
DELSIM_EVENTS=$((NUM_EVENTS * 90 / 100))
if [ $DELSIM_EVENTS -lt 1 ]; then
    DELSIM_EVENTS=1
fi

echo "Running DELSIM with $DELSIM_EVENTS events (90% of $NUM_EVENTS)..."
runsim -VERSION v94c -LABO CERN -NRUN $DELSIM_NRUN -EBEAM 45.625 -NEVMAX $DELSIM_EVENTS -gext my_events.fadgen

# Step 5: Collect outputs
echo "=== Collecting outputs ==="
if [ -f "simana.sdst" ]; then
    mv simana.sdst "${OUTPUT_DIR}/simana_${JOB_ID}.sdst"
    echo "✓ Moved simana.sdst"
else
    echo "ERROR: DELSIM failed to produce simana.sdst"
    ls -la
    exit 1
fi

# Clean up temporary files
echo "=== Cleaning up ==="
rm -f simana.fadsim simana.fadana my_events.fadgen *.out *.log fort.* lund.output

# Clean up temp directory
cd /work
rm -rf "$TEMP_DIR"

echo "=== Pipeline completed successfully ==="
echo "ISR mode: $ISR_MODE (KeyISR=$KEYISR_VALUE)"
echo "DELSIM NRUN: $DELSIM_NRUN"
echo "Output: ${OUTPUT_DIR}/simana_${JOB_ID}.sdst"
ls -lh "${OUTPUT_DIR}/simana_${JOB_ID}.sdst"
echo "========================================"
