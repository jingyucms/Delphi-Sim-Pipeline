#!/bin/bash

# KK2f-DELSIM Pipeline Script
# Usage: ./run_kk2f_pipeline.sh [num_events] [job_id] [output_dir] [ISR_mode]
# ISR_mode: "on" or "off"

set -e  # Exit on any error

# Set up DELPHI environment
echo "Setting up DELPHI environment..."
export PATH="/root/.local/bin:/root/bin:/delphi/releases/almalinux-9-x86_64/latest/scripts:/delphi/scripts:/delphi/releases/almalinux-9-x86_64/latest/bin:/delphi/releases/almalinux-9-x86_64/latest/cern/pro/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:."

# Set all DELPHI environment variables
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
export CERN_LIB="/delphi/releases/almalinux-9-x86_64/latest/cern/pro/lib64"
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
echo "✓ DELPHI environment configured, runsim found at: $(which runsim)"

# Parse parameters
NUM_EVENTS=${1:-100}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUTPUT_DIR=${3:-/work/output}
ISR_MODE=${4:-"on"}

# Generate variable NRUN for DELSIM based on job_id
BASE_NRUN=90000
if [[ "$JOB_ID" =~ ^[0-9]+$ ]]; then
    DELSIM_NRUN=$((BASE_NRUN + JOB_ID % 88000))
else
    HASH_VALUE=$(echo "$JOB_ID" | cksum | cut -d' ' -f1)
    DELSIM_NRUN=$((BASE_NRUN + HASH_VALUE % 88000))
fi

echo "=== KK2f-DELSIM Pipeline Starting ==="
echo "Events to generate: $NUM_EVENTS"
echo "Job ID: $JOB_ID"
echo "Output directory: $OUTPUT_DIR"
echo "ISR mode: $ISR_MODE"
echo "DELSIM NRUN: $DELSIM_NRUN"
echo "Working directory: $(pwd)"
echo "========================================="

# Change to kk2f build directory
cd /work/kk2f_build

# Step 1: Select correct input file based on ISR mode
echo "Step 1: Configuring KK2f for ISR-$ISR_MODE..."
if [ "$ISR_MODE" = "off" ]; then
    ln -sf kk2f_ISR_off.inp DelKK.inp
    ln -sf kk2f_qq_ISR_off.tit fort.19
else
    ln -sf kk2f.inp DelKK.inp
    ln -sf kk2f_qq_ISR_on.tit fort.19
fi
ln -sf kk2f.inp fort.5
cp input/KK2f_defaults .KK2f_defaults

# Update number of events and run number in title file
sed -i "s/NEVT .*/NEVT $NUM_EVENTS/" fort.19
sed -i "s/NRUN .*/NRUN $DELSIM_NRUN/" fort.19

# Step 2: Run KK2f generator
echo "Step 2: Generating $NUM_EVENTS events with KK2f (ISR $ISR_MODE)..."
./kk2f_qq.exe > kk2f_${JOB_ID}.log 2>&1

# Check if events were generated
if [ ! -f "lund.output" ]; then
    echo "ERROR: No events generated (lund.output missing)"
    exit 1
fi

EVENT_COUNT=$(wc -l < kk2f_${JOB_ID}.log | tail -1)
echo "KK2f generation completed"

# Step 3: Prepare for DELSIM
echo "Step 3: Preparing DELSIM input..."
mv lund.output my_events.fadgen

# Step 4: Run DELSIM simulation
echo "Step 4: Running DELSIM simulation..."
DELSIM_EVENTS=$((NUM_EVENTS * 90 / 100))
if [ $DELSIM_EVENTS -lt 1 ]; then
    DELSIM_EVENTS=1
fi

echo "Running DELSIM with $DELSIM_EVENTS events (90% of $NUM_EVENTS requested) and NRUN=$DELSIM_NRUN..."
runsim -VERSION v94c -LABO CERN -NRUN $DELSIM_NRUN -EBEAM 45.625 -NEVMAX $DELSIM_EVENTS -gext my_events.fadgen 

# Step 5: Collect outputs
echo "Step 5: Collecting outputs..."
mkdir -p "${OUTPUT_DIR}"

if [ -f "simana.sdst" ]; then
    mv simana.sdst "${OUTPUT_DIR}/kk2f_${ISR_MODE}_${JOB_ID}.sdst"
    echo "✓ Moved simana.sdst"
fi

# Step 6: Clean up
echo "Step 6: Cleaning up..."
rm -f simana.fadsim simana.fadana my_events.fadgen DelKK_tmp.out fort.* FOR*
echo "✓ Cleaned up unnecessary files"

echo "=== Pipeline completed successfully ==="
echo "Configuration used:"
echo "  KK2f ISR mode: $ISR_MODE"
echo "  DELSIM NRUN: $DELSIM_NRUN"
echo "  Events generated by KK2f: $NUM_EVENTS"
echo "  Events processed by DELSIM: $DELSIM_EVENTS"
echo "Output directory: $OUTPUT_DIR"
echo "Files created:"
ls -la "$OUTPUT_DIR" | grep kk2f
echo "========================================="
