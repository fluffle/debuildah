#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="v1.14.28"
SHASUM="af0cb3dd1e84a68f95f475c3e876820fe55f45862591de459841388b2920af57"
DEB="opencode-desktop-linux-amd64.deb"
URL="https://github.com/anomalyco/opencode/releases/download/${VERSION}/${DEB}"

shasum_check() {
  echo "${SHASUM}  ${DEB}" | sha256sum --status --check -
}

# Opencode downloaded separately from github so we add this manually...
echo "opencode=${VERSION}" > opencode.versions
check_versions opencode || exit 0

if [ ! -f "${DEB}" ] || ! shasum_check; then
  wget -O "${DEB}" "${URL}"
  if ! shasum_check; then
    echo "${DEB}: checksum mismatch"
    exit 1
  fi
fi

# Create the output container image using the opencode-tools intermediate.
run_id="$(buildah from opencode-tools:sid)"
run_dir="$(buildah mount "$run_id")"

# Extract the downloaded .deb to the mounted container.
dpkg-deb -x "$DEB" "$run_dir"
# Delete the GUI binary that we won't use
rm "${run_dir}/usr/bin/OpenCode"

# Note cmd flag is necessary because the debian docker images set one
# and we want to overwrite it and remove it here.
buildah config \
  --entrypoint '["/usr/bin/opencode-cli"]' \
  --workingdir "/workspace" \
  --env "GOROOT=/usr/lib/go-1.26" \
  --env "GOPATH=/opt/gocode" \
  --volume "/opt/gocode" \
  --volume "/workspace" \
  --volume "/home" \
  "$run_id"

commit "$run_id" "opencode" "$VERSION"
