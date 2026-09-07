# latex-devkit

Portable LaTeX build and sync toolkit for a split workspace layout.

> 日本語版は [README.ja.md](README.ja.md) を参照してください。

- [First-time project import (Premium / Free)](docs/first-import.md)

## Workspace layout

Clone this repo anywhere. All runtime directories (`projects/`, `.secrets/`) live **inside** the cloned directory and are gitignored.

```text
<anywhere>/latex-devkit/           # git clone git@github.com:YosukeIida/latex-devkit.git
  projects/
    <project>/                     # each TeX manuscript (not committed)
  .secrets/.olauth                 # localleaf cookie (not committed)
```

`WORKSPACE_ROOT` defaults to the `latex-devkit` directory itself. Override if needed:

```bash
make up WORKSPACE_ROOT=/some/other/path
```

## Design

- Build infrastructure lives in `latex-devkit` (this repo).
- Manuscripts live in `projects/*` inside the workspace root (gitignored).
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

## Output location (`$out_dir`)

**Defaults to `<project>/output/`. A project's `latexmkrc` wins if it sets `$out_dir`.**

Builds read rc files as `latexmk -norc -r latexmk/defaults.latexmkrc -r <project>/latexmkrc`. `latexmk` processes `-r` in command-line order, so the project's `latexmkrc`, read last, can override the defaults.

- Defaults live in [`latexmk/defaults.latexmkrc`](latexmk/defaults.latexmkrc) (`$out_dir`, plus the `BIBINPUTS` setting it requires).
- `compose.yaml` mounts it read-only at `/etc/latex-devkit/defaults.latexmkrc`. The mount is resolved relative to the compose file, so overriding `WORKSPACE_ROOT` does not break it.

Engine choice (`platex` / `lualatex` / …) and `$force_mode` are per-project decisions and are deliberately not in the defaults.

To override explicitly, pass an out dir as the second argument to `bin/latexmk-docker`; it becomes `-outdir=`, which beats `latexmkrc`.

> **Note**: The long-running `texd` container (from `make up`) keeps the mount set it was created with, so run `make down && make up` once after adding this mount. `make build-local` starts a throwaway container via `docker compose run --rm` every time and needs no restart.

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

## Build trigger policy: Cmd+S only

Both the Zed and VS Code templates are designed so that **builds run only when you press `Cmd+S`, never automatically on autosave**.

- **Zed**: pressing `Cmd+S` on a `.tex` file spawns the `LaTeX Build` task. Even with Zed's autosave enabled, `Cmd+S` itself does not fire on every keystroke, so builds do not run during normal editing.
- **VS Code**: `latex-workshop.latex.autoBuild.run` is pinned to `"never"`, and `Cmd+S` is bound to `latex-workshop.build`. Builds are triggered solely by `Cmd+S`, regardless of whether autosave is on or off.

## VS Code + LaTeX Workshop (host)

1. Start the daemon container:

```bash
make up
```

2. Install project settings template:

```bash
make vscode-init PROJ=my-paper
```

3. **Add `Cmd+S` keybinding (user-scope)**: VS Code does not support workspace-local keybindings, so append the snippet printed at the end of `make vscode-init` to your User keybindings (`~/Library/Application Support/Code/User/keybindings.json`). The content matches `templates/vscode/keybindings.json`.

4. Open `<WORKSPACE_ROOT>/projects/my-paper` in VS Code and press `Cmd+S` on a `.tex` file to build.

The configured tool calls `latex-devkit/bin/latexmk-docker`, which compiles inside `texd` via `docker compose exec`.

## Zed + zed-latex (host)

1. Start the daemon container:

```bash
make up
```

2. Install project settings template:

```bash
make zed-init PROJ=my-paper
```

This deploys three files: `.zed/settings.json`, `.zed/keymap.json`, and `.zed/tasks.json`. `Cmd+S` is bound to the `LaTeX Build` task.

3. Open `<WORKSPACE_ROOT>/projects/my-paper` in Zed. Pressing `Cmd+S` on a `.tex` file runs `latexmk-docker-skim`; after the build, Skim is brought to the foreground and jumps to the corresponding line.

4. Skim inverse search (Skim → Zed jump): **Skim > Preferences > Sync > PDF-TeX Sync support > Custom**

   | Field | Value |
   |---|---|
   | Command | `open` |
   | Arguments | `zed://file"%urlfile":%line` |

   Then `Shift+⌘+click` in Skim jumps to the corresponding line in Zed.

## Claude Code skills (optional)

This repository bundles a Claude Code skill for operating latex-devkit at
`skills/latex-devkit/SKILL.md`. It uses the layout `gh skill` recognizes, so you can
inspect it before adopting it:

```bash
gh skill preview YosukeIida/latex-devkit latex-devkit
```

How you install it is up to you. If you manage your dotfiles with git or Nix, prefer
your existing vendor/symlink mechanism. Otherwise:

```bash
cp -r skills/latex-devkit ~/.claude/skills/
```

Restart Claude Code and `/latex-devkit` becomes available.

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

Cookie location defaults to:

```text
<WORKSPACE_ROOT>/.secrets/.olauth
```

Commands:

```bash
make lleaf-login
make lleaf-pull PROJ=my-paper
make lleaf-push PROJ=my-paper
make lleaf-download PROJ=my-paper
```

### PROJECTS_DIR — change where projects live

Defaults to `<WORKSPACE_ROOT>/projects/`. To use an arbitrary location (e.g. a dedicated Overleaf directory), pass `PROJECTS_DIR=`.

```bash
make lleaf-pull PROJ=my-paper PROJECTS_DIR=~/workspace/overleaf-projects
make lleaf-push PROJ=my-paper PROJECTS_DIR=~/workspace/overleaf-projects
```

To avoid passing it every time, add it to `.envrc`:

```bash
echo 'export PROJECTS_DIR=$HOME/workspace/overleaf-projects' >> .envrc
direnv allow
```

### NAME — when the Overleaf project name differs from the local directory

```bash
# Overleaf name: "My Paper 2026", local directory name: "my-paper"
make lleaf-pull PROJ=my-paper NAME="My Paper 2026"
```

See [docs/first-import.md](docs/first-import.md) for the full first-time setup.
