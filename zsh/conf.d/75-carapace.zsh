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
    source <(carapace _carapace zsh)
fi
