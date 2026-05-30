# 45-1password.zsh — point ssh-agent at 1Password if its agent socket exists.
#
# Requires the 1Password desktop app with "Use the SSH agent" enabled in
# Settings → Developer. Then `ssh-add -l` lists keys from your vault and
# git/ssh commands authenticate without a private key on disk.
#
# Set up once per repo to sign commits:
#   git config gpg.format ssh
#   git config user.signingkey "ssh-ed25519 AAAA…"  # public key from 1Password
#   git config gpg.ssh.program /Applications/1Password.app/Contents/MacOS/op-ssh-sign

if [[ -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi
