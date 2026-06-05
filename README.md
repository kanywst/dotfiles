# kanywst / dotfiles

**English** | [日本語](README.ja.md)

![kanywst / dotfiles - synthwave macOS, 2026](assets/logo.png)

![tagline](https://readme-typing-svg.demolab.com/?font=Fira+Code&pause=700&color=00FFFF&width=620&height=44&lines=modern+macOS+dev+env;rust-flavoured+CLI+everywhere;atuin+%2B+fzf+%2B+starship;declarative+via+nix-darwin)

[![lint](https://github.com/kanywst/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/kanywst/dotfiles/actions/workflows/lint.yml)
![license](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

## TL;DR

```bash
git clone https://github.com/kanywst/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
exec zsh -l
```

`install.sh` is a thin GNU-stow wrapper. It links `zsh/`, `git/`,
`starship/` into `$HOME` and renames any colliding file to `*.backup` first.

## Why

- **No plugin-manager runtime**: zsh loads `conf.d/NN-*.zsh` by filename order. Nothing to break, nothing to update.
- **One runtime manager**: `mise` pins node / python / go / rust globally. NVM / pyenv / nodebrew retired.
- **One brew source of truth**: `flake.nix` declares the bundle. `darwin-rebuild switch` reconciles.
- **Secrets never enter tracked files**: `~/.zshrc.local` is sourced last by `.zshrc` and gitignored.

## What's inside

- Rust CLI: eza / bat / fd / ripgrep / delta / btop / zoxide / yazi / xh / ast-grep / procs / dust / sd / hyperfine / tokei / onefetch
- Atuin: sqlite-backed history with daemon, workspace filter, `Ctrl-R`
- mise + direnv: runtime pinning + per-directory env + repo tasks
- uv / bun: fast Python + JS package management
- nix-darwin: flake-driven macOS defaults + brew bundle
- GNU stow: modular `conf.d` zsh, no plugin manager
- Starship: k8s / docker / direnv / git status in the prompt
- fzf + fzf-tab + carapace: preview-driven completion across 500+ CLIs
- lazygit / lazydocker / k9s: TUIs for the obvious things
- ghq + fzf: `repo` jumps to anything on disk
- Ghostty: terminal config tracked (theme, splits, mac-alt)
- lefthook + gitleaks: fast parallel pre-commit hooks + secret scanning
- aichat: multi-model LLM CLI in the shell
- `work`: one-shot "update everything" CLI (nix-darwin + brew + rustup/mise/npm/krew/gh) with gum spinners
- jj (Jujutsu): git-compatible modern VCS, colocated with git per-repo
- AeroSpace: i3-like tiling WM (no SIP disable)
- Karabiner-Elements: Caps Lock → Hyper Key + hjkl arrow keys

## Stack

| Layer | Tool | Replaces |
| --- | --- | --- |
| Shell | zsh | - |
| Terminal | ghostty | iTerm2 / Alacritty / wezterm |
| Prompt | starship | oh-my-zsh themes |
| Completion | carapace + fzf-tab | per-tool completion scripts |
| History | atuin (daemon) | bare `history` + Ctrl-R |
| Listing | eza | ls |
| Pager-cat | bat | cat |
| Find | fd | find |
| Grep | ripgrep | grep |
| Sed | sd | sed (for safe rewrites) |
| Process | procs | ps |
| Disk usage | dust | du |
| Diff | delta | git's diff |
| Top | btop | top / htop |
| Bench | hyperfine | `time` loops |
| Code stats | tokei | cloc |
| Repo info | onefetch | manual `git log` summaries |
| HTTP | xh | curl / httpie |
| Cd | zoxide | cd + autojump |
| Fuzzy | fzf + fzf-tab | manual completion |
| Files TUI | yazi | ranger |
| Multiplex | zellij | tmux |
| Runtime | mise | nvm / pyenv / nodebrew |
| Per-dir env | direnv | hand-rolled `.env` sourcing |
| Python pkgs | uv | pip / poetry / virtualenv |
| JS runtime | bun | node + npm + tsx |
| Tasks | mise tasks | Makefile / justfile |
| Hooks | lefthook | husky / pre-commit (Python) |
| Secrets scan | gitleaks | manual `grep -i secret` |
| LLM CLI | aichat | one-off `curl` to API |
| VCS | jj (Jujutsu) + git | git alone |
| Tile WM | AeroSpace | yabai (needs SIP off) / Magnet |
| Keymap | Karabiner-Elements | macOS System Settings |
| App Store | mas | manual GUI installs |
| Updater | `work` (bin/) | ad-hoc `brew upgrade` / `nix flake update` runs |
| System | nix-darwin | manual `defaults write` |
| User env | home-manager (input wired) | stow only |
| Linker | GNU stow | hand-rolled `ln -s` scripts |

## Architecture

```mermaid
flowchart LR
    A[~/dotfiles] -->|install.sh| B[stow]
    B --> Z[~/.zshrc]
    B --> G[~/.gitignore_global]
    B --> S[~/.config/starship.toml]
    B --> AT[~/.config/atuin/config.toml]
    B --> GT[~/.config/ghostty/config]
    Z -->|sources| C[conf.d/*.zsh]
    C --> M[mise + direnv]
    C --> F[fzf + atuin]
    C --> P[starship]
    C --> CR[carapace]
    A -.->|optional| N[flake.nix]
    N -->|darwin-rebuild| H[Homebrew bundle]
    N -->|darwin-rebuild| D[macOS defaults]
    A -.->|optional| LH[lefthook.yml]
    LH --> HG[git hooks: zsh-n / markdownlint / gitleaks]
```

`zsh/conf.d/` is intentionally excluded from stow
(`zsh/.stow-local-ignore`) and sourced directly from
`$DOTFILES_ZSH_DIR/conf.d/`, so the loader is indifferent to symlink shape.

## Install

### 1. Clone

```bash
git clone https://github.com/kanywst/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. Stow

```bash
./install.sh             # link
./install.sh --restow    # re-link if symlinks drift
./install.sh --delete    # uninstall
```

If stow isn't installed, `brew install stow` runs automatically. Conflicting
files are renamed to `*.backup` before linking.

### 3. Tooling

```bash
# Core
brew install git gh ghq fzf jq yq stow direnv mas

# Rust-flavoured CLI
brew install starship zoxide eza bat fd ripgrep git-delta btop atuin xh \
             ast-grep yazi zellij procs dust sd hyperfine tokei onefetch \
             zstd

# Runtime + package managers
brew install mise uv bun

# Completion + hooks + security + lint
brew install carapace lefthook gitleaks shellcheck actionlint

# LLM CLI
brew install aichat

# Modern VCS + tile WM + keymap
brew install jj
brew install --cask nikitabobko/tap/aerospace karabiner-elements

# Zsh plugins
brew install zsh-autosuggestions zsh-syntax-highlighting fzf-tab

# Git / k8s / docker TUI
brew install lazygit lazydocker kubectl kubectx kubecolor k9s krew
gh extension install dlvhdr/gh-dash

# Nerd font (Starship requires it)
brew install --cask font-hack-nerd-font
```

### 4. Pin runtimes

```bash
mise use -g node@lts python@3.13 go@latest rust
```

### 5. Repo tasks + hooks

```bash
mise tasks ls           # list repo-level mise tasks
mise run lint           # zsh -n + shellcheck + markdownlint + actionlint
mise run install        # ./install.sh
mise run darwin-switch  # darwin-rebuild switch
mise run hooks          # lefthook install (writes .git/hooks/*)
mise run scan           # gitleaks detect on the full tree
```

`lefthook.yml` runs zsh-syntax, shellcheck, markdownlint, and
`gitleaks protect --staged` on pre-commit; `actionlint` + `nix flake check`
on pre-push.

### 6. Local secrets

```bash
cat > ~/.zshrc.local <<'EOF'
export GEMINI_API_KEY="..."
export OPENAI_API_KEY="..."
EOF
chmod 600 ~/.zshrc.local
```

### 7. (Optional) nix-darwin

`flake.nix` declaratively manages macOS system defaults and the Homebrew
bundle. `username` is resolved at runtime via `builtins.getEnv "USER"`, so no
account name is baked into the repo. Real switches need `--impure` to read
your `$USER`; pure eval (`nix flake check`) falls back to `user`. Select your
config with `#"$(whoami)"`.

```bash
sudo nix run github:LnL7/nix-darwin/master#darwin-rebuild -- switch \
  --flake ~/dotfiles#"$(whoami)"

darwin-rebuild switch --flake ~/dotfiles#"$(whoami)"
```

What it does:

- `system.defaults` entries → the equivalent `defaults write` runs (Dock autohide, Dark Mode, Finder hidden files, etc.)
- `brew install` against the `homebrew.brews / casks` lists (`cleanup = "none"`, so anything off-list is left alone)
- `~/.zshrc` / `~/.config/starship.toml` are left untouched (stow's territory)

To uninstall:

```bash
sudo nix run github:LnL7/nix-darwin/master#darwin-uninstaller
```

## Daily-driver reference

### Navigation

| Cmd | Action |
| --- | --- |
| `cd foo` | zoxide frecency jump |
| `..` / `...` / `....` | `cd ../..` etc. |
| `mkcd dir` | `mkdir -p && cd` |
| `Alt-C` | fzf dir picker |
| `Ctrl-T` | fzf file picker (insert) |

### Listing & viewing

| Cmd | Action |
| --- | --- |
| `ls` / `ll` / `la` / `lt` / `ltt` | eza variants |
| `cat` | bat |
| `top` | btop |
| `ps` | procs |
| `du` | dust |
| `diff` | delta |
| `tree` | eza --tree |

### Git

| Cmd | Action |
| --- | --- |
| `gs` / `gst` | status (short / full) |
| `ga` / `gap` | add / patch-add |
| `gc` / `gcm` / `gcs` | commit / -m / -s |
| `gca` / `gcan` | amend / amend --no-edit |
| `gd` / `gdc` | diff / diff --cached |
| `gl` / `gla` / `glo` | log graph / + all / last 20 |
| `gco` / `gcb` | checkout / -b |
| `gsw` / `gswc` | switch / switch -c |
| `gb` / `gbd` | branch / branch -d |
| `gp` / `gpf` | push / push --force-with-lease |
| `gpl` / `gfa` | pull --rebase / fetch --all --prune |
| `gss` / `gsp` | stash / stash pop |
| `gwl` / `gwa` / `gwr` | worktree list / add / remove |
| `gcv` / `gcam` | commit -v / commit -a -m |
| `gcf` / `gri` / `grc` / `gra` | commit --fixup / rebase -i / --continue / --abort |
| `lg` | lazygit |

### Jujutsu (jj), git-compatible

| Cmd | Action |
| --- | --- |
| `jjs` / `jjl` / `jjll` | status / log / log no-pager |
| `jjn` / `jje` / `jjd` | new / edit / diff |
| `jjp` / `jjf` | git push / git fetch --all-remotes |
| `jjsq` / `jjab` | squash / abandon |

Initialise jj inside an existing git repo (colocated):

```bash
cd <repo> && jj git init --colocate
```

### Git + fzf

| Cmd | Action |
| --- | --- |
| `gcof` | fzf branch checkout (log preview) |
| `gwt` | fzf worktree jump |
| `repo` / `g` | ghq + fzf repo jump |

### GitHub CLI

| Cmd | Action |
| --- | --- |
| `ghco` | fzf PR checkout |
| `ghpr` | `gh pr create --web` |
| `ghprl` / `ghprv` | PR list / view web |
| `ghd` | `gh dash` |

### Docker

| Cmd | Action |
| --- | --- |
| `d` | docker |
| `dc` / `dcu` / `dcd` | compose / up -d / down |
| `dcl` / `dcb` / `dcr` | logs -f / build / restart |
| `dps` / `dpsa` / `dimg` | formatted ps / ps -a / images |
| `dprune` | system prune -af --volumes |
| `ld` | lazydocker |

### Kubernetes

| Cmd | Action |
| --- | --- |
| `k` | kubecolor (color kubectl) |
| `ktx` / `kns` / `kkn` | kubectx / kubens / set ns |
| `kgp` / `kgpa` | get pods / -A |
| `kgs` / `kgd` / `kgi` / `kgn` / `kga` | get svc / deploy / ing / nodes / all |
| `kge` | events sorted by time |
| `kdp` / `kds` / `kdd` | describe pod / svc / deploy |
| `kl` / `klf` / `klp` | logs / -f / --previous |
| `kex` / `kpf` | exec -it / port-forward |
| `kaf` / `kdf` | apply -f / delete -f |
| `kw` | watch pods |
| `k9` | k9s TUI |
| `kex-fzf` / `klog-fzf` | fzf pod picker → exec / logs |

### Runtime / package managers

| Cmd | Action |
| --- | --- |
| `m` / `mr` / `mt` / `mu` / `ml` | mise / run / tasks ls / use / ls |
| `uvr` / `uva` / `uvs` / `uvi` / `uvp` | uv run / add / sync / init / pip |
| `br` / `bi` / `ba` / `bre` / `bd` / `bt` | bun run / install / add / remove / dev / test |

### AI + hooks + bench

| Cmd | Action |
| --- | --- |
| `ai` | aichat (multi-model LLM) |
| `ask "<task>"` | aichat -e: natural language → shell |
| `lh` | lefthook |
| `glk` | gitleaks detect (redacted) |
| `hf` | hyperfine benchmark |
| `onef` | onefetch repo summary |
| `ast` | atuin stats |

### Functions

| Cmd | Action |
| --- | --- |
| `mkcd <dir>` | mkdir + cd |
| `groot` | jump to git toplevel |
| `extract <file>` | auto-detect archive extractor (tar/zip/zst/7z/…) |
| `port <num>` | who's listening on a port |
| `killport <num>` | kill the listener |
| `gi <stack>` | gitignore.io fetcher |
| `fkill` | fzf process killer |
| `avg [path]` | open in Antigravity |

### System

| Cmd | Action |
| --- | --- |
| `ports` | listening ports |
| `myip` / `localip` | global / en0 IP |
| `path` | `$PATH` one-per-line |
| `pbjson` | format clipboard JSON |
| `flushdns` | macOS DNS cache flush |
| `showfiles` / `hidefiles` | Finder hidden toggle |
| `reload` / `sz` / `ez` | reload shell / source / edit zshrc |

### Updating

`work` (in the `bin` stow package, linked to `~/.local/bin/work`) bumps
everything in one run. This box is nix-darwin declarative, so the system path is
`nix flake update` + `darwin-rebuild switch` — not a bare `brew upgrade`; the
per-user managers nix doesn't own are bumped alongside it. Output is hidden
behind a gum spinner per step and only surfaces on failure.

| Cmd | Action |
| --- | --- |
| `work` | update everything: nix-darwin → brew → rustup → mise → npm-g → krew → gh ext → atuin |
| `work -v` | same, but stream every command's output live |
| `work -h` | help |

Sudo is requested once up front (for the nix-darwin switch). `cargo`/`go`
binaries are intentionally left alone — no clean bulk-updater is installed.

### Key bindings

| Key | Action |
| --- | --- |
| `Ctrl-R` | Atuin full-text history |
| `Ctrl-T` | fzf file insert |
| `Alt-C` | fzf cd |
| `Ctrl-/` | fzf preview toggle |
| `↑` / `↓` | prefix-search history |
| `Ctrl-←` / `Ctrl-→` | word-jump |
| `Ctrl-X Ctrl-E` | edit current command line in `$EDITOR` |
| `Caps Lock` (tap) | Escape (Karabiner) |
| `Caps Lock` (hold) | Hyper Key (cmd+ctrl+opt+shift) |
| `Hyper + h/j/k/l` | arrow keys |

### AeroSpace (tiling WM)

| Key | Action |
| --- | --- |
| `Alt + h/j/k/l` | focus left/down/up/right |
| `Alt-Shift + h/j/k/l` | move window |
| `Alt + 1..9` | switch workspace |
| `Alt-Shift + 1..9` | move window to workspace |
| `Alt + /` / `,` | tiles / accordion layout |
| `Alt + f` | fullscreen |
| `Alt-Shift + space` | toggle floating / tiling |
| `Alt-Shift + q` | close window |
| `Alt-Shift + c` | reload AeroSpace config |

## Design notes

- `.zshrc` is a 30-line loader; real config lives in `zsh/conf.d/NN-*.zsh`. Prefix decides load order (`00-env` → `99-local`).
- `typeset -U path PATH` dedupes `PATH` automatically.
- NVM / nodebrew / pyenv are retired; only `mise activate zsh` runs.
- `$BREW_PREFIX` is cached once per shell to skip 50-100 ms of `brew --prefix`.
- `compinit` rebuilds its dump at most once per 24 h.
- Atuin owns Ctrl-R only (`--disable-up-arrow`); ↑ stays as zsh prefix-search.
- `conf.d/` is excluded from stow and sourced from `$DOTFILES_ZSH_DIR/conf.d/`.
- Secrets live in `~/.zshrc.local`, gitignored, never tracked.

## Troubleshooting

Slow shell:

```bash
time zsh -i -c exit
zsh -xvs 2>&1 | ts -i "%.s" | sort -nr | head -20
```

Plugins not picked up:

```bash
echo "$BREW_PREFIX"
ls "$BREW_PREFIX/share/zsh-autosuggestions/"
ls "$BREW_PREFIX/share/zsh-syntax-highlighting/"
```

Stale completions:

```bash
rm -f "$XDG_CACHE_HOME/zsh/zcompdump-"*
exec zsh -l
```

## License

MIT.
