# 80-plugins.zsh — must come AFTER compinit
#
# Plugin order matters:
#   1. zsh-autosuggestions
#   2. fzf-tab (optional, tap-installed)
#   3. zsh-syntax-highlighting — MUST be last

if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
    export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# fzf-tab — replaces standard tab completion menu with fzf
for _fzftab in \
    "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh" \
    "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh" \
    "$BREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"; do
    if [[ -f "$_fzftab" ]]; then
        source "$_fzftab"
        zstyle ':fzf-tab:*' fzf-flags '--height=60%' '--layout=reverse' '--border=rounded'
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always --level=2 $realpath 2>/dev/null'
        zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --line-range :200 $realpath 2>/dev/null || eza --tree --color=always $realpath 2>/dev/null'
        # fzf-tab v1.x exposes enable-fzf-tab; older versions auto-enable.
        command -v enable-fzf-tab &>/dev/null && enable-fzf-tab
        break
    fi
done
unset _fzftab

# Syntax highlighting — KEEP LAST
if [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
