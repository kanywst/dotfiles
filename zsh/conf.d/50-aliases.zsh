# 50-aliases.zsh — non-tool-specific aliases (nav / git / docker / k8s / system)

# ----- Navigation -----
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'
alias home='cd ~'

# ----- Git -----
alias gs='git status -sb'
alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias glo='git log --oneline -20'

alias ga='git add'
alias gap='git add -p'
alias gc='git commit'
alias gcm='git commit -m'
alias gcs='git commit -s'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'

alias gd='git diff'
alias gdc='git diff --cached'

alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gswc='git switch -c'
alias gb='git branch'
alias gbd='git branch -d'
alias grs='git restore'
alias grss='git restore --staged'

alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull --rebase'
alias gfa='git fetch --all --prune'

alias gss='git stash'
alias gsp='git stash pop'

alias gwl='git worktree list'
alias gwa='git worktree add'
alias gwr='git worktree remove'

alias gcv='git commit -v'
alias gcam='git commit -a -m'
alias gcf='git commit --fixup'
alias gri='git rebase -i'
alias gra='git rebase --abort'
alias grc='git rebase --continue'

command -v lazygit &>/dev/null && alias lg='lazygit'

# ----- GitHub CLI -----
alias ghco='gh pr checkout $(gh pr list | fzf | awk "{ print \$1 }")'
alias ghpr='gh pr create --web'
alias ghprl='gh pr list'
alias ghprv='gh pr view --web'
command -v gh &>/dev/null && alias ghd='gh dash'

# ghq + fzf — jump to a repo
alias repo='cd $(ghq list -p | fzf --preview "eza --tree --level=2 --color=always {} 2>/dev/null || ls -la {}")'
alias g='repo'

# Legacy fzf-git pickers (preserved)
alias fzfv='${EDITOR} $(fzf)'
alias fzfg='git checkout $(git branch | fzf)'
alias fzfk='kill -9 $(ps aux | fzf | awk "{print \$2}")'
alias fzfd='cd $(find * -type d | fzf)'
alias fzff='find . -type f | fzf'
alias lf='${EDITOR} $(ls -1 | fzf)'
alias cf='cd $(find . -type d | fzf)'

# ----- Docker / Podman -----
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcb='docker compose build'
alias dcr='docker compose restart'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dprune='docker system prune -af --volumes'

command -v podman &>/dev/null && alias p='podman'
command -v lazydocker &>/dev/null && alias ld='lazydocker'

# ----- Kubernetes -----
if command -v kubecolor &>/dev/null; then
    alias kubectl='kubecolor'
    alias k='kubecolor'
else
    alias k='kubectl'
fi

alias ktx='kubectx'
alias kns='kubens'
alias kkn='kubectl config set-context --current --namespace'
alias kk='kubectl krew'

alias kgp='k get pods'
alias kgpa='k get pods -A'
alias kgs='k get svc'
alias kgd='k get deployment'
alias kgi='k get ingress'
alias kgn='k get nodes'
alias kga='k get all'
alias kge='k get events --sort-by=.lastTimestamp'

alias kdp='k describe pod'
alias kds='k describe svc'
alias kdd='k describe deployment'

alias kl='k logs'
alias klf='k logs -f'
alias klp='k logs --previous'

alias kex='k exec -it'
alias kpf='k port-forward'
alias kaf='k apply -f'
alias kdf='k delete -f'
alias kw='watch -n1 -d kubectl get pods'

command -v k9s &>/dev/null && alias k9='k9s'

# ----- System / macOS -----
alias h='history'
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
alias myip='curl -s ifconfig.me; echo'
alias localip='ipconfig getifaddr en0'
alias reload='exec zsh -l'
alias sz='source ~/.zshrc'
alias ez='${EDITOR} ~/dotfiles/zsh/.zshrc'

alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO  && killall Finder'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias pbjson='pbpaste | jq . | pbcopy && echo "✓ formatted JSON in clipboard"'

# ----- Runtime / package managers (2026) -----

# mise
alias m='mise'
alias mr='mise run'
alias mt='mise tasks ls'
alias mu='mise use'
alias ml='mise ls'

# uv (Python) — `uvx` is already shipped as a binary by uv itself
if command -v uv &>/dev/null; then
    alias uvr='uv run'
    alias uva='uv add'
    alias uvs='uv sync'
    alias uvi='uv init'
    alias uvp='uv pip'
fi

# bun (JS)
if command -v bun &>/dev/null; then
    alias br='bun run'
    alias bi='bun install'
    alias ba='bun add'
    alias bre='bun remove'
    alias bd='bun dev'
    alias bt='bun test'
fi

# ----- AI -----
if command -v aichat &>/dev/null; then
    alias ai='aichat'
    alias ask='aichat -e'      # shell-command generator (English → shell)
fi

# ----- Hooks / security / bench -----
command -v lefthook  &>/dev/null && alias lh='lefthook'
command -v gitleaks  &>/dev/null && alias glk='gitleaks detect --no-banner --redact'
command -v hyperfine &>/dev/null && alias hf='hyperfine'
command -v onefetch  &>/dev/null && alias onef='onefetch'
command -v atuin     &>/dev/null && alias ast='atuin stats'

# ----- Misc -----
alias gemini-init='gemini "ls -R で構造を把握し、主要な設定ファイルを読み取った上で GEMINI.md を作成して。その際、プロジェクトの主要な処理フロー（例：リクエストからレスポンスまで）を把握し、Mermaid形式のシーケンス図（sequenceDiagram）を必ず含めて。回答は不要、ファイル保存のみ実行して。"'

# Antigravity launcher (CLI launcher symlink is dead; use `open -a`)
avg() { open -a Antigravity "${@:-.}"; }
