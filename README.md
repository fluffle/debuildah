# DeBuildah

debuildah is a set of simple shell functions to make constructing container
images from debian packages easier. There are some usage examples in the
subdirectories of this git repository; they are containers I use :-)

## Setup

You will need to acquire `buildah` and probably `podman`:

```
sudo apt-get install buildah podman
```

## Assumptions

debuildah is pretty opinionated. Probably because I am, too. YMMV!

debuildah assumes you will want to run exactly one executable binary inside
your container. This binary will run as PID 1 with no init and no bootstrap
shell script.

debuildah assumes that you will run your containers read-only except for a
tmpfs mount on /run, i.e. with the podman flags `--read-only` and
`--read-only-tmpfs`. If you need a path to be writable you will mount a
writable volume from the host into the container.

debuildah assumes that you will mount any runtime configuration of the binary
into the container as a volume, and not bother with trying to synthesize this
configuration from a bunch of env vars.

debuildah assumes you want to start with the GCR [distroless images][1] as
base containers. They are based on recent debian images and maintained by
Google.

debuildah assumes that you don't care _too much_ about supply chain risk,
because you are effectively the entire supply chain. Apart from debian, of
course. If you need reproducible builds and checksummable archives, please
investigate the toolchains used to build the distroless images, they look neat,
but complicated.

debuildah assumes that you don't care to run your own docker repository and
using `scp`, `rsync` or `ansible` to copy OCI archives around is sufficient
to distribute your containers to the hosts you want to run them on. The minor
downside of this assumption is that the podman auto-update timer ... won't.

[1]: https://github.com/GoogleContainerTools/distroless/blob/main/README.md

## Building A Container

Building containers when you're not root requires userid namespace mappings.
These are accomplished via [`buildah unshare`][1]. So our container build
process looks approximately like:

1.  Write a short shell script that modifies a base container image using
    Standard Shell Tools™.
1.  Run the short shell script with `buildah unshare`.
1.  Bask in the glory of your new OCI archive.

If you need to get fancy, you may need a short shell script to run inside
the container image to do complicated things like build software. See the
`unrealircd` directory for an example of this.

[1]: https://github.com/containers/buildah/blob/main/docs/buildah-unshare.1.md

## Build Script Contents

Most build scripts will follow the same sort of pattern:

```bash
#! /bin/bash

set -e

. /path/to/debuildah

# determine dependencies of the package we want to run in our container
#
# filter_base_deps is required explicitly because, well, it only makes
# sense to filter these deps if you choose to start with the distroless
# debian base container.
declare -a pkgs=( $( libs_recurse somepackage | filter_base_deps ) )

# check if deps have changed, if not prompt the user to approve rebuilding
# the container where presumably nothing has changed. Only works if your
# scripts and the versions files created by this function are checked into
# git, because I am lazy. This is entirely optional :-)
version_check somepackage "${pkgs[@]}" || exit 0

# Start with the nonroot debian 13 distroless base image.
id="$( from_base nonroot )"

# Change to the root directory of the mounted container image.
pushd "$( buildah mount $id )"

# Install packages
busybox
install_pkgs "${pkgs[@]}"

# Customize the image however you want.
mkdir srv/somepackage/rw_volume_mount
# The nonroot user in the base image is uid/gid 65532 so you can
# ensure there are writable dirs inside the container like this:
install -o 65532 -g 65532 -m 0755 -d run/somepackage

# Use buildah `config` to set container metadata.
declare -a argv=(
    "/usr/sbin/mybinary"
    "-f"
    "/etc/somepackage/mybinary.conf"
    "--foreground"
)

buildah config \
  --entrypoint "$( entrypoint "${argv[@]} )" \
  --port 1234/tcp \
  --volume /srv/somepackage/rw_volume_mount \
  --workingdir /run/somepackage \
  "$id"

# Leave the mounted directory and commit the build to an OCI image.
popd
commit "$id" "somepackage" "$(pkg_version somepackage)"
```

## Using the built containers

I recommend using podman and quadlets to spin these containers up as systemd
services. I have not tried anything more adventurous :-)

Example quadlet files for each example container are in the respective dirs.
The quadlets assume that container images are in `/srv/images` and the volume
dirs that need to be mounted for a container to function are in a directory
under `/srv` named for the container.

Host-side I have generally created users with UIDs that match the port being
exposed. The quadlets use a custom UID map to map the "nonroot" UID 65532
inside the container to these host-side UIDs.

You will need to get podman working on your host machines. There were a few
gotchas for me, notably around IPv6:

1.  You need IP forwarding enabled via sysctl, for both IPv4 and IPv6.
1.  You need to set the `net.ipv6.conf.all.accept_ra` sysctl to 2, not 1,
    when you enable IPv6 forwarding **if your host gets its v6 address via
    SLAAC**. Otherwise forwarding disables SLAAC and you have no IPv6.
1.  podman's default network is v4 only, you need to create another network
    for it to be dual-stack.
1.  If your host has firewall rules via iptables/nftables you need to permit
    forwarding from your host interfaces to the network bridge, and vice versa.
