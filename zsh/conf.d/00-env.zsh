# 00-env.zsh — XDG base dirs, locale, PATH, language envs

# XDG Base Directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Editor / locale
export EDITOR="${EDITOR:-vim}"
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=1
export TERM="${TERM:-xterm-256color}"

# Cache `brew --prefix` (skip the 50-100ms spawn on every shell start)
if [[ -z "$BREW_PREFIX" ]] && command -v brew &>/dev/null; then
    export BREW_PREFIX="$(brew --prefix)"
fi

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

# Go
export GOROOT="$BREW_PREFIX/opt/golang/libexec"

# Ollama — keep model resident
export OLLAMA_KEEP_ALIVE="-1"

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
