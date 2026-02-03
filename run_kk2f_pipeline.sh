#!/bin/bash
set -e

NUM_EVENTS=${1:-3000}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUTPUT_DIR=${3:-/work/output}
ISR_MODE=${4:-on}

if [ "$ISR_MODE" = "off" ]; then
    CONFIG_FILE="kk2f_qq_ISR_off.tit"
elif [ "$ISR_MODE" = "on" ]; then
    CONFIG_FILE="kk2f_qq_ISR_on.tit"
else
    echo "ERROR: ISR mode must be 'on' or 'off'"
    exit 1
fi

# COMPLETE DELPHI environment setup
echo "Setting up DELPHI environment..."
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

# DEBUG: Print environment
echo "=== Environment Debug ==="
echo "GROUP_DIR=$GROUP_DIR"
echo "DELSIM_ROOT=$DELSIM_ROOT"
which runsim

# Rest of script...
BASE_NRUN=3000
if [[ "$JOB_ID" =~ ^[0-9]+$ ]]; then
    DELSIM_NRUN=$((BASE_NRUN + JOB_ID % 88000))
else
    HASH_VALUE=$(echo "$JOB_ID" | cksum | cut -d' ' -f1)
    DELSIM_NRUN=$((BASE_NRUN + HASH_VALUE % 88000))
fi

echo "=== KK2f-DELSIM Pipeline ==="
echo "Events: $NUM_EVENTS"
echo "ISR: $ISR_MODE"
echo "DELSIM NRUN: $DELSIM_NRUN"

WORK_DIR="/tmp/kk2f_${JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

cp /work/kk2f_build/kk2f_qq.exe .
cp /work/kk2f_build/.KK2f_defaults .
cp -r /work/kk2f_build/input .
cp /work/kk2f_build/kk2f.inp DelKK.inp
cp /work/kk2f_build/kk2f.inp fort.5
cp /work/kk2f_build/${CONFIG_FILE} fort.19
sed -i "s/NEVT .*/NEVT $NUM_EVENTS/" fort.19

echo "Step 1: KK2f..."
./kk2f_qq.exe > kk2f.log 2>&1

echo "Step 2: Fixer..."
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
else
    echo "❌ Failed"
    exit 1
fi
