# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
export LANG=ja_JP.UTF-8

# git
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)

autoload -Uz compinit && compinit

setopt auto_cd

setopt complete_in_word

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

# alias
alias ls='ls -G'
alias la='ls -A'

alias g='git'
alias gco='git checkout'
alias ga='git add ./'
alias gb='git branch'
alias gs='git status'
alias gc='git commit'
alias gr='git reset --hard HEAD'
alias gpum='git pull upstream main'
alias gpom='git push origin main'

alias v='nvim'

# init
eval "$(starship init zsh)"

# Added by serverless binary installer
export PATH="$HOME/.serverless/bin:$PATH"

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true
export PATH="/usr/local/opt/python@3.8/bin:$PATH"

export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

. /usr/local/opt/asdf/libexec/asdf.sh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/t/google-cloud-sdk/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/t/google-cloud-sdk/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/t/google-cloud-sdk/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/t/google-cloud-sdk/google-cloud-sdk/completion.zsh.inc'; fi

export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export ANDROID_HOME=$HOME/Library/Android/sdk

# exa
if [[ $(command -v exa) ]]; then
  alias ls='exa --icons --git'
  alias lt='exa -T -L 3 -a -I "node_modules|.git|.cache" --icons'
  alias ltl='exa -T -L 3 -a -I "node_modules|.git|.cache" -l --icons'
fi

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
