#!/bin/bash
# Submit the Pythia8+Vincia Z->hadrons production for one ISR variant to HTCondor. Run from lxplus.
# Each job: closure_gen (Vincia, per-job seed) -> native EventWriter fort.26 -> DELSIM -> SDST on EOS.
# Usage: submit_vincia_prod.sh <isron|isroff> [total_events=1500000] [evt_per_job=2500]
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAR="${1:?usage: submit_vincia_prod.sh <isron|isroff> [total_events] [evt_per_job]}"
TOTAL="${2:-1500000}"
PERJOB="${3:-2500}"
case "$VAR" in isron|isroff) ;; *) echo "ERROR: variant must be isron|isroff"; exit 1 ;; esac
NJOBS=$(( (TOTAL + PERJOB - 1) / PERJOB ))
mkdir -p "$REPO/condor_logs"; cd "$REPO"
echo "=== submit vincia $VAR: $TOTAL events / $PERJOB per job = $NJOBS jobs ==="
condor_submit generators/pythia8_key4hep/condor_vincia_prod.sub \
  -append "VARIANT = $VAR" -append "NEV = $PERJOB" -append "queue $NJOBS"
