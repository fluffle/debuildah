# MiniDLNA

Media serving for TVs that are smart-ish.

https://minidlna.com/

Note that their website says:

> Enjoy instant streaming with this lightweight open-source server solution.

... but Debian's minidlna package pulls in almost 2GiB of library deps, which
means that dependency resolution is _slow_, usually taking ~30s, and the
resulting (compressed) OCI image is ~270MB :O

## Building the container

```bash
buildah unshare ./minidlna.sh
```

## Using the container

No real tricks here; things are less complicated because DLNA uses multicast
discovery, which means the container must run in the host networking namespace.

1.  Mount your media onto `/media`.
2.  Mount a dir containing a `minidlna.conf` file onto `/etc/minidlna`.
3.  Mount a r/w volume onto `/var/lib/minidlna` so you don't have to rebuild
    your entire media index every time the container restarts.

