# Nginx

HTTP server / reverse proxy.

https://nginx.org/

## Building the container

```bash
buildah unshare ./nginx.sh
```

## Using the container

Like NSD this image sets up a default configuration matching the container
structure and includes config fragments from a mounted volume. Also like NSD it
uses high ports (8080 and 8443) so that nginx can start as the "nonroot" user
inside the container.

nginx is a bit pickier about duplication in its config fragments, so for files
in the /etc/nginx/conf.d volume:

* `http_*.conf` is included in the main `http` stanza
* `events_*.conf` is included in the main `events` stanza
* `default_server_*.conf` is included in the default `server` stanza

The stub config does not configure TLS serving, because the ACME challenges
required to get TLS certificates require HTTP serving to exist. I therefore
have two ansible roles `nginx` and `nginx-ssl`, with the `acme` role sandwiched
between them :-)
