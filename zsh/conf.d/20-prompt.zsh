# 20-prompt.zsh — Starship.
# Config lives at ~/.config/starship.toml (stowed from starship/.config/) so
# starship picks it up via its default lookup; no env override needed.

command -v starship &>/dev/null && eval "$(starship init zsh)"
