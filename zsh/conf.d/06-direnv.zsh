# 06-direnv.zsh — per-directory env via .envrc
#
# Pairs with mise: mise reads .mise.toml / .tool-versions, direnv handles
# anything project-specific you want exported only inside that tree. Run
# `direnv allow` once per .envrc to whitelist it.

if command -v direnv &>/dev/null; then
    _direnv_cache="${XDG_CACHE_HOME:-$HOME/.cache}/direnv/init.zsh"
    _direnv_bin="$(whence -p direnv 2>/dev/null)"
    if [[ ! -e "$_direnv_cache" || ( -n "$_direnv_bin" && "$_direnv_bin" -nt "$_direnv_cache" ) ]]; then
        [[ -d "${_direnv_cache:h}" ]] || mkdir -p "${_direnv_cache:h}"
        _direnv_tmp="$(mktemp "${_direnv_cache}.XXXXXX")"
        if direnv hook zsh > "$_direnv_tmp" 2>/dev/null; then
            mv -f "$_direnv_tmp" "$_direnv_cache"
        else
            rm -f "$_direnv_tmp"
            : > "$_direnv_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _direnv_tmp
    fi
    [[ -s "$_direnv_cache" ]] && source "$_direnv_cache"
    unset _direnv_cache _direnv_bin
fi
