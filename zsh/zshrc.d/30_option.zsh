### Shell Option ###
setopt auto_cd              # cd省略
setopt auto_pushd           # cdした内容を自動でpushdしてストックしてくれる
setopt auto_menu            # Tabで補完候補を表示
setopt auto_param_keys      # 括弧の対応などを自動補完
setopt auto_param_slash     # ディレクトリ名の補完で末尾に/自動で追加
setopt pushd_ignore_dups    # pushdしたディレクトリの重複を古い順から削除
setopt hist_ignore_dups     # 同じコマンドが続いた場合保存しない
setopt hist_ignore_all_dups # 履歴を古い順から削除
setopt hist_reduce_blanks   # 余分な空白を詰めて記録する
setopt ignoreeof            # C-Dでログアウトするのを防ぐ
setopt share_history        # 開いている端末間で同期する
setopt correct              # ミスタイプを修正してくれる
setopt extended_glob        # glob拡張
setopt prompt_subst         # プロンプト表示時毎に変数を展開する
setopt print_eight_bit      # 日本語ファイル名を表示させる
setopt equals               # =をwhichと同義にする
setopt no_beep              # Beep音を鳴らさない
setopt complete_aliases     # エイリアスを補完する

