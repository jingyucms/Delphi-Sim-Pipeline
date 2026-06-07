#!/bin/bash
# generators/pythia8/generate.sh - native Pythia8 path: pythia8_generate -> fort.26 DIRECTLY
# via EventWriter (no HepMC3, no hepmc2fadgen). This is the original DELPHI pythia8 pipeline /
# the ground-truth path; the generic HepMC3 variant is generators/pythia8_key4hep/.
# (For full production with DELSIM use run_pipeline.sh / the Dockerfile in this folder.)
#
# Usage: generate.sh [nevents=20] [config_z_*.txt] [outdir=$PWD/pythia8_run]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
NEV="${1:-20}"; CFG="${2:-}"; OUTDIR="${3:-$PWD/pythia8_run}"

set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1; set -u
[ -x "$HERE/pythia8_generate" ] || bash "$REPO/build_key4hep.sh" pythia8_generate >/dev/null
[ -x "$HERE/pythia8_generate" ] || { echo "ERROR: pythia8_generate not built"; exit 1; }

mkdir -p "$OUTDIR"; cd "$OUTDIR"
echo "pythia8_generate $NEV ${CFG:+config=$CFG}  outdir=$OUTDIR"
"$HERE/pythia8_generate" "$NEV" $CFG > gen.log 2>&1
if [ -s fort.26 ]; then
  echo "fort.26 -> $OUTDIR/fort.26 ($(stat -c%s fort.26) bytes)  [feed straight to DELSIM]"
else
  echo "ERROR: no fort.26 produced"; tail -15 gen.log; exit 1
fi
