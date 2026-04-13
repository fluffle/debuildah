#! /bin/bash

set -e

. "$(git rev-parse --show-toplevel)/debuildah"

declare -a pkgs=( $(deps_recurse 'lib\|nginx' nginx-light | filter_base_deps) )

version_check nginx "${pkgs[@]}" || exit 0

id="$(from_base nonroot)"
pushd "$(buildah mount "$id")"

busybox

install_pkgs "${pkgs[@]}"

cat > etc/nginx/nginx.conf << __EOF__
error_log stderr warn;
daemon off;
lock_file /run/nginx/nginx.lock;
pid /run/nginx/nginx.pid;
working_directory /run/nginx;

# necessary but defaults are fine
events {
  include /etc/nginx/conf.d/events_*.conf;
}

http {
  aio threads;
  directio 1m;
  sendfile on;
  tcp_nopush on;

  # write logs to stdout for systemd to consume
  access_log /dev/stdout;

  gzip on;

  server {
    listen 8080 default_server reuseport;
    listen [::]:8080 reuseport;
    location / {
      return 404;
    }
    include /etc/nginx/conf.d/default_server_*.conf;
  }
  include /etc/nginx/conf.d/http_*.conf;
}

__EOF__

mkdir -p etc/nginx/conf.d etc/nginx/certs.d srv/nginx var/lib/nginx
install -o 65532 -g 65532 -m 0755 -d run/nginx

# Container configuration.
declare -a args=( "/usr/sbin/nginx" "-p" "/srv/nginx" )
buildah config \
  --entrypoint "$( entrypoint "${args[@]}" )" \
  --port 8080/tcp \
  --port 8443/tcp \
  --volume /etc/nginx/conf.d \
  --volume /etc/nginx/certs.d \
  --volume /srv/nginx \
  --volume /var/lib/nginx \
  --workingdir /run/nginx \
  "$id"

popd
commit "$id" "nginx" "$(pkg_version nginx-light)"
