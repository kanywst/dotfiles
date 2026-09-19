# 05-mise.zsh — unified runtime version manager (node/python/go/rust/etc)
#
# Replaces NVM/nodebrew/pyenv-virtualenv. nvm/pyenv stay installed but are not
# loaded into the shell. Bootstrap a runtime with:
#
#   mise use -g node@lts python@3.13 go@latest
#
# If mise is missing, brew-installed node/python provide fallbacks.

if command -v mise &>/dev/null; then
    # Cache the activation script; same idiom as 06-direnv / 75-carapace.
    # Measured 2026-09-19: `mise activate zsh` cost ~20ms of a ~170ms startup.
    _mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/mise/init.zsh"
    _mise_bin="$(whence -p mise 2>/dev/null)"
    if [[ ! -e "$_mise_cache" || ( -n "$_mise_bin" && "$_mise_bin" -nt "$_mise_cache" ) ]]; then
        [[ -d "${_mise_cache:h}" ]] || mkdir -p "${_mise_cache:h}"
        _mise_tmp="$(mktemp "${_mise_cache}.XXXXXX")"
        if mise activate zsh > "$_mise_tmp" 2>/dev/null; then
            mv -f "$_mise_tmp" "$_mise_cache"
        else
            rm -f "$_mise_tmp"
            : > "$_mise_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _mise_tmp
    fi
    [[ -s "$_mise_cache" ]] && source "$_mise_cache"
    unset _mise_cache _mise_bin
fi
