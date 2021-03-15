touch ../dists/zshrc
echo > ../dists/zshrc
rm -f ~/.zcompdump  # Clear zcomp cache

command ls ./zshrc.d/*.zsh       | sort | xargs cat >> ../dists/zshrc

zsh -n ../dists/zshrc # 文法チェック
zsh -c "zcompile ../dists/zshrc" # コンパイル
