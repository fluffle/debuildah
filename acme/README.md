# acme.sh

ACME client, written entirely in shell.

http://acme.sh

Why, you might ask? Well, once you start putting things in containers it's hard
to stop.


## Building the container

```bash
buildah unshare ./acme.sh
```

## Using the container

The quadlet is set up to run as a oneshot systemd service on a timer to renew
TLS certs.

Because acme.sh itself runs inside a container as an unprivileged user, I
needed something else to copy certs to the various locations and reload
services as necessary, so I wrote a small, auditable python script that
hopefully doesn't suck too badly. I meant to get an LLM to review it but ...
didn't.

It is possible to use this container to run acme.sh to do the initial cert
generation too, though it does mean either (a) running `podman` as root, or
(b) using root privs to run `podman` as the `acme` user with `--userns
keep-id`. Example commandline, assuming `443` is the UID of the `acme` user:

```bash
podman run --rm --network host --cgroups split \
  --volume /srv/acme:/srv/acme:rw \
  --uidmap 0:65534:1 --uidmap 65532:443:1 \
  --gidmap 0:65534:1 --gidmap 65532:443:1 \
  oci-archive:/srv/images/acme.oci \
  --issue --stateless -k ec-384 \
  --domain example.com
```

This is useful because the timed execution only runs `acme.sh --cron`, which
will only renew existing certificates.
