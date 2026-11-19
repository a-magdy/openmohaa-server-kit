# OpenMoHAA dedicated server image.
#
# Contains no game data and no OpenMoHAA binaries. At first start the
# entrypoint downloads the pinned OpenMoHAA release from GitHub, checks its
# sha256 and caches it under /data. Game data (pak*.pk3 from your own copy of
# the game) is mounted read-only at /game. Never COPY game data into an image.
FROM debian:bookworm-slim

# Pinned upstream release (https://github.com/openmoh/openmohaa/releases).
# Bump all three together; check-openmohaa-release.yml opens an issue when a
# new release is out.
ARG OPENMOHAA_VERSION=v0.82.1
ARG OPENMOHAA_SHA256_AMD64=57692d057a684afb7f7e91a61fcd8c062b29ab1b639f27453830084a88cd653c
ARG OPENMOHAA_SHA256_ARM64=7963c0e493ffff3169f42a63ec5c15382e263605e9e60abc73c82716678fb180

ENV OPENMOHAA_VERSION=${OPENMOHAA_VERSION} \
    OPENMOHAA_SHA256_AMD64=${OPENMOHAA_SHA256_AMD64} \
    OPENMOHAA_SHA256_ARM64=${OPENMOHAA_SHA256_ARM64}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 mohaa \
    && useradd --system --uid 1000 --gid mohaa --home-dir /data --shell /usr/sbin/nologin mohaa \
    && mkdir -p /game /custom /data \
    && chown mohaa:mohaa /data

COPY config/ /opt/kit/config/
COPY docker/entrypoint.sh docker/healthcheck.sh /opt/kit/bin/
RUN chmod 0755 /opt/kit/bin/*.sh

USER mohaa
WORKDIR /data
VOLUME ["/data"]

EXPOSE 12203/udp 12300/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD ["/opt/kit/bin/healthcheck.sh"]

ENTRYPOINT ["/opt/kit/bin/entrypoint.sh"]
