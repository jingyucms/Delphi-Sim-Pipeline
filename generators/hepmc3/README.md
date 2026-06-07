# generators/hepmc3 — read an external HepMC3 file directly

The "bring your own HepMC3" entry point. For generators we do **not** run inside key4hep
(MadGraph, PanScales, or any tool that can emit HepMC3), there is no in-pipeline
`generate.sh`: you produce the HepMC3 file with that generator elsewhere, then convert it
here and feed the fort.26 to DELSIM.

This needs no generator-specific code because `hepmc2fadgen` (repo root) is fully
generator-agnostic — it auto-detects the HepMC3 ASCII variant via HepMC3's `deduce_reader`
(Asciiv3 from Pythia8/Sherpa/Whizard/KKMC, IO_GenEvent from Herwig). The same binary that
serves the in-pipeline generators serves this path.

## Usage
```
# 1. build the converter once (from the repo root):
./build_key4hep.sh hepmc2fadgen
# 2. audit + convert any HepMC3 file to fort.26:
generators/hepmc3/read_hepmc.sh /path/to/external.hepmc fort.26
# 3. run DELSIM on lxplus:
m2_delsim_lxplus.sh fort.26
```

## What to check on an external HepMC3 file
`read_hepmc.sh` runs `hepmc3_audit.py` first; confirm:
- **beams**: status-4 beams present, or the incoming particles first (the converter places
  them as LUJETS K=21, which is what DELSIM expects);
- **V0 set** `{310,3122,3112,3222,3312,3322}` arriving **final-state** (not decayed) — else
  DELSIM loses their displaced vertices. Configure the external generator to keep them stable;
- **b-hadrons** present as decayed (status 2) so the b-decay chain is in the record.
