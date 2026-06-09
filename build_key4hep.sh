#!/bin/bash
# build_key4hep.sh — build the HepMC3/FADGEN pipeline tools against key4hep's Pythia8 + HepMC3.
#
# Proven against key4hep 2026-04-08 (Pythia8 8.315, HepMC3 3.3.1, gcc14.2/almalinux9).
# Runs on the bare VM or on lxplus — key4hep is self-contained on CVMFS, no container needed.
# This is "subshell A": generator + converter. The DELSIM step (subshell B) runs separately
# inside the .sif and must NOT share this shell (see m2_delsim_lxplus.sh).
#
# Gotchas baked in (all real, all hit during M2 bring-up):
#   - source key4hep DIRECTLY — never `source ... | tail`; the pipe runs source in a
#     subshell and the environment changes are lost.
#   - HepMC3 headers are exposed on ROOT_INCLUDE_PATH, NOT CPLUS_INCLUDE_PATH/CPATH, so g++
#     won't auto-find them -> we locate the include dir and pass -I explicitly.
#   - HepMC3 3.3 bumped its soname to libHepMC3.so.4 (3.2.x was .so.3) AND key4hep does not
#     add the HepMC3 libdir to LD_LIBRARY_PATH -> embed it with -Wl,-rpath so the binaries are
#     self-contained at runtime (the .so lives in lib64).
#
# Usage: ./build_key4hep.sh [target ...]
#        targets: hepmc2fadgen closure_gen pythia8_generate photon_diag  (default: all)
set -uo pipefail

KEY4HEP_SETUP="${KEY4HEP_SETUP:-/cvmfs/sw.hsf.org/key4hep/setup.sh}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

echo "=== sourcing key4hep: $KEY4HEP_SETUP ==="
# key4hep's setup.sh expands unset variables, so disable nounset across the source
# (otherwise the shell exits the moment it hits one).
set +u
# shellcheck disable=SC1090
source "$KEY4HEP_SETUP" >/dev/null 2>&1
set -u
command -v pythia8-config >/dev/null || { echo "ERROR: key4hep not on PATH (pythia8-config missing)"; exit 1; }
echo "g++:     $(g++ --version | head -1)"
echo "Pythia8: $(pythia8-config --version)"

# Locate HepMC3 include dir (header is on ROOT_INCLUDE_PATH under key4hep).
HINC=""
for d in $(echo "${ROOT_INCLUDE_PATH:-}:${CPLUS_INCLUDE_PATH:-}:${CPATH:-}" | tr ':' '\n' | awk 'NF'); do
  [ -f "$d/HepMC3/GenEvent.h" ] && { HINC="$d"; break; }
done
[ -n "$HINC" ] || { echo "ERROR: HepMC3/GenEvent.h not found on include paths"; exit 1; }
HPFX="$(dirname "$HINC")"
HLIB=""
for L in "$HPFX/lib64" "$HPFX/lib"; do
  [ -e "$L/libHepMC3.so" ] && { HLIB="$L"; break; }
done
[ -n "$HLIB" ] || { echo "ERROR: libHepMC3.so not found under $HPFX"; exit 1; }
echo "HepMC3:  inc=$HINC"
echo "         lib=$HLIB"
echo

CXX="g++ -std=c++17 -O2"
PYFLAGS="$(pythia8-config --cxxflags --libs)"
HEPFLAGS="-I$HINC -L$HLIB -Wl,-rpath,$HLIB -lHepMC3"

# Optional EvtGen for closure_gen — enable with USE_EVTGEN=1. Links the key4hep
# view's own EvtGen 02.02.03 (no Pythia version bump, no .sif rebuild). $EVTGEN
# points at .../share, so headers/libs live in its package root (parent dir).
EVTGENFLAGS=""
if [ "${USE_EVTGEN:-0}" = "1" ]; then
  EVTROOT="$(dirname "${EVTGEN:?USE_EVTGEN=1 but \$EVTGEN unset — source key4hep first}")"
  EVTGENFLAGS="-DUSE_EVTGEN -I$EVTROOT/include -L$EVTROOT/lib64 -Wl,-rpath,$EVTROOT/lib64 -lEvtGen -lEvtGenExternal"
  echo "EvtGen:  ON ($EVTROOT)"
fi

build() {           # build <src> <out> <flags...>   (out may be a path; binary built next to source)
  local src="$1" out="$2"; shift 2
  local tag; tag="$(basename "$out")"
  printf '%-18s ' "$tag"
  if $CXX "$src" -o "$out" "$@" 2>"/tmp/build_${tag}.err"; then
    echo "OK ($(stat -c%s "$out") bytes)"
  else
    echo "FAILED -> /tmp/build_${tag}.err"; sed 's/^/    /' "/tmp/build_${tag}.err" | head -20; return 1
  fi
}

TARGETS=("$@"); [ ${#TARGETS[@]} -eq 0 ] && TARGETS=(hepmc2fadgen closure_gen pythia8_generate photon_diag)
rc=0
for t in "${TARGETS[@]}"; do
  case "$t" in
    # hepmc2fadgen is the shared converter -> stays at repo root. The generator sources moved
    # into generators/<gen>/ during the reorg; each binary is built next to its source.
    hepmc2fadgen)     build hepmc2fadgen.cpp hepmc2fadgen $HEPFLAGS || rc=1 ;;                   # HepMC3-only (generator-agnostic)
    closure_gen)      build generators/pythia8_key4hep/closure_gen.cpp generators/pythia8_key4hep/closure_gen $PYFLAGS $HEPFLAGS -lz $EVTGENFLAGS || rc=1 ;;
    pythia8_generate) build generators/pythia8/pythia8_generate.cpp generators/pythia8/pythia8_generate $PYFLAGS || rc=1 ;;  # native EventWriter path
    photon_diag)      build generators/pythia8/photon_diag.cpp generators/pythia8/photon_diag $PYFLAGS || rc=1 ;;
    *) echo "unknown target: $t"; rc=1 ;;
  esac
done
exit $rc
