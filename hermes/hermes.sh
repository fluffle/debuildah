#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

# Create the output container image using the opencode-tools intermediate.
run_id="$(buildah from opencode-tools:sid)"
run_dir="$(buildah mount "$run_id")"

# Use lightly-edited hermes install script to install.
# vanilla script tries to use `uv` to install an old Python then
# complains that the place it's installed Python to is not in $PATH
# ... like, duh, don't do dumb shit plz
install -m 0755 install.sh "${run_dir}/tmp/install.sh"
chroot "$run_dir" /tmp/install.sh --skip-browser --skip-setup --no-venv
rm "${run_dir}/tmp/install.sh"

# Note cmd flag is necessary because the debian docker images set one
# and we want to overwrite it and remove it here.
buildah config \
  --entrypoint '["/usr/local/bin/hermes"]' \
  --workingdir "/workspace" \
  --env "GOROOT=/usr/lib/go-1.26" \
  --env "GOPATH=/opt/gocode" \
  --volume "/opt/gocode" \
  --volume "/workspace" \
  --volume "/home" \
  "$run_id"

commit "$run_id" "hermes" "latest"
