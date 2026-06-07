#!/bin/bash
# Submit the Sherpa Z->hadrons production for one ISR variant to HTCondor. Run from lxplus.
# Each job: gen (Sherpa, per-job seed) -> hepmc2fadgen -> DELSIM -> copies HepMC3 + SDST to EOS.
# Usage: submit_sherpa_prod.sh <isroff|isrin> [total_events=1500000] [evt_per_job=2500]
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAR="${1:?usage: submit_sherpa_prod.sh <isroff|isrin> [total_events] [evt_per_job]}"
TOTAL="${2:-1500000}"
PERJOB="${3:-2500}"
case "$VAR" in isroff|isrin) ;; *) echo "ERROR: variant must be isroff|isrin"; exit 1 ;; esac
NJOBS=$(( (TOTAL + PERJOB - 1) / PERJOB ))
mkdir -p "$REPO/condor_logs"; cd "$REPO"
echo "=== submit sherpa $VAR: $TOTAL events / $PERJOB per job = $NJOBS jobs (= $((NJOBS*PERJOB)) generated) ==="
condor_submit generators/sherpa/condor_sherpa_prod.sub \
  -append "VARIANT = $VAR" -append "NEV = $PERJOB" -append "queue $NJOBS"
