# 初回プロジェクト import

Overleaf のプロジェクトをローカルに取り込む手順。
Premium（git clone 可）と Free（lleaf）でフローが分かれる。

## プロジェクトの置き場所

`latex-devkit` は `PROJECTS_DIR` 変数でプロジェクトの置き場所を自由に指定できる。

| 用途 | 推薦パス |
|---|---|
| Overleaf で管理している論文全般 | `~/workspace/overleaf-projects/` |
| 特定の実験 repo に紐づく論文 | `<repo>/research/docs/papers/` など |

```bash
# make コマンドに毎回渡す
make lleaf-pull PROJ=my-paper PROJECTS_DIR=~/workspace/overleaf-projects

# または .envrc に書いて自動化（latex-devkit ディレクトリに追記）
echo 'export PROJECTS_DIR=$HOME/workspace/overleaf-projects' >> .envrc
direnv allow
```

`PROJECTS_DIR` を省略した場合は `<latex-devkit>/projects/` がデフォルトになる。

## NAME オプション

Overleaf 上のプロジェクト名とローカルのディレクトリ名が異なる場合に `NAME=` を指定する。

```bash
# Overleaf 名: "DC_2026_IIDA_free_proj"、ローカル名: "DC2026_IIDA"
make lleaf-pull PROJ=DC2026_IIDA PROJECTS_DIR=~/workspace/overleaf-projects NAME="DC_2026_IIDA_free_proj"
```

`NAME=` を省略した場合は `PROJ` の値が Overleaf プロジェクト名として使われる。

---

## 前提

- `latex-devkit` を clone 済み
- Premium の場合：Overleaf の git URL を手元に控えている
- Free の場合：`make lleaf-login` で認証済み

どちらの場合も、プロジェクトディレクトリを直接 `git clone` しない。  
入れ子 `.git` になり、Makefile や lleaf との相性が悪い。

---

## Premium ユーザー — Overleaf git remote を使う場合

Overleaf プロジェクトの Menu → Git から `https://git.overleaf.com/<PROJECT_ID>` を取得する。

### 初回 import

```bash
PROJ=my-paper
PROJECTS_DIR=~/workspace/overleaf-projects
OVERLEAF_URL=https://git.overleaf.com/<PROJECT_ID>

# 1. /tmp に clone してソースだけコピー
git clone "${OVERLEAF_URL}" /tmp/ol-import
mkdir -p ${PROJECTS_DIR}/${PROJ}
cp -r /tmp/ol-import/. ${PROJECTS_DIR}/${PROJ}/
rm -rf ${PROJECTS_DIR}/${PROJ}/.git /tmp/ol-import

# 2. 独立リポジトリとして初期化し overleaf remote を追加
cd ${PROJECTS_DIR}/${PROJ}
git init -b main
git remote add overleaf "${OVERLEAF_URL}"
git add .
git commit -m "initial import from overleaf"

# 3. GitHub にも push する場合（任意）
git remote add origin git@github.com:<user>/<repo>.git
git push -u origin main
```

### 以後の sync

```bash
# Overleaf → ローカル
cd ${PROJECTS_DIR}/${PROJ} && git pull overleaf main

# ローカル → Overleaf + GitHub（両方）
make git-push-all PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR} BRANCH=main
```

---

## Free ユーザー — lleaf を使う場合

### 初回 import

```bash
PROJ=my-paper
PROJECTS_DIR=~/workspace/overleaf-projects

# 1. プロジェクトディレクトリと .olignore を作成
mkdir -p ${PROJECTS_DIR}/${PROJ}
cat > ${PROJECTS_DIR}/${PROJ}/.olignore << 'EOF'
.git
.git/*
.vscode
.vscode/*
.gitignore
build
build/*
*.DS_Store
*.aux
*.bbl
*.bcf
*.blg
*.brf
*.dvi
*.fdb_latexmk
*.fls
*.lof
*.log
*.lot
*.nav
*.out
*.run.xml
*.snm
*.synctex.gz
*.toc
*.vrb
*.xdv
EOF

# 2. lleaf pull で Overleaf から取得
make lleaf-pull PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR}
# Overleaf 名がローカルディレクトリ名と異なる場合は NAME= を追加
make lleaf-pull PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR} NAME="Overleaf Project Name"
```

### 以後の sync

```bash
make lleaf-pull PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR}          # Overleaf → ローカル
make lleaf-push PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR}          # ローカル → Overleaf
make lleaf-download PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR}      # コンパイル済み PDF をダウンロード
```

`PROJECTS_DIR` を `.envrc` に書いておけば省略できる（前述）。

---

## ローカルビルド（Docker）を使いたい場合

どちらの import 方式でも、ローカルコンパイルに切り替えられる。

```bash
# texd コンテナを起動
make up

# VS Code 用設定を展開（LaTeX Workshop が texd 経由でビルドする）
make vscode-init PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR}

# コマンドラインからビルド
make build-local PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR} MAIN=main.tex

# ファイル監視ビルド（fswatch が必要）
make watch-local PROJ=${PROJ} PROJECTS_DIR=${PROJECTS_DIR} MAIN=main.tex
```
