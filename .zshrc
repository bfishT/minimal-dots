
# The following lines were added by compinstall
zstyle :compinstall filename '/home/zxf/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
# End of lines configured by zsh-newuser-install

# --- dotfiles 备份别名 (dotsave/dotrestore) ---
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias dsave='dotsave'
alias drestore='dotrestore'
# ---------------------------------------------
