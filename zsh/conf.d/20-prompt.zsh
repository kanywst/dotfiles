# 20-prompt.zsh — Starship.
# Config lives at ~/.config/starship.toml (stowed from starship/.config/) so
# starship picks it up via its default lookup; no env override needed.

if command -v starship &>/dev/null; then
    # Cached like 06-direnv / 75-carapace. Only the *init* script is cached --
    # starship.toml is still read by the starship binary on every prompt, so
    # editing the theme takes effect immediately without clearing this.
    _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship/init.zsh"
    _starship_bin="$(whence -p starship 2>/dev/null)"
    if [[ ! -e "$_starship_cache" || ( -n "$_starship_bin" && "$_starship_bin" -nt "$_starship_cache" ) ]]; then
        [[ -d "${_starship_cache:h}" ]] || mkdir -p "${_starship_cache:h}"
        _starship_tmp="$(mktemp "${_starship_cache}.XXXXXX")"
        if starship init zsh > "$_starship_tmp" 2>/dev/null; then
            mv -f "$_starship_tmp" "$_starship_cache"
        else
            rm -f "$_starship_tmp"
            : > "$_starship_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _starship_tmp
    fi
    [[ -s "$_starship_cache" ]] && source "$_starship_cache"
    unset _starship_cache _starship_bin
fi
