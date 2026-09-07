# latex-devkit のビルド既定値。
#
# 各ビルドは `latexmk -norc -r <このファイル> -r latexmkrc` の順で読まれる。
# latexmk は -r をコマンドライン上の順序で処理するため、ここでの設定は
# プロジェクトの latexmkrc が同じ変数を書けば上書きされる。
# 「デフォルトはここ、プロジェクトが明示したらそちらが正」という関係になる。
#
# ここに置いてよいのは全プロジェクトに共通の既定値だけ。
# エンジン（platex / lualatex 等）や $force_mode はプロジェクト固有の
# 判断なので、各プロジェクトの latexmkrc が持つ。

# 生成物の置き場所。プロジェクト直下を中間ファイルで汚さない。
$out_dir = 'output';

# $out_dir がサブディレクトリのとき、pbibtex / bibtex はそこを cwd として
# 走るため、プロジェクト直下の refs.bib を見つけられない。
# $out_dir を既定にする以上、この設定は対で必要になる。
$ENV{'BIBINPUTS'} = '..:' . ($ENV{'BIBINPUTS'} // '');
