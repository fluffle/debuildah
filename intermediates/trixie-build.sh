#! /bin/bash

# Create a local debian image suitable for building a source .tar.gz.
# Do all builds as nobody:nogroup.

id="$(buildah from --pull docker.io/library/debian:trixie)"
buildah run --env "DEBIAN_FRONTEND=noninteractive" --network host "$id" -- sh -c '
    apt-get update;
    apt-get dist-upgrade;
    apt-get -y --no-install-recommends install \
        build-essential \
        pkg-config \
        gdb;
    mkdir -p /build/out;
    chown -R nobody:nogroup /build;
'

buildah commit --quiet --rm "$id" "debian-build:trixie"
