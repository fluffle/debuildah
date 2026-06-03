#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

VERSION="2.0.0"
SHASUM="45b2a305529842871d3246a3658c7f1685604166126100aa6998f56e96d5cdd7"
TAR="v${VERSION}.tar.gz"
URL="https://github.com/KapJI/capital-gains-calculator/archive/refs/tags/v${TAR}"

UV_VERSION="0.11.18"
UV_SHASUM="588f3e360f69ce02b6982aa99f2240e803933a6b7e176ac01617830adf955add"
UV_TAR="uv-x86_64-unknown-linux-gnu.tar.gz"
UV_URL="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_TAR}"

dl_check_binary "$URL" "$TAR" "$SHASUM"
dl_check_binary "$UV_URL" "$UV_TAR" "$UV_SHASUM"

# add versions manually...
echo "cgt-calc=${VERSION}" >> cgt-calc.versions
echo "uv=${UV_VERSION}" >> cgt-calc.versions
check_versions cgt-calc || exit 0

extract_srcs() {
  local root_dir="$1"
  # uv first
  tar -C "${root_dir}/usr/bin" --strip-components=1 -zxvf "${UV_TAR}"
  chown root:root "${root_dir}/usr/bin/uv" "${root_dir}/usr/bin/uvx"
  # then the sources
  install -o nobody -g nogroup -m 0755 -d "${root_dir}/build"
  tar -C "${root_dir}/build" --strip-components=1 -zxvf "${TAR}"
  chown -R nobody:nogroup "${root_dir}/build"
  # then the working directory
  install -o nobody -g nogroup -m 0755 -d "${root_dir}/data"
}

install_deps() {
  local id="$1"
  # Install build deps in build container, using host network.
  buildah run --network host \
    --env "DEBIAN_FRONTEND=noninteractive" \
    --env "PIP_NO_CACHE_DIR=1" \
    "$id" -- sh -c '
      apt-get update;
      apt-get -y dist-upgrade;
      apt-get -y --no-install-recommends install \
        texlive-latex-base \
        python3 \
        tar gzip \
        ;
      apt-get -y clean;
    '
}

build_srcs() {
  local id="$1"
  buildah run \
    --network host \
    --env "UV_CACHE_DIR=/build/cache" \
    --workingdir /build \
    --user nobody:nogroup \
    "$id" -- uv sync --frozen
}

id="$(buildah from debian-build:trixie)"
dir="$(buildah mount "$id")"
extract_srcs "$dir"
install_deps "$id"
build_srcs "$id"

# Install dependency packages etc.
pushd "$dir"

busybox

buildah config \
  --cmd "" \
  --entrypoint "$( entrypoint "/usr/bin/uv" "run" "--project" "/build" "cgt-calc" )" \
  --env "UV_CACHE_DIR=/build/cache" \
  --volume /data \
  --workingdir /data \
  "$id"

popd
commit "$id" "cgt-calc" "$VERSION"
