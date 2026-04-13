#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

# Of course libOpenCL1.so.1 lives in an awkward package.
declare -a pkgs=( $(libs_recurse minidlna ocl-icd-libopencl1 | filter_base_deps) )

version_check minidlna "${pkgs[@]}" || exit 0

id="$(from_base nonroot)"
pushd "$(buildah mount "$id")"

busybox

install_pkgs "${pkgs[@]}"

# libblas.so.3 and liblapack.so.3 can be provided by many packages
# (see e.g. `apt-cache search libblas.so.3`)
# each package gets a subdir in /usr/lib
# the symlink from /usr/lib is managed by update-alternatives
# this would normally be run as part of the post-install ...
# but of course we are only extracting the downloaded .debs
# so we must choose our own alternatives
pushd usr/lib/x86_64-linux-gnu
ln -s blas/libblas.so.3
ln -s lapack/liblapack.so.3
popd

# Mount points
mkdir media etc/minidlna

# Directories for minidlna to work in
install -o 65532 -g 65532 -m 0755 -d run/minidlna

# Container configuration.
declare -a args=(
  "/usr/sbin/minidlnad" "-S" "-u" "nonroot" "-f" "/etc/minidlna/minidlna.conf"
)
# NOTE: no --port because multicast needs host networking.
buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --volume /media \
  --volume /etc/minidlna \
  --volume /var/lib/minidlna \
  --workingdir /run/minidlna \
  "$id"

popd
commit "$id" "minidlna" "$(pkg_version minidlna)"
