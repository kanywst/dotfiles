#!/usr/bin/env bash
# install.sh — stow-based dotfiles installer.
#
# Each subdirectory listed in $STOW_PACKAGES is treated as a stow package whose
# contents mirror $HOME. Run from any directory; uses $0 to locate the repo.
#
# Usage:
#   ./install.sh              # link everything
#   ./install.sh --restow     # unlink & relink (recover from drift)
#   ./install.sh --delete     # unlink everything (uninstall)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=(zsh git starship atuin ghostty jj aerospace karabiner bin homebrew)

# Homebrew resolves its trust store to "$XDG_CONFIG_HOME/homebrew/trust.json",
# but the nix-darwin activation runs `brew bundle` under
# `sudo --set-home env ...`, which drops XDG_CONFIG_HOME, so there brew reads
# and *writes* ~/.homebrew/trust.json instead. Both paths have to reach the one
# file this repo tracks, and both have to be writable: `brew bundle` records
# every `trusted: true` Brewfile entry by rewriting the store.
#
# Homebrew's write_trust_store() follows exactly one symlink and refuses if what
# it lands on is another symlink ("Refusing to write insecure trust store:
# target is a symlink"). So ~/.homebrew/trust.json cannot be stowed: stow would
# point it at a symlink inside the repo, a two-hop chain that aborts the brew
# step of every `darwin-rebuild switch`. Shipping two real copies instead just
# trades the abort for silent drift, since each context writes only its own
# copy. One regular file, one direct symlink.
BREW_TRUST_FILE="$DOTFILES_DIR/homebrew/.config/homebrew/trust.json"
BREW_TRUST_ALIAS="$HOME/.homebrew/trust.json"

err()  { printf '\e[31m✗\e[0m %s\n' "$*" >&2; }
info() { printf '\e[34m▸\e[0m %s\n' "$*"; }
ok()   { printf '\e[32m✓\e[0m %s\n' "$*"; }

require_stow() {
    if ! command -v stow &>/dev/null; then
        info "GNU stow not found; attempting 'brew install stow'..."
        if command -v brew &>/dev/null; then
            brew install stow
        else
            err "Homebrew not available. Install stow manually: https://www.gnu.org/software/stow/"
            exit 1
        fi
    fi
}

# Move aside conflicting non-symlink files so stow can take over.
adopt_conflicts() {
    local pkg="$1"
    while IFS= read -r -d '' src; do
        local rel="${src#"$DOTFILES_DIR/$pkg/"}"
        local target="$HOME/$rel"
        if [[ -e "$target" && ! -L "$target" ]]; then
            info "Backing up $target → $target.backup"
            mv "$target" "$target.backup"
        elif [[ -L "$target" ]]; then
            # `-ef` follows symlinks and tests "same file" (inode), which works
            # for stow's relative symlinks AND any old absolute ones. Only
            # remove if it resolves somewhere other than the repo source.
            if ! [[ "$target" -ef "$src" ]]; then
                info "Removing existing symlink $target (was $(readlink "$target"))"
                rm "$target"
            fi
        fi
        # -type l too: catch any package file that is itself a symlink (plain
        # -type f skips those, leaving a real conflict at the target un-adopted).
    done < <(find "$DOTFILES_DIR/$pkg" \( -type f -o -type l \) -print0)
}

# Reject any trust-store path Homebrew would refuse to write, here and instantly,
# rather than three minutes into a `work` run. Mirrors trust.rb's write guard.
assert_trust_store_writable() {
    local link="$1" target
    if [[ ! -L "$link" ]]; then
        [[ -f "$link" ]] || { err "Homebrew trust store missing: $link"; exit 1; }
        return 0
    fi
    target="$(readlink "$link")"
    [[ "$target" == /* ]] || target="$(dirname "$link")/$target"
    if [[ -L "$target" ]]; then
        err "$link resolves to another symlink ($target)."
        err "Homebrew refuses to write a trust store behind two symlinks."
        exit 1
    fi
    [[ -f "$target" ]] || { err "$link does not resolve to a regular file ($target)"; exit 1; }
}

link_brew_trust_store() {
    local dir; dir="$(dirname "$BREW_TRUST_ALIAS")"
    mkdir -p "$dir"
    chmod go-w "$dir"   # trust.rb rejects a group/world-writable store directory
    if [[ -e "$BREW_TRUST_ALIAS" && ! -L "$BREW_TRUST_ALIAS" ]]; then
        info "Backing up $BREW_TRUST_ALIAS → $BREW_TRUST_ALIAS.backup"
        mv "$BREW_TRUST_ALIAS" "$BREW_TRUST_ALIAS.backup"
    fi
    ln -sfn "$BREW_TRUST_FILE" "$BREW_TRUST_ALIAS"
    assert_trust_store_writable "$BREW_TRUST_ALIAS"
    assert_trust_store_writable "$HOME/.config/homebrew/trust.json"
    ok "Homebrew trust store: $BREW_TRUST_ALIAS → $BREW_TRUST_FILE"
}

unlink_brew_trust_store() {
    [[ -L "$BREW_TRUST_ALIAS" && "$BREW_TRUST_ALIAS" -ef "$BREW_TRUST_FILE" ]] || return 0
    rm "$BREW_TRUST_ALIAS"
    ok "Unlinked $BREW_TRUST_ALIAS"
}

action="${1:-link}"
stow_flags=(--target="$HOME" --dir="$DOTFILES_DIR" --no-folding -v)

case "$action" in
    link)
        require_stow
        for pkg in "${STOW_PACKAGES[@]}"; do
            adopt_conflicts "$pkg"
        done
        stow "${stow_flags[@]}" --restow "${STOW_PACKAGES[@]}"
        ok "Stowed: ${STOW_PACKAGES[*]}"
        link_brew_trust_store
        ;;
    --restow|restow)
        require_stow
        stow "${stow_flags[@]}" --restow "${STOW_PACKAGES[@]}"
        ok "Restowed: ${STOW_PACKAGES[*]}"
        link_brew_trust_store
        ;;
    --delete|delete|uninstall)
        require_stow
        stow "${stow_flags[@]}" --delete "${STOW_PACKAGES[@]}"
        ok "Unstowed: ${STOW_PACKAGES[*]}"
        unlink_brew_trust_store
        ;;
    *)
        err "Unknown action: $action"
        echo "Usage: $0 [link|--restow|--delete]" >&2
        exit 2
        ;;
esac

echo
ok "Done. Reload your shell: exec zsh -l"
