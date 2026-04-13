#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

declare -a pkgs=( $(libs_recurse acme.sh openssl wget | filter_base_deps) )

version_check acme "${pkgs[@]}" || exit 0

id="$(from_base nonroot)"
pushd "$(buildah mount "$id")"

busybox

install_pkgs "${pkgs[@]}"

mkdir -p srv/acme

# Container configuration.
# acme.sh is running under busybox ash, which thinks wget is a builtin.
# Unfortunately busybox wget is Not Sufficient for acme.sh's needs ...
# Fortunately we can make it use /usr/bin/wget via an env var.
declare -a args=("/usr/bin/acme.sh" "--home" "/srv/acme" "--use-wget")
buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --env '_ACME_WGET=/usr/bin/wget -q' \
  --volume /srv/acme \
  --workingdir /srv/acme \
  "$id"

popd
commit "$id" "acme" "$(pkg_version acme.sh)"
