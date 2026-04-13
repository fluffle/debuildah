#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

declare -a pkgs=( $(libs_recurse nsd | filter_base_deps) )

version_check nsd "${pkgs[@]}" || exit 0

id="$(from_base nonroot)"
pushd "$(buildah mount "$id")"

busybox

install_pkgs "${pkgs[@]}"

cat > etc/nsd/nsd.conf << __EOF__
server:
	# Don't fork into background
	debug-mode: yes
	# Use standard "nonroot" user from base image
	username: nonroot
	# Write state files to /run/nsd
	pidfile: /run/nsd/nsd.pid
	xfrdfile: /run/nsd/xfrd.state
	# Bind port 5353 because we're not root
	port: 5353

include: "/etc/nsd/nsd.conf.d/*.conf"
__EOF__

# Dir for mounting zones into.
mkdir -p etc/nsd/zones

# Dir for pid / xfrd.state; no need to mount over this.
# 65532 is the numeric UID for the nonroot user inside the container.
install -o 65532 -g 65532 -m 0755 -d run/nsd

# Container configuration.
declare -a args=("/usr/sbin/nsd" "-c" "/etc/nsd/nsd.conf")
buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --port 5353/tcp --port 5353/udp \
  --volume /etc/nsd/nsd.conf.d \
  --volume /etc/nsd/zones \
  --workingdir /run/nsd \
  "$id"

popd
commit "$id" "nsd" "$(pkg_version nsd)"
