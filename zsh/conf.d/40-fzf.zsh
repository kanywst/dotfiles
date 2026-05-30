# 40-fzf.zsh — fzf integration

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || eza --tree --color=always {} 2>/dev/null"
  --preview-window=right:60%:wrap
  --bind "ctrl-/:toggle-preview"
  --bind "ctrl-d:half-page-down,ctrl-u:half-page-up"
'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="$FZF_DEFAULT_OPTS"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS='--preview "eza --tree --color=always --level=2 {}"'

# fzf shell integration. Modern fzf (>= 0.48) ships everything via `fzf --zsh`;
# fall back to brew's shell scripts on older installs. Ctrl-T file, Alt-C cd;
# Ctrl-R is later handed to Atuin.
if command -v fzf &>/dev/null && fzf --zsh &>/dev/null; then
    source <(fzf --zsh)
elif [[ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
    source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
    source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi
