# My Dotfiles 🔧

macOS 用の開発環境設定ファイル集です。Zsh, iTerm2, Starship を中心としたモダンな構成で、開発モチベーションを高めるための工夫が詰まっています。

## ✨ 特徴

- **Shell**: Zsh + [Starship](https://starship.rs/)
    - Git ブランチ・ステータス表示
    - Kubernetes Context/Namespace 表示
    - Node.js, Go, Rust 等のバージョン表示
- **Efficiency**:
    - `zoxide`: 頻度ベースのスマートなディレクトリ移動 (`z` コマンド)
    - `zsh-autosuggestions`: コマンド履歴からの入力補完
    - `eza`: アイコン付きのモダンな `ls`
    - `bat`: シンタックスハイライト付きの `cat`
    - `fzf`: 強力なファジー検索
- **DevTools**: kubectl, ghq, git などのエイリアス整備済み

## 📁 ディレクトリ構成

アプリごとにディレクトリを分割し、管理しやすくしています。

```
~/dotfiles
├── zsh/            # Zsh 関連 (.zshrc)
├── git/            # Git 関連 (.gitignore_global)
├── config/         # その他設定 (starship.toml)
├── install.sh      # セットアップスクリプト
└── ...
```

## 🛠 セットアップ手順 (Fresh Install)

新しい Mac をセットアップする際の手順です。

### 1. 前提条件

- macOS
- [Homebrew](https://brew.sh/) がインストールされていること

### 2. リポジトリの取得

ホームディレクトリ直下の `dotfiles` ディレクトリに配置することを想定しています。

```bash
git clone https://github.com/user/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. インストール (自動)

付属のスクリプトを実行すると、シンボリックリンクが自動的に作成されます。

```bash
chmod +x install.sh
./install.sh
```

### 4. 必須ツールのインストール

`.zshrc` で設定されている機能をフル活用するために、以下のツールを Homebrew でインストールします。

```bash
# 基本ツール
brew install git gh ghq fzf

# シェル拡張・モダンコマンド
brew install starship zsh-autosuggestions zoxide eza bat

# Kubernetes 関連 (必要に応じて)
brew install kubectl kubectx kube-ps1

# フォント (必須)
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

### 5. セットアップ完了

ターミナルを再起動するか、以下のコマンドで設定を読み込みます。

```bash
source ~/.zshrc
```

---

## 🎨 iTerm2 カスタマイズ

「イケてる」エンジニア仕様にするための究極のカスタマイズガイドは [iterm2.md](./iterm2.md) を参照してください。
