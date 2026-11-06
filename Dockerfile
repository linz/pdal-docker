# GDAL and PDAL base images, with Python, from conda-forge on Ubuntu LTS.
# Published as `ghcr.io/linz/li-gdal-docker` and `ghcr.io/linz/li-pdal-docker`.
# Build one with `docker build --target gdal .` or `--target pdal`.
# Users add their Python packages to a virtual environment on the image's Python, `$CONDA_PREFIX/bin/python`.
# The README has an example.

FROM ghcr.io/prefix-dev/pixi:0.82.1@sha256:f83a5fc6d1bb9a2ced27faf2b26c04c5eb618eed22fe13eb60f9225db4817ce0 AS builder

# conda environments aren't relocatable: the images keep them at this path
WORKDIR /opt/pixi

# A known location for the package cache, which the licences are copied from below
ENV PIXI_CACHE_DIR=/var/cache/pixi

COPY pixi.toml pixi.lock ./

RUN pixi install --locked --environment gdal \
    && pixi install --locked --environment pdal

# Binary redistribution must reproduce the packages' licences (e.g. clause 2 of PDAL's BSD licence).
# Copy each installed package's licence files to licenses/<package>-<version>-<build>/ in its environment,
# and fail the build if a package has none, except for packages known not to need them:
# - GCC's runtime libraries install their runtime exception under share/licenses, the GPL-3.0 text is in
#   Ubuntu's /usr/share/common-licenses, and their `-ng` and `libgfortran` packages are empty
# - SQLite is public domain
RUN for environment in gdal pdal; do \
        for record in ".pixi/envs/${environment}"/conda-meta/*.json; do \
            package=$(basename "${record}" .json); \
            if [ -d "${PIXI_CACHE_DIR}/pkgs/${package}/info/licenses" ]; then \
                mkdir -p ".pixi/envs/${environment}/licenses/${package}" \
                && cp -R "${PIXI_CACHE_DIR}/pkgs/${package}/info/licenses/." ".pixi/envs/${environment}/licenses/${package}/" \
                || exit 1; \
            else \
                case "${package}" in \
                    libgcc-[0-9]*|libgcc-ng-[0-9]*|libgomp-[0-9]*|libstdcxx-[0-9]*|libstdcxx-ng-[0-9]*) ;; \
                    libgfortran-[0-9]*|libgfortran5-[0-9]*|libsqlite-[0-9]*|sqlite-[0-9]*) ;; \
                    *) echo "no licence files for ${package} in the ${environment} environment"; exit 1 ;; \
                esac; \
            fi; \
        done; \
    done

# Record which variables activating each environment sets, so the images can check their ENV covers them
RUN for environment in gdal pdal; do \
        pixi shell-hook --environment "${environment}" --shell bash > "/tmp/activate-${environment}.sh" \
        && env --ignore-environment bash --norc --noprofile -c ". /tmp/activate-${environment}.sh && env" \
        | cut --delimiter='=' --fields=1 \
        | grep --extended-regexp --invert-match '^(_|PWD|SHLVL|PS1|PATH|XML_CATALOG_FILES|CONDA_[A-Z_]+|PIXI_[A-Z_]+)$' \
        | sort > "activation-variables-${environment}"; \
    done

FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS ubuntu

# Ubuntu `main` fixes published since the base image was built, and Ubuntu's tzdata (also `main`):
# python-dateutil only reads time zones from /usr/share/zoneinfo, and can't read conda-forge's compact
# ("slim") tzdata files, which it silently treats as UTC
RUN apt-get update \
    && apt-get upgrade --assume-yes \
    && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends tzdata \
    && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.source="https://github.com/linz/pdal-docker"

# In the gdal and pdal stages below, the environments' activation is ENV rather than an entrypoint script,
# so it still applies when the entrypoint is overridden (Kubernetes `command:`, `docker run --entrypoint`).
# PROJ_NETWORK differs on purpose: activation turns it on because the large `proj-data` grid package
# isn't installed, but keeping it off is PROJ's default and avoids grid downloads at run time.

FROM ubuntu AS gdal

COPY --from=builder /opt/pixi/.pixi/envs/gdal /opt/pixi/.pixi/envs/gdal

ENV CONDA_PREFIX=/opt/pixi/.pixi/envs/gdal
ENV PATH="$CONDA_PREFIX/bin:$PATH" \
    CPL_ZIP_ENCODING=UTF-8 \
    GDAL_DATA="$CONDA_PREFIX/share/gdal" \
    GDAL_DRIVER_PATH="$CONDA_PREFIX/lib/gdalplugins" \
    PROJ_DATA="$CONDA_PREFIX/share/proj" \
    PROJ_NETWORK=OFF

# Fail the build if a package's activation script sets a variable the ENV above doesn't
COPY --from=builder /opt/pixi/activation-variables-gdal /tmp/activation-variables
RUN ! env | cut --delimiter='=' --fields=1 | sort | comm -23 /tmp/activation-variables - | grep . \
    && rm /tmp/activation-variables

ENTRYPOINT ["tini", "--"]

FROM ubuntu AS pdal

COPY --from=builder /opt/pixi/.pixi/envs/pdal /opt/pixi/.pixi/envs/pdal

ENV CONDA_PREFIX=/opt/pixi/.pixi/envs/pdal
ENV PATH="$CONDA_PREFIX/bin:$PATH" \
    CPL_ZIP_ENCODING=UTF-8 \
    GDAL_DATA="$CONDA_PREFIX/share/gdal" \
    GDAL_DRIVER_PATH="$CONDA_PREFIX/lib/gdalplugins" \
    PDAL_DRIVER_PATH="$CONDA_PREFIX/lib" \
    PROJ_DATA="$CONDA_PREFIX/share/proj" \
    PROJ_NETWORK=OFF

# Fail the build if a package's activation script sets a variable the ENV above doesn't
COPY --from=builder /opt/pixi/activation-variables-pdal /tmp/activation-variables
RUN ! env | cut --delimiter='=' --fields=1 | sort | comm -23 /tmp/activation-variables - | grep . \
    && rm /tmp/activation-variables

ENTRYPOINT ["tini", "--"]
