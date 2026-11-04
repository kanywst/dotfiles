# 05-mise.zsh — unified runtime version manager (node/python/go/rust/etc)
#
# Replaces NVM/nodebrew/pyenv-virtualenv (nodebrew and pyenv-virtualenv were
# uninstalled 2026-11-04). nvm/pyenv stay installed but are not
# loaded into the shell. Bootstrap a runtime with:
#
#   mise use -g node@lts python@3.13 go@latest
#
# If mise is missing, brew-installed node/python provide fallbacks.

if command -v mise &>/dev/null; then
    # Cache the activation script; same idiom as 06-direnv / 75-carapace.
    # Measured 2026-09-19: `mise activate zsh` cost ~20ms of a ~170ms startup.
    #
    # Unlike the others, `mise activate zsh` is NOT PATH-independent: it emits
    # `export PATH='<the PATH it was generated under>'` literals (one dropping a
    # previous session's tool dirs, one putting the shims first). Cached as-is,
    # that froze every shell's PATH to whatever shell last regenerated it, so
    # changes to 00-env.zsh never took effect: moving ~/.rd/bin behind brew was
    # silently undone right here (verified with `zsh -i -x`). Each literal is
    # rewritten into the same operation done on the live PATH, so the cache
    # holds no PATH at all and needs no per-PATH key (a key raced between
    # shells starting at once, and nested shells kept regenerating it).
    _mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/mise/init.zsh"
    _mise_bin="$(whence -p mise 2>/dev/null)"
    _mise_self="${(%):-%x}"
    _mise_data="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
    if [[ ! -e "$_mise_cache" || ( -n "$_mise_bin" && "$_mise_bin" -nt "$_mise_cache" ) \
          || "$_mise_self" -nt "$_mise_cache" || "$(<"$_mise_cache")" == *"export PATH='"* ]]; then
        [[ -d "${_mise_cache:h}" ]] || mkdir -p "${_mise_cache:h}"
        _mise_tmp="$(mktemp "${_mise_cache}.XXXXXX")"
        if _mise_raw="$(mise activate zsh 2>/dev/null)"; then
            for _mise_line in "${(@f)_mise_raw}"; do
                if [[ "$_mise_line" == "export PATH='$_mise_data/shims:"* ]]; then
                    print -r -- '__mise_fix_path shims'
                elif [[ "$_mise_line" == "export PATH='"* ]]; then
                    print -r -- '__mise_fix_path'
                else
                    print -r -- "$_mise_line"
                fi
            done > "$_mise_tmp"
            mv -f "$_mise_tmp" "$_mise_cache"   # rename: a concurrent shell never sees half a file
        else
            rm -f "$_mise_tmp"
            : > "$_mise_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _mise_tmp _mise_raw _mise_line
    fi
    # What the literals did, on the live PATH: drop mise's per-tool install dirs
    # (hook-env adds back the ones this directory wants), and with `shims` put
    # the shims dir first.
    __mise_fix_path() {
        local d="$_mise_data"
        path=(${path:#$d/installs/*})
        [[ "$1" == shims ]] && path=("$d/shims" ${path:#$d/shims})
    }
    [[ -s "$_mise_cache" ]] && source "$_mise_cache"
    unset -f __mise_fix_path
    unset _mise_cache _mise_bin _mise_self _mise_data
fi
