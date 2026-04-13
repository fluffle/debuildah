# UnrealIRCd

IRC server

https://www.unrealircd.org/

## Building the container

UnrealIRCd isn't packaged for debian, presumably because its build process is
extremely distro-hostile. So we'll have to build from source, which means we'll
need a container image that can be used for that, like docker chained images.

Running `intermediates/trixie-build.sh` will produce a full-fat debian
container image with `build-essential` and a couple other packages installed so
we don't need to pull _everything_ every time. If you get complaints about a
missing "localhost/debian-build:trixie" container you need to run this first.

Then!

```
buildah unshare ./unrealircd.sh
```

There are actually two scripts here: the one that buildah runs via unshare, and
the one that this first script runs _inside_ the build container namespace,
which compiles UnrealIRCd.

The outer script has a lot more work to do than the others, because it must:

1.  Download and shasum the provided tarball if it doesn't exist.
1.  Prepare the build container with:
    * The source tarball and compilation script.
    * All compile time dependencies of UnrealIRCd.
1.  Run the compilation script in the build container.
1.  Create the destination container from a distroless base.
1.  Copy the resulting build artifacts to the destination.
1.  Install all the runtime deps into the destination container.

## Running the container

Configuring UnrealIRCd is complicated. The compiled binary expects to find
configuration at `/srv/irc/conf/unrealircd.conf`, and the container expects
`/srv/irc/conf` to be mounted as a volume, which is handled by the quadlet.

The resulting OCI image also contains the `unrealircdctl` binary, which can be
run via podman to do things like generate SPKI fingerprints for SSL certs and
password hashes:

```
podman run -it --rm \
    --entrypoint /srv/irc/bin/unrealircdctl \
    --volume /cert/dir:/srv/irc/conf:ro \
    oci-archive:unrealircd.oci \
    spkifp /srv/irc/conf/$CERTIFICATE
```

```
podman run -it --rm \
    --entrypoint /srv/irc/bin/unrealircdctl \
    oci-archive:unrealircd.oci \
    mkpasswd
```

This can also be run from inside the running unrealircd container via `podman
exec` to trigger server rehashes or reloads of TLS certs:

```
podman exec unrealircd /srv/irc/bin/unrealircdctl rehash
podman exec unrealircd /srv/irc/bin/unrealircdctl reloadtls
```

The only other thing to note is that Debian still ships with an `irc` user
in its default `/etc/passwd` so this user (uid 39) is used in lieu of creating
one with uid 6697.
