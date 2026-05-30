# 75-carapace.zsh — multi-shell completion for 500+ CLIs.
#
# Loads AFTER 70-completions (compinit must run first) and BEFORE 80-plugins so
# fzf-tab wraps the menu carapace generates.
#
# Bridges fall back to native completions for any command carapace doesn't ship
# a spec for. Disable a bridge by removing it from CARAPACE_BRIDGES.

if command -v carapace &>/dev/null; then
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
    # Cache the generated init script so shell startup doesn't spawn carapace.
    _carapace_cache="${XDG_CACHE_HOME:-$HOME/.cache}/carapace/init.zsh"
    # `-e` (existence) — not `-s` (size) — so an empty failure-sentinel
    # doesn't cause a retry every shell startup. The binary mtime check
    # re-triggers regeneration after a real carapace upgrade.
    if [[ ! -e "$_carapace_cache" || "$commands[carapace]" -nt "$_carapace_cache" ]]; then
        [[ -d "${_carapace_cache:h}" ]] || mkdir -p "${_carapace_cache:h}"
        # Atomic write: protects against half-written cache on Ctrl-C.
        _carapace_tmp="$(mktemp "${_carapace_cache}.XXXXXX")"
        if carapace _carapace zsh > "$_carapace_tmp"; then
            mv -f "$_carapace_tmp" "$_carapace_cache"
        else
            rm -f "$_carapace_tmp"
            : > "$_carapace_cache"   # sentinel: tried & failed; don't retry
        fi
        unset _carapace_tmp
    fi
    [[ -s "$_carapace_cache" ]] && source "$_carapace_cache"
    unset _carapace_cache
fi
