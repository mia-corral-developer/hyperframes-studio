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
