#!/bin/bash
# Condor wrapper that runs the native pythia8 DELPHI pipeline inside the pinned singularity
# image (the delphi-sim .sif = the jingyucms image). This is the singularity submission
# model (vanilla universe), replacing the deprecated universe=docker path.
#
# The image's /work is read-only but DELSIM needs GBs of scratch, so we stage /work into the
# condor worker scratch dir and bind it back as /work for the real run.
# Args are passed straight to run_pipeline.sh: <nev> <job_id> <output_dir> <config> <version> <ebeam>
set -e
SIF=/afs/cern.ch/work/z/zhangj/delphi-pythia8-pipeline/delphi-sim.sif
SCRATCH="${_CONDOR_SCRATCH_DIR:-/tmp/$$}/work"
mkdir -p "$SCRATCH"
# Ensure the output dir (e.g. an EOS path) exists - run_pipeline.sh moves the DST there but
# does not create it. Worker can mkdir EOS via the forwarded token (MY.SendCredential).
[ -n "${3:-}" ] && mkdir -p "$3"

# Stage /work from the image into the writable scratch.
singularity exec --bind "$SCRATCH:/host_scratch" "$SIF" cp -a /work/. /host_scratch/

singularity exec \
    --bind /eos:/eos \
    --bind /afs:/afs \
    --bind "$SCRATCH:/work" \
    "$SIF" \
    /work/run_pipeline.sh "$@"

JOB_ID="$2"
OUTPUT_DIR="$3"
rm -f "$OUTPUT_DIR/simana_${JOB_ID}.fadana"
echo "Dropped $OUTPUT_DIR/simana_${JOB_ID}.fadana (fadana not kept)"
