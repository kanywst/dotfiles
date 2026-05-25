# ==============================================================================
# .zshrc — 2026 modernized setup (kanywst/dotfiles)
# Layout: env → options → prompt → modern tools → fzf → aliases → functions →
#         completions → plugins → atuin (last) → local overrides
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. XDG BASE DIRECTORIES
# ------------------------------------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT & PATH
# ------------------------------------------------------------------------------
export EDITOR="${EDITOR:-vim}"
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=1
export TERM=xterm-256color

# Cache `brew --prefix` (avoid the 50-100ms hit on every shell start)
if [[ -z "$BREW_PREFIX" ]] && command -v brew &>/dev/null; then
    export BREW_PREFIX="$(brew --prefix)"
fi

# Auto-dedupe PATH
typeset -U path PATH

# Higher-priority entries first
path=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "${KREW_ROOT:-$HOME/.krew}/bin"
    "$BREW_PREFIX/opt/openssl/bin"
    "$HOME/.yarn/bin"
    "$HOME/.config/yarn/global/node_modules/.bin"
    "$HOME/istio/example/istio-1.28.0/bin"
    "$HOME/.wasmtime/bin"
    "/Users/user/.rd/bin"
    $path
)

# Go
export GOROOT="$BREW_PREFIX/opt/golang/libexec"

# Wasmtime
export WASMTIME_HOME="$HOME/.wasmtime"

# Ollama
export OLLAMA_KEEP_ALIVE="-1"

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# NVM — lazy load (saves ~1s on shell startup)
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
}
node() { unset -f node; nvm >/dev/null; node "$@"; }
npm()  { unset -f npm;  nvm >/dev/null; npm  "$@"; }
npx()  { unset -f npx;  nvm >/dev/null; npx  "$@"; }

# ------------------------------------------------------------------------------
# 2. ZSH OPTIONS & HISTORY
# ------------------------------------------------------------------------------
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

setopt EXTENDED_HISTORY          # timestamp each entry
setopt HIST_EXPIRE_DUPS_FIRST    # purge oldest dupes when overflowing
setopt HIST_IGNORE_DUPS          # don't store immediate duplicate
setopt HIST_IGNORE_ALL_DUPS      # remove older duplicates
setopt HIST_IGNORE_SPACE         # ignore lines starting with space (secret-friendly)
setopt HIST_FIND_NO_DUPS         # no dupes in incremental search
setopt HIST_REDUCE_BLANKS        # trim extra blanks
setopt HIST_VERIFY               # confirm history expansion before exec
setopt SHARE_HISTORY             # share history across panes
setopt INC_APPEND_HISTORY        # write immediately, not on shell exit

# Navigation
setopt AUTO_CD                   # `dirname` → `cd dirname`
setopt AUTO_PUSHD                # cd pushes onto dirstack
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Globbing
setopt EXTENDED_GLOB
setopt GLOB_DOTS                 # include hidden in glob matches
setopt NUMERIC_GLOB_SORT

# Misc
setopt INTERACTIVE_COMMENTS      # allow `#` comments at prompt
setopt NO_BEEP
setopt PROMPT_SUBST

# ------------------------------------------------------------------------------
# 3. PROMPT (Starship)
# ------------------------------------------------------------------------------
export STARSHIP_CONFIG="$HOME/dotfiles/config/starship.toml"
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ------------------------------------------------------------------------------
# 4. MODERN CLI REPLACEMENTS
# ------------------------------------------------------------------------------

# Zoxide (smarter cd — `z foo` jumps by frecency; `zi` interactive)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# Eza (modern ls)
if command -v eza &>/dev/null; then
    alias ls='eza --icons --git'
    alias ll='eza -l  --icons --git --group-directories-first --time-style=long-iso'
    alias la='eza -la --icons --git --group-directories-first --time-style=long-iso'
    alias lt='eza --tree --level=2 --icons --git'
    alias ltt='eza --tree --level=3 --icons --git'
    alias tree='eza --tree --icons'
fi

# Bat (modern cat)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export BAT_THEME="TwoDark"
fi

# delta (handled in gitconfig; quick stand-alone diff)
command -v delta &>/dev/null && alias diff='delta'

# btop (modern top)
command -v btop &>/dev/null && alias top='btop'

# ------------------------------------------------------------------------------
# 5. FZF
# ------------------------------------------------------------------------------
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || eza --tree --color=always {} 2>/dev/null"
  --preview-window=right:60%:wrap
  --bind "ctrl-/:toggle-preview"
  --bind "ctrl-d:half-page-down,ctrl-u:half-page-up"
'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="$FZF_DEFAULT_OPTS"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS='--preview "eza --tree --color=always --level=2 {}"'

# Homebrew fzf shell bindings (Ctrl-T file, Alt-C cd, Ctrl-R history)
if [[ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
    source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
    source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi

# ------------------------------------------------------------------------------
# 6. ALIASES — Navigation
# ------------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'
alias home='cd ~'

# ------------------------------------------------------------------------------
# 7. ALIASES — Git
# ------------------------------------------------------------------------------
# Status / log
alias gs='git status -sb'
alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias glo='git log --oneline -20'

# Stage / commit
alias ga='git add'
alias gap='git add -p'
alias gc='git commit'
alias gcm='git commit -m'
alias gcs='git commit -s'           # signed-off-by
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

# Diff
alias gd='git diff'
alias gdc='git diff --cached'

# Branch / switch / restore (modern git)
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gswc='git switch -c'
alias gb='git branch'
alias gbd='git branch -d'
alias grs='git restore'
alias grss='git restore --staged'

# Sync
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull --rebase'
alias gfa='git fetch --all --prune'

# Stash
alias gss='git stash'
alias gsp='git stash pop'

# Worktree
alias gwl='git worktree list'

# lazygit (TUI)
command -v lazygit &>/dev/null && alias lg='lazygit'

# GitHub CLI
alias ghco='gh pr checkout $(gh pr list | fzf | awk "{ print \$1 }")'   # was `gco`
alias ghpr='gh pr create --web'
alias ghprl='gh pr list'
alias ghprv='gh pr view --web'

# ghq + fzf — jump to a repo
alias repo='cd $(ghq list -p | fzf --preview "eza --tree --level=2 --color=always {} 2>/dev/null || ls -la {}")'
alias g='repo'   # preserves your `g` muscle memory (ghq jump)

# Legacy fzf-git pickers (preserved)
alias fzfv='${EDITOR} $(fzf)'
alias fzfg='git checkout $(git branch | fzf)'
alias fzfk='kill -9 $(ps aux | fzf | awk "{print \$2}")'
alias fzfd='cd $(find * -type d | fzf)'
alias fzff='find . -type f | fzf'
alias lf='${EDITOR} $(ls -1 | fzf)'
alias cf='cd $(find . -type d | fzf)'

# ------------------------------------------------------------------------------
# 8. ALIASES — Docker / Podman
# ------------------------------------------------------------------------------
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcb='docker compose build'
alias dcr='docker compose restart'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dprune='docker system prune -af --volumes'

command -v podman &>/dev/null && alias p='podman'

# ------------------------------------------------------------------------------
# 9. ALIASES — Kubernetes
# ------------------------------------------------------------------------------
if command -v kubecolor &>/dev/null; then
    alias kubectl='kubecolor'
    alias k='kubecolor'
else
    alias k='kubectl'
fi

# Context / namespace
alias ktx='kubectx'
alias kns='kubens'
alias kkn='kubectl config set-context --current --namespace'  # `kkn default`
alias kk='kubectl krew'

# get
alias kgp='k get pods'
alias kgpa='k get pods -A'
alias kgs='k get svc'
alias kgd='k get deployment'
alias kgi='k get ingress'
alias kgn='k get nodes'
alias kga='k get all'
alias kge='k get events --sort-by=.lastTimestamp'

# describe
alias kdp='k describe pod'
alias kds='k describe svc'
alias kdd='k describe deployment'

# logs
alias kl='k logs'
alias klf='k logs -f'
alias klp='k logs --previous'

# exec / port-forward
alias kex='k exec -it'
alias kpf='k port-forward'

# apply / delete
alias kaf='k apply -f'
alias kdf='k delete -f'

# watch pods
alias kw='watch -n1 -d kubectl get pods'

# k9s TUI
command -v k9s &>/dev/null && alias k9='k9s'

# ------------------------------------------------------------------------------
# 10. ALIASES — System / macOS
# ------------------------------------------------------------------------------
alias h='history'
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
alias myip='curl -s ifconfig.me; echo'
alias localip='ipconfig getifaddr en0'
alias reload='exec zsh -l'
alias sz='source ~/.zshrc'
alias ez='${EDITOR} ~/dotfiles/zsh/.zshrc'

# macOS
alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO  && killall Finder'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias pbjson='pbpaste | jq . | pbcopy && echo "✓ formatted JSON in clipboard"'

# ------------------------------------------------------------------------------
# 11. ALIASES — Misc tools
# ------------------------------------------------------------------------------
command -v glow &>/dev/null && alias md='glow'

# Gemini
alias gemini-init='gemini "ls -R で構造を把握し、主要な設定ファイルを読み取った上で GEMINI.md を作成して。その際、プロジェクトの主要な処理フロー（例：リクエストからレスポンスまで）を把握し、Mermaid形式のシーケンス図（sequenceDiagram）を必ず含めて。回答は不要、ファイル保存のみ実行して。"'

# Antigravity launcher (CLI launcher symlink is dead; use `open -a`)
avg() { open -a Antigravity "${@:-.}"; }

# ------------------------------------------------------------------------------
# 12. FUNCTIONS
# ------------------------------------------------------------------------------

# mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extract any archive
extract() {
    if [[ ! -f "$1" ]]; then
        echo "extract: '$1' is not a valid file" >&2
        return 1
    fi
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz)         tar xJf "$1" ;;
        *.tar)            tar xf  "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip  "$1" ;;
        *.zip)            unzip   "$1" ;;
        *.7z)             7z x    "$1" ;;
        *.rar)            unrar x "$1" ;;
        *) echo "extract: unknown archive type '$1'" >&2; return 1 ;;
    esac
}

# Find process listening on a port: `port 3000`
port() {
    if [[ -z "$1" ]]; then echo "usage: port <number>" >&2; return 1; fi
    lsof -nP -iTCP:"$1" -sTCP:LISTEN
}

# Kill whatever is on a port: `killport 3000`
killport() {
    local pid
    pid="$(lsof -ti tcp:"$1")"
    if [[ -n "$pid" ]]; then
        kill -9 "$pid" && echo "killed $pid on :$1"
    else
        echo "nothing on :$1"
    fi
}

# Quick .gitignore from gitignore.io: `gi macos,node,python > .gitignore`
gi() {
    curl -sL "https://www.toptal.com/developers/gitignore/api/$*"
}

# fzf-powered process killer
fkill() {
    local pid
    pid="$(ps -ef | sed 1d | fzf -m --header='[kill:process]' | awk '{print $2}')"
    [[ -n "$pid" ]] && echo "$pid" | xargs kill -"${1:-9}"
}

# fzf git-branch checkout with log preview
gcof() {
    local branch
    branch="$(git branch --all | sed 's/^[* ]*//;s|^remotes/origin/||' | sort -u \
        | fzf --preview 'git log --oneline --color=always {} | head -30')"
    [[ -n "$branch" ]] && git checkout "$branch"
}

# fzf worktree jump
gwt() {
    local wt
    wt="$(git worktree list | fzf | awk '{print $1}')"
    [[ -n "$wt" ]] && cd "$wt"
}

# fzf-pick a pod and exec into it
kex-fzf() {
    local pod
    pod="$(kubectl get pods --no-headers | fzf | awk '{print $1}')"
    [[ -n "$pod" ]] && kubectl exec -it "$pod" -- /bin/sh
}

# fzf-pick a pod and tail logs
klog-fzf() {
    local pod
    pod="$(kubectl get pods --no-headers | fzf | awk '{print $1}')"
    [[ -n "$pod" ]] && kubectl logs -f "$pod"
}

# ------------------------------------------------------------------------------
# 13. COMPLETIONS
# ------------------------------------------------------------------------------
autoload -Uz compinit
# Speed up: only rebuild compdump once a day
if [[ -n "$ZSH_COMPDUMP" ]]; then
    :
else
    ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
    [[ -d "${ZSH_COMPDUMP:h}" ]] || mkdir -p "${ZSH_COMPDUMP:h}"
fi
if [[ -n "$ZSH_COMPDUMP"(#qN.mh+24) ]]; then
    compinit -d "$ZSH_COMPDUMP"
else
    compinit -C -d "$ZSH_COMPDUMP"
fi

# Case-insensitive, partial-word, substring completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%B-- %d --%b%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# kubecolor → reuse kubectl completion
command -v kubecolor &>/dev/null && compdef kubecolor=kubectl

# ------------------------------------------------------------------------------
# 14. PLUGINS (autosuggestions, syntax-highlighting — must come after compinit)
# ------------------------------------------------------------------------------
if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
    export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Optional: fzf-tab (if installed via `brew install fzf-tab` clone)
if [[ -f "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh"
fi

# Syntax highlighting — MUST BE LAST plugin
if [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ------------------------------------------------------------------------------
# 15. KEY BINDINGS
# ------------------------------------------------------------------------------
bindkey -e                       # emacs keybindings (default; explicit)
bindkey '^[[A' up-line-or-search   # ↑ search history by prefix
bindkey '^[[B' down-line-or-search # ↓
bindkey '^[[1;5C' forward-word     # ctrl-→
bindkey '^[[1;5D' backward-word    # ctrl-←

# Edit current command line in $EDITOR with `Ctrl-X Ctrl-E`
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ------------------------------------------------------------------------------
# 16. ATUIN (Ctrl-R magical history) — LAST so it owns bindings
# ------------------------------------------------------------------------------
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# ------------------------------------------------------------------------------
# 17. IDE / EDITOR SHELL INTEGRATION
# ------------------------------------------------------------------------------
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# ------------------------------------------------------------------------------
# 18. LOCAL OVERRIDES (secrets, machine-specific) — gitignored, not tracked
# ------------------------------------------------------------------------------
# Put API keys / personal env vars in ~/.zshrc.local — see README.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
