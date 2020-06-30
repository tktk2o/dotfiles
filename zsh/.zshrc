export LANG=ja_JP.UTF-8

autoload -Uz compinit && compinit

setopt auto_cd

setopt complete_in_word

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# path
export PATH="$HOME/.jenv/bin:$PATH"

# init
eval "$(starship init zsh)"
eval "$(jenv init -)"
