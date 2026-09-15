# HyperFrames Studio — image for Dokploy (Docker Swarm + Traefik)
#
# Serves the browser-based Studio editing UI (Vite dev server) bound to 0.0.0.0
# so Traefik can route hyperframes.lab.whitelabel.lat to it.
#
# Why a dev server: upstream ships no production "serve the studio" command —
# `hyperframes preview` spawns the Studio's Vite dev server with a hardcoded
# `--host 127.0.0.1` (packages/cli/src/commands/preview.ts:previewViteArgs) and
# exposes no flag to change it. We run the same dev server ourselves with an
# explicit bind + allowed host instead of patching upstream.
#
# Build context clones upstream at a pinned commit for reproducibility.
FROM node:22-bookworm-slim

# Pinned upstream commit (heygen-com/hyperframes @ main).
ARG HF_REF=f98b8ead374c20e850995ba071c1da37cdbefe54

# ── System deps: ffmpeg + headless-Chrome runtime libs + fonts ──────────────
# Mirrors the upstream render image (packages/gcp-cloud-run/Dockerfile) so the
# Studio's render button works inside this container too.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git ffmpeg \
      libgbm1 libnss3 libatk-bridge2.0-0 libdrm2 libxcomposite1 libxdamage1 \
      libxrandr2 libcups2 libasound2 libpangocairo-1.0-0 libxshmfence1 libgtk-3-0 \
      fonts-liberation fonts-noto-color-emoji fonts-noto-cjk fonts-noto-core \
      fonts-noto-extra fonts-noto-ui-core fonts-freefont-ttf fonts-dejavu-core fontconfig \
    && rm -rf /var/lib/apt/lists/* && fc-cache -fv

# ── chrome-headless-shell (deterministic BeginFrame capture) ─────────────────
RUN npx --yes @puppeteer/browsers install chrome-headless-shell@148.0.7778.167 \
      --path /opt/puppeteer \
    && CHS="$(find /opt/puppeteer/chrome-headless-shell -name chrome-headless-shell -type f | head -n1)" \
    && mkdir -p /opt/chrome \
    && ln -s "$CHS" /opt/chrome/chrome-headless-shell \
    && /opt/chrome/chrome-headless-shell --version

ENV HYPERFRAMES_CHROME_PATH=/opt/chrome/chrome-headless-shell \
    PRODUCER_HEADLESS_SHELL_PATH=/opt/chrome/chrome-headless-shell \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    CONTAINER=true

# ── bun (repo's package manager / build driver) ──────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v1.3.9"
ENV PATH="/root/.bun/bin:$PATH"

WORKDIR /app

# ─ Clone upstream at the pinned ref ─────────────────────────────────────────
RUN git clone https://github.com/heygen-com/hyperframes.git /app/hf \
    && git -C /app/hf checkout "${HF_REF}"

WORKDIR /app/hf

# ── Install workspace dependencies ───────────────────────────────────────────
RUN bun install --frozen-lockfile

# ── Build the workspace packages the Studio dev server + render path need ────
# Same set/order as the upstream Cloud Run image. Workspace packages are not
# prebuilt in a fresh clone, so producer's esbuild resolution otherwise fails
# on parsers/core compiler entrypoints.
RUN bun run --cwd packages/parsers build \
    && bun run --cwd packages/lint build \
    && bun run --cwd packages/studio-server build \
    && bun run --cwd packages/core build \
    && bun run --cwd packages/core build:hyperframes-runtime:modular \
    && bun run --cwd packages/sdk build \
    && bun run --cwd packages/sdk-playground build \
    && bun run --cwd packages/engine build \
    && (cd packages/producer && bunx tsx scripts/generate-font-data.ts) \
    && bun run --cwd packages/producer build

# ─ Seed sample projects (packages/studio/data/ is gitignored) ───────────────
# Studio lists every dir under data/projects that contains index.html.
RUN mkdir -p packages/studio/data/projects \
    && cp -r registry/examples/kinetic-type packages/studio/data/projects/kinetic-type \
    && cp -r registry/examples/product-promo packages/studio/data/projects/product-promo

# ─ Project gallery launcher (/projects.html) ────────────────────────────────
# Upstream ships no project picker: the Studio opens a single project chosen by
# the URL hash (#project/<id>). This static page lists every project via
# GET /api/projects with a live thumbnail and links into the editor. It lives in
# Vite's publicDir, so it is served at /projects.html without shadowing the SPA
# index.html. Baked into the image so it survives Dokploy redeploys.
COPY public/projects.html /app/hf/packages/studio/public/projects.html

# ── Runtime config ───────────────────────────────────────────────────────────
# Preview host → bind all interfaces (otherwise 127.0.0.1 only).
# allowedHosts → Vite 6 blocks requests whose Host header isn't allowed; behind
# Traefik the Host is the public domain, so whitelist it explicitly.
ENV HYPERFRAMES_PREVIEW_HOST=0.0.0.0 \
    HYPERFRAMES_PREVIEW_PROJECT_NAME=kinetic-type \
    HYPERFRAMES_PREVIEW_PROJECT_DIR=/app/hf/packages/studio/data/projects/kinetic-type \
    __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=hyperframes.lab.whitelabel.lat \
    PORT=5190

EXPOSE 5190

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=10 \
    CMD curl -fsS http://localhost:5190/ >/dev/null || exit 1

WORKDIR /app/hf/packages/studio

# Run the Studio dev server (UI + mounted studio-server API + producer) on all
# interfaces. `--bun` matches the package's own `dev` script.
CMD ["bun", "--bun", "./node_modules/.bin/vite", "--host", "0.0.0.0", "--port", "5190"]