#!/bin/bash
# run_generic_condor.sh - condor entry for the key4hep generic path (sherpa/herwig/whizard/
# pythia8_key4hep/kkmc). Transferred to the worker as the job executable; it execs the shared
# run_generic.sh from its AFS-absolute path so run_generic.sh's REPO resolves to the AFS clone
# (readable via the forwarded Kerberos/AFS credential - MY.SendCredential=true in the .sub).
#
# Heavy generator + DELSIM I/O runs in worker-LOCAL scratch (_CONDOR_SCRATCH_DIR); only the
# final DST is copied to EOS. (run_generic.sh writes ALL intermediates - Sherpa Process dirs,
# events.hepmc3, fort.26 - into its outdir, so pointing that at EOS would hammer EOS-fuse.)
#
# Args:  <generator> <nevents> <eos_dest_dir>
set -uo pipefail
REPO=/afs/cern.ch/work/z/zhangj/delphi-pythia8-pipeline
GEN="${1:?usage: run_generic_condor.sh <generator> <nevents> <eos_dest_dir>}"
NEV="${2:?nevents}"
EOSDEST="${3:?eos_dest_dir}"

WORK="${_CONDOR_SCRATCH_DIR:-/tmp/$$}/genwork"
mkdir -p "$WORK" "$EOSDEST"
echo "=== run_generic_condor: GEN=$GEN NEV=$NEV host=$(hostname) WORK=$WORK EOSDEST=$EOSDEST ==="
[ -r "$REPO/run_generic.sh" ] || { echo "FATAL: cannot read $REPO/run_generic.sh (no AFS token?)"; exit 3; }

bash "$REPO/run_generic.sh" "$GEN" "$NEV" "$WORK"
rc=$?
echo "run_generic.sh rc=$rc"

DST="$WORK/fort.26.sdst"
if [ -s "$DST" ]; then
  OUT="$EOSDEST/${GEN}.sdst"
  cp -f "$DST" "$OUT" && echo "DST -> $OUT ($(stat -c%s "$OUT") bytes)"
else
  echo "ERROR: no DST produced at $DST"; rc=1
fi
exit $rc
