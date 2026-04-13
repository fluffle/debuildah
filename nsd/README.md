# NSD

Authoritative DNS server.

https://nlnetlabs.nl/projects/nsd/about/

## Building the container

```bash
buildah unshare ./nsd.sh
```

## Using the container

The build script compiles a stub config into the container that correctly sets
nsd up to run in the foreground and write its state files to writable tmpfs.
The configuration uses nsd's `include` directive to include all `*.conf` files
from `/etc/nsd/nsd.conf.d`, which is where the quadlet mounts the volume
containing configurations from the host.

It binds to port 5353 inside the container so it can start as the "nonroot"
user that the base image defaults to without needing permission changes. This
is then exposed as port 53 on the host by the quadlet.
