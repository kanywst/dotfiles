# 05-mise.zsh — unified runtime version manager (node/python/go/rust/etc)
#
# Replaces NVM/nodebrew/pyenv-virtualenv. nvm/pyenv stay installed but are not
# loaded into the shell. Bootstrap a runtime with:
#
#   mise use -g node@lts python@3.13 go@latest
#
# If mise is missing, brew-installed node/python provide fallbacks.

if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi
