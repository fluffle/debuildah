#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="v1.14.40"
SHASUM="d5314507b964bc98b52c8117a0b9d2cb0190eae04fb334bf5448762a5042968d"
TAR="opencode-linux-x64.tar.gz"
URL="https://github.com/anomalyco/opencode/releases/download/${VERSION}/${TAR}"

shasum_check() {
  echo "${SHASUM}  ${TAR}" | sha256sum --status --check -
}

# Opencode downloaded separately from github so we add this manually...
echo "opencode=${VERSION}" > opencode.versions
check_versions opencode || exit 0

if [ ! -f "${TAR}" ] || ! shasum_check; then
  wget -O "${TAR}" "${URL}"
  if ! shasum_check; then
    echo "${TAR}: checksum mismatch"
    exit 1
  fi
fi

# Create the output container image using the opencode-tools intermediate.
run_id="$(buildah from opencode-tools:sid)"
run_dir="$(buildah mount "$run_id")"

# Extract the downloaded .tar.gz to the mounted container.
tar -zxf "$TAR" -C "${run_dir}/usr/bin"

# Note cmd flag is necessary because the debian docker images set one
# and we want to overwrite it and remove it here.
buildah config \
  --entrypoint '["/usr/bin/opencode"]' \
  --workingdir "/workspace" \
  --env "GOROOT=/usr/lib/go-1.26" \
  --env "GOPATH=/opt/gocode" \
  --volume "/opt/gocode" \
  --volume "/workspace" \
  --volume "/home" \
  "$run_id"

commit "$run_id" "opencode" "$VERSION"
