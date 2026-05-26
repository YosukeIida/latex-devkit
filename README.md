# latex-devkit

Portable LaTeX build and sync toolkit for a split workspace layout.

- [初回プロジェクト import（Premium / Free）](docs/first-import.md)

## Workspace layout

Clone this repo anywhere.  All runtime directories (`projects/`, `.secrets/`) live **inside** the cloned directory and are gitignored.

```text
<anywhere>/latex-devkit/           # git clone git@github.com:YosukeIida/latex-devkit.git
  projects/
    <project>/                     # each TeX manuscript (not committed)
  .secrets/.olauth                 # localleaf cookie (not committed)
```

`WORKSPACE_ROOT` defaults to the `latex-devkit` directory itself.  Override if needed:

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

Zed / VS Code どちらのテンプレートも、**autosave で勝手にビルドされず、`Cmd+S` を押したときだけビルドされる**設計にしてある。

- **Zed**: `.tex` ファイル上で `Cmd+S` を押すと `LaTeX Build` タスクが起動する。Zed の autosave が有効でも `Cmd+S` 自体は発火しないため、編集中に勝手にビルドは走らない。
- **VS Code**: `latex-workshop.latex.autoBuild.run` を `"never"` に固定したうえで、`Cmd+S` の keybinding を `latex-workshop.build` にバインドする。autosave の ON/OFF に依存せず、`Cmd+S` 押下時だけビルドされる。

## VS Code + LaTeX Workshop (host)

1. Start daemon container:

```bash
make up
```

2. Install project settings template:

```bash
make vscode-init PROJ=my-paper
```

3. **Add `Cmd+S` keybinding (user-scope)**: VS Code の keybinding はワークスペースローカルに置けないため、`make vscode-init` の出力末尾に表示されるスニペットを、自分の User keybindings (`~/Library/Application Support/Code/User/keybindings.json`) に追記する。中身は `templates/vscode/keybindings.json` と同じ。

4. Open `<WORKSPACE_ROOT>/projects/my-paper` in VS Code and press `Cmd+S` on a `.tex` file to build.

The configured tool calls `latex-devkit/bin/latexmk-docker`, which compiles inside `texd` via `docker compose exec`.

## Zed + zed-latex (host)

1. Start daemon container:

```bash
make up
```

2. Install project settings template:

```bash
make zed-init PROJ=my-paper
```

これで `.zed/settings.json`、`.zed/keymap.json`、`.zed/tasks.json` の 3 ファイルが展開される。`Cmd+S` が `LaTeX Build` タスクにバインドされる。

3. Open `<WORKSPACE_ROOT>/projects/my-paper` in Zed. `.tex` ファイル上で `Cmd+S` を押すと `latexmk-docker-skim` が実行され、ビルド後に Skim が前面に出て該当行が表示される。

4. Skim inverse search (Skim → Zed jump): **Skim > Preferences > Sync > PDF-TeX Sync support > Custom**

   | Field | Value |
   |---|---|
   | Command | `open` |
   | Arguments | `zed://file"%urlfile":%line` |

   Then `Shift+⌘+click` in Skim jumps to the corresponding line in Zed.

## Claude Code skills (optional)

このリポジトリには latex-devkit を Claude Code から操作するための skill が同梱されている。

```bash
cp -r skills/* ~/.claude/skills/
```

これで Claude Code から `/latex-devkit`（ビルド操作の補助）と `/install-skill`（他の `.skill` ファイルを入れる）が使えるようになる。Claude Code を再起動すると反映される。

詳細は各 `skills/<name>/SKILL.md` を参照。

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

### PROJECTS_DIR — プロジェクトの置き場所を変える

デフォルトは `<WORKSPACE_ROOT>/projects/`。Overleaf 専用ディレクトリなど任意の場所を使う場合は `PROJECTS_DIR=` で指定する。

```bash
make lleaf-pull PROJ=my-paper PROJECTS_DIR=~/workspace/overleaf-projects
make lleaf-push PROJ=my-paper PROJECTS_DIR=~/workspace/overleaf-projects
```

毎回入力するのが手間な場合は `.envrc` に追記しておく。

```bash
echo 'export PROJECTS_DIR=$HOME/workspace/overleaf-projects' >> .envrc
direnv allow
```

### NAME — Overleaf プロジェクト名がローカルと異なる場合

```bash
# Overleaf 名: "My Paper 2026"、ローカルディレクトリ名: "my-paper"
make lleaf-pull PROJ=my-paper NAME="My Paper 2026"
```

詳細な手順は [docs/first-import.md](docs/first-import.md) を参照。
