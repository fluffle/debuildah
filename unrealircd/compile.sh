#! /bin/bash

set -e

# This script expects to be run inside the build container with the flags:
#   --user nobody:nogroup --workingdir /build --env TAR="${TAR}"

tar -zxvf "${TAR}"
cd "${TAR%.tar.gz}"

# Unreal hard-codes their own trusted certificates bundle, ugh.
# Obvs we should just use /etc/ssl/certs/ca-certificates.crt.
# Who needs proper patches when sed can do the trick :-D
sed -i 's#"%s/tls/curl-ca-bundle.crt", CONFDIR#"/etc/ssl/certs/ca-certificates.crt"#' \
  src/tls.c \
  src/url_curl.c \
  src/conf.c

# target semi-recent CPU arch
export CFLAGS="-Os -march=haswell -mtune=skylake"

./configure \
  --prefix=/build/out \
  --enable-ssl \
  --enable-dynamic-linking \
  --with-bindir=/srv/irc/bin \
  --with-confdir=/srv/irc/conf \
  --with-scriptdir=/srv/irc \
  --with-modulesdir=/srv/irc/modules \
  --with-docdir=/srv/irc/doc \
  --with-tmpdir=/run/irc/tmp \
  --with-logdir=/run/irc/log \
  --with-datadir=/run/irc/data \
  --with-cachedir=/run/irc/cache \
  --with-pidfile=/run/irc/unrealircd.pid \
  --with-controlfile=/run/irc/unrealircd.sock \
  --without-privatelibdir \
  --with-builddir="${PWD}" \
  --with-system-argon2 \
  --with-system-pcre2 \
  --with-system-sodium \
  --with-system-cares \
  --with-system-jansson \
  --with-nick-history=100 \
  --with-permissions=0755 \
  --with-maxconnections=1024 \
  --with-operoverride-verify

make -j8
make install
