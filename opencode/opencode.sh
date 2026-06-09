#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

# Create the output container image using the opencode-tools intermediate.
run_id="$(buildah from opencode-tools:sid)"
run_dir="$(buildah mount "$run_id")"

# Download and install tuicr (https://github.com/agavra/tuicr)
TUICR_VER="0.17.1"
TUICR="https://github.com/agavra/tuicr/releases/download/v${TUICR_VER}/tuicr-${TUICR_VER}-x86_64-unknown-linux-gnu.tar.gz"
wget -q -O- "${TUICR}" | tar -zxvf -
install -o root -g root -m 0755 ./tuicr "${run_dir}/usr/local/bin/tuicr" && rm ./tuicr

# Use `npm` to install bun and opencode in the container.
# This messes up version checking but ehhh.
chroot "$run_dir" \
  npm install --global bun opencode-linux-x64 \
    @opencode-ai/sdk @opencode-ai/plugin

# The opencode-linux-x64 npm doesn't add a symlink, guh.
(cd "${run_dir}/usr/local/bin"; ln -s ../lib/node_modules/opencode-linux-x64/bin/opencode)

# Note cmd flag is necessary because the debian docker images set one
# and we want to overwrite it and remove it here.
buildah config \
  --entrypoint '["/usr/local/bin/opencode"]' \
  --workingdir "/workspace" \
  --env "GOROOT=/usr/lib/go-1.26" \
  --env "GOPATH=/opt/gocode" \
  --volume "/opt/gocode" \
  --volume "/workspace" \
  --volume "/home" \
  "$run_id"

commit "$run_id" "opencode" "latest"
