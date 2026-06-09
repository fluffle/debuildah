#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="$(cd /home/alex/git/sp0rkle; git rev-parse --short=8 HEAD)"

# sp0rkle doesn't have external deps
echo "sp0rkle=dev-${VERSION}" > sp0rkle.versions
check_versions sp0rkle || exit 0

build_srcs() {
  local id="$1"
  # The git repo needs to be owned by the same user executing the build
  # otherwise go exits with the error:
  #   error obtaining VCS status: exit status 128
  #       Use -buildvcs=false to disable VCS stamping.
  # See https://github.com/golang/go/issues/53532.
  # See https://groups.google.com/g/golang-nuts/c/LZbM2WlZoJM.
  #
  # We want to build from the local src fork which is owned by me. When
  # this is mounted inside the container during `buildah unshare`, it
  # shows up as being owned by root because unshare creates a new uid
  # namespace mapping my uid to root. So we end up building as "root",
  # but the volume is mounted ro so it's probably fine...
  buildah run \
    --network host \
    --env GOCACHE=/tmp \
    --volume /home/alex/git/sp0rkle:/src:ro \
    --workingdir /src \
    "$id" -- \
    go install .
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
build_id="$(buildah from --pull=newer docker.io/library/golang:trixie)"
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
