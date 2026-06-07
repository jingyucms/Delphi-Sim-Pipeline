#!/bin/bash
# generators/kkmc/generate.sh - M3 subshell A (KKMCee path): produce events.hepmc3.
# KKMCee 5.01 (key4hep) = the modern KK2F, DELPHI's own legacy e+e- generator. Clean CLI,
# native HepMC3 (Asciiv3). No container needed.
#
# Hadronization: KKMC uses JETSET 7.4 (the LUND string = PYTHIA6's fragmentation), with
# Tauola for tau decays and Photos for QED radiation in decays.
#
# !!! KNOWN LIMITATION (2026-06-06): the key4hep KKMCee build emits PARTON-LEVEL events
# (e+e- -> q qbar + ISR; quarks are status-1, NO hadrons) despite KeyHad=1, with
# "cling::AutoLoadingVisitor" errors in the log -> its hadronization backend is not engaging.
# So this output is NOT yet hadron-level and NOT ready for DELSIM as-is. Options to resolve:
#   (a) fix the KKMCee hadronization (looks like a ROOT/cling autoloading issue);
#   (b) hadronize the parton-level HepMC3 downstream with Pythia8;
#   (c) use the legacy DELPHI KK2F Fortran path (kk2f_build/), which DOES hadronize via
#       JETSET -> LUJETS -> fort.26 directly.
# Always check the result with hepmc3_audit.py before trusting it.
#
# Usage: generate.sh [nevents=20] [ecms=91.187] [outdir=$PWD/kkmc_run]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
NEV="${1:-20}"; ECMS="${2:-91.187}"; OUTDIR="${3:-$PWD/kkmc_run}"

set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1 || true
command -v KKMCee >/dev/null || { echo "ERROR: KKMCee not on PATH (key4hep not sourced?)"; exit 1; }

mkdir -p "$OUTDIR"; cd "$OUTDIR"
echo "KKMCee -f Hadrons -e $ECMS -n $NEV  outdir=$OUTDIR"
KKMCee -f Hadrons -e "$ECMS" -n "$NEV" -o kkmcee.hepmc > kkmc.log 2>&1 || { echo "ERROR: KKMCee failed"; tail -15 kkmc.log; exit 1; }
if [ -s kkmcee.hepmc ]; then
  cp -f kkmcee.hepmc events.hepmc3
  echo "HepMC3 -> $OUTDIR/events.hepmc3 ($(stat -c%s events.hepmc3) bytes)"
  echo "WARNING: key4hep KKMCee currently emits PARTON-LEVEL output - audit before DELSIM."
else
  echo "ERROR: no kkmcee.hepmc produced"; tail -15 kkmc.log; exit 1
fi
