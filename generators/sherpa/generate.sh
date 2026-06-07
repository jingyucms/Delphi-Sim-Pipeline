#!/bin/bash
# generators/sherpa/generate.sh - M3 subshell A (Sherpa path): produce events.hepmc3.
# Sources key4hep, runs Sherpa 3.x with the sibling Sherpa.yaml, normalizes the output to
# <outdir>/events.hepmc3 ready for the shared hepmc2fadgen. No container needed (VM or lxplus).
#
# Usage: generate.sh [nevents=20] [outdir=$PWD/sherpa_run]
# Then:  hepmc2fadgen <outdir>/events.hepmc3 fort.26   (shared tail; same as every generator)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
NEV="${1:-20}"
OUTDIR="${2:-$PWD/sherpa_run}"
# Config selection: SHERPA_YAML may be an absolute path or a bare filename in this folder.
# Default = Sherpa.yaml (backward compatible). ISR variants: Sherpa_isr_on.yaml / Sherpa_isr_off.yaml.
SHERPA_YAML="${SHERPA_YAML:-Sherpa.yaml}"
[ -f "$SHERPA_YAML" ] || SHERPA_YAML="$HERE/$SHERPA_YAML"
[ -f "$SHERPA_YAML" ] || { echo "ERROR: Sherpa config not found: $SHERPA_YAML"; exit 1; }

# key4hep's setup expands unset vars -> disable nounset across the source.
set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1; set -u
command -v Sherpa >/dev/null || { echo "ERROR: Sherpa not on PATH (key4hep not sourced?)"; exit 1; }

mkdir -p "$OUTDIR"; cd "$OUTDIR"
# Per-job random seed (SHERPA_SEED -> Sherpa -R): REQUIRED in production so parallel jobs do not
# all generate IDENTICAL events. Unset -> Sherpa's built-in default seed (fine for single tests).
SEED_ARG=""
[ -n "${SHERPA_SEED:-}" ] && SEED_ARG="-R ${SHERPA_SEED}"
echo "$(Sherpa --version 2>/dev/null | head -1)  nev=$NEV  outdir=$OUTDIR  config=$SHERPA_YAML  seed=${SHERPA_SEED:-<default>}"
# -e overrides EVENTS; integration (Results.zip) is reused if already present in OUTDIR.
Sherpa -f "$SHERPA_YAML" -e "$NEV" $SEED_ARG > sherpa.log 2>&1
rc=$?
echo "Sherpa rc=$rc"
if [ -s sherpa_events ]; then
  cp -f sherpa_events events.hepmc3
  echo "HepMC3 -> $OUTDIR/events.hepmc3 ($(stat -c%s events.hepmc3) bytes)"
else
  echo "ERROR: no sherpa_events produced"; tail -15 sherpa.log; exit 1
fi
exit $rc
