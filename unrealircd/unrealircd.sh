#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="6.2.4"
SHASUM="3e3ea1edd0ade91cd49ef1a4aed479f82dfa722b7dffb9ebd5e54d2baee84b19"
TAR="unrealircd-${VERSION}.tar.gz"
URL="https://www.unrealircd.org/downloads/${TAR}"

shasum_check() {
  echo "${SHASUM}  ${TAR}" | sha256sum --status --check -
}

# Library deps of compiled unrealircd binary
declare -a deps=(
  "libcrypt1"
  "libpcre2-8-0"
  "libargon2-1"
  "libcares2"
  "libsodium23"
  "libjansson4"
)
declare -a pkgs=( $(libs_recurse "${deps[@]}" | filter_base_deps) )

write_versions unrealircd "${pkgs[@]}"
# There's no unrealircd package so we add this manually...
echo "unrealircd=${VERSION}" >> unrealircd.versions
check_versions unrealircd || exit 0

if [ ! -f "${TAR}" ] || ! shasum_check; then
  wget -O "${TAR}" "${URL}"
  if ! shasum_check; then
    echo "${TAR}: checksum mismatch"
    exit 1
  fi
fi

copy_srcs() {
  local id="$1"
  # Copy build script and source tarball into build container's /build dir.
  build_dir="$(buildah mount "$id")"
  install -o nobody -g nogroup -m 0644 -t "${build_dir}/build" "${TAR}"
  install -o nobody -g nogroup -m 0755 -t "${build_dir}/build" compile.sh
  install -o nobody -g nogroup -m 0755 -d "${build_dir}/srv/irc"
  install -o nobody -g nogroup -m 0755 -d "${build_dir}/run/irc"
  buildah unmount "$id"
}

build_deps() {
  local id="$1"
  # Install unreal build deps in build container, using host network.
  buildah run --network host "$id" -- \
    apt-get -y --no-install-recommends install \
      openssl \
      libssl-dev \
      libpcre2-dev \
      libargon2-dev \
      libsodium-dev \
      libc-ares-dev \
      libjansson-dev \
      libcurl4-openssl-dev
}

build_srcs() {
  local id="$1"
  # Run build script inside build container, without networking.
  buildah run \
    --network none \
    --workingdir /build \
    --user nobody:nogroup \
    --env TAR="${TAR}" \
    "$id" -- /build/compile.sh
}

install_files() {
  local from="$1"
  local to="$2"
  # Copy build artifacts from build container to run container.
  # Create dirs.
  install -o 65532 -g 65532 -m 0755 -d "${to}"/run/irc/{,cache,data,log,tmp}
  install -o 65532 -g 65532 -m 0755 -d "${to}"/srv/irc/{bin,conf,certs.d}
  install -o 65532 -g 65532 -m 0755 -d "${to}"/srv/irc/modules/{chanmodes,extbans,rpc,usermodes}
  # Copy binaries.
  install -o 65532 -g 65532 -m 0700 "${from}/srv/irc/bin/unrealircd" "${to}/srv/irc/bin/unrealircd"
  install -o 65532 -g 65532 -m 0700 "${from}/srv/irc/bin/unrealircdctl" "${to}/srv/irc/bin/unrealircdctl"
  # Copy modules.
  install -o 65532 -g 65532 -m 0700 -t "${to}/srv/irc/modules" "${from}"/srv/irc/modules/*.so
  install -o 65532 -g 65532 -m 0700 -t "${to}/srv/irc/modules/chanmodes" "${from}"/srv/irc/modules/chanmodes/*.so
  install -o 65532 -g 65532 -m 0700 -t "${to}/srv/irc/modules/extbans" "${from}"/srv/irc/modules/extbans/*.so
  install -o 65532 -g 65532 -m 0700 -t "${to}/srv/irc/modules/rpc" "${from}"/srv/irc/modules/rpc/*.so
  install -o 65532 -g 65532 -m 0700 -t "${to}/srv/irc/modules/usermodes" "${from}"/srv/irc/modules/usermodes/*.so
}

# Build UnrealIRCd
build_id="$(buildah from debian-build:trixie)"
copy_srcs "$build_id"
build_deps "$build_id"
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
  --entrypoint "$( entrypoint "/srv/irc/bin/unrealircd" "-F" )" \
  --port 6667/tcp \
  --port 6697/tcp \
  --port 7011/tcp \
  --volume /srv/irc/conf \
  --volume /srv/irc/certs.d \
  "$run_id"

popd
commit "$run_id" "unrealircd" "$VERSION"
