# 30-modern-cli.zsh — Rust-based replacements for classic Unix tools

# zoxide — `cd` is shadowed; `zi` for interactive
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# eza — modern ls
if command -v eza &>/dev/null; then
    alias ls='eza --icons --git'
    alias ll='eza -l  --icons --git --group-directories-first --time-style=long-iso'
    alias la='eza -la --icons --git --group-directories-first --time-style=long-iso'
    alias lt='eza --tree --level=2 --icons --git'
    alias ltt='eza --tree --level=3 --icons --git'
    alias tree='eza --tree --icons'
fi

# bat — modern cat
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export BAT_THEME="TwoDark"
fi

# delta — git diff renderer; also stand-alone
command -v delta &>/dev/null && alias diff='delta'

# btop — modern top
command -v btop &>/dev/null && alias top='btop'

# xh — modern curl/httpie (Rust)
command -v xh &>/dev/null && alias http='xh'

# ast-grep — structural search/replace
command -v ast-grep &>/dev/null && alias sg='ast-grep'

# yazi — TUI file manager with auto-cd on exit
if command -v yazi &>/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# zellij — modern terminal multiplexer
command -v zellij &>/dev/null && alias zj='zellij'

# tldr (tlrc impl)
command -v tldr &>/dev/null || command -v tlrc &>/dev/null && alias help='tldr'

# glow — markdown viewer
command -v glow &>/dev/null && alias md='glow'
