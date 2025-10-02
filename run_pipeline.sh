#!/bin/bash

# DELPHI-Pythia8 Pipeline Script
# Usage: ./run_pipeline.sh [num_events] [job_id] [output_dir] [config_file]

set -e  # Exit on any error

# Set up complete DELPHI environment (all variables from working container)
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
export PYTHIA8DATA="/usr/share/Pythia8/xmldoc"
export LD_LIBRARY_PATH="/usr/lib64:/lib64:$LD_LIBRARY_PATH"

# Also add after setting DELPHI environment:
echo "=== Checking Pythia8 Data ==="
echo "PYTHIA8DATA: $PYTHIA8DATA"
ls -la "$PYTHIA8DATA" 2>/dev/null || echo "Pythia8 data directory not found"
find /usr -name "xmldoc" -type d 2>/dev/null | head -5

# Verify runsim is available
if ! command -v runsim &> /dev/null; then
    echo "ERROR: runsim not found"
    echo "PATH: $PATH"
    exit 1
fi
echo "✓ DELPHI environment configured, runsim found at: $(which runsim)"

# Updated parameter handling with config file support
NUM_EVENTS=${1:-3000}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUTPUT_DIR=${3:-/work/output}
CONFIG_FILE=${4:-""}
DELSIM_VERSION=${5:-"v94c"}
E_BEAM=${6:-"45.625"}

echo "DELSIM version: $DELSIM_VERSION"
echo "Beam energy: $E_BEAM"

# Generate variable NRUN for DELSIM based on job_id and time
# This ensures different random seeds for DELSIM across jobs
BASE_NRUN=3000
if [[ "$JOB_ID" =~ ^[0-9]+$ ]]; then
    # If JOB_ID is numeric, use it directly
    DELSIM_NRUN=$((BASE_NRUN + JOB_ID % 88000))  # Keep within reasonable range
else
    # If JOB_ID is string (like timestamp), hash it to get number
    HASH_VALUE=$(echo "$JOB_ID" | cksum | cut -d' ' -f1)
    DELSIM_NRUN=$((BASE_NRUN + HASH_VALUE % 88000))
fi

echo "=== DELPHI-Pythia8 Pipeline Starting ==="
echo "Events to generate: $NUM_EVENTS"
echo "Job ID: $JOB_ID"
echo "Output directory: $OUTPUT_DIR"
if [ -n "$CONFIG_FILE" ]; then
    echo "Pythia config file: $CONFIG_FILE"
else
    echo "Pythia config: default (Z->hadrons)"
fi
echo "DELSIM NRUN: $DELSIM_NRUN"
echo "Working directory: $(pwd)"
echo "========================================="

# Change to work directory (replaces your manual 'cd /work')
cd /work

# Step 1: Smart Pythia generator compilation check
echo "=== Checking Pythia8 Generator ==="
if [ -f "pythia8_generate" ] && [ -x "pythia8_generate" ]; then
    echo "✅ Using existing pythia8_generate binary"
elif [ -w "." ]; then
    echo "Directory writable, compiling..."
    if make clean && make pythia8_generate; then
        echo "✅ Compilation successful"
    else
        echo "❌ Compilation failed"
        exit 1
    fi
else
    echo "❌ No binary found and directory not writable"
    exit 1
fi

# Verify compilation succeeded
if [ ! -f "./pythia8_generate" ]; then
    echo "ERROR: Compilation failed"
    exit 1
fi

# Add this to your script RIGHT BEFORE compilation check:
echo "=== Environment at Runtime ==="
echo "PWD: $(pwd)"
echo "USER: $(whoami)"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PATH: $PATH"
echo "PYTHIA8DATA: $PYTHIA8DATA"

echo "=== Pre-Pythia Debug ==="
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "Checking pythia8_generate dependencies:"
ldd ./pythia8_generate 2>/dev/null || echo "ldd failed"
echo "File permissions:"
ls -la pythia8_generate
echo "=== Starting Pythia ==="

# Step 2: Generate events with optional config file
echo "Step 2: Generating $NUM_EVENTS events..."
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo "Using config file: $CONFIG_FILE"
    cat "$CONFIG_FILE"
    echo "--- End of config file ---"
    ./pythia8_generate $NUM_EVENTS "$CONFIG_FILE"
else
    echo "Using default configuration"
    ./pythia8_generate $NUM_EVENTS
fi

# ADD DEBUGGING HERE:
echo "=== DEBUG: Pythia generation completed ==="
echo "Pythia exit code: $?"
echo "Current directory contents:"
ls -la
echo "Looking for fort.* files:"
ls -la fort.* 2>/dev/null || echo "No fort.* files found"
echo "Looking for *.fadgen files:"
ls -la *.fadgen 2>/dev/null || echo "No .fadgen files found"
echo "Working directory: $(pwd)"
echo "Disk space:"
df -h .
echo "=== END DEBUG ==="

# Check if events were generated
if [ ! -f "fort.26" ]; then
    echo "ERROR: No events generated (fort.26 missing)"
    exit 1
fi

# Count lines in fort.26 to verify
EVENT_COUNT=$(wc -l < fort.26)
echo "Generated event file contains $EVENT_COUNT lines"

# Step 3: Prepare for DELSIM (replaces your manual 'mv fort.26 my_events.fadgen')
echo "Step 3: Preparing DELSIM input..."
mv fort.26 my_events.fadgen

# Step 4: Run DELSIM simulation with variable NRUN
echo "Step 4: Running DELSIM simulation..."
# Calculate 90% of requested events for DELSIM to prevent hangs
DELSIM_EVENTS=$((NUM_EVENTS * 90 / 100))
# Ensure minimum of 1 event
if [ $DELSIM_EVENTS -lt 1 ]; then
    DELSIM_EVENTS=1
fi

echo "Running DELSIM with $DELSIM_EVENTS events (90% of $NUM_EVENTS requested) and NRUN=$DELSIM_NRUN..."
# Run runsim 
runsim -VERSION $DELSIM_VERSION -LABO CERN -NRUN $DELSIM_NRUN -EBEAM $E_BEAM -NEVMAX $DELSIM_EVENTS -gext my_events.fadgen 

# Step 5: Collect outputs (move instead of copy to save disk space)
echo "Step 5: Collecting outputs..."

if [ -f "simana.sdst" ]; then
    mv simana.sdst "${OUTPUT_DIR}/simana_${JOB_ID}.sdst"
    echo "✓ Moved simana.sdst"
fi

# Clean up large unnecessary files to save space
echo "Step 6: Cleaning up large files..."
rm -f simana.fadsim simana.fadana my_events.fadgen *.out *.log fort.* FOR*
echo "✓ Cleaned up unnecessary files"

echo "=== Pipeline completed successfully ==="
echo "Configuration used:"
if [ -n "$CONFIG_FILE" ]; then
    echo "  Pythia config: $CONFIG_FILE"
else
    echo "  Pythia config: default"
fi
echo "  DELSIM NRUN: $DELSIM_NRUN"
echo "  Events generated by Pythia: $NUM_EVENTS"
echo "  Events processed by DELSIM: $DELSIM_EVENTS (80%)"
echo "Output directory: $OUTPUT_DIR"
echo "Files created:"
ls -la "$OUTPUT_DIR"
echo "========================================="
