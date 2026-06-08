#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="b9549"
SHASUM="015a0971716d42d53ceac3e00101fc4c581580f6cdff5fe679ff82fefeba7e4c"
TAR="${VERSION}.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAR}"

# Library deps of compiled llama-server binary
declare -a deps=( "libstdc++6" "libgcc-s1" )
declare -a pkgs=( $(libs_recurse "${deps[@]}" | filter_base_deps) )

write_versions llama "${pkgs[@]}"
# There's no llama-server package so we add this manually...
echo "llama=${VERSION}" >> llama.versions
check_versions llama || exit 0

if [ ! -f "${TAR}" ] || ! sha256_check "${TAR}" "${SHASUM}"; then
  wget -O "${TAR}" "${URL}"
  if ! sha256_check "${TAR}" "${SHASUM}"; then
    echo "${TAR}: checksum mismatch"
    exit 1
  fi
fi

copy_srcs() {
  local id="$1"
  # Copy build script and extract source tarball into build container's /build dir.
  build_dir="$(buildah mount "$id")"
  tar -C "${build_dir}/build" -zxvf "${TAR}"
  chown -R nobody:nogroup "${build_dir}/build/llama.cpp-${VERSION}"
  install -o nobody -g nogroup -m 0755 -t "${build_dir}/build" compile.sh
  buildah unmount "$id"
}

build_srcs() {
  local id="$1"
  # Run build script inside build container, without networking.
  buildah run \
    --network none \
    --workingdir /build \
    --user nobody:nogroup \
    --env VERSION="${VERSION}" \
    "$id" -- /build/compile.sh
}

install_files() {
  local from="$1"
  local to="$2"
  # Copy build artifacts from build container to run container.
  # Create dirs.
  install -o 65532 -g 65532 -m 0755 -d "${to}"/models
  # Copy binaries.
  install -o 65532 -g 65532 -m 0700 "${from}/build/llama.cpp-${VERSION}/build/bin/llama-server" "${to}/usr/bin/llama-server"
}

# Build llama.cpp
build_id="$(buildah from debian-build:trixie)"
copy_srcs "$build_id"
build_srcs "$build_id"

# Create the output container image.
run_id="$(from_base nonroot)"
build_dir="$(buildah mount "$build_id")"
run_dir="$(buildah mount "$run_id")"

# Copy build artifacts and clean up build container.
install_files "$build_dir" "$run_dir"
buildah unmount "$build_id"
buildah rm "$build_id"

# Install dependency packages etc.
pushd "$run_dir"

busybox

install_pkgs "${pkgs[@]}"

buildah config \
  --entrypoint "$( entrypoint "/usr/bin/llama-server" )" \
  --port 8080/tcp \
  --volume /models \
  --workingdir /models \
  "$run_id"

popd
commit "$run_id" "llama" "$VERSION"
