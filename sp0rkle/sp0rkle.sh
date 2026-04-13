#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="latest"

build_srcs() {
  local id="$1"
  buildah run \
    --network host \
    --user nobody:nogroup \
    --env GOCACHE=/tmp \
    "$id" -- \
    go install "github.com/fluffle/sp0rkle@$VERSION"
}

install_files() {
  local from="$1"
  local to="$2"
  # Copy build artifacts from build container to run container.
  # Create dirs.
  install -o 65532 -g 65532 -m 0755 -d "${to}"/srv/sp0rkle/{bin,cache,db}
  # Copy binary.
  install -o 65532 -g 65532 -m 0700 "${from}/go/bin/sp0rkle" "${to}/srv/sp0rkle/bin/sp0rkle"
}

# Build sp0rkle from local sources.
build_id="$(buildah from docker.io/library/golang:trixie)"
build_srcs "$build_id"

run_id="$(from_base nonroot)"
build_dir="$(buildah mount "$build_id")"
run_dir="$(buildah mount "$run_id")"
oldpwd="$(pwd)"

# Copy build artifacts and clean up build container.
install_files "$build_dir" "$run_dir"
buildah unmount "$build_id"
buildah rm "$build_id"

# Install dependency packages etc.
pushd "$run_dir"

busybox

declare -a args=(
  "/srv/sp0rkle/bin/sp0rkle"
  "--ssl"
  "--bolt_only"
  "--boltdb"
  "/srv/sp0rkle/db/sp0rkle.boltdb"
  "--backup_dir"
  "/srv/sp0rkle/db/backup"
  "--url_cache_dir"
  "/srv/sp0rkle/cache"
)

buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --port 6666/tcp \
  --volume /srv/sp0rkle/cache \
  --volume /srv/sp0rkle/db \
  --workingdir /srv/sp0rkle \
  "$run_id"

popd
commit "$run_id" "sp0rkle" "$VERSION"
