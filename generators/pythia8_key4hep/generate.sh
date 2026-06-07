#!/bin/bash
# generators/pythia8_key4hep/generate.sh - M3 subshell A (Pythia8 via key4hep -> HepMC3).
# Builds (if needed) and runs closure_gen, which generates Pythia8 events and writes
# events.hepmc3 for the shared hepmc2fadgen. This is the GENERIC HepMC3 path, matching
# sherpa/herwig/whizard. The native EventWriter->fort.26 path is generators/pythia8/.
#
# Usage: generate.sh [nevents=20] [config] [outdir=$PWD/pythia8_key4hep_run]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
NEV="${1:-20}"; CFG="${2:-}"; OUTDIR="${3:-$PWD/pythia8_key4hep_run}"

set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1; set -u
[ -x "$HERE/closure_gen" ] || bash "$REPO/build_key4hep.sh" closure_gen >/dev/null
[ -x "$HERE/closure_gen" ] || { echo "ERROR: closure_gen not built"; exit 1; }

mkdir -p "$OUTDIR"; cd "$OUTDIR"
echo "closure_gen $NEV ${CFG:+config=$CFG}  outdir=$OUTDIR"
"$HERE/closure_gen" "$NEV" $CFG > gen.log 2>&1
# closure_gen writes events.hepmc3 (+ a fort.26 via EventWriter) in CWD
if [ -s events.hepmc3 ]; then
  echo "HepMC3 -> $OUTDIR/events.hepmc3 ($(stat -c%s events.hepmc3) bytes)"
else
  echo "ERROR: no events.hepmc3 produced"; tail -15 gen.log; exit 1
fi
