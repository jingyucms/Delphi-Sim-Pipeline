#!/bin/bash
# run_generic.sh - shared production driver for the key4hep generators:
#   generate (CVMFS/key4hep) -> hepmc2fadgen -> DELSIM (.sif) -> DST.
# For: pythia8_key4hep, sherpa, herwig, whizard, kkmc.
# (Native pythia8 and kk2f have their OWN containerized pipelines:
#  generators/pythia8/run_pipeline.sh and generators/kk2f/run_kk2f_pipeline.sh.)
#
# Run on a host with BOTH CVMFS (key4hep) AND singularity (lxplus / a condor worker).
# Env isolation is automatic: each generate.sh sources key4hep in its own child process, so
# the converter and DELSIM run in this clean shell (hepmc2fadgen is rpath-self-contained;
# m2_delsim_lxplus.sh sources no key4hep) -> key4hep libs never leak into the .sif.
#
# Usage: run_generic.sh <generator> [nevents=20] [outdir=$PWD/<gen>_prod]
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${1:?usage: run_generic.sh <pythia8_key4hep|sherpa|herwig|whizard|kkmc> [nevents] [outdir]}"
NEV="${2:-20}"
OUTDIR="${3:-$PWD/${GEN}_prod}"
GENDIR="$REPO/generators/$GEN"

[ -x "$GENDIR/generate.sh" ] || { echo "ERROR: no generate.sh for '$GEN' ($GENDIR)"; exit 1; }
[ -x "$REPO/hepmc2fadgen" ] || { echo "ERROR: hepmc2fadgen not built (./build_key4hep.sh hepmc2fadgen)"; exit 1; }
mkdir -p "$OUTDIR"
echo "=== [$GEN] production: nev=$NEV outdir=$OUTDIR ==="

# 1) generate -> events.hepmc3  (each generate.sh sources key4hep in its own process)
echo "--- generate ---"
case "$GEN" in
  sherpa|herwig)    bash "$GENDIR/generate.sh" "$NEV" "$OUTDIR" ;;
  kkmc)             bash "$GENDIR/generate.sh" "$NEV" 91.187 "$OUTDIR" ;;
  pythia8_key4hep)  bash "$GENDIR/generate.sh" "$NEV" "" "$OUTDIR" ;;
  whizard)          bash "$GENDIR/generate.sh" "$OUTDIR" ;;   # n_events set in zhad.sin
  *) echo "ERROR: unknown generator '$GEN'"; exit 1 ;;
esac
[ -s "$OUTDIR/events.hepmc3" ] || { echo "ERROR: no $OUTDIR/events.hepmc3 produced"; exit 1; }

# 2) convert -> fort.26  (rpath-self-contained; NO key4hep in this shell -> keeps DELSIM clean)
echo "--- convert (hepmc2fadgen) ---"
"$REPO/hepmc2fadgen" "$OUTDIR/events.hepmc3" "$OUTDIR/fort.26"

# 3) DELSIM in the .sif -> DST  (m2_delsim_lxplus.sh sources no key4hep)
echo "--- DELSIM ---"
bash "$REPO/m2_delsim_lxplus.sh" "$OUTDIR/fort.26" "$NEV"
echo "=== [$GEN] DONE -> $OUTDIR/fort.26.sdst ==="
