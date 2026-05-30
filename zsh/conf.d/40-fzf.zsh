# 40-fzf.zsh — fzf integration

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || eza --tree --color=always {} 2>/dev/null"
  --preview-window=right:60%:wrap
  --bind "ctrl-/:toggle-preview"
  --bind "ctrl-d:half-page-down,ctrl-u:half-page-up"
'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="$FZF_DEFAULT_OPTS"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS='--preview "eza --tree --color=always --level=2 {}"'

# fzf shell integration. Modern fzf (>= 0.48) ships everything via `fzf --zsh`;
# cache the generated script to skip the subprocess on every shell start, and
# fall back to brew's shell scripts on older installs.
# Ctrl-T file, Alt-C cd; Ctrl-R is later handed to Atuin.
if command -v fzf &>/dev/null; then
    _fzf_cache="${XDG_CACHE_HOME:-$HOME/.cache}/fzf/init.zsh"
    # `whence -p` is a zsh builtin (no module required) returning the path
    # of an external command, or empty if there is none.
    _fzf_bin="$(whence -p fzf 2>/dev/null)"
    # Regenerate when the cache doesn't exist OR the fzf binary is newer than
    # the cache; `-e` (existence) — not `-s` (size) — so a previously-failed
    # generation (empty sentinel below) doesn't make us retry every shell.
    if [[ ! -e "$_fzf_cache" || ( -n "$_fzf_bin" && "$_fzf_bin" -nt "$_fzf_cache" ) ]]; then
        [[ -d "${_fzf_cache:h}" ]] || mkdir -p "${_fzf_cache:h}"
        # Atomic write: a Ctrl-C mid-generation leaves the old cache intact.
        _fzf_tmp="$(mktemp "${_fzf_cache}.XXXXXX")"
        if fzf --zsh > "$_fzf_tmp" 2>/dev/null; then
            mv -f "$_fzf_tmp" "$_fzf_cache"
        else
            rm -f "$_fzf_tmp"
            # Empty sentinel: marks "we tried, --zsh isn't supported here".
            # The binary mtime check above still re-triggers on a real upgrade.
            : > "$_fzf_cache"
        fi
        unset _fzf_tmp
    fi
    if [[ -s "$_fzf_cache" ]]; then
        source "$_fzf_cache"
    elif [[ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
        source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
    fi
    unset _fzf_cache _fzf_bin
fi
