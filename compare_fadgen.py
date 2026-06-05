#!/usr/bin/env python3
"""
compare_fadgen.py — closure comparator for the fort.26 (FADGEN/LUJETS) records.

Compares two fort.26 files event-by-event for PHYSICS-equivalence (not byte
identity): the EventWriter reference (fort.26 from the direct Pythia path) vs
the hepmc2fadgen output (Pythia -> HepMC3 -> fort.26).

Particles are matched by (pdg, px, py, pz, E) rounded to a tolerance, since the
two paths may order particles differently. We check:
  * event-count agreement
  * final-state (K1 in {1,4}) multiset agreement, per event  <- what DELSIM tracks
  * full valid-particle multiset agreement
  * PARENTAGE tree agreement: each particle keyed with its mother's pdg (via
    K[2]) — DELSIM rebuilds the decay tree from K(I,3), so this is the
    b-tagging-truth-relevant check the earlier version was missing
  * status-code disagreements on matched particles (benign 2-vs-21 expected)

PASS requires: equal event count AND every event's final-state set identical
AND every event's parentage multiset identical.

Usage: compare_fadgen.py fort26_A fort26_B [--tol 1e-3]
"""
import struct
import sys
from collections import Counter


def read_fadgen(path):
    """Return list of events; each event is a list of (K(5), P(5), V(5))."""
    with open(path, "rb") as fh:
        data = fh.read()
    events, off, nbytes = [], 0, len(data)
    while off + 8 <= nbytes:
        rec = struct.unpack_from("<i", data, off)[0]; off += 4
        n = struct.unpack_from("<i", data, off)[0]; off += 4
        if n == 0:  # end marker (rec=4, n=0, rec=4)
            break
        parts = []
        for _ in range(n):
            K = struct.unpack_from("<5i", data, off); off += 20
            P = struct.unpack_from("<5f", data, off); off += 20
            V = struct.unpack_from("<5f", data, off); off += 20
            parts.append((K, P, V))
        off += 4  # trailing record_size
        if rec != 4 + n * 60:
            print(f"  WARN: record_size {rec} != expected {4 + n*60} (event {len(events)+1})")
        events.append(parts)
    return events


def key(part, tol):
    K, P, _ = part
    q = 1.0 / tol
    return (K[1], round(P[0] * q), round(P[1] * q), round(P[2] * q), round(P[3] * q))


def mother_pdg(ev, part):
    """PDG of the particle pointed to by K[2] (1-based), 0 if none/out of range."""
    m = part[0][2]
    if 1 <= m <= len(ev):
        return ev[m - 1][0][1]
    return 0


def parent_key(ev, part, tol):
    return key(part, tol) + (mother_pdg(ev, part),)


def is_final(part):
    return part[0][0] in (1, 4)


def is_b_hadron(pdg):
    n = abs(pdg)
    return (500 <= n < 600) or (5000 <= n < 6000)  # b mesons / b baryons


def from_b(ev, part):
    """Walk the K[2] mother chain; return |pdg| of nearest b-hadron ancestor, else 0.
    This is the b-tagging truth a downstream tagger derives from the gen tree."""
    p = part
    for _ in range(400):
        m = p[0][2]
        if not (1 <= m <= len(ev)):
            return 0
        mp = ev[m - 1]
        if is_b_hadron(mp[0][1]):
            return abs(mp[0][1])
        p = mp
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    a_path, b_path = sys.argv[1], sys.argv[2]
    tol = 1e-3
    if "--tol" in sys.argv:
        tol = float(sys.argv[sys.argv.index("--tol") + 1])

    A = read_fadgen(a_path)
    B = read_fadgen(b_path)
    print(f"events: A={len(A)}  B={len(B)}")
    if len(A) != len(B):
        print("  !! event count mismatch — alignment is by index, results below may be off")
    nev = min(len(A), len(B))

    tot_fin_a = tot_fin_b = tot_fin_match = 0
    tot_tree_a = tot_tree_match = 0
    tot_finpar_a = tot_finpar_match = 0
    perfect_final = perfect_tree = 0
    diverge_pdg = Counter()
    tot_btruth_a = tot_btruth_match = nfromb_a = nfromb_b = 0
    status_disagree = Counter()
    status_disagree_pdg = {}

    for i in range(nev):
        ea, eb = A[i], B[i]
        # final-state multiset
        fa = Counter(key(p, tol) for p in ea if is_final(p))
        fb = Counter(key(p, tol) for p in eb if is_final(p))
        tot_fin_a += sum(fa.values()); tot_fin_b += sum(fb.values())
        tot_fin_match += sum((fa & fb).values())
        if fa == fb:
            perfect_final += 1
        # parentage (tree) multiset — particle keyed with its mother's pdg
        pa = Counter(parent_key(ea, p, tol) for p in ea)
        pb = Counter(parent_key(eb, p, tol) for p in eb)
        tot_tree_a += sum(pa.values()); tot_tree_match += sum((pa & pb).values())
        if pa == pb:
            perfect_tree += 1
        # final-state parentage (the b-tagging-relevant subset) + divergence breakdown
        fpa = Counter(parent_key(ea, p, tol) for p in ea if is_final(p))
        fpb = Counter(parent_key(eb, p, tol) for p in eb if is_final(p))
        tot_finpar_a += sum(fpa.values())
        tot_finpar_match += sum((fpa & fpb).values())
        for kk, c in (pa - pb).items():
            diverge_pdg[kk[0]] += c
        # b-tagging truth: final particle keyed with its nearest b-hadron ancestor
        ba = Counter((key(p, tol), from_b(ea, p)) for p in ea if is_final(p))
        bb = Counter((key(p, tol), from_b(eb, p)) for p in eb if is_final(p))
        tot_btruth_a += sum(ba.values())
        tot_btruth_match += sum((ba & bb).values())
        nfromb_a += sum(1 for p in ea if is_final(p) and from_b(ea, p))
        nfromb_b += sum(1 for p in eb if is_final(p) and from_b(eb, p))
        # status disagreement on matched particles
        amap = {}
        for p in ea:
            amap.setdefault(key(p, tol), []).append(p[0][0])
        for p in eb:
            k = key(p, tol)
            if k in amap and amap[k]:
                sa = amap[k].pop()
                sb = p[0][0]
                if sa != sb:
                    status_disagree[(sa, sb)] += 1
                    status_disagree_pdg.setdefault((sa, sb), Counter())[k[0]] += 1

    print(f"\nfinal-state (K1 in 1,4):  A={tot_fin_a} B={tot_fin_b} matched={tot_fin_match}"
          f"  ({100*tot_fin_match/max(tot_fin_a,1):.2f}% of A)")
    print(f"  events with identical final-state set: {perfect_final}/{nev}")
    print(f"parentage tree:  matched={tot_tree_match}/{tot_tree_a}"
          f"  ({100*tot_tree_match/max(tot_tree_a,1):.2f}%)")
    print(f"  events with identical parentage set:   {perfect_tree}/{nev}")
    print(f"final-state parentage (b-tag relevant): matched={tot_finpar_match}/{tot_finpar_a}"
          f"  ({100*tot_finpar_match/max(tot_finpar_a,1):.2f}%)")
    if diverge_pdg:
        print(f"  diverging-parentage particles by pdg: {diverge_pdg.most_common(14)}")
    print(f"b-tagging truth (final particle -> nearest b-ancestor):"
          f" matched={tot_btruth_match}/{tot_btruth_a}"
          f"  ({100*tot_btruth_match/max(tot_btruth_a,1):.2f}%)")
    print(f"  final particles tagged from-b:  A={nfromb_a}  B={nfromb_b}")
    if status_disagree:
        print("\nstatus disagreements on matched particles (A->B): count")
        for (sa, sb), c in sorted(status_disagree.items(), key=lambda kv: -kv[1]):
            print(f"  {sa} -> {sb}: {c}   top pdg: {status_disagree_pdg[(sa,sb)].most_common(8)}")

    ok = (len(A) == len(B) and perfect_final == nev and perfect_tree == nev
          and tot_fin_match == tot_fin_a == tot_fin_b)
    print(f"\nCLOSURE: {'PASS' if ok else 'DIFFERENCES — inspect above'}"
          f"  (final-state {perfect_final}/{nev}, tree {perfect_tree}/{nev})")


if __name__ == "__main__":
    main()
