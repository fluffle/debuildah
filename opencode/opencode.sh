#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

# Create the output container image using the opencode-tools intermediate.
run_id="$(buildah from opencode-tools:sid)"
run_dir="$(buildah mount "$run_id")"

# Use `npm` to install bun and opencode in the container.
# This messes up version checking but ehhh.
chroot "$run_dir" \
  npm install --global bun opencode-ai

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
