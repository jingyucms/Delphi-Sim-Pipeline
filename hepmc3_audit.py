#!/usr/bin/env python3
"""hepmc3_audit.py - audit a HepMC3 Asciiv3 file for FADGEN/DELSIM readiness.

For each file reports: event count, status-code histogram, beam presence (status 4),
final-state count, the V0 set's status (must arrive final-state=1 to survive DELSIM -
if the generator decays them, DELSIM silently loses their displaced vertices), and
b-hadron presence + whether their decay chain is recorded (status-2 b => chain present;
status-1 b => undecayed B handed to DELSIM, which cannot decay it).

Use to check a new generator's HepMC3 conventions against what hepmc2fadgen/DELSIM expect.

Usage: hepmc3_audit.py file.hepmc3 [file2 ...]
"""
import sys
import collections

V0 = {310, 3122, 3112, 3222, 3312, 3322}
V0 |= {-p for p in list(V0)}


def is_b(pdg):
    a = abs(pdg)
    return (500 <= a < 600) or (5000 <= a < 6000)


V0_NAMES = {310: 'K0S', 3122: 'Lambda', 3112: 'Sigma-', 3222: 'Sigma+', 3312: 'Xi-', 3322: 'Xi0'}


def detect_format(path):
    """Asciiv3 (Pythia8/Sherpa) vs IO_GenEvent/HepMC2 (Herwig) - P-line fields differ."""
    with open(path) as fh:
        for _ in range(3):
            line = fh.readline()
            if 'IO_GenEvent' in line:
                return 'hepmc2'
            if 'Asciiv3' in line:
                return 'asciiv3'
    return 'asciiv3'


def audit(path):
    fmt = detect_format(path)
    # P-line: Asciiv3 = "P id vtx pdg px py pz e m status" (pdg=3, status=9);
    #         IO_GenEvent = "P barcode pdg px py pz e m status ..." (pdg=2, status=8).
    pdg_i, st_i = (2, 8) if fmt == 'hepmc2' else (3, 9)
    nev = 0
    st = collections.Counter()
    beams = final = v0_final = v0_decayed = b_total = 0
    b_status = collections.Counter()
    v0_species = collections.defaultdict(collections.Counter)  # pdg -> {status: n}
    with open(path) as fh:
        for line in fh:
            if line.startswith('E '):
                nev += 1
            elif line.startswith('P '):
                f = line.split()
                pdg = int(f[pdg_i])
                status = int(f[st_i])
                st[status] += 1
                if status == 4:
                    beams += 1
                if status == 1:
                    final += 1
                if pdg in V0:
                    v0_species[pdg][status] += 1
                    if status == 1:
                        v0_final += 1
                    elif status == 2:
                        v0_decayed += 1
                if is_b(pdg):
                    b_total += 1
                    b_status[status] += 1

    v0_note = ('OK (stable, will displace in DELSIM)' if v0_decayed == 0 and v0_final
               else 'WARN: V0s DECAYED by generator -> DELSIM loses displaced vertices' if v0_decayed
               else 'none seen in sample')
    b_note = ('chain present (decayed b = status 2)' if b_status.get(2)
              else 'WARN: b-hadrons only final-state -> DELSIM cannot decay them' if b_status.get(1)
              else 'no b-hadrons in sample (b not produced/contained?)')
    print(f"== {path} ==")
    print(f"  format: {fmt}   events: {nev}")
    print(f"  status histogram: {dict(sorted(st.items()))}")
    print(f"  beams (status 4): {beams}  ({'OK' if beams else 'MISSING -> converter must hoist beams'})")
    print(f"  final-state (status 1): {final}  (~{final / nev:.1f}/evt)" if nev else "")
    print(f"  V0 set: final={v0_final} decayed={v0_decayed}  ({v0_note})")
    for pdg in sorted(V0_NAMES):
        pos = dict(sorted(v0_species.get(pdg, {}).items()))
        neg = dict(sorted(v0_species.get(-pdg, {}).items()))
        if pos or neg:
            flag = '' if not (pos.get(2) or neg.get(2)) else '  <-- DECAYED!'
            print(f"      {V0_NAMES[pdg]:<7} ({pdg:>5}) status {pos or '-'}   anti({-pdg:>6}) {neg or '-'}{flag}")
    print(f"  b-hadrons: {b_total} by status {dict(sorted(b_status.items()))}  ({b_note})")
    print()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        audit(p)
