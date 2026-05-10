# Local container runs via CVMFS (cmssw/el9 + singularity)

This directory provides a CVMFS-backed path for running the Pythia → DELSIM
pipeline **locally** (no CERN lxplus, no Condor, no Jingyu's private image).
It uses the community `cmssw/el9:x86_64` base image, mounts CVMFS
(`delphi.cern.ch`, `sft.cern.ch`) at runtime, and gets the DELPHI release + LCG
Pythia from there.

## Prerequisites on the host

- `singularity-ce` 3.8+ (or `apptainer`) with rootless mode working
- `/cvmfs/delphi.cern.ch/` and `/cvmfs/sft.cern.ch/` reachable (autofs + cvmfs)
- AlmaLinux 9 host with the package set for X11/Motif/libgfortran installed —
  these get bind-mounted into the container because the `cmssw/el9` image does
  not ship `libgfortran-5`, `libXm`, `libXp`, etc. On AlmaLinux 9 they are in
  the `motif` + `libgfortran` + `compat-libgfortran-48` packages.
- Nothing DELPHI-specific has to be installed on the host.

## Quickstart

```sh
cd container/
./run_singularity.sh 200 smoketest /tmp/out ../config_z_tautau.txt
# -> writes /tmp/out/simana_smoketest.sdst (~660 kB for N=100 Z->tautau events)
```

The first run pulls `docker://cmssw/el9:x86_64` into `~/.cache/singularity-delphi/`
(~930 MB, ~1 min). Subsequent runs reuse the cached `.sif`.

Override the cache location by setting `IMAGE_DIR` in the environment before
calling the script.

## What the wrapper does

1. **Pull the base image** once.
2. **Bind `/cvmfs` read-only** — gives the container access to both the DELPHI
   release (`/cvmfs/delphi.cern.ch/releases/almalinux-9-x86_64/latest`) and
   LCG_109 (`/cvmfs/sft.cern.ch/lcg/views/LCG_109/x86_64-el9-gcc13-opt`).
3. **Bind `/lib64` at `/host_lib64`** (read-only) and prepend it to
   `LD_LIBRARY_PATH` *inside* the container so the DELSIM Fortran binaries can
   find the libs the cmssw image doesn't ship. Container's own `/lib64`
   (glibc, linker) is not touched.
4. **Stage 1**: source `LCG_109` and compile `pythia8_generate` from the
   repo's C++ source against LCG Pythia 8.317.
5. **Stage 2**: generate N events with `pythia8_generate <N> config.txt`.
   The log line `Event <i> ACCEPTED: ... N FSR-γ from ℓ` confirms the
   feature/fsr-photons changes are active.
6. **Stage 3**: source `/cvmfs/delphi.cern.ch/setup.sh`, override
   `DELPHI_DDB` and `DELPHI_DATA_ROOT` to point at CVMFS instead of the
   CERN-only `/eos/opendata/delphi` (the condition-data tree is mirrored onto
   CVMFS), then run `runsim -VERSION v94c -LABO CERN ...` exactly as the lxplus
   pipeline does.
7. Move the resulting `simana.sdst` into the requested output dir and tag it
   with the job id.

## Why not a purpose-built Dockerfile?

Could bake the host libs into a derived image, but (a) keeps the image fat, (b)
ties the user to a specific AlmaLinux 9 lib set, (c) loses the "runs against
today's CVMFS" benefit. The bind-mount pattern is what CI systems (GitLab CI
with Docker-in-Docker or `cvmfs-csi`) already use. If preservation requires a
fully self-contained artifact, a `Dockerfile.el9cvmfs` installing `motif`,
`libgfortran` and related rpm packages via `dnf` before `ENTRYPOINT` is a
two-line diff from this wrapper — not implemented here because it wasn't the
current need.

## Comparison with the main `run_pipeline.sh`

| aspect | `run_pipeline.sh` (lxplus) | `container/run_singularity.sh` (local) |
|---|---|---|
| base image | `docker.io/jingyucms/delphi-pythia8:v2.6` | `docker.io/cmssw/el9:x86_64` |
| runtime | Docker universe in HTCondor | singularity/apptainer |
| DELPHI release | baked into image | CVMFS at runtime |
| Pythia 8 | baked into image (≤ 8.306ish) | LCG_109 → 8.317 |
| condition data | `/eos/opendata/delphi` | `/cvmfs/delphi.cern.ch/condition-data` |
| needs CERN network | yes (EOS) | no |
| needs root / admin | no | no |

Both produce the same `.sdst` output format, so downstream `delphi-nanoaod`
processing is agnostic to which path was used.
