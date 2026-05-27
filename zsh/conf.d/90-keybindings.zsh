# 90-keybindings.zsh — explicit keymap configuration

bindkey -e                          # emacs keybindings
bindkey '^[[A' up-line-or-search    # ↑ prefix-search history
bindkey '^[[B' down-line-or-search  # ↓
bindkey '^[[1;5C' forward-word      # ctrl-→
bindkey '^[[1;5D' backward-word     # ctrl-←

# Edit current command line in $EDITOR with `Ctrl-X Ctrl-E`
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
