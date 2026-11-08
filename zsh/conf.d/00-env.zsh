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
# 80-plugins stack no-ops. Fall back to the standard Apple-Silicon prefix, and
# since path_helper (/etc/zprofile) was skipped too, put brew's bins on PATH.
if [[ -z "$BREW_PREFIX" && -d /opt/homebrew ]]; then
    export BREW_PREFIX="/opt/homebrew"
    path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" $path)
fi

# Homebrew: skip analytics ping and the auto-update on every `brew install`.
# nix-darwin owns reconciliation; manual `brew install` is just for trial runs.
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

# Auto-dedupe PATH
typeset -U path PATH

# Higher-priority entries first.
# Rancher Desktop's ~/.rd/bin goes LAST, not first. It is load-bearing for
# `docker`/`nerdctl`/`docker compose`, which nothing else on PATH provides, so
# appending keeps those working. But it also ships its own kubectl and helm,
# and in front of brew those won: the shell ran RD's kubectl 1.37.0 / helm 4.2.3
# while flake.nix declares, and bump upgrades, brew's 1.37.2 / 4.3.1.
# Dropped from the inherited PATH first: `typeset -U` keeps the FIRST copy, so a
# nested shell (or `exec zsh`) inheriting the old order would keep RD in front.
path=(${path:#$HOME/.rd/bin})
path=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "${KREW_ROOT:-$HOME/.krew}/bin"
    "$BREW_PREFIX/opt/openssl/bin"
    "$HOME/.yarn/bin"
    "$HOME/.config/yarn/global/node_modules/.bin"
    $path
    "$HOME/.rd/bin"
)

# Go — mise activate handles GOROOT/GOPATH; modern Go (>= 1.10) auto-detects
# GOROOT from the binary path, so don't pin it to brew's keg here.

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
