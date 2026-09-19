# 95-atuin.zsh — magical history search; loaded LAST so it owns Ctrl-R.
#
# --disable-up-arrow keeps ↑ as zsh's prefix-search (set in 90-keybindings.zsh).
# Atuin handles Ctrl-R only.

if command -v atuin &>/dev/null; then
    # Cached like 06-direnv / 75-carapace. The cache key is the binary mtime, so
    # changing the flags above needs a one-off `rm` of the cache to take effect.
    _atuin_cache="${XDG_CACHE_HOME:-$HOME/.cache}/atuin/init.zsh"
    _atuin_bin="$(whence -p atuin 2>/dev/null)"
    if [[ ! -e "$_atuin_cache" || ( -n "$_atuin_bin" && "$_atuin_bin" -nt "$_atuin_cache" ) ]]; then
        [[ -d "${_atuin_cache:h}" ]] || mkdir -p "${_atuin_cache:h}"
        _atuin_tmp="$(mktemp "${_atuin_cache}.XXXXXX")"
        if atuin init zsh --disable-up-arrow > "$_atuin_tmp" 2>/dev/null; then
            mv -f "$_atuin_tmp" "$_atuin_cache"
        else
            rm -f "$_atuin_tmp"
            : > "$_atuin_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _atuin_tmp
    fi
    [[ -s "$_atuin_cache" ]] && source "$_atuin_cache"
    unset _atuin_cache _atuin_bin
fi
