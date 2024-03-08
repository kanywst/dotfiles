#!/bin/bash

set -e

DOTFILES_DIR="$HOME/dotfiles"

echo "🚀 Setting up dotfiles..."

# Function to create symlink
link_file() {
    local src=$1
    local dst=$2

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ -L "$dst" ]; then
            local current_link=$(readlink "$dst")
            if [ "$current_link" == "$src" ]; then
                echo "✅  $dst already linked to $src"
                return
            fi
            echo "🗑️  Removing existing symlink $dst (was $current_link)"
            rm "$dst"
        else
            echo "⚠️  Backing up existing file $dst to $dst.backup"
            mv "$dst" "$dst.backup"
        fi
    fi

    echo "🔗 Linking $src to $dst"
    ln -s "$src" "$dst"
}

# Zsh
link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

# Git
link_file "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

# Starship
mkdir -p "$HOME/.config"
link_file "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"

echo "🎉 Dotfiles setup complete! Please restart your shell."
