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
        # NB: homebrew/trust.json is deliberately a *real* file in both
        # .homebrew/ and .config/homebrew/, NOT a symlink to its sibling —
        # Homebrew's trust-store writer refuses a symlink whose target is also a
        # symlink ("Refusing to write insecure trust store: target is a
        # symlink"), which aborts the brew step of `darwin-rebuild switch`.
        # darwin activation resolves the store at ~/.homebrew, interactive brew
        # at ~/.config/homebrew, so both paths ship the (identical) list.
    done < <(find "$DOTFILES_DIR/$pkg" \( -type f -o -type l \) -print0)
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
        ;;
    --restow|restow)
        require_stow
        stow "${stow_flags[@]}" --restow "${STOW_PACKAGES[@]}"
        ok "Restowed: ${STOW_PACKAGES[*]}"
        ;;
    --delete|delete|uninstall)
        require_stow
        stow "${stow_flags[@]}" --delete "${STOW_PACKAGES[@]}"
        ok "Unstowed: ${STOW_PACKAGES[*]}"
        ;;
    *)
        err "Unknown action: $action"
        echo "Usage: $0 [link|--restow|--delete]" >&2
        exit 2
        ;;
esac

echo
ok "Done. Reload your shell: exec zsh -l"
