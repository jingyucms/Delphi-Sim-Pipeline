# DELPHI-Pythia8 pipeline image.
#
# Build CONTEXT = repo ROOT (the image bakes the shared hepmc2fadgen + run_delsim_only.sh from
# the root in addition to this folder's pythia8 sources). The CI builds it as:
#     context: .    file: generators/pythia8/Dockerfile
#
# Beyond the native pythia8 gen+DELSIM pipeline, this image now also carries HepMC3 +
# hepmc2fadgen, so the .sif can do  events.hepmc3 -> fort.26 -> DELSIM  entirely in-container
# for the key4hep generators (sherpa/herwig/whizard/...): the host only does key4hep generation.
FROM docker.io/jingyucms/delphi-pythia8:v2.4

USER root

# DELPHI environment (DELSIM lives under /delphi/releases/almalinux-9-x86_64/...).
ENV PATH="/root/.local/bin:/root/bin:/delphi/releases/almalinux-9-x86_64/latest/scripts:/delphi/scripts:/delphi/releases/almalinux-9-x86_64/latest/bin:/delphi/releases/almalinux-9-x86_64/latest/cern/pro/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:."

# Runtime libs for ROOT-from-CVMFS + build tools (gcc-c++/cmake/wget for the HepMC3 build).
RUN dnf install -y tbb xxhash-libs cmake git gcc-c++ make wget && dnf clean all

# --- HepMC3, built IN-IMAGE with the container's own gcc (AlmaLinux9) -------------------------
# This keeps the ABI consistent with the old DELPHI env - we do NOT drop the modern
# key4hep/gcc14 binary into this container. Core library only (no python/rootio/search).
ARG HEPMC3_VERSION=3.3.1
RUN cd /tmp && \
    wget -q https://gitlab.cern.ch/hepmc/HepMC3/-/archive/${HEPMC3_VERSION}/HepMC3-${HEPMC3_VERSION}.tar.gz && \
    tar xzf HepMC3-${HEPMC3_VERSION}.tar.gz && \
    cmake -S HepMC3-${HEPMC3_VERSION} -B /tmp/hepmc3-build -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DHEPMC3_ENABLE_PYTHON=OFF -DHEPMC3_ENABLE_ROOTIO=OFF \
          -DHEPMC3_ENABLE_SEARCH=OFF -DHEPMC3_BUILD_EXAMPLES=OFF -DHEPMC3_BUILD_DOCS=OFF && \
    cmake --build /tmp/hepmc3-build -j2 --target install && \
    ldconfig && rm -rf /tmp/HepMC3-${HEPMC3_VERSION}*

RUN mkdir -p /work && chmod 777 /work
WORKDIR /work

# --- pythia8 native pipeline (this folder) ---------------------------------------------------
COPY generators/pythia8/Makefile /work/
COPY generators/pythia8/pythia8_generate.cpp /work/
COPY generators/pythia8/run_pipeline.sh /work/
COPY generators/pythia8/*.txt /work/
RUN chmod +x /work/run_pipeline.sh

# --- shared converter + DELSIM-only runner (repo root) ---------------------------------------
COPY hepmc2fadgen.cpp /work/
COPY run_delsim_only.sh /work/
RUN g++ -std=c++17 -O2 /work/hepmc2fadgen.cpp -o /work/hepmc2fadgen \
        -I/usr/local/include -L/usr/local/lib -L/usr/local/lib64 \
        -Wl,-rpath,/usr/local/lib -Wl,-rpath,/usr/local/lib64 -lHepMC3 && \
    chmod +x /work/hepmc2fadgen /work/run_delsim_only.sh

RUN mkdir -p /work/output

# Pre-compile pythia8_generate.
RUN make clean && make pythia8_generate && chmod +x pythia8_generate

# Native pythia8 pipeline remains the default entrypoint; for the key4hep generators the .sif
# is exec'd directly (hepmc2fadgen / run_delsim_only.sh) by run_generic.sh / m2_delsim_lxplus.sh.
ENTRYPOINT ["/work/run_pipeline.sh"]
CMD ["50"]
