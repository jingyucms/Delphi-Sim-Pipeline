#!/bin/bash
# generators/whizard/generate.sh - M3 subshell A (Whizard path): produce events.hepmc3.
# Runs Whizard 3.1.5 (key4hep) with zhad.sin (e+e- -> q qbar per flavour, PYTHIA6
# hadronization, V0 set kept stable via PYGIVE), normalizes output to events.hepmc3.
# No container needed (VM or lxplus). n_events is set inside zhad.sin.
#
# NB: Whizard marks the e+e- beams as status 3 (not 4); hepmc2fadgen still places them
# first as K=21, which is what DELSIM expects. Output ASCII is Asciiv3.
#
# Usage: generate.sh [outdir=$PWD/whizard_run]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
OUTDIR="${1:-$PWD/whizard_run}"

set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1; set -u
command -v whizard >/dev/null || { echo "ERROR: whizard not on PATH (key4hep not sourced?)"; exit 1; }

mkdir -p "$OUTDIR"; cd "$OUTDIR"
echo "$(whizard --version 2>/dev/null | head -1)  outdir=$OUTDIR"
whizard "$HERE/zhad.sin" > whizard.log 2>&1 || { echo "ERROR: whizard failed"; tail -20 whizard.log; exit 1; }
if [ -s whizard_events.hepmc ]; then
  cp -f whizard_events.hepmc events.hepmc3
  echo "HepMC3 -> $OUTDIR/events.hepmc3 ($(stat -c%s events.hepmc3) bytes)"
else
  echo "ERROR: no whizard_events.hepmc produced"; tail -20 whizard.log; exit 1
fi
