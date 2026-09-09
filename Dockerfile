# PDAL runtime, built from source and published as `ghcr.io/linz/pdal-docker:<version>`.
# Built as a small image with only core PDAL libraries, Python3 and GDAL.

ARG PDAL_VERSION=2.10.2
ARG PDAL_COMMIT=27008f6241be44585c866a29dfc13bb16d678dab

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG PDAL_VERSION
ARG PDAL_COMMIT

RUN apt-get update \
    && apt-get install --assume-yes --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libcurl4-openssl-dev \
    libgdal-dev \
    libgeotiff-dev \
    libproj-dev \
    ninja-build \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Assert the commit matches the expected SHA from this tag, so a moved tag fails the build.
RUN git clone --depth 1 --branch "$PDAL_VERSION" https://github.com/PDAL/PDAL.git /usr/src/pdal
RUN test "$(git -C /usr/src/pdal rev-parse HEAD)" = "$PDAL_COMMIT"

# Ninja as used by PDAL CI
RUN cmake -S /usr/src/pdal -B /usr/src/pdal/build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local
RUN cmake --build /usr/src/pdal/build --parallel "$(nproc)"
RUN cmake --install /usr/src/pdal/build

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update \
    && apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        libgdal34t64 \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# BSD clause 2: binary redistribution must reproduce the licence.
COPY --from=builder /usr/src/pdal/LICENSE.txt /usr/share/doc/pdal/copyright
COPY --from=builder /usr/local/bin/pdal /usr/local/bin/pdal
COPY --from=builder /usr/local/lib/ /usr/local/lib/
RUN ldconfig \
    && ! ldd /usr/local/bin/pdal | grep -q 'not found' \
    && pdal --version

ARG PDAL_VERSION
ARG PDAL_COMMIT
LABEL nz.govt.linz.pdal.version="$PDAL_VERSION"
LABEL nz.govt.linz.pdal.commit="$PDAL_COMMIT"
LABEL org.opencontainers.image.source="https://github.com/linz/pdal-docker"
