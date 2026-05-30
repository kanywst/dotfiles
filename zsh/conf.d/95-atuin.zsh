# 95-atuin.zsh — magical history search; loaded LAST so it owns Ctrl-R.
#
# --disable-up-arrow keeps ↑ as zsh's prefix-search (set in 90-keybindings.zsh).
# Atuin handles Ctrl-R only.

if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
