# 06-direnv.zsh — per-directory env via .envrc
#
# Pairs with mise: mise reads .mise.toml / .tool-versions, direnv handles
# anything project-specific you want exported only inside that tree. Run
# `direnv allow` once per .envrc to whitelist it.

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi
