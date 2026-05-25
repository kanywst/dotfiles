# dotfiles

kanywst's macOS dotfiles. Modern Rust-based CLI stack, Starship prompt, Atuin
history, fzf-powered pickers everywhere.

## 特徴

- **Shell**: Zsh + [Starship](https://starship.rs/)
- **Modern CLI** (Rust-based replacements):
  - `eza` — `ls` with icons & git status
  - `bat` — `cat` with syntax highlighting
  - `fd` — fast `find`
  - `ripgrep` — fast `grep`
  - `zoxide` — frecency-based `cd` (replaces `cd` directly)
  - `delta` — better `git diff`
  - `btop` — modern `top`
- **History**: [Atuin](https://atuin.sh/) — SQLite-backed, full-text Ctrl-R
- **Fuzzy finding**: `fzf` with `bat`/`eza` previews on Ctrl-T, Alt-C, Ctrl-R
- **Git**: `lazygit` TUI + `delta` diffs + 30+ aliases
- **Kubernetes**: `kubecolor` + `kubectx` + `k9s` + 20+ aliases
- **Plugins**: `zsh-autosuggestions`, `zsh-syntax-highlighting`

## Setup

### 1. リポジトリ取得

```bash
git clone https://github.com/kanywst/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. インストール

```bash
chmod +x install.sh
./install.sh
```

### 3. 必須ツール

```bash
# Core
brew install git gh ghq fzf jq yq

# Modern CLI
brew install starship zoxide eza bat fd ripgrep git-delta btop atuin

# Zsh plugins
brew install zsh-autosuggestions zsh-syntax-highlighting

# Git / GitHub TUI
brew install lazygit

# Kubernetes
brew install kubectl kubectx kube-ps1 kubecolor k9s krew

# Font (Starship needs Nerd Font)
brew install --cask font-hack-nerd-font
```

### 4. オプション (2026 で人気)

```bash
# 統合バージョン管理 (nvm/pyenv/rustup を一本化したいなら)
brew install mise

# ディレクトリごとの env (mise を入れるなら不要)
brew install direnv

# Docker/Podman TUI
brew install lazydocker

# tldr (man の代替)
brew install tlrc

# モダン curl
brew install httpie
```

### 5. ローカル secrets

API キーなど tracked file に書きたくないものは `~/.zshrc.local` に置く。
`.zshrc` 末尾で自動 source される。

```bash
cat > ~/.zshrc.local << 'EOF'
export GEMINI_API_KEY="..."
export OPENAI_API_KEY="..."
EOF
chmod 600 ~/.zshrc.local
```

### 6. 反映

```bash
source ~/.zshrc
```

## 使い方

### Navigation

| コマンド   | 動作                                   |
| ---------- | -------------------------------------- |
| `cd foo`   | zoxide — 過去訪問頻度で賢く jump       |
| `cd -`     | 直前のディレクトリへ                   |
| `..`       | `cd ..`                                |
| `...`      | `cd ../..`                             |
| `....`     | `cd ../../..`                          |
| `mkcd dir` | `mkdir -p dir && cd dir`               |
| `Alt-C`    | fzf でディレクトリを fuzzy 検索して cd |
| `Ctrl-T`   | fzf でファイル名を挿入                 |

### File / Listing

| コマンド | 動作                         |
| -------- | ---------------------------- |
| `ls`     | `eza --icons --git`          |
| `ll`     | long format, git status 付き |
| `la`     | hidden 含む                  |
| `lt`     | tree (2 階層)                |
| `ltt`    | tree (3 階層)                |
| `cat`    | `bat` (syntax highlighting)  |
| `top`    | `btop` (グラフィカル)        |
| `diff`   | `delta`                      |

### Git

| コマンド | 動作                                 |
| -------- | ------------------------------------ |
| `gs`     | `git status -sb` (短縮)              |
| `gst`    | `git status` (full)                  |
| `ga`     | `git add`                            |
| `gap`    | `git add -p` (パッチ単位で stage)    |
| `gc`     | `git commit`                         |
| `gcm`    | `git commit -m`                      |
| `gcs`    | `git commit -s` (signed-off)         |
| `gca`    | `git commit --amend`                 |
| `gcan`   | `git commit --amend --no-edit`       |
| `gco`    | `git checkout`                       |
| `gcb`    | `git checkout -b`                    |
| `gsw`    | `git switch`                         |
| `gswc`   | `git switch -c`                      |
| `gd`     | `git diff`                           |
| `gdc`    | `git diff --cached`                  |
| `gl`     | `git log --oneline --graph`          |
| `gla`    | `gl` + `--all`                       |
| `gp`     | `git push`                           |
| `gpf`    | `git push --force-with-lease` (安全) |
| `gpl`    | `git pull --rebase`                  |
| `gfa`    | `git fetch --all --prune`            |
| `gb`     | `git branch`                         |
| `gss`    | `git stash`                          |
| `gsp`    | `git stash pop`                      |
| `lg`     | lazygit TUI を起動                   |

### Git + fzf (interactive)

| コマンド     | 動作                                          |
| ------------ | --------------------------------------------- |
| `gcof`       | branch を fzf で選んで checkout (log preview) |
| `gwt`        | worktree を fzf で選んで cd                   |
| `fzfg`       | branch を fzf で選んで checkout (旧式)        |
| `repo` / `g` | ghq + fzf でリポジトリ jump                   |

### GitHub CLI

| コマンド | 動作                        |
| -------- | --------------------------- |
| `ghco`   | PR を fzf で選んで checkout |
| `ghpr`   | `gh pr create --web`        |
| `ghprl`  | `gh pr list`                |
| `ghprv`  | `gh pr view --web`          |

### Docker / Compose

| コマンド | 動作                     |
| -------- | ------------------------ |
| `d`      | `docker`                 |
| `dc`     | `docker compose`         |
| `dcu`    | `docker compose up -d`   |
| `dcd`    | `docker compose down`    |
| `dcl`    | `docker compose logs -f` |
| `dcb`    | `docker compose build`   |
| `dcr`    | `docker compose restart` |
| `dps`    | 整形済み `docker ps`     |
| `dpsa`   | `docker ps -a`           |
| `dimg`   | `docker images`          |
| `dprune` | 全消し (volumes 含む)    |

### Kubernetes

| コマンド   | 動作                                         |
| ---------- | -------------------------------------------- |
| `k`        | `kubecolor` (色付き kubectl)                 |
| `ktx`      | `kubectx` (cluster 切替)                     |
| `kns`      | `kubens` (namespace 切替)                    |
| `kkn`      | `k config set-context --current --namespace` |
| `kgp`      | `k get pods`                                 |
| `kgpa`     | `k get pods -A` (全 namespace)               |
| `kgs`      | `k get svc`                                  |
| `kgd`      | `k get deployment`                           |
| `kgi`      | `k get ingress`                              |
| `kgn`      | `k get nodes`                                |
| `kga`      | `k get all`                                  |
| `kge`      | events を時間順に                            |
| `kdp`      | `k describe pod`                             |
| `kl`       | `k logs`                                     |
| `klf`      | `k logs -f` (follow)                         |
| `klp`      | `k logs --previous` (前回 pod の log)        |
| `kex`      | `k exec -it`                                 |
| `kpf`      | `k port-forward`                             |
| `kaf`      | `k apply -f`                                 |
| `kw`       | `watch -n1 kubectl get pods`                 |
| `k9`       | `k9s` TUI                                    |
| `kex-fzf`  | fzf で pod 選んで shell に入る               |
| `klog-fzf` | fzf で pod 選んで logs -f                    |

### Functions

| コマンド         | 動作                                      |
| ---------------- | ----------------------------------------- |
| `mkcd <dir>`     | mkdir + cd                                |
| `extract <file>` | `.zip` `.tar.gz` `.7z` などを自動判別解凍 |
| `port <num>`     | port を listen しているプロセスを表示     |
| `killport <num>` | port にいるプロセスを kill                |
| `gi <stack>`     | gitignore.io から `.gitignore` 生成       |
| `fkill`          | プロセスを fzf で選んで kill              |
| `avg [path]`     | Antigravity でディレクトリを開く          |

例:

```bash
mkcd ~/projects/my-app
gi macos,node,vscode > .gitignore
killport 3000
extract release.tar.xz
```

### System

| コマンド                  | 動作                                     |
| ------------------------- | ---------------------------------------- |
| `ports`                   | listen 中の全 port を表示                |
| `myip`                    | グローバル IP                            |
| `localip`                 | en0 のローカル IP                        |
| `path`                    | `$PATH` を 1 行 1 エントリで表示         |
| `pbjson`                  | クリップボードの JSON を整形して書き戻し |
| `flushdns`                | macOS DNS キャッシュクリア               |
| `showfiles` / `hidefiles` | Finder で隠しファイル表示切替            |
| `reload`                  | `exec zsh -l` (シェル丸ごと再起動)       |
| `sz`                      | `source ~/.zshrc`                        |
| `ez`                      | `.zshrc` を `$EDITOR` で開く             |

### Key bindings

| キー                | 動作                                    |
| ------------------- | --------------------------------------- |
| `Ctrl-R`            | Atuin — 全履歴を全文検索                |
| `Ctrl-T`            | fzf でファイルを fuzzy 選択して挿入     |
| `Alt-C`             | fzf でディレクトリを fuzzy 選択して cd  |
| `Ctrl-/`            | fzf のプレビュー表示切替                |
| `↑` / `↓`           | プレフィックス一致で履歴検索            |
| `Ctrl-←` / `Ctrl-→` | 単語単位で移動                          |
| `Ctrl-X Ctrl-E`     | 現在のコマンドラインを `$EDITOR` で編集 |

## 設計メモ

- **PATH dedup**: `typeset -U path PATH` で自動的に重複を除去。
- **NVM lazy-load**: `node`/`npm`/`npx` 初回呼び出し時に nvm を遅延ロード。
  シェル起動が約 1 秒速くなる。
- **brew prefix キャッシュ**: `$BREW_PREFIX` を 1 度だけ計算。
- **compinit 1 日 1 回**: `zcompdump` の rebuild を 24h ごとに制限して起動を高速化。
- **secrets 分離**: `~/.zshrc.local` は git 管理外。tracked file に
  API key を書かない。

## トラブルシューティング

シェルが遅い時:

```bash
# 起動時間計測
time zsh -i -c exit

# プロファイル
zsh -xvs 2>&1 | ts -i "%.s" | sort -nr | head -20
```

プラグインが効かない時:

```bash
echo $BREW_PREFIX
ls $BREW_PREFIX/share/zsh-autosuggestions/
ls $BREW_PREFIX/share/zsh-syntax-highlighting/
```

完了補完が古い時:

```bash
rm -f "$XDG_CACHE_HOME/zsh/zcompdump-"*
exec zsh -l
```

## ライセンス

MIT
