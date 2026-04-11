# DELPHI-Pythia8 Pipeline Docker Image
# Use your existing working image instead of pulling fresh
FROM docker.io/jingyucms/delphi-pythia8:v2.4

# Already has Pythia 8 installed, so skip the installation
# Switch to root (probably already root in your image)
USER root

# Set up DELPHI environment variables based on what we found
ENV PATH="/root/.local/bin:/root/bin:/delphi/releases/almalinux-9-x86_64/latest/scripts:/delphi/scripts:/delphi/releases/almalinux-9-x86_64/latest/bin:/delphi/releases/almalinux-9-x86_64/latest/cern/pro/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:."

# Install runtime libraries required to link/run ROOT 6.34.04 from CVMFS:
#   tbb       – provides libtbb.so.2 (Intel TBB, used by libImt.so)
#   xxhash-libs – provides libxxhash.so.0 (used by libCore.so / libROOTNTuple.so)
#   cmake / git – needed to clone and build delphi-nanoaod inside the container at CI time
RUN dnf install -y tbb xxhash-libs cmake git && dnf clean all

# Create work directory (replaces your mounted /work)
RUN mkdir -p /work
WORKDIR /work

RUN chmod 777 /work
RUN chown -R root:root /work

# Copy your existing pipeline files
COPY Makefile /work/
COPY pythia8_generate.cpp /work/
COPY run_pipeline.sh /work/
COPY *.txt /work/

# Set executable permissions
RUN chmod +x /work/run_pipeline.sh

# Create output directory for results
RUN mkdir -p /work/output

# Stay as root (like in your current workflow)
# No user switch needed

# Pre-compile pythia8
RUN make clean && make pythia8_generate && chmod +x pythia8_generate

# Set entrypoint to run the pipeline
ENTRYPOINT ["/work/run_pipeline.sh"]

# Default: generate 50 events
CMD ["50"]