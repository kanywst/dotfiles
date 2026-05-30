# ==============================================================================
# .zshrc — kanywst/dotfiles (2026)
#
# This file is a thin loader. Real configuration lives in conf.d/, sourced in
# lexical order so the prefix number controls precedence:
#
#   00-env          XDG dirs, locale, PATH, language envs
#   05-mise         unified runtime version manager
#   06-direnv       per-directory .envrc loader
#   10-options      zsh options & history
#   20-prompt       Starship
#   30-modern-cli   eza/bat/delta/btop/xh/yazi/zellij/sg
#   40-fzf          fzf + Ctrl-T / Alt-C bindings (Ctrl-R later)
#   50-aliases      nav/git/docker/k8s/system
#   60-functions
#   70-completions  compinit (rebuilds at most once a day)
#   80-plugins      autosuggestions, fzf-tab, syntax-highlighting (last)
#   90-keybindings
#   95-atuin        Ctrl-R history search (loaded last to own the bind)
#   99-local        IDE integration + ~/.zshrc.local
# ==============================================================================

DOTFILES_ZSH_DIR="${DOTFILES_ZSH_DIR:-$HOME/dotfiles/zsh}"

if [[ -d "$DOTFILES_ZSH_DIR/conf.d" ]]; then
    for _conf in "$DOTFILES_ZSH_DIR/conf.d"/*.zsh(N); do
        source "$_conf"
    done
    unset _conf
fi
