#! /bin/bash

# Create a local debian image suitable for building a source .tar.gz.
# Do all builds as nobody:nogroup.

id="$(buildah from --pull=newer docker.io/library/debian:trixie)"
buildah run --env "DEBIAN_FRONTEND=noninteractive" --network host "$id" -- sh -c '
    apt-get update;
    apt-get -y dist-upgrade;
    apt-get -y --no-install-recommends install \
        build-essential \
        gcc-14 g++-14 \
        libssl-dev \
        pkg-config \
        gdb \
        git \
        cmake \
    ;
    mkdir -p /build/out;
    chown -R nobody:nogroup /build;
    apt-get -y clean;
'

buildah commit --quiet --rm "$id" "debian-build:trixie"
