# OpenCode

Agentic coding CLI tool

https://opencode.ai/

The default opencode container image (ghcr.io/anomalyco/opencode) does not
contain many tools for the agents to use. At least one other person has run
into this (github.com/randommm/opencode -> ghcr.io/randommm/opencode) but
they broke their container so I guess I gotta roll my own.

## Building the container

Opencode build .deb files pretty regularly using github actions and we'll want
to stay pretty close to the latest version. OTOH all the tools etc can probably
survive being refreshed less regularly. Which means...

Running `intermediates/opencode-tools.sh` will produce a full-fat debian
container image with a bunch of useful stuff in it, primarily Go, Python, Perl
and a C compiler as well as lots of standard CLI tools. We can base the
opencode CLI container image on this. Then, as per usual:

```
buildah unshare ./opencode.sh
```

Newer versions and their SHA256SUMs can be found at:

    https://github.com/anomalyco/opencode/releases

## Running the container

I have a script `bin/opencode` that runs the opencode container and handles
mapping namespaces etc. I created a separate user to run agents and CLIs as
so they can't read or write to anything I care about. That user is in my
primary user's group, so I can manage read or write access to stuff owned by me
by changing the group r/w/x bits.

> /home/alex/gemini/bin/opencode

```bash
#! /bin/sh

TTY=""
if [ -z "$@" ]; then TTY="-it"; fi

exec \
  podman run "$TTY" --rm --network host --umask 002 \
  --user 11001:1001 --hostuser gemini-alex --passwd \
  --passwd-entry '$USERNAME:x:$UID:$GID:$NAME:/home:/whocares' \
  --userns keep-id \
  --volume "/home/alex/.opencode:/home" \
  --volume "$(pwd):/workspace" \
  --volume "/home/alex/gemini/go:/opt/gocode:rw" \
  --env "GOPATH=/opt/gocode" \
  ${OPENCODE_PODMAN_FLAGS:-} \
  "oci-archive:/home/alex/git/debuildah/opencode/opencode.oci" \
  ${OPENCODE_CLI_FLAGS:-} \
  "$@"
```

Becoming the gemini-alex user requires `runuser` to start the systemd user
session, so that podman can find a dbus connection to systemd.

> /home/alex/bin/gemini

```bash
#! /bin/sh

exec sudo runuser -P -l gemini-alex
```

So we add something to sudoers to avoid password prompts for this command...

> /etc/sudoers.d/40_gemini-alex

```
Defaults:alex umask = 0002
Defaults:alex env_keep += "TERM TERMINFO COLORTERM"
alex    ALL=(root:alex) NOPASSWD: /sbin/runuser -P -l gemini-alex
```

