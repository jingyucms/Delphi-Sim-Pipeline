#!/bin/bash
# generators/herwig/submit.sh - submit herwig production to HTCondor via the shared condor_generic.sub.
# Each job runs run_generic.sh herwig <nevents> = generate -> hepmc2fadgen -> DELSIM, on a worker
# with CVMFS (key4hep) + apptainer/singularity. Run from lxplus (needs condor + a Kerberos ticket).
# UNTESTED scaffold - validate one submission before scaling.
# Usage: submit.sh [nevents=1000] [njobs=10]
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NEV="${1:-1000}"; NJOBS="${2:-10}"
mkdir -p "$REPO/condor_logs"; cd "$REPO"
condor_submit condor_generic.sub -append "GEN = herwig" -append "NEV = $NEV" -append "queue $NJOBS"
