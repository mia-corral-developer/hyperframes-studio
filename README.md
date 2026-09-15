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

## Shared projects with the MCP

The Studio and the [hyperframes-mcp](../hyperframes-mcp) server are **separate
containers**. By default each has its own workspace, so projects created/rendered
through the MCP are invisible in the Studio UI. This compose mounts the **same
external volume** the MCP uses (`code_hf-mcp-projects`) at the Studio's projects
dir, so both share one source of truth. Base image seeds a couple of demos; the
volume then carries everything the MCP writes.

## Project gallery — `/projects.html`

Upstream has **no project picker**: the Studio opens a single project selected by
the URL hash (`#project/<id>`), defaulting to `HYPERFRAMES_PREVIEW_PROJECT_NAME`.
`public/projects.html` is a small static launcher that lists every project from
`GET /api/projects` with a live thumbnail
(`/api/projects/<id>/thumbnail/index.html?t=<sec>&format=png`) and links into the
editor. It is copied into Vite's `publicDir` at build time, so it is served at
**https://hyperframes.lab.whitelabel.lat/projects.html** and baked into the image
(survives redeploys).

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
