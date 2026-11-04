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
    #
    # Unlike the others, `mise activate zsh` is NOT PATH-independent: it starts
    # with `export PATH='<the PATH it was generated under>'`, a literal. Cached,
    # that froze every shell's PATH to whatever shell last regenerated it, so
    # changes to 00-env.zsh never took effect: moving ~/.rd/bin behind brew was
    # silently undone right here (verified with `zsh -i -x`). The PATH it was
    # generated under is stored next to it and a mismatch regenerates, so the
    # cache only ever replays a PATH equal to the one already in place.
    _mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/mise/init.zsh"
    _mise_bin="$(whence -p mise 2>/dev/null)"
    _mise_key="${_mise_cache}.path"
    if [[ ! -e "$_mise_cache" || ( -n "$_mise_bin" && "$_mise_bin" -nt "$_mise_cache" ) \
          || ! -r "$_mise_key" || "$(<"$_mise_key")" != "$PATH" ]]; then
        [[ -d "${_mise_cache:h}" ]] || mkdir -p "${_mise_cache:h}"
        _mise_tmp="$(mktemp "${_mise_cache}.XXXXXX")"
        if mise activate zsh > "$_mise_tmp" 2>/dev/null; then
            mv -f "$_mise_tmp" "$_mise_cache"
        else
            rm -f "$_mise_tmp"
            : > "$_mise_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        print -rn -- "$PATH" > "$_mise_key"
        unset _mise_tmp
    fi
    [[ -s "$_mise_cache" ]] && source "$_mise_cache"
    unset _mise_cache _mise_bin _mise_key
fi
