# 60-functions.zsh — shell functions

# mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1"; }

# jump to the git toplevel of the current tree
groot() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "groot: not inside a git repo" >&2
        return 1
    }
    cd -- "$root"
}

# Extract any archive
extract() {
    if [[ ! -f "$1" ]]; then
        echo "extract: '$1' is not a valid file" >&2
        return 1
    fi
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz)         tar xJf "$1" ;;
        *.tar.zst|*.tzst) zstd -dc "$1" | tar -xf - ;;  # works on BSD tar (macOS) too
        *.tar)            tar xf  "$1" ;;
        # `-k` (keep) so the original archive survives — tar/unzip behave
        # the same way; bunzip2/gunzip/unzstd default to deleting the input.
        *.bz2)            bunzip2 -k "$1" ;;
        *.gz)             gunzip  -k "$1" ;;
        *.zst)            unzstd  -k "$1" ;;
        *.zip)            unzip   "$1" ;;
        *.7z)             7z x    "$1" ;;
        *.rar)            unrar x "$1" ;;
        *) echo "extract: unknown archive type '$1'" >&2; return 1 ;;
    esac
}

# Find process listening on a port: `port 3000`
port() {
    if [[ -z "$1" ]]; then echo "usage: port <number>" >&2; return 1; fi
    lsof -nP -iTCP:"$1" -sTCP:LISTEN
}

# Kill whatever is on a port: `killport 3000`
killport() {
    local pid
    pid="$(lsof -ti tcp:"$1")"
    if [[ -n "$pid" ]]; then
        kill -9 "$pid" && echo "killed $pid on :$1"
    else
        echo "nothing on :$1"
    fi
}

# .gitignore from gitignore.io
gi() {
    curl -sL "https://www.toptal.com/developers/gitignore/api/$*"
}

# fzf-powered process killer. `command ps` bypasses the ps→procs alias from
# 30-modern-cli.zsh; procs lacks the BSD `-ef` flags this picker needs.
fkill() {
    local pid
    pid="$(command ps -ef | sed 1d | fzf -m --header='[kill:process]' | awk '{print $2}')"
    [[ -n "$pid" ]] && echo "$pid" | xargs kill -"${1:-9}"
}

# fzf git-branch checkout with log preview
gcof() {
    local branch
    branch="$(git branch --all | sed 's/^[* ]*//;s|^remotes/origin/||' | sort -u \
        | fzf --preview 'git log --oneline --color=always {} | head -30')"
    [[ -n "$branch" ]] && git checkout "$branch"
}

# fzf worktree jump
gwt() {
    local wt
    wt="$(git worktree list | fzf | awk '{print $1}')"
    [[ -n "$wt" ]] && cd "$wt"
}

# fzf-pick a pod and exec into it
kex-fzf() {
    local pod
    pod="$(kubectl get pods --no-headers | fzf | awk '{print $1}')"
    [[ -n "$pod" ]] && kubectl exec -it "$pod" -- /bin/sh
}

# fzf-pick a pod and tail logs
klog-fzf() {
    local pod
    pod="$(kubectl get pods --no-headers | fzf | awk '{print $1}')"
    [[ -n "$pod" ]] && kubectl logs -f "$pod"
}
