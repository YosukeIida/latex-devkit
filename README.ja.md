# latex-devkit

分離されたワークスペース構成のためのポータブルな LaTeX ビルド & 同期ツールキット。

> English version: see [README.md](README.md).

- [初回プロジェクト import（Premium / Free）](docs/first-import.md)

## ワークスペース構成

このリポジトリは任意の場所に clone する。実行時に使うディレクトリ（`projects/`、`.secrets/`）はすべて clone 先の **内部** に置かれ、gitignore されている。

```text
<anywhere>/latex-devkit/           # git clone git@github.com:YosukeIida/latex-devkit.git
  projects/
    <project>/                     # 各 TeX 原稿（コミットしない）
  .secrets/.olauth                 # localleaf の cookie（コミットしない）
```

`WORKSPACE_ROOT` のデフォルトは `latex-devkit` ディレクトリ自身。変更する場合は上書きできる：

```bash
make up WORKSPACE_ROOT=/some/other/path
```

## 設計方針

- ビルド基盤は `latex-devkit`（このリポジトリ）に置く。
- 原稿は workspace root の `projects/*` に置く（gitignore 済み）。
- ローカルコンパイルは、事前ビルド済み TeX Live イメージをベースにした常駐 Docker サービス（`texd`）で行う。
- Overleaf 同期は基本的に git remote ベース（`origin` + 任意の `overleaf`）。
- `localleaf (lleaf)` はフォールバックとして利用可能。

## 必要なもの

- Docker / Docker Compose
- `uv`（`lleaf` フォールバックコマンド用）
- `fswatch`（任意。watch モード用）

## TeX Live イメージのポリシー

- デフォルトのイメージリポジトリ: `texlive/texlive`
- デフォルトのバージョンタグ: `TL2024-historic`
- 実効イメージ: `texlive/texlive:TL2024-historic`
- Docker Hub の公開イメージを使うことで、ローカルでの `install-tl` ビルドのオーバーヘッドを避ける。
- 実行時にバージョンタグだけ上書きできる:

```bash
make up TEXLIVE_IMAGE_TAG=TL2024-historic
```

- リポジトリ + タグの両方を上書きすることも可能:

```bash
make up TEXLIVE_IMAGE_REPO=texlive/texlive TEXLIVE_IMAGE_TAG=TL2024-historic
```

Apple Silicon の注意点:
- プラットフォーム不一致で pull/run が失敗する場合は次を試す:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 make up
```

## 生成物の置き場所（`$out_dir`）

**デフォルトは `<project>/output/`。プロジェクトの `latexmkrc` が `$out_dir` を書いていればそちらが勝つ。**

ビルドは `latexmk -norc -r latexmk/defaults.latexmkrc -r <project>/latexmkrc` の順で rc を読む。`latexmk` は `-r` をコマンドライン上の順序で処理するため、後から読まれるプロジェクトの `latexmkrc` が既定値を上書きできる。

- 既定値の定義: [`latexmk/defaults.latexmkrc`](latexmk/defaults.latexmkrc)（`$out_dir` と、それに対で必要な `BIBINPUTS`）
- コンテナへは `compose.yaml` が `/etc/latex-devkit/defaults.latexmkrc` として read-only でマウントする。compose ファイル相対で解決されるので、`WORKSPACE_ROOT` を上書きしても壊れない。

エンジン（`platex` / `lualatex` 等）や `$force_mode` はプロジェクト固有の判断なので既定値には入れない。各プロジェクトの `latexmkrc` が持つ。

明示的に上書きしたい場合は `bin/latexmk-docker` の第2引数で `-outdir=` を渡せる（脱出口）。ただしこれは `latexmkrc` の `$out_dir` より強い。

> **注意**: 常駐コンテナ（`make up` した `texd`）は起動時のマウント構成を保持する。`defaults.latexmkrc` のマウントを追加した直後は `make down && make up` が必要。`make build-local` は毎回 `docker compose run --rm` で使い捨てコンテナを起動するため、こちらは再起動不要。

## 主要コマンド

`latex-devkit` 直下で実行する。

```bash
make pull-image
make up
make ps
make build-local PROJ=my-paper MAIN=main.tex
make watch-local PROJ=my-paper MAIN=main.tex
make down
```

## ビルドのトリガーポリシー: Cmd+S のときだけ

Zed / VS Code 両方のテンプレートとも、**autosave で勝手にビルドされず、`Cmd+S` を押したときだけビルドされる**設計になっている。

- **Zed**: `.tex` ファイル上で `Cmd+S` を押すと `LaTeX Build` タスクが起動する。Zed の autosave が有効でも `Cmd+S` 自体は発火しないため、編集中に勝手にビルドは走らない。
- **VS Code**: `latex-workshop.latex.autoBuild.run` を `"never"` に固定したうえで、`Cmd+S` の keybinding を `latex-workshop.build` にバインドする。autosave の ON/OFF に依存せず、`Cmd+S` 押下時だけビルドされる。

## VS Code + LaTeX Workshop（ホスト側）

1. デーモンコンテナを起動:

```bash
make up
```

2. プロジェクト設定テンプレートを展開:

```bash
make vscode-init PROJ=my-paper
```

3. **`Cmd+S` keybinding を追加（user スコープ）**: VS Code はワークスペースローカルな keybinding をサポートしていないため、`make vscode-init` の出力末尾に表示されるスニペットを、自分の User keybindings (`~/Library/Application Support/Code/User/keybindings.json`) に追記する。中身は `templates/vscode/keybindings.json` と同じ。

4. `<WORKSPACE_ROOT>/projects/my-paper` を VS Code で開き、`.tex` ファイル上で `Cmd+S` を押すとビルドされる。

設定されているツールは `latex-devkit/bin/latexmk-docker` を呼び、`docker compose exec` 経由で `texd` コンテナ内でコンパイルされる。

## Zed + zed-latex（ホスト側）

1. デーモンコンテナを起動:

```bash
make up
```

2. プロジェクト設定テンプレートを展開:

```bash
make zed-init PROJ=my-paper
```

これで `.zed/settings.json`、`.zed/keymap.json`、`.zed/tasks.json` の 3 ファイルが展開される。`Cmd+S` が `LaTeX Build` タスクにバインドされる。

3. `<WORKSPACE_ROOT>/projects/my-paper` を Zed で開く。`.tex` ファイル上で `Cmd+S` を押すと `latexmk-docker-skim` が実行され、ビルド後に Skim が前面に出て該当行が表示される。

4. Skim の inverse search（Skim → Zed へジャンプ）: **Skim > Preferences > Sync > PDF-TeX Sync support > Custom**

   | フィールド | 値 |
   |---|---|
   | Command | `open` |
   | Arguments | `zed://file"%urlfile":%line` |

   設定後、Skim 上で `Shift+⌘+click` すると Zed の該当行にジャンプする。

## Claude Code skills（任意）

このリポジトリには latex-devkit を Claude Code から操作するための skill が同梱されている。

```bash
cp -r skills/* ~/.claude/skills/
```

これで Claude Code から `/latex-devkit`（ビルド操作の補助）と `/install-skill`（他の `.skill` ファイルを入れる）が使えるようになる。Claude Code を再起動すると反映される。

詳細は各 `skills/<name>/SKILL.md` を参照。

## Git 同期ポリシー

各原稿リポジトリの内部では:

- `origin`: GitHub（プライマリ）
- `overleaf`: Overleaf の Git remote（任意）

Push ヘルパ:

```bash
make git-push-all PROJ=my-paper BRANCH=main
```

`origin` に push したあと、`overleaf` が設定されていれば続けて push する。

## localleaf フォールバック

Cookie のデフォルト場所:

```text
<WORKSPACE_ROOT>/.secrets/.olauth
```

コマンド:

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
