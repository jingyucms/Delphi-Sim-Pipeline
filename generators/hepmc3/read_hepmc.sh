#!/bin/bash
# generators/hepmc3/read_hepmc.sh - convert ANY external HepMC3 file to FADGEN/fort.26.
#
# The "bring your own HepMC3" path for generators we do NOT run inside key4hep (MadGraph,
# PanScales, or anything that can emit HepMC3). hepmc2fadgen is fully generator-agnostic
# (auto-detects Asciiv3 and IO_GenEvent via deduce_reader), so nothing here is
# generator-specific. Audits the file first so you can see beams / V0-stability / b-chain
# before committing to a DELSIM run.
#
# Usage: read_hepmc.sh <input.hepmc> [out=fort.26] [--no-audit]
#   then on lxplus: m2_delsim_lxplus.sh <out>
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"

IN="${1:?usage: read_hepmc.sh <input.hepmc> [out=fort.26] [--no-audit]}"
OUT="${2:-fort.26}"
[ -s "$IN" ] || { echo "ERROR: input not found/empty: $IN"; exit 1; }
[ -x "$REPO/hepmc2fadgen" ] || { echo "ERROR: $REPO/hepmc2fadgen not built. Run: ./build_key4hep.sh hepmc2fadgen"; exit 1; }

# key4hep provides libHepMC3 at runtime (rpath is embedded, but source for safety on a bare host)
set +u; source "$KEY4HEP_SETUP" >/dev/null 2>&1 || true

if [[ " $* " != *" --no-audit "* ]]; then
  echo "=== audit: $IN ==="
  python3 "$REPO/hepmc3_audit.py" "$IN" || true
  echo
fi
echo "=== convert -> $OUT ==="
"$REPO/hepmc2fadgen" "$IN" "$OUT"
echo "Done. Next (on lxplus): m2_delsim_lxplus.sh $OUT"
