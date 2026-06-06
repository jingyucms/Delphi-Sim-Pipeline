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


def audit(path):
    nev = 0
    st = collections.Counter()
    beams = final = v0_final = v0_decayed = b_total = 0
    b_status = collections.Counter()
    with open(path) as fh:
        for line in fh:
            if line.startswith('E '):
                nev += 1
            elif line.startswith('P '):
                f = line.split()
                pdg = int(f[3])
                status = int(f[-1])
                st[status] += 1
                if status == 4:
                    beams += 1
                if status == 1:
                    final += 1
                if pdg in V0:
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
    print(f"  events: {nev}")
    print(f"  status histogram: {dict(sorted(st.items()))}")
    print(f"  beams (status 4): {beams}  ({'OK' if beams else 'MISSING -> converter must hoist beams'})")
    print(f"  final-state (status 1): {final}  (~{final / nev:.1f}/evt)" if nev else "")
    print(f"  V0 set: final={v0_final} decayed={v0_decayed}  ({v0_note})")
    print(f"  b-hadrons: {b_total} by status {dict(sorted(b_status.items()))}  ({b_note})")
    print()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        audit(p)
