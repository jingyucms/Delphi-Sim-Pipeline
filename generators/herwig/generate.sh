#!/bin/bash
# generators/herwig/generate.sh - M3 subshell A (Herwig7 path): produce events.hepmc3.
# Runs Herwig 7.3 (key4hep) with LEP-DELPHI.in, normalizes the output to events.hepmc3.
# No container needed (VM or lxplus).
#
# Two key4hep-Herwig gotchas baked in:
#   - ThePEG/Herwig plugin libs are in lib/ThePEG, lib/Herwig SUBDIRS and are NOT on
#     LD_LIBRARY_PATH -> add them, else "libThePEG.so.30: cannot open shared object file".
#   - Herwig's defaults reference the CT14lo PDF set, which key4hep doesn't ship -> point
#     LHAPDF_DATA_PATH at CERN's central CVMFS set repo (+ bundled share for the index).
# NB: Herwig writes HepMC2-style "IO_GenEvent" ASCII (not Asciiv3); hepmc2fadgen handles
# both via deduce_reader.
#
# Usage: generate.sh [nevents=20] [outdir=$PWD/herwig_run]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
NEV="${1:-20}"
OUTDIR="${2:-$PWD/herwig_run}"

set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1; set -u
command -v Herwig >/dev/null || { echo "ERROR: Herwig not on PATH (key4hep not sourced?)"; exit 1; }

HWPFX="$(dirname "$(dirname "$(command -v Herwig)")")"
PLATFORM="$(dirname "$(dirname "$HWPFX")")"
TPLIB="$(dirname "$(ls "$PLATFORM"/thepeg/*/lib/ThePEG/libThePEG.so.* 2>/dev/null | head -1)")"
[ -n "$TPLIB" ] || { echo "ERROR: could not locate ThePEG lib dir"; exit 1; }
export LD_LIBRARY_PATH="$TPLIB:$HWPFX/lib/Herwig:${LD_LIBRARY_PATH:-}"
export LHAPDF_DATA_PATH="/cvmfs/sft.cern.ch/lcg/external/lhapdfsets/current:$(lhapdf-config --datadir 2>/dev/null)"

mkdir -p "$OUTDIR"; cd "$OUTDIR"
echo "$(Herwig --version 2>/dev/null | head -1)  nev=$NEV  outdir=$OUTDIR"
Herwig read "$HERE/LEP-DELPHI.in" > read.log 2>&1 || { echo "ERROR: Herwig read failed"; tail -15 read.log; exit 1; }
Herwig run LEP-DELPHI.run -N "$NEV" > run.log 2>&1 || { echo "ERROR: Herwig run failed"; tail -15 run.log; exit 1; }
if [ -s herwig_events ]; then
  cp -f herwig_events events.hepmc3
  echo "HepMC3 -> $OUTDIR/events.hepmc3 ($(stat -c%s events.hepmc3) bytes)"
else
  echo "ERROR: no herwig_events produced"; tail -15 run.log; exit 1
fi
