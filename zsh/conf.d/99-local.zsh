# 99-local.zsh — IDE shell integration + machine-local overrides

# Kiro IDE
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# Local overrides (secrets, machine-specific) — gitignored, not tracked.
# Put API keys / personal env vars in ~/.zshrc.local — see README.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
