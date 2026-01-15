# source .zshrc
alias sz='source ~/.zshrc'

# ==============================================================================
# ENVIRONMENT VARIABLES & PATHS
# ==============================================================================

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Enable colors in the terminal
export CLICOLOR=1
export TERM=xterm-256color

# OpenSSL
export PATH=$(brew --prefix openssl)/bin:$PATH

# Go
export GOROOT="$(brew --prefix golang)/libexec"
export PATH="$PATH:$HOME/go/bin/"

# Rancher Desktop
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Yarn
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Istio
export PATH="$PATH:$HOME/istio/example/istio-1.28.0/bin"

# Wasmtime
export WASMTIME_HOME="$HOME/.wasmtime"
export PATH="$WASMTIME_HOME/bin:$PATH"

# Golang
export PATH="$PATH:$HOME/go/bin"

# ==============================================================================
# PROMPT & THEME (Starship)
# ==============================================================================

# Use custom starship config in dotfiles
export STARSHIP_CONFIG="$HOME/dotfiles/config/starship.toml"

# Initialize starship
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# NOTE: kube-ps1 is disabled in favor of Starship's kubernetes module.
# source "/opt/homebrew/opt/kube-ps1/share/kube-ps1.sh"
# PS1='$(kube_ps1)'$PS1

# ==============================================================================
# PLUGINS
# ==============================================================================

# Syntax highlighting (brew)
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Auto-suggestions (brew) - SUGGESTED
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Zoxide (Smart directory navigation) - SUGGESTED
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd='z'
fi

# Initialize completion system
autoload -Uz compinit
compinit

# Kubernetes kubectl autocompletion
if command -v kubectl &> /dev/null; then
    compdef _kubectl kubectl
fi

# ==============================================================================
# ALIASES & TOOLS
# ==============================================================================

# Kubernetes
alias k='kubectl'
alias ktx='kubectx'
alias kns='kubens'
alias kk='kubectl krew'

# Docker
alias d='docker'

# Modern Replacements (eza for ls, bat for cat)
if command -v eza &> /dev/null; then
    alias ls='eza --icons --git'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias tree='eza --tree --icons'
fi

if command -v bat &> /dev/null; then
    alias cat='bat'
fi

# FZF
alias fzfv='vim $(fzf)'
alias fzfg='git checkout $(git branch | fzf)'
alias fzfk='kill -9 $(ps aux | fzf | awk "{print \$2}")'
alias fzfd='cd $(find * -type d | fzf)'
alias fzff='find . -type f | fzf'

# export FZF_DEFAULT_OPTS='--height 60% --reverse --border --exact'

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {}"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# GHQ & Git
alias g='cd $(ghq list -p | fzf --preview "cat {}/README.md")'
alias gco='gh pr checkout $(gh pr list | fzf | awk "{ print \$1 }")'
alias gcs='git commit -s'

# Gemini
alias gemini-init='gemini "ls -R で構造を把握し、主要な設定ファイルを読み取った上で GEMINI.md を作成して。その際、プロジェクトの主要な処理フロー（例：リクエストからレスポンスまで）を把握し、Mermaid形式のシーケンス図（sequenceDiagram）を必ず含めて。回答は不要、ファイル保存のみ実行して。"'
