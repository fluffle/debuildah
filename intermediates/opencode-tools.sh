#! /bin/bash

# Create a local debian image based on sid for running opencode in.

id="$(buildah from --pull docker.io/library/debian:sid)"
buildah run --network host "$id" -- sh -c '
    apt-get update;
    apt-get -y dist-upgrade;
    apt-get -y --no-install-recommends install \
        git git-man \
        curl \
        jq \
        bash less strace \
        bsdutils bsdextrautils \
        coreutils diffutils findutils util-linux \
        grep ripgrep \
        sed mawk \
        zip unzip tar gzip bzip2 xz-utils \
        perl \
        python3 python3-pip python3-yaml \
        golang-go \
        build-essential gdb \
        nodejs node-typescript node-tslib npm \
        sqlite3 \
        mdformat \
        ;
    mkdir -p /workspace;
    chown -R nobody:nogroup /workspace;
'

# remove cmd / entrypoint from this container
buildah config --cmd "" --entrypoint "" "$id"

buildah commit --quiet --rm "$id" "opencode-tools:sid"
