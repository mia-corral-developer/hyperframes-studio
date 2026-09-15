# hyperframes-studio (deploy)

Dokploy deployment artifact for the [HyperFrames](https://github.com/heygen-com/hyperframes)
**Studio** (browser composition editor).

- `Dockerfile` — clones upstream at a pinned commit, builds the workspace packages
  the Studio dev server needs, seeds sample projects, and runs the Studio (Vite
  dev server) bound to `0.0.0.0:5190`.
- `docker-compose.yml` — Dokploy/Swarm service with Traefik labels for
  `hyperframes.lab.whitelabel.lat`.

Not a fork of upstream: this repo only carries the deployment recipe and clones
`heygen-com/hyperframes` at build time.

Deploy: Dokploy compose project pointing at this repo's `main` (build context = git URL).
Live: https://hyperframes.lab.whitelabel.lat

## Host requirement (one-time)

Vite 6 runs a filesystem watcher (chokidar) that exhausts the inotify limits and
the container crashes with `EMFILE: too many open files`. Raise them on the host:

```bash
sudo sysctl -w fs.inotify.max_user_instances=2048 fs.inotify.max_user_watches=1048576
printf 'fs.inotify.max_user_instances=2048\nfs.inotify.max_user_watches=1048576\n' \
  | sudo tee /etc/sysctl.d/99-inotify.conf && sudo sysctl -p /etc/sysctl.d/99-inotify.conf
```

The compose also sets `ulimits.nofile: 65536`.

## Notes

- This is the Studio's **dev server** (HMR on), not a production build: upstream
  ships no command to serve the Studio in production mode.
- The Studio **Render** button works inside the container (chrome-headless-shell +
  ffmpeg are installed). It is CPU/RAM heavy — watch it on a shared VPS.
