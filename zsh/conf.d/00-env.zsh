# 00-env.zsh — XDG base dirs, locale, PATH, language envs

# XDG Base Directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Editor / locale
# unconditional: nix-darwin's /etc/zshenv exports EDITOR=nano before this, so ${EDITOR:-vim} would lose
export EDITOR=vim
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=1
export TERM="${TERM:-xterm-256color}"

# Cache `brew --prefix` (skip the 50-100ms spawn on every shell start)
if [[ -z "$BREW_PREFIX" ]] && command -v brew &>/dev/null; then
    export BREW_PREFIX="$(brew --prefix)"
fi
# A non-login shell may not have brew on PATH yet; without a prefix the whole
# 80-plugins stack no-ops. Fall back to the standard Apple-Silicon prefix.
if [[ -z "$BREW_PREFIX" && -d /opt/homebrew ]]; then
    export BREW_PREFIX="/opt/homebrew"
fi

# Homebrew: skip analytics ping and the auto-update on every `brew install`.
# nix-darwin owns reconciliation; manual `brew install` is just for trial runs.
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

# Auto-dedupe PATH
typeset -U path PATH

# Higher-priority entries first.
# Rancher Desktop's docker shim lives in ~/.rd/bin; keep before brew so `docker`
# resolves there if RD is running.
path=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "${KREW_ROOT:-$HOME/.krew}/bin"
    "$BREW_PREFIX/opt/openssl/bin"
    "$HOME/.yarn/bin"
    "$HOME/.config/yarn/global/node_modules/.bin"
    "$HOME/.rd/bin"
    $path
)

# Go — mise activate handles GOROOT/GOPATH; modern Go (>= 1.10) auto-detects
# GOROOT from the binary path, so don't pin it to brew's keg here.

# Ollama — keep model resident
export OLLAMA_KEEP_ALIVE="-1"

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
