# 初回プロジェクト import

Overleaf のプロジェクトを `projects/<name>/` に取り込む手順。
Premium（git clone 可）と Free（lleaf）でフローが分かれる。

## 前提

- `latex-devkit` を clone 済み（`WORKSPACE_ROOT` = latex-devkit ディレクトリ）
- Premium の場合：Overleaf の git URL を手元に控えている
- Free の場合：`make lleaf-login` で認証済み

どちらの場合も、プロジェクトディレクトリ（`projects/<name>/`）を直接 `git clone` しない。  
入れ子 `.git` になり、Makefile や lleaf との相性が悪い。

---

## Premium ユーザー — Overleaf git remote を使う場合

Overleaf プロジェクトの Menu → Git から `https://git.overleaf.com/<PROJECT_ID>` を取得する。

### 初回 import

```bash
PROJ=sita2025
OVERLEAF_URL=https://git.overleaf.com/<PROJECT_ID>

# 1. /tmp に clone してソースだけコピー
git clone "${OVERLEAF_URL}" /tmp/ol-import
mkdir -p projects/${PROJ}
cp -r /tmp/ol-import/. projects/${PROJ}/
rm -rf projects/${PROJ}/.git /tmp/ol-import

# 2. 独立リポジトリとして初期化し overleaf remote を追加
cd projects/${PROJ}
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
cd projects/${PROJ} && git pull overleaf main

# ローカル → Overleaf + GitHub（両方）
make git-push-all PROJ=${PROJ} BRANCH=main
```

---

## Free ユーザー — lleaf を使う場合

### 初回 import

```bash
PROJ=sita2025

# 1. プロジェクトディレクトリと .olignore を作成
mkdir -p projects/${PROJ}
cat > projects/${PROJ}/.olignore << 'EOF'
.git
.git/*
.gitignore
build
build/*
*.pdf
*.aux
*.log
*.out
*.toc
*.fls
*.fdb_latexmk
*.synctex.gz
__pycache__
__pycache__/*
EOF

# 2. lleaf pull で Overleaf から取得
#   NAME= は Overleaf 上のプロジェクト名がローカルディレクトリ名と異なる場合のみ指定
make lleaf-pull PROJ=${PROJ}
# または
make lleaf-pull PROJ=${PROJ} NAME="Overleaf Project Name"
```

### 以後の sync

```bash
make lleaf-pull PROJ=${PROJ}          # Overleaf → ローカル
make lleaf-push PROJ=${PROJ}          # ローカル → Overleaf
make lleaf-download PROJ=${PROJ}      # コンパイル済み PDF をダウンロード
```

---

## ローカルビルド（Docker）を使いたい場合

どちらの import 方式でも、ローカルコンパイルに切り替えられる。

```bash
# texd コンテナを起動
make up

# VS Code 用設定を展開（LaTeX Workshop が texd 経由でビルドする）
make vscode-init PROJ=${PROJ}

# コマンドラインからビルド
make build-local PROJ=${PROJ} MAIN=main.tex

# ファイル監視ビルド（fswatch が必要）
make watch-local PROJ=${PROJ} MAIN=main.tex
```
