#!/bin/bash
# Run the full Pythia -> DELSIM pipeline locally using a stock cmssw/el9
# singularity image backed by CVMFS, instead of Jingyu's baked DELPHI image.
#
# Prereqs on host:
#   * singularity-ce (or apptainer) >= 3.8
#   * /cvmfs/delphi.cern.ch and /cvmfs/sft.cern.ch visible (autofs / cvmfs-fuse)
#   * AlmaLinux 9 on host with libgfortran-11 and motif packages installed
#     (we bind-mount them into the container because the cmssw/el9 image is
#     minimal and does not carry them).
#
# Usage:
#   ./run_singularity.sh <n_events> <job_id> <out_dir> <config_file>
#
# Example:
#   ./run_singularity.sh 200 smoketest /tmp/out ../config_z_tautau.txt
#
# The wrapper handles:
#   * pulling / caching the cmssw/el9 SIF on first run
#   * compiling pythia8_generate from the checked-out source using LCG_109 Pythia 8.317
#   * running runsim with DELPHI_DDB / DELPHI_DATA_ROOT redirected to the CVMFS
#     copies (no EOS dependency)

set -eo pipefail

N_EVENTS=${1:-200}
JOB_ID=${2:-$(date +%Y%m%d_%H%M%S)}
OUT_DIR=${3:-$PWD/out}
CONFIG_FILE=${4:-$PWD/../config_z_tautau.txt}
DELSIM_VERSION=${5:-v94c}
E_BEAM=${6:-45.625}

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
IMAGE_DIR=${IMAGE_DIR:-$HOME/.cache/singularity-delphi}
IMAGE=$IMAGE_DIR/cmssw-el9-x86_64.sif
LCG_VIEW=/cvmfs/sft.cern.ch/lcg/views/LCG_109/x86_64-el9-gcc13-opt

mkdir -p "$IMAGE_DIR" "$OUT_DIR"

if [ ! -f "$IMAGE" ]; then
    echo "=== Pulling cmssw/el9:x86_64 to $IMAGE ==="
    singularity pull --name "$(basename "$IMAGE")" --dir "$IMAGE_DIR" \
        docker://cmssw/el9:x86_64 || {
            # The pull step sometimes errors on cleanup of a temp bundle but
            # still produces the .sif. Validate and continue.
            [ -f "$IMAGE" ] || exit 1
        }
fi

# The DELSIM binaries (simrun36, delana43.exe, shortdst.exe) need libgfortran-5,
# libquadmath, libXm, libXp, libquadmath — not present in the minimal cmssw/el9
# image. Rather than binding them one by one, we mount the host /lib64 read-only
# at /host_lib64 inside the container and prepend it to LD_LIBRARY_PATH. The
# container's own /lib64 (glibc etc.) stays authoritative; the host libs are
# only consulted for names the container lacks.
BIND_LIBS=(--bind /lib64:/host_lib64:ro)

# Stage the work dir so the container has a writable /work.
WORK=$OUT_DIR/work_${JOB_ID}
mkdir -p "$WORK"
cp "$REPO_ROOT/pythia8_generate.cpp" "$REPO_ROOT/Makefile" "$WORK/"
cp "$CONFIG_FILE" "$WORK/config.txt"

echo "=== Stage 1: compile pythia8_generate against LCG Pythia 8.317 ==="
singularity exec --cleanenv --bind /cvmfs --bind "$WORK:/work" "${BIND_LIBS[@]}" \
    "$IMAGE" bash -c "
        set +u
        source $LCG_VIEW/setup.sh
        cd /work
        make clean
        make pythia8_generate
    "

echo "=== Stage 2: generate $N_EVENTS Pythia events (config=$(basename "$CONFIG_FILE")) ==="
singularity exec --cleanenv --bind /cvmfs --bind "$WORK:/work" "${BIND_LIBS[@]}" \
    "$IMAGE" bash -c "
        set +u
        source $LCG_VIEW/setup.sh
        cd /work
        ./pythia8_generate $N_EVENTS /work/config.txt
    " | tail -40
mv "$WORK/fort.26" "$WORK/my_events.fadgen"

echo "=== Stage 3: DELSIM (runsim $DELSIM_VERSION NRUN=3101 EBEAM=$E_BEAM N=$N_EVENTS) ==="
singularity exec --cleanenv --bind /cvmfs --bind "$WORK:/work" "${BIND_LIBS[@]}" \
    "$IMAGE" bash -c "
        set +u
        source /cvmfs/delphi.cern.ch/setup.sh > /dev/null 2>&1
        # /eos/opendata/delphi is not reachable outside CERN; CVMFS carries the
        # same condition data. Override the defaults.
        export DELPHI_DDB=/cvmfs/delphi.cern.ch/condition-data
        export DELPHI_DATA_ROOT=/cvmfs/delphi.cern.ch
        # Host /lib64 bound at /host_lib64; expose it to ld.so only as a
        # fallback path for names the container image does not ship.
        export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/host_lib64
        cd /work
        runsim -VERSION $DELSIM_VERSION -LABO CERN -NRUN 3101 -EBEAM $E_BEAM \\
               -NEVMAX $N_EVENTS -gext my_events.fadgen
    " | tail -40

if [ -f "$WORK/simana.sdst" ]; then
    mv "$WORK/simana.sdst" "$OUT_DIR/simana_${JOB_ID}.sdst"
    echo "=== DONE: $OUT_DIR/simana_${JOB_ID}.sdst ==="
else
    echo "=== DELSIM did not produce simana.sdst; check $WORK for logs ==="
    exit 1
fi

# Preserve the DELANA full-DST alongside. It carries per-track 3-D track
# elements (PA.TETP / TEID / TEOD / TEFA / TEFB) that the shortDST drops.
if [ -f "$WORK/simana.fadana" ]; then
    mv "$WORK/simana.fadana" "$OUT_DIR/simana_${JOB_ID}.fadana"
    echo "=== DONE: $OUT_DIR/simana_${JOB_ID}.fadana (full DST) ==="
fi
