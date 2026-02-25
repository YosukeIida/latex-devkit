# latex-devkit

Portable LaTeX build and sync toolkit for a split workspace layout.

## Workspace layout

```text

  latex-devkit/              # this public repo
  projects/
    <project>/               # each TeX manuscript as independent git repo
  .secrets/.olauth           # localleaf cookie (not committed)
```

## Design

- Build infrastructure lives in `latex-devkit`.
- Manuscripts live in `projects/*` as separate repos.
- Local compile uses a long-running Docker service (`texd`) based on a prebuilt TeX Live image.
- Overleaf sync is primarily git-remote based (`origin` + optional `overleaf`).
- `localleaf (lleaf)` remains available as a fallback.

## Prerequisites

- Docker / Docker Compose
- `uv` (for `lleaf` fallback commands)
- `fswatch` (optional, for watch mode)

## TeX Live image policy

- Default image repo: `texlive/texlive`
- Default version tag: `TL2024-historic`
- Effective image: `texlive/texlive:TL2024-historic`
- This uses a public image from Docker Hub and avoids local `install-tl` build overhead.
- You can override only the version tag at runtime:

```bash
make up TEXLIVE_IMAGE_TAG=TL2024-historic
```

- You can also override repo + tag together:

```bash
make up TEXLIVE_IMAGE_REPO=texlive/texlive TEXLIVE_IMAGE_TAG=TL2024-historic
```

Apple Silicon note:
- If pull/run fails due to platform mismatch, try:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 make up
```

## Core commands

Run these from `latex-devkit`.

```bash
make pull-image
make up
make ps
make build-local PROJ=my-paper MAIN=main.tex
make watch-local PROJ=my-paper MAIN=main.tex
make down
```

## VS Code + LaTeX Workshop (host)

1. Start daemon container:

```bash
make up
```

2. Install project settings template:

```bash
make vscode-init PROJ=my-paper
```

3. Open `projects/my-paper` in VS Code and build with LaTeX Workshop.

The configured tool calls `latex-devkit/bin/latexmk-docker`, which compiles inside `texd` via `docker compose exec`.

## Git sync policy

Inside each manuscript repo:

- `origin`: GitHub (primary)
- `overleaf`: Overleaf Git remote (optional)

Push helper:

```bash
make git-push-all PROJ=my-paper BRANCH=main
```

This pushes to `origin` first, then `overleaf` if configured.

## localleaf fallback

Cookie location is fixed to:

```text
.secrets/.olauth
```

Commands:

```bash
make lleaf-login
make lleaf-pull PROJ=my-paper
make lleaf-push PROJ=my-paper
make lleaf-download PROJ=my-paper
```

Set `NAME="Overleaf Project Name"` only when Overleaf project name differs from local directory name.
